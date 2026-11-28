
import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { isActiveRelationship } from "./relationship_state";

// ==========================================
// RATE LIMIT CONFIGURATION
// ==========================================

const MESSAGE_LIMIT = 5;
const MESSAGE_WINDOW_MS = 60_000;

const validId = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[A-Za-z0-9_-]{1,140}$/.test(value);

// ==========================================
// SEND PLAYER MESSAGE
// ==========================================

export const sendPlayerMessage = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const uid = request.auth?.uid;
    const npcId: unknown = request.data?.npcId;
    const text: unknown = request.data?.text;

    // Authentication
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in first.",
      );
    }

    // Input validation
    if (
      !validId(npcId) ||
      typeof text !== "string" ||
      !text.trim() ||
      text.trim().length > 1000
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid message.",
      );
    }

    const messageText = text.trim();

    if (getApps().length === 0) initializeApp();

    const db = getFirestore();

    const matchRef = db.doc(
      `players/${uid}/matches/${npcId}`,
    );

    const messageRef = matchRef
      .collection("messages")
      .doc();

    // Server-only rate limit document.
    const limitRef = db.doc(
      `orbitRateLimits/${uid}`,
    );

    await db.runTransaction(async (tx) => {
      // All reads before writes.
      const [match, limitSnapshot] = await Promise.all([
        tx.get(matchRef),
        tx.get(limitRef),
      ]);

      // Validate conversation.
      if (!match.exists) {
        throw new HttpsError(
          "not-found",
          "Match not found.",
        );
      }

      if (!isActiveRelationship(
        match.get("relationshipStatus")
      )) {
        throw new HttpsError(
          "failed-precondition",
          "This conversation has ended.",
        );
      }

      // ======================================
      // ROLLING WINDOW RATE LIMIT
      // ======================================

      const now = Date.now();

      const storedTimestamps: unknown =
        limitSnapshot.get("messageTimestamps");

      const recentTimestamps: number[] =
        Array.isArray(storedTimestamps)
          ? storedTimestamps.filter(
              (value): value is number =>
                typeof value === "number" &&
                Number.isFinite(value) &&
                value > now - MESSAGE_WINDOW_MS,
            )
          : [];

      if (recentTimestamps.length >= MESSAGE_LIMIT) {
        throw new HttpsError(
          "resource-exhausted",
          "You're sending messages too quickly. Try again shortly.",
        );
      }

      // Update rate limit.
      tx.set(
        limitRef,
        {
          messageTimestamps: [
            ...recentTimestamps,
            now,
          ],
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // ======================================
      // CREATE PLAYER MESSAGE
      // ======================================

      tx.create(messageRef, {
        sender: "player",
        text: messageText,
        createdAt: FieldValue.serverTimestamp(),

        // Delivery & read receipts
        deliveredAt: null,
        readAt: null,
      });
    });

    return {
      messageId: messageRef.id,
    };
  },
);