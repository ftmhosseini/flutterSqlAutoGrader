import {
  collection,
  doc,
  getDocs,
  getDoc,
  query,
  setDoc,
  updateDoc,
  where,
  orderBy,
  deleteDoc,
} from "firebase/firestore";
import { db } from "../../firebase";
import {getAllStudentsPerCohorts} from "./cohorts"
import { deleteAttemptsByAssignment } from "./questionAttempts";
import { deleteAssignmentByAssignmentId } from "./studentAssignments";

const dbCollection = collection(db, "assignments");
const today = () => new Date().toISOString().split("T")[0]; // YYYY-MM-DD

async function createNewAssignment(assignment) {
  try {
    const newDocRef = doc(dbCollection);
    const assignmentId = newDocRef.id;
    await setDoc(newDocRef, { ...assignment, assignment_id: assignmentId });
    return assignmentId;
  } catch (error) {
    console.error(`createNewAssignment: ${error}`);
  }
}

// Teacher: only their own assignments, ordered by due date
async function getAllAssignmentByOwner(ownerId) {
  try {
    const q = query(dbCollection, where("owner_user_id", "==", ownerId));
    const snap = await getDocs(q);
    return snap.docs.map(d => d.data()).sort((a, b) => {
      const aDate = a.due_date || a.dueDate || "";
      const bDate = b.due_date || b.dueDate || "";
      return aDate.localeCompare(bDate);
    });
  } catch (error) {
    console.error(`getAllAssignmentByOwner: ${error}`);
    return [];
  }
}

async function updateAssignment(assignment) {
  try {
    const assignmentQuery = query(
      dbCollection,
      where("assignment_id", "==", assignment.assignment_id),
    );
    const objAssignment = await getDocs(assignmentQuery);

    if (objAssignment.empty) {
      return null;
    }
    const assignmentDocRef = objAssignment.docs[0].ref;
    await updateDoc(assignmentDocRef, assignment);
    return assignmentDocRef;
  } catch (error) {
    console.error(`updateAssignment: ${error}`);
  }
}

async function getAssignmentsForStudent(cohortIds) {
  try {
    // includes assignments assigned to "all" or any of the student's cohorts
    const targets = ["all", ...cohortIds];
    const assignmentsQuery = query(dbCollection, where("student_class", "in", targets));
    const querySnapshot = await getDocs(assignmentsQuery);
    return querySnapshot.docs.map((d) => d.data());
  } catch (error) {
    console.error(`getAssignmentsForStudent: ${error}`);
    return [];
  }
}

async function addQuestionToAssignment(assignmentId, incomeQuestion) {
  try {
    const docSnap = await getDoc(doc(db, 'assignments', assignmentId));
    if (!docSnap.exists()) return null;

    const existing = docSnap.data().questions || [];
    await updateDoc(docSnap.ref, { questions: [...existing, incomeQuestion] });
  } catch (error) {
    console.error(`addQuestionToAssignment: ${error}`);
  }
}

async function getStudentCohortIds(studentUid) {
  try {
    const snap = await getDocs(query(collection(db, "cohorts"), where("student_uids", "array-contains", studentUid)));
    return snap.docs.map(d => d.data().cohort_id);
  } catch (error) {
    console.error(`getStudentCohortIds: ${error}`);
    return [];
  }
}
async function deleteAssignment(assignmentId) {
  try {
    const docSnap = await getDoc(doc(db, 'assignments', assignmentId));
    if (!docSnap.exists()) return null;
    console.log(docSnap.data());    

    const assignmentDocRef = docSnap.data();
    console.log("assignmentDocRef: ", assignmentDocRef);
    const cohort_students = await getAllStudentsPerCohorts(assignmentDocRef.student_class);
    const studentUids = cohort_students[0]?.student_uids || [];
    const questionIds = assignmentDocRef.questions.map(q => q.question_id);
    console.log("cohort_students: ", cohort_students);
    console.log("questionIds: ", questionIds);
    for (const student of studentUids) {
      for (const qid of questionIds) {
        console.log("calling delete function for student: ", student, "question_id:", qid);
        deleteAttemptsByAssignment(qid, student);
      }
    }

    //delete records from student_assignments deleteAssignmentByAssignmentId(assignmentId) 
    await deleteAssignmentByAssignmentId(assignmentDocRef.assignment_id);

    //await deleteDoc(assignmentDocRef, assignment);
    await deleteDoc(doc(db, 'assignments', assignmentId));
    return assignmentDocRef;
  } catch (error) {
    console.error(`deleteAssignment: ${error}`);
  }
}
export { createNewAssignment, getAllAssignmentByOwner, updateAssignment, getAssignmentsForStudent, addQuestionToAssignment, deleteAssignment };
