# خطة المعمارية الجديدة — Local-First POS

> الهدف: تحويل المشروع من **Cloud-First (Firestore)** إلى **Local-First (SQLite)** مع طبقة مزامنة قابلة للتبديل تخدم أربع باقات اشتراك (A/B/C/D) من نفس الكود الواحد.

---

## 1. المبدأ الحاكم (اقرأه قبل أي سطر كود)

**قاعدة بيانات SQLite المحلية هي مصدر الحقيقة الوحيد لكل جهاز (Single Source of Truth).**

كل عملية بيع، كل تعديل مخزون، كل قبض نقدي → يُكتب في SQLite **أولاً وفوراً داخل Transaction واحدة**، ثم تُلتقط لاحقاً من طبقة المزامنة وتُرسل للأجهزة الأخرى/السحابة.

النتيجة العملية:
- الكاشير **لا ينتظر الشبكة أبداً**. زر "إتمام البيع" يستجيب خلال ~5ms لا خلال 800ms.
- انقطاع الإنترنت = صفر تأثير على البيع.
- تكلفة Firebase تنخفض من "لكل قراءة/كتابة" إلى "صفر" في الباقات A/B، و"نسخة احتياطية باردة" في C.

هذا بالضبط ما فشل سابقاً عند استبدال `.snapshots()` بـ `.get().asStream()`: المشكلة لم تكن في الفكرة بل في أن Firestore ليس قاعدة بيانات محلية. **Drift يعطيك Streams حقيقية محلية** (`watch()`) تحل محل `.snapshots()` بشكل مطابق في السلوك وأسرع.

---

## 2. الطبقات (Layers)

```
┌─────────────────────────────────────────────────┐
│ presentation   (Widgets + Riverpod Providers)   │  لا يعرف شيئاً عن SQLite أو الشبكة
├─────────────────────────────────────────────────┤
│ domain         (Entities + Repository ABCs +    │  Dart نقي — بدون أي import لـ flutter
│                 UseCases + Policies)            │
├─────────────────────────────────────────────────┤
│ data           (Drift DAOs + RepositoryImpl +   │  الوحيد الذي يلمس SQL
│                 Outbox writer)                  │
├─────────────────────────────────────────────────┤
│ sync           (SyncEngine + Transport ABC)     │  لا يعرف الـ UI إطلاقاً
│   ├── transport_none   (باقة A)                 │
│   ├── transport_lan    (باقة B/C)               │
│   └── transport_cloud  (باقة D)                 │
└─────────────────────────────────────────────────┘
```

**القانون الأول:** `presentation` لا يستورد `drift` ولا `dio` ولا `web_socket_channel`. أبداً.
**القانون الثاني:** الـ UI **لا يعرف ما هي الباقة**. يقرأ `FeatureFlags` فقط.

---

## 3. هيكل الـ Monorepo المقترح

```
apps/
  po/                    # نقطة البيع (Windows + Android tablet)
  st/                    # تطبيق التاجر / الإدارة
  ua/                    # تطبيق المستخدم
  dash/                  # (جديد، باقة D) لوحة المتابعة عن بُعد — Flutter Web

packages/
  shared_models/         # موجود — Freezed entities + SyncMeta mixin
  shared_ui/             # موجود — يُرقّى إلى Design System كامل (انظر skill التصميم)
  pos_db/                # جديد — Drift: Tables, DAOs, Migrations, Seeds
  pos_domain/            # جديد — Repository interfaces + UseCases (Dart نقي)
  pos_data/              # جديد — تنفيذ الـ Repositories فوق pos_db + كتابة الـ Outbox
  pos_sync/              # جديد — SyncEngine + Transport ABC + Conflict policies
  pos_sync_lan/          # جديد — mDNS discovery + WebSocket host/peer
  pos_sync_cloud/        # جديد — REST/WS client + backup uploader
  pos_licensing/         # جديد — التحقق من الترخيص + FeatureFlags
  pos_printing/          # يُفصل من الكود الحالي (الطابعة الحرارية + PDF)
```

**الأداة:** `melos` لإدارة الحزم (`melos bootstrap`, `melos run gen`, `melos run test`).

### اتجاه الاعتماديات (Dependency Direction) — صارم
```
apps → pos_domain ← pos_data → pos_db
         ↑                       ↑
      pos_sync ─────────────────┘
      pos_licensing
```
`pos_domain` لا يعتمد على أي حزمة أخرى من حزماتك. هذا ما يجعل الاختبار سهلاً والتعديل آمناً.

