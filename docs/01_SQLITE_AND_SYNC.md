# SQLite + محرّك المزامنة — التصميم التفصيلي

---

## الجزء الأول: تصميم قاعدة البيانات

### 1.1 الشكل الموحّد لكل صف قابل للمزامنة

كل جدول قابل للمزامنة **يجب** أن يحتوي هذه الأعمدة الستة:

```sql
id           TEXT    PRIMARY KEY,          -- UUID v7 (مرتّب زمنياً)
store_id     TEXT    NOT NULL,
rev          INTEGER NOT NULL DEFAULT 1,   -- يزيد مع كل تعديل
updated_at   INTEGER NOT NULL,             -- epoch millis UTC
updated_by   TEXT    NOT NULL,             -- device_id
is_deleted   INTEGER NOT NULL DEFAULT 0    -- حذف ناعم (Tombstone)
```

**لماذا الحذف الناعم إجباري؟** لو حذفت صفاً فعلياً على جهاز، الجهاز الآخر لن يعرف أبداً أنه حُذف وسيعيد إرساله. الـ Tombstone يُنظَّف تلقائياً بعد 90 يوماً بمهمة صيانة.

في Drift اجعلها `mixin`:
```dart
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  IntColumn  get rev => integer().withDefault(const Constant(1))();
  IntColumn  get updatedAt => integer()();
  TextColumn get updatedBy => text()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}
```

### 1.2 الجداول الأساسية

**بيانات رئيسية (Master Data) — سياسة الدمج: آخر كاتب يفوز لكل حقل**
```
stores, users, roles, categories, products, product_variants,
units, price_lists, customers, suppliers, payment_methods, settings, devices
```

**بيانات حركية (Transactional) — غير قابلة للتعديل بعد الإغلاق**
```
invoices              (رأس الفاتورة — status: draft | closed | voided)
invoice_lines         (سطور — لا تُعدّل بعد closed)
purchases, purchase_lines
returns, return_lines  (التصحيح يكون بوثيقة إرجاع، لا بتعديل الفاتورة)
```

**دفاتر إضافة فقط (Append-Only Ledgers) — لا تعارض ممكن إطلاقاً**
```sql
CREATE TABLE stock_moves (          -- كل حركة مخزون سطر جديد
  id TEXT PRIMARY KEY, store_id TEXT, variant_id TEXT,
  qty_delta INTEGER NOT NULL,       -- موجب أو سالب (بوحدات صحيحة)
  reason TEXT NOT NULL,             -- sale|purchase|return|adjust|transfer|count
  ref_type TEXT, ref_id TEXT,
  occurred_at INTEGER, device_id TEXT,
  ...SyncColumns
);

CREATE TABLE cash_moves (           -- كل حركة صندوق سطر جديد
  id TEXT PRIMARY KEY, store_id TEXT, shift_id TEXT,
  amount_minor INTEGER NOT NULL,    -- موجب/سالب، بالوحدة الصغرى
  kind TEXT NOT NULL,               -- sale|refund|payin|payout|open|close
  ...
);

CREATE TABLE shifts (id, store_id, user_id, opened_at, closed_at, opening_minor, closing_minor, ...);
```

**جداول البنية التحتية (لا تُزامَن)**
```sql
sync_outbox, sync_applied, sync_log, sync_peers, device_identity, app_log
```

**جداول مشتقة (Cache) — تُبنى محلياً، لا تُرسَل أبداً**
```sql
CREATE TABLE stock_balance (variant_id TEXT PRIMARY KEY, store_id TEXT, qty INTEGER, updated_at INTEGER);
```
تُحدَّث داخل نفس الـ Transaction التي تكتب `stock_moves`. لو تشوّشت، أعد بناءها بـ `SUM(qty_delta)` — عملية آمنة تماماً.

### 1.3 قواعد لا تتفاوض عليها

1. **النقود = أعداد صحيحة.** `amount_minor INTEGER`. لا `double` أبداً. الفواصل العشرية في العملة تنتج فروق قروش تُفسد المطابقة.
2. **الكميات = أعداد صحيحة** مع `scale` لكل وحدة (مثلاً 3 أرقام → 1.250 كغم تُخزَّن `1250`).
3. **الوقت = epoch millis UTC.** لا نصوص، ولا توقيت محلي في قاعدة البيانات. التحويل في طبقة العرض فقط.
4. **أرقام الفواتير لا تتصادم offline:** كل جهاز له `device_code` من 2–3 أحرف يُمنح عند الإقران → `P1-000123`. لا تستخدم عدّاداً عالمياً مشتركاً.
5. **الفاتورة المغلقة لا تُعدَّل.** الإلغاء `voided` يكتب حركات معاكسة، ولا يمسح السطور. هذا شرط محاسبي وشرط مزامنة في آن واحد.
6. **الفهارس المطلوبة:** `(store_id, updated_at)` على كل جدول مزامَن، `(store_id, occurred_at)` على الدفاتر، `(barcode)` فريد على المتغيرات، `(status, created_at)` على `sync_outbox`.

