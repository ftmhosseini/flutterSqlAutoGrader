import { collection, doc, setDoc } from "firebase/firestore";
import { db, auth } from "../firebase";
import seedData from "./seedData.json";
import questions from "./questions.json";

export async function seedAllData() {
  const ownerUid = auth.currentUser.uid;

  // Seed cohorts
  for (const cohort of seedData.cohorts) {
    await setDoc(doc(db, "cohorts", cohort.cohort_id), {
      ...cohort,
      owner_user_id: ownerUid,
      created_on: new Date(),
    });
  }

  // Seed assignments + their questions
  for (const assignment of seedData.assignments) {
    const { questions: qs, ...assignmentData } = assignment;
    await setDoc(doc(db, "assignments", assignment.assignment_id), {
      ...assignmentData,
      owner_user_id: ownerUid,
      created_on: new Date(),
      updated_on: new Date(),
    });
    for (const q of qs) {
      const qRef = doc(collection(db, "presetQuestions"));
      await setDoc(qRef, {
        ...q,
        question_id: qRef.id,
        assignment_id: assignment.assignment_id,
        created_on: new Date(),
        updated_on: new Date(),
      });
    }
  }

  // Seed preset questions
  for (const [dataset, tables] of Object.entries(questions)) {
    for (const [table, presets] of Object.entries(tables)) {
      for (const preset of presets) {
        await setDoc(doc(db, "presetQuestions", `${dataset}_${table}_${preset.id}`), {
          datasetName: dataset,
          tableName: table,
          question: preset.question,
          answer: preset.answer,
          difficulty: preset.difficulty,
          marks: preset.question_mark,
          max_attemps: preset.max_attemps || 1
        });
      }
    }
  }
}