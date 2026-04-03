import { doc, getDoc, setDoc, getDocs, updateDoc, collection, query, where } from "firebase/firestore";
import { db } from "../../firebase";

export async function getUser(uid) {
  const snap = await getDoc(doc(db, "users", uid));
  return snap.exists() ? snap.data() : null;
}

export async function markUserVerified(uid) {
  await updateDoc(doc(db, "users", uid), { emailVerified: true });
}

export async function createUser(uid, data) {
  await setDoc(doc(db, "users", uid), data);
}

export async function getAllUsers() {
  const snap = await getDocs(collection(db, "users"));
  return snap.docs.map(d => ({ uid: d.id, ...d.data() }));
}
