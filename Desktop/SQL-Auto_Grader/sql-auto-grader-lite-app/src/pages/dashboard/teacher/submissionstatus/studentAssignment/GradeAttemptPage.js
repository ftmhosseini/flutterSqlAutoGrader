// import { useEffect, useState } from "react";
// import { updateAttemptCorrectness } from "../../../../../components/model/questionAttempts";
// import { CodeEditor } from "../../../teacher/assignmentform/createquestionset/CodeEditor";
// import "./StudentAssignmentPage.css";
// //import "./GradeAttemptPage.css"

// export default function GradeAttemptPage({ attempt, question, autoGrade, dataset, onClose }) {
  
//   const [isCorrect, setIsCorrect] = useState(attempt.is_correct ?? false);
//   //const computedMark = isCorrect ? question.mark : 0;
 
//   async function handleToggle() {
//     const newValue = !isCorrect;

//     await updateAttemptCorrectness(attempt.id, newValue);

//     setIsCorrect(newValue);
//     onClose();
// }

//   return (
//     <div className="grading-container">
//       <div className="teacher-box">
//         <h3>Expected Answer</h3>
//         <pre>{question.answer}</pre>
//         <p><strong>Marks:</strong> {question.mark}</p>
//         <p><strong>Order Matters:</strong> {String(question.orderMatters)}</p>
//         <p><strong>Alias Strict:</strong> {String(question.aliasStrict)}</p>
//       </div>

//       <div className="student-box">
//         <h3>Student Answer</h3>
//         <pre>{attempt.submitted_sql}</pre>
//       </div>

//       <div className="editor-box">
//         <CodeEditor selectedDataset={dataset} />
//       </div>
//       <div className="bottom-box">
//         <div className="grade-display">
//           <strong>Mark:</strong> {isCorrect ? question.mark : 0} / {question.mark}
//       </div>
//       <div style={{ marginTop: '20px', display: "flex", gap: "12px" }}>
//         <button className="toggle-btn" onClick={handleToggle}>
//           {isCorrect ? "Mark Incorrect" : "Mark Correct"}
//         </button>
//         <button className="close-btn" onClick={onClose}>
//           Cancel
//         </button>
//       </div>
//     </div>    
      
//     </div>
//   );
// }

import { useEffect, useState } from "react";
import { updateAttemptCorrectness } from "../../../../../components/model/questionAttempts";
import { CodeEditor } from "../../../teacher/assignmentform/createquestionset/CodeEditor";
import "./GradeAttemptPage.css";

export default function GradeAttemptPage({ attempt, question, autoGrade, dataset, onClose }) {
  
  const [isCorrect, setIsCorrect] = useState(attempt.is_correct ?? false);
 
  async function handleToggle() {
    const newValue = !isCorrect;
    await updateAttemptCorrectness(attempt.id, newValue);
    setIsCorrect(newValue);
    onClose();
  }

  return (
    <div className="grading-container">

      <div className="grading-top">
        <div className="teacher-box">
          <h3>Expected Answer</h3>
          <pre>{question.answer}</pre>
          <p><strong>Marks:</strong> {question.mark}</p>
          <p><strong>Order Matters:</strong> {String(question.orderMatters)}</p>
          <p><strong>Alias Strict:</strong> {String(question.aliasStrict)}</p>
        </div>

        <div className="student-box">
          <h3>Student Answer</h3>
          <pre>{attempt.submitted_sql}</pre>
        </div>
      </div>
      <div className="editor-box">
        <CodeEditor selectedDataset={dataset} />
      </div>

      <div className="bottom-box">
        <div className="grade-display">
          <strong>Mark:</strong> {isCorrect ? question.mark : 0} / {question.mark}
        </div>
        <div style={{ display: "flex", gap: "12px" }}>
          <button className="toggle-btn" onClick={handleToggle}>
            {isCorrect ? "Mark Incorrect" : "Mark Correct"}
          </button>
          <button className="close-btn" onClick={onClose}>
            Cancel
          </button>
        </div>
      </div>

    </div>
  );
}