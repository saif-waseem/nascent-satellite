import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * Securely validates an activation code for the POS or Store app.
 * The code comparison happens server-side, never exposing the stored code to the client.
 *
 * @param data.tenantId - The tenant's unique ID
 * @param data.code     - The activation code entered by the user
 * @param data.appType  - Either 'pos' or 'store'
 */
export const verifyActivationCode = functions.https.onCall(async (data, context) => {
  const { tenantId, code, appType } = data;

  if (!tenantId || !code || !appType) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields.");
  }

  if (appType !== "pos" && appType !== "store") {
    throw new functions.https.HttpsError("invalid-argument", "appType must be 'pos' or 'store'.");
  }

  const tenantRef = db.collection("tenants").doc(tenantId);
  const tenantSnap = await tenantRef.get();

  if (!tenantSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Tenant not found.");
  }

  const tenantData = tenantSnap.data()!;

  const expectedCodeField = appType === "pos" ? "posActivationCode" : "activationCode";
  const enableField = appType === "pos" ? "isPosEnabled" : "isStoreEnabled";

  const expectedCode = tenantData[expectedCodeField] as string | undefined;

  if (!expectedCode) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "No activation code configured for this tenant. Contact support."
    );
  }

  // Case-insensitive comparison
  if (code.trim().toUpperCase() !== expectedCode.trim().toUpperCase()) {
    throw new functions.https.HttpsError("permission-denied", "Invalid activation code.");
  }

  // Code is correct — activate permanently
  await tenantRef.update({
    [enableField]: true,
    isActive: true,
  });

  // Log the activation event
  await tenantRef.collection("activation_logs").add({
    date: admin.firestore.FieldValue.serverTimestamp(),
    type: appType === "pos" ? "POS_ACTIVATION" : "STORE_ACTIVATION",
    codeUsed: code.trim().toUpperCase(),
    activatedAt: new Date().toISOString(),
  });

  return { success: true, message: "Activation successful!" };
});
