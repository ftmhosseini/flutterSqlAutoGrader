import {
  collection,
  doc,
  getDocs,
  getDoc,
  setDoc,
  query,
  where,
  getCountFromServer,
  orderBy,
} from "firebase/firestore";
import { db } from "../../firebase";

const quizCol = collection(db, "student_quizzes");
const quizzesCol = collection(db, "quizzes");

export async function getAllQuizByOwner(ownerId) {
  try {
    const snap = await getDocs(
      query(quizzesCol, where("owner_user_id", "==", ownerId)),
    );
    return snap.docs
      .map((d) => d.data())
      .sort(
        (a, b) =>
          (b.created_on?.toMillis?.() ?? 0) - (a.created_on?.toMillis?.() ?? 0),
      );
  } catch (e) {
    console.error("getAllQuizByOwner:", e);
    return [];
  }
}

export async function createNewQuiz(quiz) {
  try {
    const ref = doc(quizzesCol);
    await setDoc(ref, { ...quiz, quiz_id: ref.id });
    return ref.id;
  } catch (e) {
    console.error("createNewQuiz:", e);
  }
}

export async function getQuizzesForStudent(studentId) {
  try {
    const cohortSnap = await getDocs(
      query(collection(db, "cohorts"), where("student_uids", "array-contains", studentId)),
    );
    const cohortIds = cohortSnap.docs.map((d) => d.data().cohort_id);
    const targets = ["all", ...cohortIds];

    const submissionSnap = await getDocs(
      query(quizCol, where("student_user_id", "==", studentId)),
    );
    const submissionMap = {};
    submissionSnap.docs.forEach((d) => { submissionMap[d.data().quiz_id] = d.data(); });

    // fetch quizzes by cohort
    const quizSnap = targets.length
      ? await getDocs(query(quizzesCol, where("student_class", "in", targets)))
      : { docs: [] };
    const quizMap = {};
    quizSnap.docs.forEach((d) => { quizMap[d.data().quiz_id] = d.data(); });

    // also fetch quizzes the student already submitted (cohort may be deleted)
    const submittedQuizIds = Object.keys(submissionMap).filter(id => !quizMap[id]);
    if (submittedQuizIds.length) {
      for (let i = 0; i < submittedQuizIds.length; i += 10) {
        const snap = await getDocs(query(quizzesCol, where("quiz_id", "in", submittedQuizIds.slice(i, i + 10))));
        snap.docs.forEach((d) => { quizMap[d.data().quiz_id] = d.data(); });
      }
    }

    return Object.values(quizMap).map((q) => {
      const sub = submissionMap[q.quiz_id];
      return { ...q, status: sub ? "Completed" : "New", achievedMark: sub ? sub.mark : null };
    });
  } catch (e) {
    console.error("getQuizzesForStudent:", e);
    return [];
  }
}

export async function submitStudentQuiz({
  quiz_id,
  student_user_id,
  submitted_sql,
  is_correct,
  mark,
}) {
  try {
    const ref = doc(quizCol);
    await setDoc(ref, {
      student_quiz_id: ref.id,
      quiz_id,
      student_user_id,
      submitted_sql,
      is_correct,
      mark,
      status: "submitted",
      submissionDate: new Date().toISOString(),
    });
    return ref.id;
  } catch (e) {
    console.error("submitStudentQuiz:", e);
  }
}

export async function getQuizById(quiz_id) {
  try {
    const snap = await getDocs(
      query(quizzesCol, where("quiz_id", "==", quiz_id)),
    );
    return snap.empty ? null : snap.docs[0].data();
  } catch (e) {
    console.error("getQuizById:", e);
    return null;
  }
}

export async function getStudentQuizSubmission(quiz_id, student_user_id) {
  try {
    const snap = await getDocs(
      query(
        quizCol,
        where("quiz_id", "==", quiz_id),
        where("student_user_id", "==", student_user_id),
      ),
    );
    if (snap.empty) return null;
    return snap.docs[0].data();
  } catch (e) {
    console.error("getStudentQuizSubmission:", e);
    return null;
  }
}

