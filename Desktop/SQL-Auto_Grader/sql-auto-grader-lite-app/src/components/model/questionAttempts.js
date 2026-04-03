import {
  collection,
  doc,
  getCountFromServer,
  getDocs,
  getDoc,
  query,
  setDoc,
  updateDoc,
  where,
  deleteDoc,
} from "firebase/firestore";
import { db } from "../../firebase";

const dbCollection = collection(db, "question_attempts");
const questionCollection = collection(db, "questions");

function toComparableDate(value) {
  if (!value) {
    return Number.NEGATIVE_INFINITY;
  }

  const parsedDate = new Date(value).getTime();
  return Number.isNaN(parsedDate) ? Number.NEGATIVE_INFINITY : parsedDate;
}

function pickBetterAttempt(currentBest, candidate) {
  if (!currentBest) {
    return candidate;
  }

  const bestIsCorrect = Boolean(currentBest.is_correct);
  const candidateIsCorrect = Boolean(candidate.is_correct);

  if (candidateIsCorrect && !bestIsCorrect) {
    return candidate;
  }

  if (!candidateIsCorrect && bestIsCorrect) {
    return currentBest;
  }

  return toComparableDate(candidate.submitted_on) >
    toComparableDate(currentBest.submitted_on)
    ? candidate
    : currentBest;
}

async function createAttempt(questionAttempt) {
  try {
    const newDocRef = doc(dbCollection);
    const attemptId = newDocRef.id;
    await setDoc(newDocRef, {
      ...questionAttempt,
      attempt_id: attemptId,
    });

    return attemptId;
  } catch (error) {
    console.error(`createAttempt: ${error}`);
    return null;
  }
}

async function getAttemptByUserQuestion(userId, questionId) {
  if (!userId || !questionId) return [];
  try {
    const questionQuery = query(
      questionCollection,
      where("question_id", "==", questionId),
    );
    const questionSnapshot = await getDocs(questionQuery);
    const question = questionSnapshot.docs[0]?.data() ?? null;

    const attemptsQuery = query(
      dbCollection,
      where("question_id", "==", questionId),
      where("student_user_id", "==", userId),
    );
    const attemptSnap = await getDocs(attemptsQuery);

    return attemptSnap.docs.map((attemptDoc) => ({
      ...attemptDoc.data(),
      prompt: question?.prompt ?? question?.questionText ?? null,
    }));
  } catch (error) {
    console.error(`getAttemptByUserQuestion: ${error}`);
    return [];
  }
}

async function countAttempt(questionId, userId) {
  try {
    const attemptsQuery = query(
      dbCollection,
      where("question_id", "==", questionId),
      where("student_user_id", "==", userId),
    );
    const snapshot = await getCountFromServer(attemptsQuery);
    return snapshot.data().count;
  } catch (error) {
    console.error(`countAttempt: ${error}`);
    return 0;
  }
}

async function getBestAttemptByUserQuestion(userId, questionId) {
  const attempts = await getAttemptByUserQuestion(userId, questionId);
  if (attempts.length === 0) return null;
  return attempts.reduce(pickBetterAttempt, null);
}

// Returns the attempt selected by grading policy: 'best' | 'first' | 'latest'
async function getAttemptByPolicy(userId, questionId, policy = 'best') {
  const attempts = await getAttemptByUserQuestion(userId, questionId);
  if (attempts.length === 0) return null;
  if (policy === 'first') {
    return attempts.reduce((a, b) => toComparableDate(a.submitted_on) <= toComparableDate(b.submitted_on) ? a : b);
  }
  if (policy === 'latest') {
    return attempts.reduce((a, b) => toComparableDate(a.submitted_on) >= toComparableDate(b.submitted_on) ? a : b);
  }
  return attempts.reduce(pickBetterAttempt, null); // 'best'
}

async function getStudentInfo(studentId) {
  try {
    const snap = await getDoc(doc(db, "users", studentId));
    return snap.exists() ? snap.data() : null;
  } catch (error) {
    console.error(`getStudentInfo: ${error}`);
    return null;
  }
}

async function getAttemptsByStudent(studentId) {
  try {
    const q = query(dbCollection, where("student_user_id", "==", studentId));
    const snap = await getDocs(q);
    return snap.docs.map(d => ({ id: d.id, ...d.data() }));
  } catch (error) {
    console.error(`getAttemptsByStudent: ${error}`);
    return [];
  }
}
// added by sreyasi: Compute grade for a single question
function computeQuestionGrade(question, attempt) {
  console.log("Inside computeQuestionGrade - question, attempt: ",question, attempt);
  if (!attempt) return 0;
  return attempt.is_correct ? question.mark : 0;
}

async function overrideAttemptMark(attemptId, is_correct) {
  try {
    const q = query(dbCollection, where("attempt_id", "==", attemptId));
    const snap = await getDocs(q);
    if (!snap.empty) await updateDoc(snap.docs[0].ref, { is_correct });
  } catch (error) {
    console.error(`overrideAttemptMark: ${error}`);
  }
}

// added by sreyasi: Compute total earned + total possible marks
function computeTotalMarks(questions, attempts) {
  console.log("Inside computeTotalMarks - questions, attempts: ",questions, attempts);
  let earned = 0;
  let total = 0;

  questions.forEach(q => {
    total += q.mark;

    const attempt = attempts.find(a => a.question_id === q.question_id);
    if (!attempt) return;

    if (attempt.is_correct) {
      earned += q.mark;
    }
  });

  return { earned, total };
}

async function updateAttemptCorrectness(attemptId, newValue) {
  const ref = doc(db, "question_attempts", attemptId);
  console.log("Inside  updateAttemptCorrectness: ref, newValue ", ref, newValue);
  await updateDoc(ref, {
    is_correct: newValue
  });

  return true;
}

async function deleteAttemptsByAssignment( questionId, StudentId) {

  const q = query(dbCollection, 
    where("question_id", "==", questionId),
    where("student_user_id", "==", StudentId),

  );
  
  const snap = await getDocs(q);
  if (!snap.empty){
    const deletions = snap.docs.map(d => deleteDoc(d.ref));
    await Promise.all(deletions);
    console.log(`Deleted ${snap.size} docs from ${dbCollection} where student_user_id=${StudentId}`);    
  }else{
    console.log("no attempt record found to delete");    
  }
}
export {
  countAttempt,
  createAttempt,
  getBestAttemptByUserQuestion,
  getAttemptByPolicy,
  getAttemptByUserQuestion,
  getStudentInfo,
  getAttemptsByStudent,
  overrideAttemptMark,
  computeQuestionGrade,
  computeTotalMarks,
  updateAttemptCorrectness,
  deleteAttemptsByAssignment,
};
