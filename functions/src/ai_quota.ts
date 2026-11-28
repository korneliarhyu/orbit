import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

// Demo limits are shared across all NPC rooms of one account.
const AI_MINUTE_LIMIT = 5;
const AI_DAILY_LIMIT = 30;
const AI_PARALLEL_LIMIT = 2;
const WINDOW_MS = 60_000;
const LEASE_MS = 90_000; // Longer than the 60s callable timeout.
const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;

type Lease = { id: string; expiresAt: number };

function activeLeases(value: unknown, now: number): Lease[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is Lease =>
    item !== null && typeof item === "object" &&
    typeof item.id === "string" &&
    typeof item.expiresAt === "number" &&
    Number.isFinite(item.expiresAt) && item.expiresAt > now,
  );
}

function wibDay(now: number): string {
  return new Date(now + WIB_OFFSET_MS).toISOString().slice(0, 10);
}

// Reserve before starting paid generation. Failed attempts are not refunded.
// Mock generation also counts so the same protection can be tested locally.
export async function reserveAiRequest(
  db: Firestore,
  uid: string,
  leaseId: string,
): Promise<boolean> {
  const ref = db.doc(`orbitRateLimits/${uid}`);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const now = Date.now();
    const day = wibDay(now);
    const storedCount: unknown = snapshot.get("aiDailyCount");
    const dailyCount = snapshot.get("aiDayKey") === day &&
      typeof storedCount === "number" && Number.isSafeInteger(storedCount) &&
      storedCount >= 0 ? storedCount : 0;
    const storedTimes: unknown = snapshot.get("aiRequestTimestamps");
    const recent: number[] = Array.isArray(storedTimes)
      ? storedTimes.filter((value): value is number =>
          typeof value === "number" && Number.isFinite(value) &&
          value > now - WINDOW_MS,
        )
      : [];
    const leases = activeLeases(snapshot.get("aiActiveLeases"), now);

    if (dailyCount >= AI_DAILY_LIMIT) {
      throw new HttpsError("resource-exhausted", "Daily AI quota reached.", {
        reason: "ai_daily_quota",
      });
    }
    if (recent.length >= AI_MINUTE_LIMIT) {
      throw new HttpsError("resource-exhausted", "AI request rate limit reached.", {
        reason: "ai_rate_limit",
      });
    }
    // Existing client busy-retry logic handles temporary concurrency limits.
    // No quota is consumed for a rejected reservation.
    if (leases.length >= AI_PARALLEL_LIMIT) return false;

    tx.set(ref, {
      aiDayKey: day,
      aiDailyCount: dailyCount + 1,
      aiRequestTimestamps: [...recent, now],
      aiActiveLeases: [...leases, { id: leaseId, expiresAt: now + LEASE_MS }],
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });
}

export async function releaseAiRequest(
  db: Firestore,
  uid: string,
  leaseId: string,
): Promise<void> {
  const ref = db.doc(`orbitRateLimits/${uid}`);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return;
    const leases = activeLeases(snapshot.get("aiActiveLeases"), Date.now());
    tx.update(ref, {
      aiActiveLeases: leases.filter((lease) => lease.id !== leaseId),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}
