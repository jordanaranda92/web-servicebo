import * as functionsV1 from "firebase-functions/v1";
import {getFirestore} from "firebase-admin/firestore";

export const onUserDeleted = functionsV1
  .region("europe-west1")
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const docRef = getFirestore().collection("users").doc(uid);
    const snap = await docRef.get();
    if (snap.exists) {
      await docRef.delete();
      console.log(`[onUserDeleted] Documento users/${uid} eliminado`);
    } else {
      console.log(`[onUserDeleted] No existía users/${uid}, nada que borrar`);
    }
  });