---

## 4. اختيار التقنيات

| المهمة | الخيار | لماذا هذا وليس غيره |
|---|---|---|
| قاعدة البيانات المحلية | **Drift** (`drift` + `drift_flutter` + `sqlite3_flutter_libs`) | أنواع آمنة، Migrations منظّمة، و`watch()` يعطي Streams تفاعلية تحل محل `.snapshots()` تماماً. `sqflite` الخام يجبرك على كتابة SQL يدوياً بلا أمان أنواع. |
| التشفير على القرص (اختياري) | `sqlcipher_flutter_libs` | تبديل سطر واحد في الـ setup. مفيد لو زبون طلبها. |
| المعرّفات | **UUID v7** (`uuid` package) | مرتّب زمنياً + فريد عالمياً. `AUTOINCREMENT` يدمّر المزامنة (تصادم مفاتيح بين جهازين offline). |
| النماذج | Freezed + json_serializable (كما هو) | يبقى. يضاف `SyncMeta` لكل كيان قابل للمزامنة. |
| إدارة الحالة | Riverpod + hooks (كما هو) | يبقى. يُفضّل `riverpod_generator` للتوحيد. |
| التوجيه | go_router (كما هو) | يبقى. |
| الشبكة المحلية | `nsd` (mDNS) + `shelf` + `shelf_web_socket` + `web_socket_channel` | يعمل على Windows/Android/macOS. بديل احتياطي: UDP broadcast + إدخال IP يدوي. |
| السحابة (باقة D) | **Supabase** (Postgres + Realtime + RLS) أو VPS صغير + Postgres + Dart Frog | التسعير مرتبط بالحجم لا بعدد القراءات. Firestore يحاسبك على كل قراءة مستند — ونقطة بيع تولّد ملايين القراءات شهرياً. |
| النسخ الاحتياطي (باقة C) | تخزين S3-compatible (Cloudflare R2 / Backblaze B2) | تخزين بارد رخيص جداً؛ R2 بلا رسوم egress. |
| ما يبقى من Firebase | **FCM فقط** (+ Crashlytics اختياري) | مجاني عملياً. احذف `cloud_firestore` و`firebase_auth`. |

> ملاحظة تكلفة: احتفظ بـ Firebase Core فقط إن احتجت الإشعارات. حذف `cloud_firestore` يحل أيضاً مشكلة انهيار Windows التي عالجتها سابقاً بـ `cacheSizeBytes`، لأن السبب الجذري (Firebase C++ SDK) يختفي.

---

## 5. مسار الهجرة (Migration Path) — 7 مراحل قابلة للتسليم

كل مرحلة **تُسلَّم وتعمل** قبل بدء التالية. لا تفتح مرحلتين معاً.

| # | المرحلة | المخرج القابل للاختبار | تقدير |
|---|---|---|---|
| **M0** | تجميد وتوثيق | مخطط Firestore الحالي موثّق في `docs/legacy_schema.md` + سكربت تصدير كل بيانات زبون إلى JSON | 2–3 أيام |
| **M1** | `pos_db` | مخطط Drift كامل + Migrations + اختبارات DAO على قاعدة in-memory | 5–7 أيام |
| **M2** | `pos_domain` + `pos_data` | كل الـ Repositories منفذة فوق SQLite + سكربت استيراد JSON→SQLite | 7–10 أيام |
| **M3** | تبديل الـ UI | تطبيق `po` يعمل **بالكامل offline** على SQLite. Firestore معطّل بـ flag | 5–7 أيام |
| **M4** | الترخيص | `pos_licensing` + بوابات الميزات + باقة **A** جاهزة للبيع | 4–5 أيام |
| **M5** | مزامنة LAN | `pos_sync` + `pos_sync_lan` → باقتا **B** و**C** | 10–14 يوم |
| **M6** | السحابة | `pos_sync_cloud` + `dash` → باقة **D** | 12–18 يوم |

**اشحن A أولاً.** يمكنك بيع الباقة A بعد M4 وتمويل بقية التطوير منها.

