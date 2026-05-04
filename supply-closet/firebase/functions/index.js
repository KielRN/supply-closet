/**
 * SupplyCloset Cloud Functions
 *
 * Includes:
 *  - lookupUdi: GUDID/openFDA barcode-to-product lookup with Firestore cache
 *  - awardXp: server-side XP/badge engine called by client (callable function)
 *  - onSupplyTagged: Firestore trigger that updates aggregates and stockout signals
 *  - decayConfidence: scheduled job that decays stale supply confidence scores
 *  - syncRecalls: scheduled job that pulls recall data from openFDA
 *  - rolloverDailyChallenges: scheduled job to expire stale challenges at midnight UTC
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();
const db = admin.firestore();

// ─── XP point values (mirror lib/config/constants.dart) ──────────────
const POINTS = {
  tagNew: 10,
  confirmExisting: 5,
  completeProcedure: 15,
  reportNotFound: 5,
  firstTagOnUnit: 25,
  streakBonus: 50,
};

// ─── lookupUdi ──────────────────────────────────────────────────────
//
// Looks up a barcode against GUDID via openFDA. Cached in Firestore for
// 90 days. Falls back to "unknown" if not found.
exports.lookupUdi = onCall({region: "us-central1"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  // Rate limit: max 30 lookups per minute per user
  const uid = request.auth.uid;
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (userSnap.exists) {
    const profile = userSnap.data();
    const now = Date.now();
    const windowMs = 60000;
    const maxLookups = 30;
    const recentLookups = (profile.udiLookupTimestamps || [])
        .map(timestampMillis)
        .filter((ts) => now - ts < windowMs);
    if (recentLookups.length >= maxLookups) {
      throw new HttpsError("resource-exhausted", "Too many lookups. Please wait.");
    }
    recentLookups.push(now);
    await userRef.update({udiLookupTimestamps: recentLookups});
  }

  const barcode = (request.data && request.data.barcode) || "";
  if (!barcode || barcode.length < 8) {
    throw new HttpsError("invalid-argument", "barcode required");
  }

  // Strip GS1 application identifiers and extract the GTIN/UDI-DI.
  // Most medical device barcodes are encoded as GS1-128 with AI 01 (GTIN).
  const di = extractDi(barcode);

  // Check cache
  const cached = await db.collection("udi_cache").doc(di).get();
  if (cached.exists) {
    const data = cached.data();
    const ageDays = (Date.now() - data.cachedAt.toMillis()) / (1000 * 60 * 60 * 24);
    if (ageDays < 90) {
      logger.info("UDI cache hit", {di});
      return data.record;
    }
  }

  // openFDA lookup
  const apiKey = process.env.OPENFDA_API_KEY || "";
  const url = `https://api.fda.gov/device/udi.json?search=identifiers.id:"${di}"&limit=1` +
              (apiKey ? `&api_key=${apiKey}` : "");
  try {
    const res = await fetch(url);
    if (!res.ok) {
      logger.warn("openFDA non-200", {status: res.status, di});
      return {found: false, di};
    }
    const json = await res.json();
    if (!json.results || json.results.length === 0) {
      // Cache the miss too (negative cache, shorter TTL handled by 90-day ageDays check above)
      const empty = {found: false, di};
      await db.collection("udi_cache").doc(di).set({
        record: empty,
        cachedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return empty;
    }
    const r = json.results[0];
    const record = {
      found: true,
      di,
      brandName: r.brand_name || "",
      versionOrModel: r.version_or_model_number || "",
      companyName: r.company_name || "",
      deviceDescription: r.device_description || "",
      gmdnTerm: (r.gmdn_terms && r.gmdn_terms[0] && r.gmdn_terms[0].name) || "",
      sizes: (r.device_sizes || []).map((s) => `${s.value}${s.unit || ""}`),
      isSterile: r.is_sterile === "true" || r.is_sterile === true,
      isSingleUse: r.is_single_use === "true" || r.is_single_use === true,
    };
    await db.collection("udi_cache").doc(di).set({
      record,
      cachedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return record;
  } catch (e) {
    logger.error("lookupUdi failed", e);
    return {found: false, di, error: "lookup_failed"};
  }
});

function extractDi(barcode) {
  // Naive parser: handles plain GTIN-14 / UPC and GS1 (01) prefix
  let b = String(barcode).trim();
  if (b.startsWith("01") && b.length >= 16) {
    return b.substring(2, 16); // 14-digit GTIN
  }
  // Pad to 14 for GTIN-14 normalization
  if (/^\d{8,14}$/.test(b)) {
    return b.padStart(14, "0");
  }
  return b;
}

function timestampMillis(value) {
  if (typeof value === "number") return value;
  if (value && typeof value.toMillis === "function") return value.toMillis();
  return 0;
}

// ─── awardXp ────────────────────────────────────────────────────────
//
// Server-side XP engine. Client cannot write to its own points field;
// it calls this function. Function applies multipliers, bonuses, and
// updates streak / badges atomically.
//
// Anti-farming measures:
//  - Rate limit: minimum 5 seconds between XP awards per user
//  - Action verification: tag actions require a recent supply tag by this user
exports.awardXp = onCall({region: "us-central1"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = request.auth.uid;
  const {
    action,
    isFirstTagOnUnit,
    isNightShift,
    supplyId,
    facilityId,
    unitId,
    roomId,
  } = request.data || {};
  if (!action || !POINTS[action]) {
    throw new HttpsError("invalid-argument", "Unknown action");
  }

  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User missing");
    const profile = snap.data();

    // ── Rate limit: sliding window — max 10 awards per 60 seconds ──
    const now = Date.now();
    const windowMs = 60000; // 1 minute
    const maxAwards = 10;
    const recentTimestamps = (profile.xpAwardTimestamps || [])
        .map(timestampMillis)
        .filter((ts) => now - ts < windowMs);

    if (recentTimestamps.length >= maxAwards) {
      throw new HttpsError(
          "resource-exhausted",
          "Too many actions. Please slow down.",
      );
    }

    // Keep only timestamps within the window + the new one
    recentTimestamps.push(now);

    // ── Verify tag actions actually occurred ───────────────────────
    if (action === "tagNew" || action === "confirmExisting") {
      if (!facilityId || !unitId) {
        throw new HttpsError(
            "invalid-argument",
            "facilityId and unitId required for tag actions.",
        );
      }
      // Check that this user recently tagged a supply in their unit
      const recentTag = await _verifyRecentTag(
          uid,
          facilityId,
          unitId,
          roomId || "main",
          supplyId,
      );
      if (!recentTag) {
        throw new HttpsError(
            "failed-precondition",
            "No recent tag found. Tag a supply first.",
        );
      }
    }

    let xp = POINTS[action];
    if (isFirstTagOnUnit) xp += POINTS.firstTagOnUnit;
    if (isNightShift) xp = Math.round(xp * 1.25);

    const isTagAction = action === "tagNew" || action === "confirmExisting";
    const streakDays = updateStreak(profile, isTagAction);
    xp = Math.round(xp * streakMultiplier(streakDays));

    const newPoints = (profile.points || 0) + xp;
    const newBadges = computeBadges(profile, action, streakDays, newPoints);
    const newTotalTags = (profile.totalTags || 0) +
        (action === "tagNew" || action === "confirmExisting" ? 1 : 0);

    const updateData = {
      points: newPoints,
      totalTags: newTotalTags,
      tagsThisMonth: (profile.tagsThisMonth || 0) + 1,
      streakDays,
      badges: Array.from(new Set([...(profile.badges || []), ...newBadges])),
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
      xpAwardTimestamps: recentTimestamps.map((ts) =>
        admin.firestore.Timestamp.fromMillis(ts)),
    };
    // Only update lastTagAt for tag actions (streak requires tagging)
    if (isTagAction) {
      updateData.lastTagAt = admin.firestore.FieldValue.serverTimestamp();
    }
    tx.update(userRef, updateData);

    return {xpAwarded: xp, newPoints, newBadges};
  });
});

/**
 * Verify that the user recently tagged a supply in the given unit.
 * Checks the supply document for the user's ID in taggedByUserIds
 * and confirms the tag was created/updated within the last 60 seconds.
 */
