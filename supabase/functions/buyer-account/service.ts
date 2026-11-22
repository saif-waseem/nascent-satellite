import { importPKCS8, SignJWT } from "npm:jose@5.10.0";

const project = "my-store-b0723";
const db = "projects/" + project + "/databases/(default)/documents";
const api = "https://firestore.googleapis.com/v1/" + db;
const days10 = 10 * 24 * 3600 * 1000;
type Fields = Record<string, any>;
const str = (v: string) => ({ stringValue: v });
const field = (d: Fields | undefined, k: string) =>
  d?.fields?.[k]?.stringValue ?? "";
const doc = (coll: string, id: string) => db + "/" + coll + "/" + id;
const idOk = (s: unknown) =>
  typeof s === "string" && /^[a-zA-Z0-9_-]{1,150}$/.test(s);
class Failure extends Error {
  constructor(public status: number, msg: string) {
    super(msg);
  }
}
function requireThat(ok: unknown, status: number, msg: string) {
  if (!ok) throw new Failure(status, msg);
}
async function rpc(name: string, args: unknown) {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const response = await fetch(
    Deno.env.get("SUPABASE_URL") + "/rest/v1/rpc/" + name,
    {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: "Bearer " + key,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(args),
    },
  );
  requireThat(response.ok, 503, "خدمة الحسابات غير متاحة");
  return await response.json();
}
let access = "", until = 0;
async function google() {
  if (Date.now() < until) return access;
  const raw = await rpc("buyer_service_configuration", {});
  requireThat(raw, 503, "خدمة إدارة الحسابات قيد الإعداد");
  const sa = JSON.parse(raw!);
  requireThat(sa.project_id === project, 503, "إعداد المشروع غير مطابق");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/datastore",
  }).setProtectedHeader({ alg: "RS256" })
    .setIssuer(sa.client_email).setAudience(
      "https://oauth2.googleapis.com/token",
    ).setIssuedAt().setExpirationTime("55m")
    .sign(await importPKCS8(sa.private_key, "RS256"));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  requireThat(r.ok, 503, "تعذر اتصال خدمة الحسابات");
  access = (await r.json()).access_token;
  until = Date.now() + 3000000;
  return access;
}
async function request(path: string, method = "GET", body?: unknown) {
  return await fetch("https://firestore.googleapis.com/v1/" + path, {
    method,
    headers: {
      Authorization: "Bearer " + await google(),
      "Content-Type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}
async function read(name: string) {
  const r = await request(name);
  if (r.status === 404) return null;
  requireThat(r.ok, 503, "تعذر فحص الحساب");
  return await r.json();
}
const put = (name: string, fields: Fields, prior: Fields | null) => ({
  update: { name, fields },
  currentDocument: prior ? { updateTime: prior.updateTime } : { exists: false },
});
const remove = (d: Fields) => ({
  delete: d.name,
  currentDocument: { updateTime: d.updateTime },
});
async function commit(writes: unknown[]) {
  const r = await request(db + ":commit", "POST", { writes });
  requireThat(
    r.ok,
    r.status === 409 ? 409 : 503,
    "تعذّر حفظ التغيير. أعد المحاولة.",
  );
}
async function query(collectionId: string, where: unknown, limit = 100) {
  const r = await request(db + ":runQuery", "POST", {
    structuredQuery: { from: [{ collectionId }], where, limit },
  });
  requireThat(r.ok, 503, "تعذرت قراءة السجلات");
  return (await r.json()).flatMap((x: Fields) =>
    x.document ? [x.document] : []
  );
}
const filter = (k: string, op: string, value: unknown) => ({
  fieldFilter: { field: { fieldPath: k }, op, value },
});
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization,apikey,content-type,x-buyer-token",
  "Content-Type": "application/json",
};
async function user(token: string) {
  const key = "AIzaSyCjmGWBANCyPt3sFF6L7Cxp1N1I_w_E5Ws";
  const r = await fetch(
    "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + key,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken: token }),
    },
  );
  requireThat(r.ok, 401, "سجّل الدخول بالبريد مجددًا");
  const u = (await r.json()).users?.[0];
  requireThat(
    u?.emailVerified === true && !u.disabled,
    403,
    "أكّد بريدك الإلكتروني ثم حاول مجددًا",
  );
  return { uid: u.localId as string, email: String(u.email).toLowerCase() };
}
async function isReviewer(tenant: string, email: string) {
  return await rpc("is_buyer_reviewer", {
    p_tenant: tenant,
    p_email: email,
  }) === true;
}
export function lifecycle(deps = { read, commit, query, isReviewer, request }) {
  const {
    read: readDoc,
    commit: writeDocs,
    query: findDocs,
    isReviewer: canReview,
    request: callFirestore,
  } = deps;
  async function purge(d: Fields) {
    const key = d.name.split("/").pop();
    const profile = await readDoc(doc("users", key));
    if (!profile || field(profile, "accountState") !== "pendingDeletion") {
      throw new Failure(409, "تغيرت حالة الحساب");
    }
    const expires = Date.parse(d.fields.expiresAt.timestampValue);
    requireThat(Date.now() >= expires, 409, "مهلة الاستعادة سارية");
    // Redact buyer contact data while retaining the merchant's financial order.
    const orders = await findDocs(
      "orders",
      filter("userId", "EQUAL", str(key)),
    );
    if (orders.length) {
      await writeDocs(orders.map((o: Fields) => ({
        update: {
          name: o.name,
          fields: {
            userId: str("deleted-" + crypto.randomUUID()),
            userName: str("مشتري محذوف"),
            userPhone: str(""),
            address: str(""),
            landmark: str(""),
            isHiddenForUser: { booleanValue: true },
          },
        },
        updateMask: {
          fieldPaths: [
            "userId",
            "userName",
            "userPhone",
            "address",
            "landmark",
            "isHiddenForUser",
          ],
        },
        currentDocument: { updateTime: o.updateTime },
      })));
    }
    const sub = await callFirestore(
      db + "/users/" + key + "/daily_stats?pageSize=100",
    );
    requireThat(sub.ok, 503, "تعذر حذف بيانات الحساب");
    const stats = (await sub.json()).documents ?? [];
    if (stats.length) await writeDocs(stats.map(remove));
    if (orders.length === 100 || stats.length === 100) return;
    const binding = await readDoc(doc("buyer_identity", key));
    await writeDocs([
      remove(profile),
      remove(d),
      ...(binding ? [remove(binding)] : []),
    ]);
  }
  async function act(input: Fields, actor: { uid: string; email: string }) {
    const tenant = input.tenant;
    requireThat(idOk(tenant), 400, "متجر غير صالح");
    if (input.action === "reviews") {
      requireThat(
        await canReview(tenant, actor.email),
        403,
        "الحساب غير مخوّل لهذا المتجر",
      );
      const docs = await findDocs(
        "buyer_review_requests",
        filter("tenant", "EQUAL", str(tenant)),
      );
      return {
        requests: docs.map((r: Fields) => ({
          phone: field(r, "phone"),
          email: field(r, "email"),
          id: r.name.split("/").pop(),
        })),
      };
    }
    const phone = input.phone;
    requireThat(
      typeof phone === "string" && /^\d{8,15}$/.test(phone),
      400,
      "رقم غير صالح",
    );
    const key = tenant + "_" + phone;
    const p = doc("users", key),
      b = doc("buyer_identity", key),
      q = doc("buyer_review_requests", key),
      a = doc("buyer_deletions", key);
    const [profile, binding, review, archive] = await Promise.all([
      readDoc(p),
      readDoc(b),
      readDoc(q),
      readDoc(a),
    ]);
    if (input.action === "register") {
      if (
        profile && binding && field(binding, "uid") === actor.uid && !archive
      ) {
        return {};
      }
      requireThat(
        !profile && !binding && !archive,
        409,
        "رقم الهاتف مسجل بالفعل",
      );
      const name = String(input.name ?? "").trim(),
        address = String(input.address ?? "").trim();
      requireThat(
        name.length > 0 && name.length <= 200 && address.length >= 5 &&
          address.length <= 1000,
        400,
        "راجع الاسم والعنوان",
      );
      const store = await readDoc(doc("tenants", tenant));
      requireThat(store, 404, "المتجر غير موجود");
      const referral = String(input.referral ?? "").trim();
      const writes: unknown[] = [];
      if (referral) {
        const sponsors = await findDocs("users", {
          compositeFilter: {
            op: "AND",
            filters: [
              filter("tenantId", "EQUAL", str(tenant)),
              filter("referralCode", "EQUAL", str(referral)),
            ],
          },
        }, 2);
        requireThat(
          sponsors.length === 1 && !field(sponsors[0], "accountState"),
          400,
          "رمز دعوة غير صالح",
        );
        const sponsor = sponsors[0];
        writes.push({
          transform: {
            document: sponsor.name,
            fieldTransforms: ["loyaltyPoints", "referralCount"].map((k, i) => ({
              fieldPath: k,
              increment: { integerValue: i === 0 ? "50" : "1" },
            })),
          },
          currentDocument: { updateTime: sponsor.updateTime },
        });
      }
      const fields = {
        id: str(key),
        tenantId: str(tenant),
        email: str(actor.email),
        name: str(name),
        phone: str(phone),
        address: str(address),
        landmark: str(String(input.landmark ?? "").slice(0, 500)),
        createdAt: str(new Date().toISOString()),
        identityUid: str(actor.uid),
        loyaltyPoints: {
          integerValue: String(
            Number(store.fields?.registrationPoints?.integerValue ?? 50),
          ),
        },
        referralCode: str(crypto.randomUUID()),
        referredBy: str(referral),
      };
      await writeDocs([
        ...writes,
        put(p, fields, null),
        put(b, { uid: str(actor.uid), tenant: str(tenant) }, null),
      ]);
      return {};
    }
    if (input.action === "approve" || input.action === "reject") {
      requireThat(
        await canReview(tenant, actor.email),
        403,
        "الحساب غير مخوّل لهذا المتجر",
      );
      requireThat(
        review && profile && !binding && !archive,
        409,
        "لم يعد الطلب صالحًا",
      );
      if (input.action === "reject") {
        await writeDocs([remove(review)]);
        return {};
      }
      actor = { uid: field(review, "uid"), email: field(review, "email") };
    } else if (!binding && input.action === "delete") {
      requireThat(
        profile && typeof input.password === "string" &&
          input.password.length > 0 &&
          field(profile, "password") === input.password,
        403,
        "تعذر تأكيد ملكية الحساب القديم",
      );
      requireThat(
        !review || field(review, "uid") === actor.uid,
        409,
        "يوجد طلب قيد المراجعة",
      );
      if (!review) {
        await writeDocs([
          put(q, {
            tenant: str(tenant),
            phone: str(phone),
            uid: str(actor.uid),
            email: str(actor.email),
          }, null),
        ]);
      }
      return { review: true };
    } else {
      requireThat(
        binding && field(binding, "uid") === actor.uid,
        403,
        "تعذر التحقق من هوية المشتري",
      );
    }
    if (input.action === "restore") {
      requireThat(
        archive && profile &&
          field(profile, "accountState") === "pendingDeletion",
        409,
        "لا يوجد حساب قابل للاستعادة",
      );
      requireThat(
        Date.now() < Date.parse(archive.fields.expiresAt.timestampValue),
        410,
        "انتهت مهلة الاستعادة",
      );
      const fields = {
        ...archive.fields.profile.mapValue.fields,
        email: str(actor.email),
        identityUid: str(actor.uid),
      };
      delete fields.password;
      await writeDocs([put(p, fields, profile), remove(archive)]);
      return {};
    }
    requireThat(
      input.action === "delete" || input.action === "approve",
      400,
      "عملية غير مدعومة",
    );
    if (archive) return { deadline: archive.fields.expiresAt.timestampValue };
    requireThat(profile, 404, "الحساب غير موجود");
    const deadline = new Date(Date.now() + days10).toISOString(),
      saved = { ...profile.fields };
    delete saved.password;
    await writeDocs([
      put(a, {
        expiresAt: { timestampValue: deadline },
        profile: { mapValue: { fields: saved } },
      }, null),
      put(p, {
        tenantId: str(tenant),
        accountState: str("pendingDeletion"),
        isBlocked: { booleanValue: true },
        deleteAfter: str(deadline),
      }, profile),
      ...(!binding
        ? [put(b, { uid: str(actor.uid), tenant: str(tenant) }, null)]
        : []),
      ...(review ? [remove(review)] : []),
    ]);
    return { deadline };
  }
  return { act, purge };
}
const { act, purge } = lifecycle();
export async function handle(req: Request) {
  const reply = (status: number, data: unknown) =>
    new Response(JSON.stringify(data), { status, headers: CORS });
  if (req.method === "OPTIONS") return reply(200, {});
  if (req.method !== "POST") return reply(405, {});
  try {
    const input = await req.json();
    if (input.action === "purge") {
      const worker = req.headers.get("x-buyer-worker");
      requireThat(
        worker &&
          await rpc("buyer_worker_authorized", { p_key: worker }) === true,
        403,
        "غير مخوّل",
      );
      const rows = await query(
        "buyer_deletions",
        filter("expiresAt", "LESS_THAN_OR_EQUAL", {
          timestampValue: new Date().toISOString(),
        }),
        30,
      );
      const results = await Promise.allSettled(rows.map(purge));
      requireThat(
        results.every((x) => x.status === "fulfilled"),
        503,
        "تعذّر استكمال بعض الطلبات",
      );
      return reply(200, { processed: rows.length });
    }
    const token = req.headers.get("x-buyer-token");
    requireThat(token, 401, "يلزم تسجيل الدخول");
    return reply(200, await act(input, await user(token!)));
  } catch (e) {
    return reply(e instanceof Failure ? e.status : 503, {
      error: e instanceof Failure ? e.message : "تعذّر تنفيذ العملية الآن",
    });
  }
}
