import { lifecycle } from "./service.ts";
import assert from "node:assert/strict";
const db = "projects/my-store-b0723/databases/(default)/documents/";
const str = (stringValue: string) => ({ stringValue });
const user = { uid: "buyer-a", email: "a@example.invalid" };
function fixture() {
  const docs = new Map<string, any>();
  let v = 0;
  const set = (name: string, fields: any) =>
    docs.set(name, { name, fields, updateTime: String(v++) });
  set(db + "tenants/demo", {});
  const api = lifecycle({
    read: async (name) => docs.get(name) ?? null,
    commit: async (writes) => {
      for (const w of writes as any[]) {
        const prev = docs.get(w.update?.name ?? w.delete);
        if (w.currentDocument.exists === false) assert.ok(!prev);
        else assert.equal(w.currentDocument.updateTime, prev?.updateTime);
      }
      for (const w of writes as any[]) {
        if (w.delete) docs.delete(w.delete);
        else set(w.update.name, w.update.fields);
      }
    },
    query: async () => [],
    request: async () => Response.json({}),
    isReviewer: async (t, e) => t === "demo" && e === "admin@example.invalid",
  });
  const act = (action: string, actor = user, extra = {}) =>
    api.act({ tenant: "demo", phone: "12345678", action, ...extra }, actor);
  return {
    docs,
    set,
    api,
    act,
    p: db + "users/demo_12345678",
    a: db + "buyer_deletions/demo_12345678",
  };
}
Deno.test("verified buyer self-service, restore once and strict expiration", async () => {
  const f = fixture();
  await f.act("register", user, { name: "Customer", address: "Demo address" });
  await assert.rejects(
    f.act("delete", { uid: "other", email: "other@example.invalid" }),
  );
  const start = Date.now();
  const result = await f.act("delete");
  const deadline = Date.parse(result.deadline!);
  assert.ok(
    deadline >= start + 10 * 86400000 && deadline <= Date.now() + 10 * 86400000,
  );
  assert.equal((await f.act("delete")).deadline, result.deadline);
  assert.equal(f.docs.get(f.p).fields.name, undefined);
  await f.act("restore");
  assert.equal(f.docs.get(f.p).fields.name.stringValue, "Customer");
  await f.act("delete");
  f.docs.get(f.a).fields.expiresAt.timestampValue = new Date(Date.now() - 1)
    .toISOString();
  await assert.rejects(f.act("restore"));
  await f.api.purge(f.docs.get(f.a));
  assert.ok(!f.docs.has(f.p) && !f.docs.has(f.a));
  await assert.rejects(f.act("restore"));
});
Deno.test("legacy deletion requires store reviewer and cannot start the timer at request time", async () => {
  const f = fixture();
  f.set(f.p, { name: str("old"), password: str("example-only") });
  await f.act("delete", user, { password: "example-only" });
  assert.ok(!f.docs.has(f.a));
  await assert.rejects(f.act("approve"));
  await f.act("approve", { uid: "admin", email: "admin@example.invalid" });
  assert.ok(f.docs.has(f.a));
  await f.act("restore");
  assert.equal(f.docs.get(f.p).fields.password, undefined);
  assert.equal(f.docs.get(f.p).fields.identityUid.stringValue, user.uid);
});