// export async function totalQuizesByStudent(studentId) {
//   try {
//     const quizzQuery = query(
//       quizCol,
//       where("student_user_id", "==", studentId),
//     );
//     const snapshot = await getCountFromServer(quizzQuery);
//     return snapshot.data().count;
//   } catch (error) {
//     console.error(`totalQuizesByStudent: ${error}`);
//     return 0;
//   }
// }

export async function getQuizSubmissionsWithDetails(teacherId) {
  try {
    // Only this teacher's quizzes, ordered by creation date
    const teacherQuizzesSnap = await getDocs(
      query(quizzesCol, where("owner_user_id", "==", teacherId)),
    );
    const teacherQuizzes = teacherQuizzesSnap.docs.map(d => d.data()).sort((a, b) => (b.created_on?.toMillis?.() ?? 0) - (a.created_on?.toMillis?.() ?? 0));
    if (!teacherQuizzes.length) { console.warn('[QuizTable] No quizzes found for teacher:', teacherId); return []; }

    const quizMap = {};
    teacherQuizzes.forEach((q) => {
      quizMap[q.quiz_id] = q;
    });
    const teacherQuizIds = teacherQuizzes.map((q) => q.quiz_id);

    // Submissions for those quizzes ordered by submissionDate desc
    let submissions = [];
    for (let i = 0; i < teacherQuizIds.length; i += 10) {
      const snap = await getDocs(
        query(quizCol, where("quiz_id", "in", teacherQuizIds.slice(i, i + 10))),
      );
      submissions.push(...snap.docs.map((d) => ({ id: d.id, ...d.data() })));
    }

    const userIds = [...new Set(submissions.map((s) => s.student_user_id))];
    const userSnaps = await Promise.all(
      userIds.map((uid) => getDoc(doc(db, "users", uid))),
    );
    const userMap = {};
    userSnaps.forEach((s, i) => {
      if (s.exists()) userMap[userIds[i]] = s.data();
    });

    // Build submitted rows
    const submissionMap = {};
    submissions.forEach((s) => {
      submissionMap[`${s.quiz_id}_${s.student_user_id}`] = s;
    });

    // Include all students in cohorts for not-yet-submitted rows
    const cohortIds = [
      ...new Set(teacherQuizzes.map((q) => q.student_class).filter(Boolean)),
    ];
    let cohortStudentMap = {};
    if (cohortIds.length) {
      const cohortSnaps = await getDocs(
        query(collection(db, "cohorts"), where("cohort_id", "in", cohortIds)),
      );
      cohortSnaps.docs.forEach((d) => {
        const c = d.data();
        cohortStudentMap[c.cohort_id] = c.student_uids || [];
      });
      const allStudentIds = [
        ...new Set(Object.values(cohortStudentMap).flat()),
      ];
      const studentSnaps = await Promise.all(
        allStudentIds.map((uid) => getDoc(doc(db, "users", uid))),
      );
      studentSnaps.forEach((s, i) => {
        if (s.exists()) userMap[allStudentIds[i]] = s.data();
      });
    }

    const result = [];
    teacherQuizzes.forEach((q) => {
      const students = cohortStudentMap[q.student_class] || [];
      // also include any students who already submitted, even if cohort is gone
      const submittedStudents = submissions
        .filter(s => s.quiz_id === q.quiz_id)
        .map(s => s.student_user_id);
      const allStudents = [...new Set([...students, ...submittedStudents])];

      allStudents.forEach(uid => {
        const sub = submissionMap[`${q.quiz_id}_${uid}`];
        result.push({
          id: `${q.quiz_id}_${uid}`,
          quiz_id: q.quiz_id,
          student_user_id: uid,
          studentName: userMap[uid]?.fullName || "Unknown",
          quizTitle: q.title || "Quiz",
          status: sub ? "Submitted" : "Assigned",
          submissionDate: sub?.submissionDate || "-",
          mark: sub?.mark ?? "-",
        });
      });
    });

    console.log('[QuizTable] quizzes:', teacherQuizzes.map(q => ({ quiz_id: q.quiz_id, title: q.title, student_class: q.student_class })));
    console.log('[QuizTable] submissions:', submissions.length);
    console.log('[QuizTable] cohortStudentMap:', cohortStudentMap);
    console.log('[QuizTable] result rows:', result.length);
    return result;
  } catch (e) {
    console.error("getQuizSubmissionsWithDetails:", e);
    return [];
  }
}
