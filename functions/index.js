const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({
  region: "asia-southeast1",
  maxInstances: 10,
});

// ============================================================
// EXISTING FUNCTIONS
// ============================================================

exports.sayHello = onCall((request) => {
  return {
    message: "Hello from Firebase Functions!",
  };
});

// Cloud Function para sa pagbura ng User Account
exports.deleteUserAccount = onCall(async (request) => {
  // Siguraduhing authenticated ang tumatawag
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
    // Burahin ang User sa Firebase Authentication
    await admin.auth().deleteUser(targetUid);

    // Burahin ang user's addresses
    const userRef = admin.firestore().collection("users").doc(targetUid);

    const addressesSnapshot = await userRef
        .collection("addresses")
        .get();

    const batch = admin.firestore().batch();

    addressesSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    // Burahin ang mismong user document
    batch.delete(userRef);

    await batch.commit();

    return {
      success: true,
      message:
        "Matagumpay na nabura ang account sa Authentication at Firestore.",
    };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});


// ============================================================
// REAL ADMIN PUSH NOTIFICATIONS
// ============================================================

const db = admin.firestore();
const messaging = admin.messaging();


// ============================================================
// GET ALL ADMIN FCM TOKENS
// ============================================================

async function getAdminRecipients() {
  const usersSnapshot = await db
      .collection("users")
      .where("role", "==", "admin")
      .get();

  const admins = [];

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();

    const tokens = [];

    // --------------------------------------------------------
    // New token structure:
    //
    // users/{uid}/fcmTokens/{tokenDocument}
    // --------------------------------------------------------

    const tokensSnapshot = await userDoc.ref
        .collection("fcmTokens")
        .where("active", "==", true)
        .get();

    tokensSnapshot.docs.forEach((tokenDoc) => {
      const tokenData = tokenDoc.data();

      if (tokenData.token) {
        tokens.push({
          token: tokenData.token,
          tokenDocRef: tokenDoc.ref,
        });
      }
    });

    // --------------------------------------------------------
    // Backward compatibility:
    //
    // users/{uid}.fcmToken
    // --------------------------------------------------------

    if (userData.fcmToken) {
      tokens.push({
        token: userData.fcmToken,
        tokenDocRef: null,
      });
    }

    // Remove duplicate tokens
    const uniqueTokens = [];
    const seenTokens = new Set();

    for (const item of tokens) {
      if (!seenTokens.has(item.token)) {
        seenTokens.add(item.token);
        uniqueTokens.push(item);
      }
    }

    if (uniqueTokens.length > 0) {
      admins.push({
        uid: userDoc.id,
        tokens: uniqueTokens,
      });
    }
  }

  return admins;
}


// ============================================================
// CREATE NOTIFICATION RECORD IN FIRESTORE
// ============================================================