---

## الجزء الثاني: محرّك المزامنة

### 2.1 نمط الصندوق الصادر (Outbox Pattern)

```sql
CREATE TABLE sync_outbox (
  op_id      TEXT PRIMARY KEY,   -- UUID v7
  entity     TEXT NOT NULL,      -- 'invoices'
  entity_id  TEXT NOT NULL,
  op         TEXT NOT NULL,      -- upsert | delete | append
  payload    TEXT NOT NULL,      -- JSON للصف كاملاً
  created_at INTEGER NOT NULL,
  attempts   INTEGER NOT NULL DEFAULT 0,
  status     TEXT NOT NULL DEFAULT 'pending'  -- pending|sent|acked|failed
);

CREATE TABLE sync_applied (op_id TEXT PRIMARY KEY, applied_at INTEGER);  -- منع التطبيق المكرر
CREATE TABLE sync_log    (seq INTEGER PRIMARY KEY AUTOINCREMENT, op_id TEXT, payload TEXT, at INTEGER);
CREATE TABLE sync_peers  (peer_id TEXT PRIMARY KEY, last_seq INTEGER, last_seen_at INTEGER);
```

**القاعدة الحديدية:** كل كتابة على بيانات المستخدم تحدث داخل **Transaction واحدة** تشمل:
`تعديل الجدول` + `إدراج سطر في sync_outbox`.
إذا نجحت الكتابة ولم يُدرَج الـ op → ضياع بيانات صامت. إذا أُدرج الـ op وفشلت الكتابة → شبح. الـ Transaction تمنع الاثنين.

اجعل ذلك مستحيل النسيان: **ممنوع على أي كود خارج `pos_data` أن يستدعي `db.into(...)` أو `db.update(...)` مباشرة.** كل شيء يمر عبر:
```dart
Future<T> writeSynced<T>(Future<T> Function(SyncWriter w) body);
```

### 2.2 سياسة حل التعارض — لكل كيان سياسته

| نوع البيانات | السياسة | السبب |
|---|---|---|
| Master data (منتجات، أسعار، زبائن) | **LWW لكل حقل** بـ `updated_at`، وعند التساوي يفوز `device_id` الأكبر معجمياً | التعديل نادر ومتزامن الحدوث أندر |
| Ledgers (stock_moves, cash_moves) | **دمج بالإضافة** — لا تعارض أصلاً، كل عملية سطر مستقل | مجموع الحركات مستقل عن الترتيب |
| Invoices | **إنشاء فقط** — لا تعديل بعد الإغلاق | يزيل التعارض من الجذر |
| Settings | LWW على مستوى المفتاح، والجهاز المضيف له أولوية | تجنّب "حرب إعدادات" بين الأجهزة |
| Shifts | مالك الوردية (الجهاز الذي فتحها) هو المخوّل الوحيد بإغلاقها | منطق عمل لا تقني |

**لا تستخدم سياسة عامة واحدة.** ضعها كـ enum في `pos_sync`:
```dart
enum MergePolicy { lastWriteWins, appendOnly, createOnly, hostWins }
const entityPolicies = <String, MergePolicy>{ 'products': MergePolicy.lastWriteWins, ... };
```

### 2.3 واجهة النقل المجرّدة — قلب التصميم

```dart
abstract class SyncTransport {
  Stream<LinkState> get link;                       // offline|connecting|online|degraded
  Future<void> push(List<SyncOp> ops);
  Stream<SyncBatch> incoming();                     // دفعات واردة مع seq
  Future<SyncBatch> pull({required int sinceSeq});
  Future<SnapshotHandle> requestSnapshot();         // لجهاز جديد
  Future<void> close();
}
```

التنفيذات:
- `NoopTransport` — باقة A. يبتلع كل شيء بصمت.
- `LanHostTransport` / `LanPeerTransport` — باقات B/C.
- `CloudTransport` — باقة D.
- `CompositeTransport([lan, cloud])` — باقة D الحقيقية: **يعمل على LAN حتى لو سقط الإنترنت، ويصالح السحابة عند العودة.** هذه هي ميزتك البيعية الأقوى.

`SyncEngine` واحد فقط يعمل فوق أي منها. **إضافة باقة جديدة مستقبلاً = كتابة Transport جديد، لا لمس أي شيء آخر.**

### 2.4 بروتوكول الشبكة المحلية (LAN)

**الاكتشاف:** المضيف يعلن خدمة mDNS باسم `_satpos._tcp` على المنفذ `8765` مع TXT: `store_id`, `host_name`, `ver`.
بديل احتياطي (شبكات تحجب mDNS — شائع في راوترات بعض المقاهي): UDP broadcast على `255.255.255.255:8766` كل 3 ثوانٍ + خيار إدخال IP يدوياً. **نفّذ الاحتياطي من اليوم الأول، ستحتاجه.**

