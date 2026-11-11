import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { isActiveRelationship } from "./relationship_state";

export const endMatch = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const uid = request.auth?.uid;
    const npcId: unknown = request.data?.npcId;

    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in first.");
    }

    if (
      typeof npcId !== "string" ||
      !/^[A-Za-z0-9_-]{1,140}$/.test(npcId)
    ) {
      throw new HttpsError("invalid-argument", "Invalid NPC ID.");
    }

    if (getApps().length === 0) initializeApp();

    const db = getFirestore();
    const matchRef = db.doc(`players/${uid}/matches/${npcId}`);

    return db.runTransaction(async (tx) => {
      const match = await tx.get(matchRef);

      if (!match.exists) {
        throw new HttpsError("not-found", "Match not found.");
      }

      if (!isActiveRelationship(match.get("relationshipStatus"))) {
        return { ended: true, alreadyEnded: true };
      }

      tx.update(matchRef, {
        relationshipStatus: "unmatched_player",
        unmatchReason: "player_choice",
        unmatchedAt: FieldValue.serverTimestamp(),
        replyLock: FieldValue.delete(),
      });

      return { ended: true, alreadyEnded: false };
    });
  },
);