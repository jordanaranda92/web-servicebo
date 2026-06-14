import {onSchedule} from "firebase-functions/v2/scheduler";
import {getFirestore} from "firebase-admin/firestore";
import {DATABASE_ID} from "./database";

const RETENTION_DAYS = 30;
const BATCH_LIMIT = 500;

/**
 * Runs daily at 03:00 Madrid time.
 * Deletes order documents (and their subcollections) older than
 * RETENTION_DAYS days.
 *
 * Order documents use the date as their ID: "YYYY-MM-DD", so a simple
 * string comparison is enough to decide which ones are expired.
 */
export const cleanupOldOrders = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "Europe/Madrid",
    region: "europe-west1",
  },
  async () => {
    const db = getFirestore(DATABASE_ID);
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - RETENTION_DAYS);
    const cutoffStr = cutoff.toISOString().slice(0, 10); // "YYYY-MM-DD"

    const ordersSnap = await db.collection("orders").get();
    let totalDeleted = 0;

    for (const doc of ordersSnap.docs) {
      // Only process documents whose ID is a valid date <= cutoff
      if (doc.id > cutoffStr) continue;

      await deleteDocumentWithSubcollections(db, doc.ref);
      totalDeleted++;
    }

    console.log(
      "[cleanupOldOrders] Deleted " +
      `${totalDeleted} order(s) older than ${cutoffStr}`
    );
  }
);

/**
 * Deletes a Firestore document together with all its known
 * subcollections (rows, history, meta). Uses batched writes
 * to stay within Firestore limits.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {FirebaseFirestore.DocumentReference} docRef Document
 *   to delete.
 */
async function deleteDocumentWithSubcollections(
  db: FirebaseFirestore.Firestore,
  docRef: FirebaseFirestore.DocumentReference
): Promise<void> {
  const subcollections = ["rows", "history", "meta"];

  for (const sub of subcollections) {
    const subSnap = await docRef.collection(sub).get();
    if (subSnap.empty) continue;

    // Delete in batches of BATCH_LIMIT
    let batch = db.batch();
    let count = 0;
    for (const subDoc of subSnap.docs) {
      batch.delete(subDoc.ref);
      count++;
      if (count % BATCH_LIMIT === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    if (count % BATCH_LIMIT !== 0) {
      await batch.commit();
    }
  }

  // Finally delete the parent document itself
  await docRef.delete();
}
