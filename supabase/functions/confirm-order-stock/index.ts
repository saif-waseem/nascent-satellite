// The client supplies an order ID and its Firebase session. Only Firestore
// supplies the tenant, quantities and revision sent to the privileged RPC.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, apikey, x-firebase-token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number) => new Response(null, { status, headers: cors });
const root = "https://firestore.googleapis.com/v1/projects/my-store-b0723/databases/(default)/documents/orders/";
const firestoreProject = "my-store-b0723";
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
function rpc(name:string, args:unknown) {
  return fetch(Deno.env.get("SUPABASE_URL") + "/rest/v1/rpc/" + name, {
    method:"POST", headers:{apikey:key,Authorization:"Bearer "+key,"Content-Type":"application/json"},
    body:JSON.stringify(args)
  });
}
async function sync(order:string,token:string) {
    const headers = { Authorization: "Bearer " + token };
    const url = new URL(root + encodeURIComponent(order));
    for (const field of ["tenantId","status","items","stockSyncEnabled","stockSyncPending"])
      url.searchParams.append("mask.fieldPaths",field);
    const response = await fetch(url,{headers});
    if (!response.ok) return reply(response.status === 403 ? 403 : 503);
    const doc = await response.json();
    const f = doc.fields;
    if (f?.stockSyncPending?.booleanValue !== true) return reply(204);
    if (f?.stockSyncEnabled?.booleanValue === true) {
    const raw = f.items?.arrayValue;
    if (!raw || !["active","completed","cancelled"].includes(f.status?.stringValue)) return reply(422);
    const items = f.status.stringValue === "cancelled" ? [] : (raw.values ?? []).map((v: any) => {
      const item = v.mapValue.fields;
      return {id:(item.productId ?? item.id)?.stringValue, color:item.color?.stringValue ?? "Default",
        size:item.size?.stringValue ?? "Default", qty:Number(item.quantity?.integerValue)};
    });
    const result = await rpc("sync_confirmed_order_stock",{p_order:order,p_tenant:f.tenantId.stringValue,p_version:doc.updateTime,p_items:items});
    if (!result.ok) { console.error("Order stock transaction failed",result.status); return reply(409); }
    }
    // A concurrently edited order must stay pending for the next pass.
    const ack = new URL(root + encodeURIComponent(order));
    ack.searchParams.set("updateMask.fieldPaths","stockSyncPending");
    ack.searchParams.set("currentDocument.updateTime",doc.updateTime);
    const updated = await fetch(ack, {method:"PATCH",headers:{...headers,"Content-Type":"application/json"},
      body:JSON.stringify({fields:{stockSyncPending:{booleanValue:false}}})});
    return reply(updated.ok ? 204 : 409);
}
async function sweep(worker:string) {
  const session = await rpc("order_stock_worker_session",{worker});
  if (!session.ok) return reply(403);
  const refresh = await session.json();
  // Public Firebase web API key used by the same storefront project.
  const firebaseKey = "AIzaSyCjmGWBANCyPt3sFF6L7Cxp1N1I_w_E5Ws";
  const auth = refresh
    ? await fetch("https://securetoken.googleapis.com/v1/token?key="+firebaseKey,{
        method:"POST",body:new URLSearchParams({grant_type:"refresh_token",refresh_token:refresh})})
    : await fetch("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="+firebaseKey,{
        method:"POST",headers:{"Content-Type":"application/json"},body:'{"returnSecureToken":true}'});
  if (!auth.ok) return reply(503);
  const result = await auth.json();
  const token:string = result.id_token ?? result.idToken;
  const newRefresh:string = result.refresh_token ?? result.refreshToken;
  if (newRefresh && newRefresh !== refresh) {
    if (!(await rpc("save_order_stock_session",{worker,refresh_token:newRefresh})).ok) return reply(503);
  }
  let cursor:string|undefined;
  let failed = false;
  // One query page at a time, fetching document IDs only. Continue past
  // conflicted orders so one bad record cannot block subsequent orders.
  do {
    const query = {from:[{collectionId:"orders"}],select:{fields:[{fieldPath:"__name__"}]},
      where:{fieldFilter:{field:{fieldPath:"stockSyncPending"},op:"EQUAL",value:{booleanValue:true}}},
      orderBy:[{field:{fieldPath:"__name__"},direction:"ASCENDING"}],limit:25,
      ...(cursor?{startAt:{values:[{referenceValue:cursor}],before:false}}:{})};
    const res = await fetch("https://firestore.googleapis.com/v1/projects/"+firestoreProject+"/databases/(default)/documents:runQuery",{
      method:"POST",headers:{Authorization:"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify({structuredQuery:query})});
    if (!res.ok) return reply(503);
    const rows = (await res.json()).flatMap((r:{document?:{name:string}})=>r.document?[r.document.name]:[]);
    for(let i=0;i<rows.length;i+=5) {
      const results=await Promise.allSettled(rows.slice(i,i+5).map((name:string)=>sync(name.split("/").pop()!,token)));
      if(results.some(r=>r.status==="rejected" || !r.value.ok)) failed=true;
    }
    cursor = rows.length===25 ? rows[24] : undefined;
  } while(cursor);
  return reply(failed?409:204);
}
Deno.serve(async (req) => {
  if(req.method==="OPTIONS") return reply(204);
  if(req.method!=="POST") return reply(405);
  try {
    const worker=req.headers.get("x-stock-worker");
    if(worker) return await sweep(worker);
    const token=req.headers.get("x-firebase-token");
    if(!token || token.length>8192) return reply(401);
    const {order}=await req.json();
    if(typeof order!=="string" || !/^[A-Za-z0-9_-]{1,160}$/.test(order)) return reply(400);
    return await sync(order,token);
  } catch { return reply(503); }
});