**الإقران (Pairing):** المضيف يعرض رمزاً من 6 أرقام صالحاً 5 دقائق → الجهاز الجديد يرسله مع بصمته → المضيف يصدر `device_token` (HMAC) يُحفَظ في `flutter_secure_storage` → يُمنح `device_code` لترقيم الفواتير.

**الاتصال:** WebSocket دائم. إطارات JSON:
```jsonc
{"t":"hello","device":"...","ver":1}
{"t":"auth","token":"..."}
{"t":"push","ops":[...]}                  // peer → host
{"t":"ack","op_ids":[...],"seq":10432}    // host → peer
{"t":"bcast","ops":[...],"seq":10433}     // host → كل الأقران
{"t":"pull","since":10400}                // peer → host بعد إعادة الاتصال
{"t":"ping"} / {"t":"pong"}               // كل 15 ثانية
```

**المضيف هو مصدر الحقيقة داخل الشبكة** ويمنح `seq` تصاعدياً في `sync_log`. الأقران يلحقون بالـ `seq`. هذا يجعل إعادة الاتصال تافهة: "أعطني ما بعد 10400".

**تعيين المضيف يدوي لا تلقائي.** في المتجر يوجد حاسوب يبقى شغالاً — اجعله المضيف بإعداد صريح "الجهاز الرئيسي". الانتخاب التلقائي (Raft/Bully) تعقيد لا يحتاجه متجر بـ 4 أجهزة، ويسبب حالات "مضيفان" مربكة.

**عند فقد المضيف:** الأقران يواصلون البيع محلياً (Outbox يتراكم) + شريط تنبيه "غير متصل بالجهاز الرئيسي — N عملية بانتظار المزامنة". لا توقف البيع أبداً.

**جهاز جديد ينضم:** لا تشغّل 40 ألف op. المضيف ينفّذ `VACUUM INTO` لنسخة متسقة → يرسلها مضغوطة عبر HTTP على نفس المنفذ → الجهاز يستوردها ثم يبدأ الدلتا من `seq` الحالي.

### 2.5 السحابة

**باقة C — نسخ احتياطي فقط (رخيص جداً)**
1. المضيف فقط يرفع. مرة يومياً + عند إغلاق آخر وردية.
2. `VACUUM INTO backup.db` → gzip → تشفير AES-GCM (مفتاح مشتق من سر المتجر عبر `cryptography`) → رفع إلى تخزين S3-compatible.
3. المسار: `store/{store_id}/{yyyy-MM-dd}.db.gz.enc`
4. الاحتفاظ: 30 يومية + 12 شهرية. حجم نسخة متجر متوسط بعد الضغط: بضعة ميغابايتات.
5. **اختبر الاستعادة شهرياً بشكل آلي.** نسخة احتياطية غير مُختبَرة ليست نسخة احتياطية.

**باقة D — مزامنة لحظية**
اجعل واجهة السحابة **مطابقة لبروتوكول LAN** (نفس أسماء الإطارات، نفس منطق `seq`). عندها `CloudTransport` يصبح نسخة شبه حرفية من `LanPeerTransport` — وهذا يوفّر عليك أسابيع.

بنية موصى بها:
- Postgres (جدول `ops` مقسّم حسب `store_id`، مع `seq BIGSERIAL` لكل متجر).
- نقطتان فقط: `POST /sync/push` و `WS /sync/stream?since=`.
- مصادقة: JWT قصير العمر مقابل `device_token`.
- عزل المستأجرين: `store_id` في كل صف + Row Level Security.
- لوحة `dash` تقرأ تجميعات جاهزة (مبيعات اليوم، أفضل المنتجات، حالة الأجهزة)، لا الصفوف الخام.

### 2.6 اختبارات لا يُشحن بدونها

1. **جهازان وهميان في نفس الاختبار:** كلاهما يبيع نفس المنتج offline، ثم يتصلان → يجب أن يكون المخزون النهائي = `الابتدائي − المجموع` بالضبط.
2. **تكرار الرسائل:** أرسل نفس الـ op ثلاث مرات → أثر واحد فقط (بفضل `sync_applied`).
3. **قطع في منتصف الدفعة:** أغلق الاتصال بعد إرسال نصف الـ ops → لا ضياع ولا تكرار بعد إعادة الاتصال.
4. **ساعة منحرفة:** جهاز متأخر ساعتين → الترتيب يبقى صحيحاً (استخدم `seq` من المضيف للترتيب، و`updated_at` للدمج فقط).
5. **اختبار استعادة نسخة احتياطية** من ملف مشفّر إلى قاعدة عاملة.
