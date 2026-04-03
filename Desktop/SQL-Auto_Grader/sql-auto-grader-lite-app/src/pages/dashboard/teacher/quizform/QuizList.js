import { useEffect, useState } from "react";
import { getAllQuizByOwner } from "../../../../components/model/quizzes";
import CollapsiblePanel from "../assignmentform/collapsiblepanel/CollapsiblePanel";
import userSession from "../../../../components/services/UserSession";
import "./QuizManager.css";

function QuizList({ onCreate }) {
  const [quizzes, setQuizzes] = useState([]);
  const [expanded, setExpanded] = useState(null);
  const toggleQuiz = (id) => setExpanded(prev => prev === id ? null : id);

  useEffect(() => {
    getAllQuizByOwner(userSession.uid).then((data) => {
      const sorted = [...(data || [])].sort((a, b) => 
        (b.created_on?.toMillis() || 0) - (a.created_on?.toMillis() || 0)
      );
      setQuizzes(sorted);
    });
  }, []);

  return (
    <div className="container-fluid p-0">
      <div className="d-sm-flex align-items-center justify-content-between mb-4 px-3 pt-3">
        <h1 className="h3 mb-0 text-gray-800">Quizzes</h1>
        <button onClick={onCreate} className="btn btn-success btn-icon-split shadow-sm">
          <span className="icon text-white-50">
            <i className="fas fa-plus"></i>
          </span>
          <span className="text">New Quiz</span>
        </button>
      </div>

      <div className="quiz-list-container px-3">
        {quizzes.length === 0 ? (
          <div className="card shadow mb-4">
            <div className="card-body text-center py-5">
              <i className="fas fa-folder-open fa-3x text-gray-300 mb-3"></i>
              <p className="text-gray-500 mb-0">No quizzes found. Create your first one!</p>
            </div>
          </div>
        ) : (
          quizzes.map((a) => (
            <div key={a.quiz_id} className="card shadow mb-3 border-left-primary">
              <CollapsiblePanel
                title={a.title}
                preview={a.questionText?.substring(0, 80) || "(no question content)"}
                isCollapsed={expanded !== a.quiz_id}
                onToggle={() => toggleQuiz(a.quiz_id)}
              >
                <div className="card-body bg-light rounded-bottom">
                  <div className="row">
                    <div className="col-md-6 mb-3">
                      <label className="small font-weight-bold text-primary text-uppercase">Question Text</label>
                      <textarea readOnly value={a.questionText || ""} className="form-control bg-white" rows="3" />
                    </div>
                    <div className="col-md-6 mb-3">
                      <label className="small font-weight-bold text-success text-uppercase">Correct SQL Answer</label>
                      <textarea readOnly value={a.answer || ""} className="form-control bg-white font-italic" rows="3" />
                    </div>
                  </div>
                  
                  <div className="quiz-meta-grid border-top pt-3 mt-2 d-flex flex-wrap">
                    <div className="mr-4 mb-2">
                       <span className="badge badge-info p-2 text-uppercase">Difficulty: {a.difficulty || "easy"}</span>
                    </div>
                    <div className="text-gray-600 small mr-4 mb-2">
                      <i className="fas fa-redo fa-fw mr-1"></i> Max Attempts: <strong>{a.max_attempts || 1}</strong>
                    </div>
                    <div className="text-gray-600 small mr-4 mb-2">
                      <i className="fas fa-star fa-fw mr-1"></i> Mark: <strong>{a.mark || 1}</strong>
                    </div>
                    <div className="text-gray-600 small mr-4 mb-2">
                      <i className="fas fa-sort-amount-down fa-fw mr-1"></i> Order: <strong>{a.orderMatters ? "Yes" : "No"}</strong>
                    </div>
                    <div className="text-gray-600 small mb-2">
                      <i className="fas fa-tag fa-fw mr-1"></i> Alias Strict: <strong>{a.aliasStrict ? "Yes" : "No"}</strong>
                    </div>
                  </div>
                </div>
              </CollapsiblePanel>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export default QuizList;