const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const REGION = "me-central2";

// 1. حجز آمن بـ Transaction لمنع الحجز المزدوج (Race Condition) وحساب الرسوم في السيرفر
exports.createReservationAtomic = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  const { carId, buyerName, buyerPhone, buyerCity } = request.data;
  if (!carId) throw new HttpsError("invalid-argument", "معرف السيارة مطلوب.");

  const carRef = db.collection("cars").doc(carId);
  const orderRef = db.collection("orders").doc();

  return await db.runTransaction(async (tx) => {
    const carSnap = await tx.get(carRef);
    if (!carSnap.exists) throw new HttpsError("not-found", "السيارة غير موجودة.");
    const car = carSnap.data();
    if (car.status === "reserved" || car.status === "sold") {
      throw new HttpsError("failed-precondition", "عذراً، تم حجز السيارة للتو من مشترٍ آخر.");
    }

    const now = admin.firestore.Timestamp.now();
    const slaExpiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + 2 * 60 * 60 * 1000);

    tx.update(carRef, { status: "reserved", reserved_by: request.auth.uid, reserved_at: now });
    tx.set(orderRef, {
      order_code: `MRD-${Math.floor(100000 + Math.random() * 900000)}`,
      car_id: carId,
      car_title: car.title || "",
      car_price: car.price || 0,
      showroom_id: car.showroom_id || "",
      showroom_owner_uid: car.owner_uid || "",
      region_id: car.region_id || "riyadh",
      buyer_uid: request.auth.uid,
      buyer_name: buyerName || "",
      buyer_phone: buyerPhone || "",
      buyer_city: buyerCity || "الرياض",
      deposit_amount: 300,
      inspection_fee: 250,
      inspection_platform_commission: 50,
      towing_commission_rate: 0.10,
      status: "pending_showroom",
      sla_expires_at: slaExpiresAt,
      created_at: now,
    });

    return { orderId: orderRef.id };
  });
});

// 2. المؤقت الآلي كل 15 دقيقة: إلغاء مهلة الساعتين للمعرض + تحرير ضمان الفاحص بعد 48 ساعة
exports.scheduledOrderMaintenance = onSchedule({ schedule: "every 15 minutes", region: REGION }, async () => {
  const now = admin.firestore.Timestamp.now();

  // أ) إلغاء الطلبات التي تجاوزت مهلة الساعتين بدون رد المعرض
  const expiredShowroom = await db.collection("orders")
    .where("status", "==", "pending_showroom")
    .where("sla_expires_at", "<=", now)
    .limit(50)
    .get();

  for (const doc of expiredShowroom.docs) {
    await doc.ref.update({ status: "expired_no_showroom_reply", auto_refund_triggered: true });
    if (doc.data().car_id) {
      await db.collection("cars").doc(doc.data().car_id).update({ status: "available" });
    }
  }

  // ب) تحرير مستحقات الفاحص بعد 48 ساعة إذا لم يُفتح نزاع
  const cutoff48h = admin.firestore.Timestamp.fromMillis(now.toMillis() - 48 * 60 * 60 * 1000);
  const readyEscrow = await db.collection("orders")
    .where("inspector_payout_status", "==", "escrow_held")
    .where("inspection_completed_at", "<=", cutoff48h)
    .limit(50)
    .get();

  for (const doc of readyEscrow.docs) {
    if (!doc.data().escrow_frozen) {
      await doc.ref.update({ inspector_payout_status: "released_auto_48h", released_at: now });
    }
  }
});

// 3. إشعارات فورية (FCM) عند تحديث حالة الطلب
exports.onOrderNotification = onDocumentWritten({ document: "orders/{orderId}", region: REGION }, async (event) => {
  const after = event.data?.after?.data();
  if (!after) return;
  const topic = `order_${event.params.orderId}`;
  try {
    await admin.messaging().send({
      topic,
      notification: {
        title: `تحديث طلبك ${after.order_code || ""}`,
        body: `الحالة الحالية للطلب: ${after.status}`,
      },
    });
  } catch (_) {}
});

// 4. مولّد رمز QR للفوترة الإلكترونية (ZATCA TLV Base64) لعمولات المنصة
function generateZatcaQrBase64(sellerName, vatNumber, timestampIso, totalWithVat, vatAmount) {
  const tlv = (tag, val) => {
    const buf = Buffer.from(String(val), "utf8");
    return Buffer.concat([Buffer.from([tag, buf.length]), buf]);
  };
  return Buffer.concat([
    tlv(1, sellerName),
    tlv(2, vatNumber),
    tlv(3, timestampIso),
    tlv(4, Number(totalWithVat).toFixed(2)),
    tlv(5, Number(vatAmount).toFixed(2)),
  ]).toString("base64");
}

// 5. Webhook لبوابة الدفع المرخصة (Moyasar / Tap / HyperPay Split Payments)
exports.paymentSplitWebhook = onRequest({ region: REGION }, async (req, res) => {
  const { orderId, status, commissionTotal } = req.body || {};
  if (!orderId || status !== "paid") return res.status(400).send("ignored");

  const vat = (Number(commissionTotal || 50) * 15) / 115;
  const qr = generateZatcaQrBase64(
    "منصة معرضي للوساطة التقنية",
    "300000000000003", // يُستبدل بالرقم الضريبي الفعلي عند الإطلاق
    new Date().toISOString(),
    commissionTotal || 50,
    vat
  );

  await db.collection("orders").doc(orderId).update({
    deposit_paid: true,
    zatca_commission_qr: qr,
    paid_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  return res.status(200).json({ ok: true, zatca_qr: qr });
});
