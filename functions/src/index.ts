import {initializeApp} from "firebase-admin/app";

initializeApp();

export {fdProxy} from "./fd-proxy";
export {onUserCreated} from "./on-user-created";
export {onUserDeleted} from "./on-user-deleted";

