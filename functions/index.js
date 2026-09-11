const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

exports.sayHello = onCall((request) => {
  return {
    message: "Hello from Firebase Functions!"
  };
});

// Cloud Function para sa pagbura ng User Account (Auth + Firestore)
exports.deleteUserAccount = onCall(async (request) => {
  // 1. Siguraduhing authenticated ang tumatawag na Admin
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Kailangan mong maging logged in para isagawa ang action na ito."
    );
  }

  const targetUid = request.data.uid;
  if (!targetUid) {
    throw new HttpsError(
      "invalid-argument",
      "Kailangan ng valid na Target User ID (UID)."
    );
  }

  try {
    // 2. Burahin ang User sa Firebase Authentication
    await admin.auth().deleteUser(targetUid);

    // 3. Burahin ang mga subcollections (halimbawa: 'addresses')
    const userRef = admin.firestore().collection("users").doc(targetUid);
    const addressesSnapshot = await userRef.collection("addresses").get();

    const batch = admin.firestore().batch();
    addressesSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    // 4. Burahin ang mismong User document sa 'users' collection
    batch.delete(userRef);
    await batch.commit();

    return {
      success: true,
      message: "Mataagumpay na nabura ang account sa Authentication at Firestore."
    };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});