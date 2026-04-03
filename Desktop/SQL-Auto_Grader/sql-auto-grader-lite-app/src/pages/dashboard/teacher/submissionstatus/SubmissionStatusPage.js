import { useState } from "react";
import AssignmentTable from "./studentAssignment/AssignmentTable";
import QuizTable from "./QuizTable";
import StudentAssignmentPage from "./studentAssignment/StudentAssignmentPage";
import "./Submission.css"; 

function SubmissionStatusPage() {
  const [activeTab, setActiveTab] = useState("assignments");
  const [selectedStudentId, setSelectedStudentId] = useState("");
  const [selectedAssignmetId, setselectedAssignmetId] = useState("");

  return (
    <div className="container-fluid submission-page">
      <div className="d-sm-flex align-items-center justify-content-between mb-4">
        <h2 className="cohort-title">Submission Status</h2>
      </div>

      {(selectedStudentId !== "") ? (
        <div className="card shadow mb-4">
          <div className="card-body">
             <StudentAssignmentPage
                studentId={selectedStudentId}
                assignmentId={selectedAssignmetId}
                onBack={() => setSelectedStudentId("")}
              />
          </div>
        </div>
      ) : (
        <div className="card shadow mb-4">
          <div className="card-header py-3">
            <ul className="nav nav-tabs card-header-tabs">
              <li className="nav-item">
                <button
                  className={`nav-link ${activeTab === "assignments" ? "active" : ""}`}
                  onClick={() => setActiveTab("assignments")}
                >
                  Assignments
                </button>
              </li>
              <li className="nav-item">
                <button
                  className={`nav-link ${activeTab === "quizzes" ? "active" : ""}`}
                  onClick={() => setActiveTab("quizzes")}
                >
                  Quizzes
                </button>
              </li>
            </ul>
          </div>
          
          <div className="card-body">
            {activeTab === "assignments" ? (
              <AssignmentTable 
                onSelectStudent={setSelectedStudentId} 
                onselectAssignmentId={setselectedAssignmetId}
              />
            ) : (
              <QuizTable onSelectStudent={setSelectedStudentId} />
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export default SubmissionStatusPage;