### أسلوب الهجرة الآمن: الكتابة المزدوجة (Dual-Write)
في M3، للزبائن الحاليين (دار لندن، أنيقة مدينتي):
1. اكتب إلى SQLite (المصدر) **و** Firestore (ظل) لمدة 2–4 أسابيع.
2. شغّل سكربت مقارنة يومي: عدد الفواتير/المجاميع في الاثنين.
3. عند تطابق 100% لأسبوعين → اقطع Firestore.

لا تقطع Firestore ليلة واحدة. الفشل في POS يعني متجر متوقف.

---

## 6. قابلية التعديل (المطلب رقم 3)

هذه القواعد هي التي تجعل أي مطور — أو وكيل AI — يضيف ميزة دون كسر شيء:

1. **كل Feature = مجلد كامل بثلاث طبقات**
   ```
   features/inventory/
     domain/     inventory_repository.dart   (abstract)  · entities · usecases
     data/       inventory_repository_impl.dart · inventory_dao.dart
     presentation/  screens · widgets · providers
   ```
2. **عقد الاختبار (Contract Test):** كل `Repository` مجرّد له ملف اختبار مشترك واحد يُشغّل على التنفيذ الحقيقي وعلى الـ Fake. إضافة تنفيذ جديد = تمرير نفس الاختبار.
3. **لا Magic Strings:** أسماء الجداول والأعمدة من Drift المولّد فقط. مفاتيح الإعدادات في `SettingsKeys` enum.
4. **ADRs:** كل قرار معماري في `docs/adr/NNNN-عنوان.md` بصيغة: السياق / القرار / البدائل المرفوضة / النتائج.
5. **`AGENTS.md` في الجذر:** ليقرأه Antigravity وClaude Code وأي أداة قبل أي مهمة — يمنع إعادة اختراع ما هو موجود في `shared_ui`.
6. **Codegen موحّد:** `melos run gen` = `dart run build_runner build -d` على كل الحزم. لا أوامر يدوية متفرقة.
7. **ممنوع `print`** — استخدم `logger` مع مستويات، ووجّه الأخطاء إلى جدول `app_log` محلي حتى تستطيع سحب سجل من جهاز زبون.

---

## 7. ما الذي يتغيّر في الكود الحالي فعلياً؟

| الحالي | البديل | حجم التغيير |
|---|---|---|
| `FirebaseFirestore.instance.collection(...).snapshots()` | `db.watchInvoices(storeId)` | متوسط — تغيير في طبقة الـ repository فقط إن كانت مفصولة، وإلا فكل استدعاء |
| `Hive` box للتخزين المؤقت | جداول SQLite مباشرة (لم تعد هناك حاجة لطبقة cache منفصلة) | حذف — نقطة تبسيط كبيرة |
| `Hive` للإعدادات الصغيرة | جدول `settings` أو `shared_preferences` | صغير |
| `firebase_auth` | مستخدمون محليون في جدول `users` + PIN/هاش، وللباقة D: JWT من السيرفر | متوسط |
| `firebase_options.dart` | يبقى فقط لو أبقيت FCM | صغير |
| Freezed models | تبقى + يضاف `SyncMeta` | صغير |
| go_router / Riverpod | بلا تغيير | صفر |

**الخلاصة:** البنية الحالية (Feature-Driven + Riverpod + Freezed) ممتازة ولا تحتاج إعادة كتابة. أنت تستبدل **طبقة البيانات فقط** وتضيف **طبقة مزامنة**. هذا هو بالضبط العائد الذي دفعته سابقاً حين اخترت فصل الاهتمامات.

---

## 8. مخاطر يجب الاعتراف بها

1. **المزامنة أصعب مما تبدو.** 70% من أخطاء أنظمة POS متعددة الأجهزة تأتي من دمج خاطئ للمخزون. الحل المعتمد هنا (سجلات إضافة فقط Append-Only) يلغي فئة كاملة من هذه الأخطاء — لا تتجاوزه مهما بدا مغرياً.
2. **الباقة D تعني أنك أصبحت مشغّل بنية تحتية.** نسخ احتياطي، مراقبة، تحديثات أمنية، استجابة عند التعطل. سعّر ذلك ولا تعد بـ SLA لا تستطيع الوفاء به.
3. **الترخيص لن يمنع القرصنة** — يمنع النسخ العرضي فقط. لا تُفسد تجربة الزبون الدافع بحمايات عدوانية (انظر قاعدة فترة السماح في وثيقة الباقات).
4. **لا تهاجر ثلاثة تطبيقات دفعة واحدة.** ابدأ بـ `po` وحده.
