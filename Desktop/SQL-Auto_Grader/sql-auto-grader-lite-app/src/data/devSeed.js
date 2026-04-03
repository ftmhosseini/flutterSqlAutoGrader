// DEV ONLY — delete this file and its imports in Dashboard.js before pushing to GitHub
import { collection, doc, setDoc } from "firebase/firestore";
import { db, auth } from "../firebase";
import seedData from "./seedData.json";
import questions from "./questions.json";
import dbConfig from "./db-config.json";

export async function seedAllData() {
  const ownerUid = auth.currentUser.uid;

  for (const cohort of seedData.cohorts) {
    await setDoc(doc(db, "cohorts", cohort.cohort_id), {
      ...cohort,
      owner_user_id: ownerUid,
      created_on: new Date(),
    });
  }

  for (const assignment of seedData.assignments) {
    const { questions: qs, ...assignmentData } = assignment;
    await setDoc(doc(db, "assignments", assignment.assignment_id), {
      ...assignmentData,
      questions: qs,
      owner_user_id: ownerUid,
      created_on: new Date(),
      updated_on: new Date(),
    });
  }

  for (const [dataset, tables] of Object.entries(questions)) {
    for (const [table, presets] of Object.entries(tables)) {
      for (const preset of presets) {
        await setDoc(doc(db, "presetQuestions", `${dataset}_${table}_${preset.id}`), {
          datasetName: dataset,
          tableName: table,
          question: preset.question,
          answer: preset.answer,
          difficulty: preset.difficulty,
          mark: preset.mark,
          max_attempts: preset.max_attempts,
        });
      }
    }
  }
}

export async function uploadDbConfig() {
  await setDoc(doc(db, "sqliteConfigs", "mainConfig"), dbConfig);
}