async function createAdminNotification({
  recipientId,
  type,
  title,
  body,
  orderId = null,
  chatId = null,
  senderId = null,
}) {
  await db.collection("notifications").add({
    recipientId,
    recipientType: "admin",

    type,
    title,
    body,

    orderId,
    chatId,
    senderId,

    isRead: false,

    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}


// ============================================================
// SEND PUSH NOTIFICATION TO ADMIN DEVICES
// ============================================================

async function sendToAdminDevices({
  type,
  title,
  body,
  orderId = null,
  chatId = null,
  senderId = null,
}) {
  const admins = await getAdminRecipients();

  if (admins.length === 0) {
    console.log("No admin FCM tokens found.");
    return;
  }

  for (const adminUser of admins) {
    // --------------------------------------------------------
    // Save notification in Firestore
    // --------------------------------------------------------

    await createAdminNotification({
      recipientId: adminUser.uid,
      type,
      title,
      body,
      orderId,
      chatId,
      senderId,
    });

    const tokens = adminUser.tokens.map((item) => item.token);

    if (tokens.length === 0) {
      continue;
    }

    // --------------------------------------------------------
    // Select notification channel
    // --------------------------------------------------------

    const channelId =
      type === "order"
        ? "admin_orders_v2"
        : "admin_chats_v2";

    // --------------------------------------------------------
    // Send FCM
    // --------------------------------------------------------

    try {
      const response = await messaging.sendEachForMulticast({
        tokens: tokens,

        notification: {
          title: title,
          body: body,
        },

        data: {
          type: type,

          orderId: orderId ? String(orderId) : "",

          chatId: chatId ? String(chatId) : "",

          senderId: senderId ? String(senderId) : "",
        },

        android: {
          priority: "high",

          notification: {
            channelId: channelId,
            sound: "default",

            notificationCount: 1,
          },
        },

        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      });

      console.log(
        `Notification sent to admin ${adminUser.uid}:`,
        response.successCount,
        "success,",
        response.failureCount,
        "failed."
      );

      // ------------------------------------------------------
      // Disable invalid FCM tokens
      // ------------------------------------------------------

      for (let i = 0; i < response.responses.length; i++) {
        const sendResponse = response.responses[i];

        if (!sendResponse.success) {
          const errorCode = sendResponse.error?.code;

          if (
            errorCode ===
              "messaging/registration-token-not-registered" ||
            errorCode ===
              "messaging/invalid-registration-token"
          ) {
            const tokenInfo = adminUser.tokens[i];

            if (tokenInfo.tokenDocRef) {
              await tokenInfo.tokenDocRef.update({
                active: false,
                updatedAt:
                  admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
    } catch (error) {
      console.error(
        `Failed to send notification to admin ${adminUser.uid}:`,
        error
      );
    }
  }
}


// ============================================================
// NEW ORDER → NOTIFY ADMIN
// ============================================================

exports.notifyAdminOnNewOrder = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const order = event.data?.data();

    if (!order) {
      return;
    }

    // Ignore test orders
    if (
      order.isTest === true ||
      order.testMode === true
    ) {
      console.log("Test order ignored.");
      return;
    }

    const orderId = event.params.orderId;

    // --------------------------------------------------------
    // Get order total
    // --------------------------------------------------------

    const totalRaw =
      order.totalAmount ??
      order.total ??
      order.amount ??
      0;

    const total = Number(totalRaw) || 0;

    // --------------------------------------------------------
    // Get customer ID
    // --------------------------------------------------------

    const customerId =
      order.userId ??
      order.customerId ??
      null;

    let customerName = "Customer";

    // --------------------------------------------------------
    // Get customer name
    // --------------------------------------------------------

    if (customerId) {
      try {
        const customerDoc = await db
            .collection("users")
            .doc(String(customerId))
            .get();

        if (customerDoc.exists) {
          const customerData = customerDoc.data();

          customerName =
            customerData?.name ??
            customerData?.displayName ??
            customerName;
        }
      } catch (error) {
        console.error(
          "Failed to get customer information:",
          error
        );
      }
    }

    // --------------------------------------------------------
    // Notification content
    // --------------------------------------------------------

    const title = "New Order Received";

    const body =
      `${String(customerName)} placed order #${orderId} ` +
      `worth ₱${total.toFixed(2)}.`;

    // --------------------------------------------------------
    // Send notification
    // --------------------------------------------------------

    await sendToAdminDevices({
      type: "order",

      title: title,

      body: body,

      orderId: orderId,
    });
  }
);


// ============================================================
// NEW CUSTOMER CHAT MESSAGE → NOTIFY ADMIN
// ============================================================
//
// Expected Firestore structure:
//
// chats
//   └── {chatId}
//         └── messages
//               └── {messageId}
//
// Expected message fields:
//
// senderId
// senderRole
// senderName
// text
//
// ============================================================

exports.notifyAdminOnNewCustomerMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();

    if (!message) {
      return;
    }

    // --------------------------------------------------------
    // Ignore test messages
    // --------------------------------------------------------

    if (
      message.isTest === true ||
      message.testMode === true
    ) {
      console.log("Test chat message ignored.");
      return;
    }

    const chatId = event.params.chatId;

    // --------------------------------------------------------
    // Determine sender
    // --------------------------------------------------------

    const senderId =
      message.senderId ??
      message.userId ??
      message.fromUserId ??
      null;

    const senderRole = String(
      message.senderRole ??
      message.role ??
      message.senderType ??
      ""
    ).toLowerCase();

    // --------------------------------------------------------
    // Don't notify admin when admin sends the message
    // --------------------------------------------------------

    if (senderRole === "admin") {
      return;
    }

    // --------------------------------------------------------
    // If role isn't provided, check the sender's user document
    // --------------------------------------------------------

    if (
      senderRole !== "admin" &&
      senderId
    ) {
      try {
        const senderDoc = await db
            .collection("users")
            .doc(String(senderId))
            .get();

        if (senderDoc.exists) {
          const senderData = senderDoc.data();

          const role = String(
            senderData?.role ?? ""
          ).toLowerCase();

          if (role === "admin") {
            return;
          }
        }
      } catch (error) {
        console.error(
          "Failed to check sender role:",
          error
        );
      }
    }

    // --------------------------------------------------------
    // Get message text
    // --------------------------------------------------------

    const text =
      message.text ??
      message.message ??
      message.content ??
      "";

    const safeText = String(text).trim();

    // --------------------------------------------------------
    // Ignore empty messages unless it is an image
    // --------------------------------------------------------

    if (
      !safeText &&
      message.type !== "image"
    ) {
      return;
    }

    // --------------------------------------------------------
    // Sender name
    // --------------------------------------------------------

    const senderName =
      message.senderName ??
      message.userName ??
      "Customer";

    // --------------------------------------------------------
    // Notification body
    // --------------------------------------------------------

    let body;

    if (safeText) {
      body = safeText.slice(0, 180);
    } else {
      body = "Sent a new image.";
    }

    // --------------------------------------------------------
    // Send notification to admin
    // --------------------------------------------------------

    await sendToAdminDevices({
      type: "chat",

      title:
        `New message from ${String(senderName)}`,

      body: body,

      chatId: chatId,

      senderId:
        senderId
          ? String(senderId)
          : null,
    });
  }
);