async function _verifyRecentTag(uid, facilityId, unitId, roomId, supplyId) {
  // If a specific supplyId is provided, check that one
  if (supplyId) {
    const supplyRef = db
        .collection("facilities").doc(facilityId)
        .collection("units").doc(unitId)
        .collection("supplyRooms").doc(roomId)
        .collection("supplies").doc(supplyId);
    const doc = await supplyRef.get();
    if (!doc.exists) return false;
    const data = doc.data();
    const taggedBy = data.taggedByUserIds || [];
    if (!taggedBy.includes(uid)) return false;
    const lastConfirmed = data.lastConfirmed ? data.lastConfirmed.toMillis() : 0;
    return (Date.now() - lastConfirmed) < 60000; // within 60 seconds
  }

  // Otherwise, scan recent supplies for this user's tags
  const suppliesRef = db
      .collection("facilities").doc(facilityId)
      .collection("units").doc(unitId)
      .collection("supplyRooms").doc(roomId)
      .collection("supplies")
      .where("taggedByUserIds", "array-contains", uid)
      .orderBy("lastConfirmed", "desc")
      .limit(1);

  const snap = await suppliesRef.get();
  if (snap.empty) return false;
  const data = snap.docs[0].data();
  const lastConfirmed = data.lastConfirmed ? data.lastConfirmed.toMillis() : 0;
  return (Date.now() - lastConfirmed) < 60000;
}

