const crypto = require("crypto");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const REGION = "me-central2";

function calcReservationFee(carPrice) {
  if (!carPrice || carPrice <= 0) return 150;
  if (carPrice >= 250000) return 500;
  if (carPrice >= 100000) return 300;
  return 150;
}

// 1. حجز آمن بـ Transaction لمنع الحجز المزدوج (Race Condition)
exports.createReservationAtomic = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  const { carId, buyerName, buyerPhone, buyerCity, paymentMethod, paymentGateway } = request.data || {};
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
    const slaDeadline = admin.firestore.Timestamp.fromMillis(now.toMillis() + 2 * 60 * 60 * 1000);
    const fee = calcReservationFee(Number(car.price || 0));
    const orderCode = `MRD-${Math.floor(100000 + Math.random() * 900000)}`;
    const handoverPin = String(Math.floor(1000 + Math.random() * 9000));
    const cleanPhone = String(buyerPhone || "").replace(/\D/g, "");
    const phoneLast4 = cleanPhone.slice(-4);

    tx.update(carRef, { status: "reserved", reserved_by: request.auth.uid, reserved_at: now });
    tx.set(orderRef, {
      order_code: orderCode,
      handover_pin: handoverPin,
      car_id: carId,
      car_title: `${car.make || ""} ${car.model || ""} ${car.year || ""}`.trim(),
      car_price: Number(car.price || 0),
      showroom_id: car.showroom_id || "",
      showroom_name: car.showroom_name || "معرض معتمد",
      showroom_owner_uid: car.owner_uid || "",
      region_id: car.region_id || "riyadh",
      buyer_uid: request.auth.uid,
      buyer_name: buyerName || "",
      buyer_phone: cleanPhone,
      buyer_phone_last4: phoneLast4,
      buyer_city: buyerCity || "الرياض",
      payment_method: paymentMethod || "شراء كاش (قيمة السيارة)",
      payment_gateway: paymentGateway || "مدى (Mada)",
      reservation_fee: fee,
      total_paid: fee,
      escrow_protected: true,
      inspection_status: "none",
      shipping_status: "none",
      invoice_issued: false,
      status: "paid_waiting_showroom",
      sla_deadline: slaDeadline,
      sla_expires_at: slaDeadline,
      created_at: now,
    });

    return { orderId: orderRef.id, orderCode, handoverPin, reservationFee: fee };
  });
});

// 2. المؤقت الآلي كل 15 دقيقة: إلغاء مهلة الساعتين + تحرير ضمان الفاحص بعد 48 ساعة
exports.scheduledOrderMaintenance = onSchedule({ schedule: "every 15 minutes", region: REGION }, async () => {
  const now = admin.firestore.Timestamp.now();

  const expiredShowroom = await db.collection("orders")
    .where("status", "in", ["paid_waiting_showroom", "pending_showroom"])
    .where("sla_deadline", "<=", now)
    .limit(50)
    .get();

  for (const doc of expiredShowroom.docs) {
    await doc.ref.update({ status: "expired_no_showroom_reply", auto_refund_triggered: true });
    if (doc.data().car_id) {
      await db.collection("cars").doc(doc.data().car_id).update({ status: "available" });
    }
  }

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

  // ج) مراقبة مهلة الفاحص (24 ساعة): خصم 50 ر.س وإعادة فتح المهمة تلقائياً لفاحص آخر
  const cutoff24h = admin.firestore.Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);
  const lateInspections = await db.collection("orders")
    .where("inspection_status", "==", "inspector_accepted")
    .where("inspector_uid_claimed_at", "<=", cutoff24h)
    .limit(50)
    .get();

  for (const doc of lateInspections.docs) {
    const lateUid = doc.data().inspector_uid || "";
    await doc.ref.update({
      inspection_status: "pending_inspector",
      inspector_uid: admin.firestore.FieldValue.delete(),
      inspector_sla_penalty_50: true,
      reopened_at: now,
    });
    if (lateUid) {
      await db.collection("ledger_entries").add({
        type: "inspector_sla_penalty",
        inspector_uid: lateUid,
        order_id: doc.id,
        amount: -50,
        note: "غرامة تأخر الفاحص عن مهلة 24 ساعة وإعادة فتح المهمة",
        created_at: now,
      });
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

// 4. مولّد رمز QR للفوترة الإلكترونية (ZATCA TLV Base64)
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

// 5. Webhook محمي بتوقيع سري لبوابة الدفع (Moyasar / Tap / HyperPay)
exports.paymentSplitWebhook = onRequest({ region: REGION }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");
  const expectedSecret = process.env.PAYMENT_WEBHOOK_SECRET || "";
  const providedSecret = req.get("x-webhook-secret") || "";
  const a = Buffer.from(expectedSecret, "utf8");
  const b = Buffer.from(providedSecret, "utf8");
  if (!expectedSecret || a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return res.status(401).json({ ok: false, error: "unauthorized_webhook" });
  }

  const { orderId, status, commissionTotal } = req.body || {};
  if (!orderId || typeof orderId !== "string" || status !== "paid") return res.status(400).send("ignored");
  const existing = await db.collection("orders").doc(orderId).get();
  if (!existing.exists) return res.status(404).send("order_not_found");
  if (existing.data()?.deposit_paid === true) return res.status(200).json({ ok: true, idempotent: true });

  const vat = (Number(commissionTotal || 50) * 15) / 115;
  const qr = generateZatcaQrBase64(
    "منصة شاري للوساطة التقنية",
    process.env.ZATCA_VAT_NUMBER || "300000000000003",
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


// قاعدة الربط الرسمية مع بوابة واثق (Wathq API v5) للتحقق من السجل التجاري / الرقم الموحد
exports.verifyCommercialRegistrationWithWathq = onCall({ region: "me-central2" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }
  const crNumber = String(request.data?.crNumber || "").replace(/\s+/g, "");
  if (!/^(700\d{7}|\d{10})$/.test(crNumber)) {
    throw new HttpsError("invalid-argument", "صيغة الرقم الموحد أو السجل التجاري غير صحيحة.");
  }
  const apiKey = process.env.WATHQ_API_KEY;
  if (!apiKey) {
    return {
      mode: "manual_review_fallback",
      verified: false,
      crNumber,
      message: "قاعدة الربط جاهزة؛ بانتظار إضافة WATHQ_API_KEY للتوثيق الآلي (يعمل التوثيق اليدوي حالياً).",
    };
  }
  const resp = await fetch(`https://api.wathq.sa/v5/commercialregistration/info/${crNumber}`, {
    headers: { apiKey, accept: "application/json" },
  });
  if (!resp.ok) {
    throw new HttpsError("failed-precondition", "تعذر التحقق من السجل عبر واثق، تأكد من الرقم.");
  }
  const info = await resp.json();
  return {
    mode: "wathq_live",
    verified: info?.status?.id === "active" || info?.status?.name === "نشط",
    crNumber,
    commercialName: info?.crName || "",
    expiryDate: info?.expiryDate || "",
    statusName: info?.status?.name || "",
  };
});
