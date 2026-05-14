import * as functionsV1 from "firebase-functions/v1";
import {getFirestore} from "firebase-admin/firestore";

export const onUserCreated = functionsV1
  .region("europe-west1")
  .auth.user()
  .onCreate(async (user) => {
    const uid = user.uid;
    const email = user.email ?? "";
    const userName = email.split("@")[0] || "";

    await getFirestore().collection("users").doc(uid).set({
      userName,
      role: "employee",
    });

    console.log(
      `[onUserCreated] Documento users/${uid} creado con userName="${userName}"`
    );
  });