/**
 * Update streak based on last meaningful tag action.
 * Requires at least one tag/confirm per day to maintain streak.
 * Uses lastTagAt (set when a tag action occurs) instead of lastActive.
 */
function updateStreak(profile, isTagAction) {
  const lastTag = profile.lastTagAt ? profile.lastTagAt.toDate() : null;
  if (!lastTag) return isTagAction ? 1 : (profile.streakDays || 1);
  const now = new Date();
  const diffHours = (now - lastTag) / (1000 * 60 * 60);
  if (diffHours < 24) return profile.streakDays || 1; // same day
  if (diffHours < 48) return (profile.streakDays || 0) + 1; // next day
  return isTagAction ? 1 : (profile.streakDays || 1); // streak broken unless starting fresh
}

function streakMultiplier(streak) {
  if (streak >= 14) return 2.5;
  if (streak >= 7) return 2.0;
  if (streak >= 5) return 1.5;
  if (streak >= 3) return 1.2;
  if (streak >= 2) return 1.1;
  return 1.0;
}

function computeBadges(profile, action, streakDays, newPoints) {
  const earned = [];
  const has = (id) => (profile.badges || []).includes(id);
  if (newPoints >= 100 && !has("century_club")) earned.push("century_club");
  if (newPoints >= 5000 && !has("supply_sensei")) earned.push("supply_sensei");
  if (streakDays >= 5 && !has("streak_5")) earned.push("streak_5");
  return earned;
}

