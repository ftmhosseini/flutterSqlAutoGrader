import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import userSession from "../../../../components/services/UserSession";
import { getAssignmentDetailsByAssignmentId } from "../../../../components/model/studentAssignments";
import { getBestAttemptByUserQuestion } from "../../../../components/model/questionAttempts";
import LoadingOverlay from "../LoadingOverlay";
import "./SubmittedQuestions.css";

const SubmittedQuestions = () => {
  const { assignment_id } = useParams();
  const navigate = useNavigate();
  const [questions, setQuestions] = useState([]);
  const [title, setTitle] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [openQuestions, setOpenQuestions] = useState({});

  useEffect(() => {
    const load = async () => {
      try {
        const assignment =
          await getAssignmentDetailsByAssignmentId(assignment_id);
        setTitle(assignment.title || "Assignment");
        const qs = await Promise.all(
          (assignment.questions || []).map(async (q, i) => {
            const attempt = await getBestAttemptByUserQuestion(
              userSession.uid,
              q.question_id,
            );
            return {
              index: i + 1,
              questionText: q.questionText,
              mark: q.mark || 1,
              submittedSql: attempt?.submitted_sql || "-",
              earnedMark: attempt?.is_correct ? q.mark || 1 : 0,
              isCorrect: attempt?.is_correct || false,
            };
          }),
        );
        setQuestions(qs);
      } catch (e) {
        console.error("Failed to load submitted questions:", e);
      } finally {
        setIsLoading(false);
      }
    };
    load();
  }, [assignment_id]);

  const totalEarned = questions.reduce((sum, q) => sum + q.earnedMark, 0);
  const totalMarks = questions.reduce((sum, q) => sum + q.mark, 0);
  const percentage =
    totalMarks > 0 ? Math.round((totalEarned / totalMarks) * 100) : 0;

  const toggleQuestion = (index) => {
    setOpenQuestions((prev) => ({
      ...prev,
      [index]: !prev[index],
    }));
  };

  return (
    <div className="submitted-questions-page">
      <LoadingOverlay isOpen={isLoading} message="Loading..." />

      <div className="submitted-questions-header">
        <div>
          <h4>{title}</h4>
          <p className="submitted-questions-subtitle">
            Review each submitted SQL answer and the score earned for every
            question.
          </p>
        </div>
        <button
          className="btn btn-sm btn-outline-secondary submitted-questions-back"
          onClick={() => navigate(-1)}
        >
          Back
        </button>
      </div>

      {questions.length > 0 && (
        <>
          <div>
            <p className="submitted-score-label">
              Overall Result: {totalEarned} / {totalMarks}
            </p>
          </div>
        </>
      )}

      {questions.length === 0 && !isLoading && (
        <div className="submitted-empty-state">
          No submitted questions found for this assignment.
        </div>
      )}

      {questions.length > 0 && (
        <div className="submitted-question-list">
          {questions.map((q) => (
            <article key={q.index} className="submitted-question-card">
              <button
                type="button"
                className="submitted-question-toggle"
                onClick={() => toggleQuestion(q.index)}
              >
                <div className="submitted-question-top">
                  <div className="submitted-question-heading">
                    <div className="submitted-question-number">{q.index}</div>
                    <div>
                      <p className="submitted-question-index">
                        Question {q.index}
                      </p>
                      <h6 className="submitted-question-text">
                        {q.questionText}
                      </h6>
                    </div>
                  </div>
                  <div className="submitted-question-meta">
                    <span
                      className={`badge submitted-result-badge ${q.isCorrect ? "bg-success" : "bg-danger"}`}
                    >
                      {q.isCorrect ? "Correct" : "Incorrect"}
                    </span>
                    <span className="submitted-expand-icon">
                      {openQuestions[q.index] ? "−" : "+"}
                    </span>
                  </div>
                </div>
              </button>

              {openQuestions[q.index] && (
                <>
                  <div className="submitted-answer-block">
                    <label className="submitted-answer-label">
                      Your Answer
                    </label>
                    <p className="submitted-answer-code">{q.submittedSql}</p>
                  </div>

                  <div className="submitted-question-footer">
                    <span className="submitted-mark">
                      Mark:{" "}
                      <strong>
                        {q.earnedMark} / {q.mark}
                      </strong>
                    </span>
                  </div>
                </>
              )}
            </article>
          ))}
        </div>
      )}
    </div>
  );
};

export default SubmittedQuestions;
