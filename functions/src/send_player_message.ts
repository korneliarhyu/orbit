import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { isActiveRelationship } from "./relationship_state";

const validId = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[A-Za-z0-9_-]{1,140}$/.test(value);

export const sendPlayerMessage = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const uid = request.auth?.uid;
    const npcId: unknown = request.data?.npcId;
    const text: unknown = request.data?.text;

    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in first.");
    }

    if (
      !validId(npcId) ||
      typeof text !== "string" ||
      !text.trim() ||
      text.trim().length > 1000
    ) {
      throw new HttpsError("invalid-argument", "Invalid message.");
    }

    if (getApps().length === 0) initializeApp();

    const db = getFirestore();
    const matchRef = db.doc(`players/${uid}/matches/${npcId}`);
    const messageRef = matchRef.collection("messages").doc();

    await db.runTransaction(async (tx) => {
      const match = await tx.get(matchRef);

      if (!match.exists) {
        throw new HttpsError("not-found", "Match not found.");
      }

      if (!isActiveRelationship(match.get("relationshipStatus"))) {
        throw new HttpsError(
          "failed-precondition",
          "This conversation has ended.",
        );
      }

      tx.create(messageRef, {
        sender: "player",
        text: text.trim(),
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    return { messageId: messageRef.id };
  },
);