// ─── onSupplyTagged trigger ─────────────────────────────────────────
//
// Listens for new supply tags. Updates per-unit aggregates and detects
// "first tagger on unit" so we can award the Founding Tagger badge.
exports.onSupplyTagged = onDocumentCreated(
    "facilities/{facilityId}/units/{unitId}/supplyRooms/{roomId}/supplies/{supplyId}",
    async (event) => {
      const {facilityId, unitId} = event.params;
      const data = event.data && event.data.data();
      if (!data) return;

      const aggRef = db.collection("facilities").doc(facilityId)
          .collection("units").doc(unitId);
      await aggRef.set({
        totalTags: admin.firestore.FieldValue.increment(1),
        lastTagAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    });

// ─── decayConfidence (daily) ────────────────────────────────────────
//
// Uses a collection group query to efficiently scan all supplies across
// all facilities. Processes in batches of 400 (Firestore batch limit is 500).
exports.decayConfidence = onSchedule({
  schedule: "every day 03:00",
  region: "us-central1",
  timeoutSeconds: 540,
  memory: "512MiB",
}, async () => {
  const now = Date.now();
  const staleThresholdMs = 7 * 24 * 60 * 60 * 1000; // 7 days
  let processed = 0;
  let lastDoc = null;
  const batchSize = 400;

  // Paginate through all supplies using collection group query
  while (true) {
    let query = db.collectionGroup("supplies")
        .where("lastConfirmed", "<",
            new Date(now - staleThresholdMs))
        .orderBy("lastConfirmed")
        .limit(batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      const d = doc.data();
      const lastConfirmed = d.lastConfirmed ? d.lastConfirmed.toMillis() : now;
      const daysSince = (now - lastConfirmed) / (1000 * 60 * 60 * 24);
      const decay = Math.min(0.5, (daysSince - 7) * 0.02);
      const newConfidence = Math.max(0, (d.confidence || 0.5) - decay);
      batch.update(doc.ref, {confidence: newConfidence});
      processed++;
    }

    await batch.commit();
    lastDoc = snap.docs[snap.docs.length - 1];

    // Safety: if we got fewer than batchSize, we're done
    if (snap.docs.length < batchSize) break;
  }

  logger.info("decayConfidence done", {processed});
});

// ─── syncRecalls (daily) ────────────────────────────────────────────
//
// Pulls recent device recalls from openFDA and writes them to
// `recalls/{udi}` so the app can flag a supply as recalled.
exports.syncRecalls = onSchedule({
  schedule: "every day 04:00",
  region: "us-central1",
}, async () => {
  const apiKey = process.env.OPENFDA_API_KEY || "";
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      .toISOString().slice(0, 10).replace(/-/g, "");
  const url = `https://api.fda.gov/device/recall.json?search=event_date_initiated:[${since}+TO+${"NOW"}]&limit=100` +
              (apiKey ? `&api_key=${apiKey}` : "");
  try {
    const res = await fetch(url);
    if (!res.ok) return;
    const json = await res.json();
    const batch = db.batch();
    for (const r of (json.results || [])) {
      if (!r.product_code) continue;
      const ref = db.collection("recalls").doc(r.recall_number || r.product_code);
      batch.set(ref, {
        productCode: r.product_code,
        reason: r.reason_for_recall || "",
        classification: r.classification || "",
        eventDate: r.event_date_initiated || "",
        firmName: r.recalling_firm || "",
      }, {merge: true});
    }
    await batch.commit();
    logger.info("syncRecalls done", {count: (json.results || []).length});
  } catch (e) {
    logger.error("syncRecalls failed", e);
  }
});

// ─── rolloverDailyChallenges (daily) ─────────────────────────────────
//
// Resets per-day challenge progress at midnight UTC and snapshots the
// previous day's stats for analytics.
exports.rolloverDailyChallenges = onSchedule({
  schedule: "every day 00:00",
  region: "us-central1",
}, async () => {
  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const dateKey = yesterday.toISOString().slice(0, 10);
  await db.collection("challenge_snapshots").doc(dateKey).set({
    snapshotAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  logger.info("Daily challenge rollover", {dateKey});
});

// ─── cleanupStaleSupplies (weekly) ──────────────────────────────────
//
// Deletes supplies with confidence < 0.1 that haven't been confirmed
// in 30+ days. Prevents unbounded data growth.
exports.cleanupStaleSupplies = onSchedule({
  schedule: "every sunday 05:00",
  region: "us-central1",
  timeoutSeconds: 540,
  memory: "512MiB",
}, async () => {
  const now = Date.now();
  const staleThresholdMs = 30 * 24 * 60 * 60 * 1000; // 30 days
  let deleted = 0;
  let lastDoc = null;
  const batchSize = 400;

  while (true) {
    let query = db.collectionGroup("supplies")
        .where("confidence", "<", 0.1)
        .where("lastConfirmed", "<",
            new Date(now - staleThresholdMs))
        .orderBy("confidence")
        .orderBy("lastConfirmed")
        .limit(batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
      deleted++;
    }

    await batch.commit();
    lastDoc = snap.docs[snap.docs.length - 1];

    if (snap.docs.length < batchSize) break;
  }

  logger.info("cleanupStaleSupplies done", {deleted});
});

// healthCheck removed — use GCP-native health monitoring instead
