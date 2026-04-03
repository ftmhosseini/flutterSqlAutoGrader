import { collection, doc, getDocs, setDoc,getDoc, updateDoc, arrayUnion, query, where, orderBy } from "firebase/firestore";
import { db } from "../../firebase";

const dbCollection = collection(db, "cohorts");

export async function getAllStudents() {
  const q = query(collection(db, "users"), where("role", "==", "student"), orderBy("fullName", "asc"));
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ uid: d.id, ...d.data() }));
}

export async function getCohortsByOwner(ownerUid) {
  const q = query(dbCollection, where("owner_user_id", "==", ownerUid), orderBy("name", "asc"));
  const snap = await getDocs(q);
  return snap.docs.map((d) => d.data());
}
const generateRandomCode = (length) => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  };
export async function createCohort(cohort) {
  let snap;
  let code;
  let ref;
  do{
    code = generateRandomCode(5)
    ref = doc(dbCollection, code);
    snap = await getDoc(ref);
  }while(snap.exists())
  
  await setDoc(ref, { 
    ...cohort, 
    cohort_id: code // Now the code and ID are the same
  });
  return code;
}
export async function JoinCohort(code, user_id) {
  const upperCode = code.trim().toUpperCase();
  const ref = doc(dbCollection, upperCode);
  const snap = await getDoc(ref);

  if (!snap.exists()) throw new Error("No cohort found with this code.");

  await updateDoc(ref, { student_uids: arrayUnion(user_id) });
  return { cohort_id: upperCode, ...snap.data() };
}

export async function updateCohort(cohortId, student_uids) {
  await setDoc(doc(dbCollection, cohortId), { student_uids }, { merge: true });
}
export async function getStudentCohorts(user_id) {
 const q = query(dbCollection, where("student_uids", "array-contains", user_id));
  const snap = await getDocs(q);
  return snap.docs.map((d) => d.data());
 }


export async function getAllCohorts() {
  const q = query(dbCollection, orderBy("name", "asc"));
  const snap = await getDocs(q);
  return snap.docs.map((d) => d.data());
}

export async function getAllStudentsPerCohorts(cohortId) {
  console.log("Inside getAllStudentsPerCohorts: cohortId: ", cohortId)
  const q = query(dbCollection, 
    where("cohort_id", "==", cohortId)
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => d.data());
}

