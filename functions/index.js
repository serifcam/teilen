const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();
const db = getFirestore();

exports.sendFriendRequestNotification = onDocumentCreated(
  "friendRequests/{requestId}",
  async (event) => {
    const request = event.data.data();

    const senderId = request.senderId;
    const receiverId = request.receiverId;

    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.exists
      ? senderDoc.data().name || "Bir kullanıcı"
      : "Bir kullanıcı";

    const receiverDoc = await db.collection("users").doc(receiverId).get();
    const fcmToken = receiverDoc.exists
      ? receiverDoc.data().fcmToken
      : null;

    if (!fcmToken) {
      logger.info("🚫 FCM token bulunamadı veya kullanıcı yok.");
      return;
    }

    const message = {
      notification: {
        title: "Yeni Arkadaşlık İsteği",
        body: `${senderName} size arkadaşlık isteği gönderdi, uygulamaya girip onaylayabilirsiniz.`
      },
      token: fcmToken
    };

    try {
      const response = await getMessaging().send(message);
      logger.info("📤 Bildirim gönderildi:", response);
    } catch (error) {
      logger.error("❌ Bildirim gönderilemedi:", error);
    }
  }
);
