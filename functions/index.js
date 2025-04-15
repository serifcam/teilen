const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const logger = require('firebase-functions/logger');

initializeApp();
const db = getFirestore();

/**
✅ Arkadaşlık isteği bildirimi gönderir
 */
exports.sendFriendRequestNotification = onDocumentCreated(
  'friendRequests/{requestId}',
  async (event) => {
    const request = event.data.data();
    const senderId = request.senderId;
    const receiverId = request.receiverId;

    const senderDoc = await db.collection('users').doc(senderId).get();
    const senderName = senderDoc.exists
      ? senderDoc.data().name || 'Bir kullanıcı'
      : 'Bir kullanıcı';

    const receiverDoc = await db.collection('users').doc(receiverId).get();
    const receiverData = receiverDoc.exists ? receiverDoc.data() : {};
    const fcmToken = receiverData.fcmToken || null;

    const XnotificationsEnabled = receiverData.XnotificationsEnabled !== false;
    const XfriendRequestEnabled = receiverData.XfriendRequestEnabled !== false;

    if (!fcmToken || !XnotificationsEnabled || !XfriendRequestEnabled) {
      return logger.info('🔕 Arkadaşlık bildirimi gönderilmedi (token yok veya kullanıcı bu bildirimi kapatmış).');
    }

    const message = {
      notification: {
        title: 'Yeni Arkadaşlık İsteği',
        body: `${senderName} size arkadaşlık isteği gönderdi.`
      },
      data: {
        type: 'friendRequest'
      },
      token: fcmToken
    };

    try {
      const response = await getMessaging().send(message);
      logger.info('📤 Arkadaşlık bildirimi gönderildi:', response);
    } catch (error) {
      logger.error('❌ Arkadaşlık bildirimi gönderilemedi:', error);
    }
  }
);

/**
 * ✅ Borç bildirimlerini gönderir (bireysel, grup, ödeme)
 */
exports.sendDebtNotification = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const data = event.data.data();
    if (!data || !data.toUser) {
      return logger.info('⚠️ Bildirim verisi eksik.');
    }

    const {toUser, type, amount = 0, fromUserEmail = 'Bilinmeyen'} = data;
    const receiverDoc = await db.collection('users').doc(toUser).get();
    const receiverData = receiverDoc.exists ? receiverDoc.data() : {};
    const fcmToken = receiverData.fcmToken || null;

    const XnotificationsEnabled = receiverData.XnotificationsEnabled !== false;
    const XindividualDebtEnabled = receiverData.XindividualDebtEnabled !== false;
    const XgroupDebtEnabled = receiverData.XgroupDebtEnabled !== false;
    const XdebtPaidEnabled = receiverData.XdebtPaidEnabled !== false;

    if (!fcmToken || !XnotificationsEnabled) {
      return logger.info('🔕 Bildirim gönderilmedi (token yok veya genel bildirim kapalı).');
    }

    let title = 'Yeni Borç Bildirimi';
    let body = '';

    if (type === 'newDebt') {
      if (!XindividualDebtEnabled) {
        return logger.info('🔕 Bireysel borç bildirimi kapalı.');
      }
      body = `${fromUserEmail} size ${amount} TL borç eklemiştir.`;
    } else if (type === 'groupDebt') {
      if (!XgroupDebtEnabled) {
        return logger.info('🔕 Grup borç bildirimi kapalı.');
      }
      body = `${fromUserEmail} size ${amount} TL grup borcu eklemiştir.`;
    } else if (type === 'debtPaid') {
      if (!XdebtPaidEnabled) {
        return logger.info('🔕 Borç ödendi bildirimi kapalı.');
      }
      title = 'Borç Ödendi Onayı Bekliyor';
      body = `${fromUserEmail}, size olan ${amount} TL borcunu ödemiştir.`;
    } else {
      return logger.info(`ℹ️ Bilinmeyen bildirim tipi: ${type}`);
    }

    const message = {
      notification: {
        title,
        body
      },
      data: {
        type: type || 'unknown'
      },
      token: fcmToken
    };

    try {
      const response = await getMessaging().send(message);
      logger.info('📤 Borç bildirimi gönderildi:', response);
    } catch (error) {
      logger.error('❌ Borç bildirimi gönderilemedi:', error);
    }
  }
);
