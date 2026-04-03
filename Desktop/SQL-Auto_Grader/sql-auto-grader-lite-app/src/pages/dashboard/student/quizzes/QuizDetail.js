import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { useAppContext } from "../../../../components/db/service/context";
import { isSelectQuery } from "../../../../components/db/queryValidation";
import { compareQueryResult } from "../../../../components/comparison/sqlComparison";
import { normalizeQuery } from "../../../../components/db/queryValidation";
import CodeMirror from "@uiw/react-codemirror";
import { sql } from "@codemirror/lang-sql";
import { SQL_KEYWORDS } from "../../../../components/db/common";
import { autocompletion, completeFromList } from "@codemirror/autocomplete";
import { EditorView, keymap } from "@codemirror/view";
import {
  submitStudentQuiz,
  getStudentQuizSubmission,
  getQuizById,
} from "../../../../components/model/quizzes";
import { useParams } from "react-router-dom";
import "../assignments/AssignmentDetail.css";
import TableSchema from "../../tableView/TableSchema";
import userSession from "../../../../components/services/UserSession";

const QuizDetail = () => {
  const { getTableSchemaInTable, fetchItems } = useAppContext();
  const navigate = useNavigate();
  const location = useLocation();
  const { quiz_id } = useParams();
  const [quiz, setQuiz] = useState(location.state?.quiz || null);

  useEffect(() => {
    if (!quiz && quiz_id) {
      getQuizById(quiz_id).then((data) => {
        if (data) setQuiz({ ...data, status: "New" });
      });
    }
  }, [quiz_id]);

  const [sqlCode, setSqlCode] = useState("");
  const [expectedResult, setExpectedResult] = useState([]);
  const [studentResult, setStudentResult] = useState([]);
  const [isCorrect, setIsCorrect] = useState(false);
  const [error, setError] = useState("");
  const [submitted, setSubmitted] = useState(false);
  useEffect(() => {
    if (quiz?.status === "Completed") setSubmitted(true);
  }, [quiz]);
  const [showResults, setShowResults] = useState(false);
  const [tableSchemas, setTableSchemas] = useState({});

  const [viewSql, setViewSql] = useState(null);

  useEffect(() => {
    if (quiz?.status !== "Completed") return;
    const user = userSession.uid;
    if (!user) return;
    getStudentQuizSubmission(quiz.quiz_id, user).then((sub) => {
      if (sub?.submitted_sql) {
        setSqlCode(sub.submitted_sql);
        setViewSql(sub.submitted_sql);
      }
    });
  }, [quiz]);

  useEffect(() => {
    if (!viewSql || expectedResult.length === 0) return;
    const normalizedquery = normalizeQuery(viewSql);
    fetchItems(quiz.dataset, normalizedquery).then((result) => {
      if (result?.isSuccessful && result.data?.length > 0) {
        const columns = Object.keys(result.data[0]);
        const values = result.data.map((row) => Object.values(row));
        const formatted = [{ lc: columns, values }];
        setStudentResult(formatted);
        setIsCorrect(
          compareQueryResult(
            expectedResult,
            formatted,
            quiz?.orderMatters,
            quiz?.aliasStrict,
          ),
        );
      }
      setShowResults(true);
    });
  }, [viewSql, expectedResult]);

  useEffect(() => {
    if (!quiz?.dataset || !quiz?.answer) return;
    const normalizedquery = normalizeQuery(quiz?.answer);
    console.log(normalizedquery);

    fetchItems(quiz.dataset, normalizedquery).then((result) => {
      const rows = result?.data;
      if (!rows || rows.length === 0) return;
      const columns = Object.keys(rows[0]);

      // 2. Extract Values (convert each object into an array of its values)
      const values = rows.map((row) => Object.values(row));

      // 3. Format it for your JSX
      const formattedData = {
        lc: columns,
        values: values,
      };
      setExpectedResult(formattedData ? [formattedData] : []);
    });
    (quiz.tables || []).forEach((table) => {
      getTableSchemaInTable(quiz.dataset, table).then((schema) =>
        setTableSchemas((prev) => ({ ...prev, [table]: schema })),
      );
    });
  }, [quiz]);

  const sqlKeywordCompletions = completeFromList(
    SQL_KEYWORDS.map((keyword) => ({
      label: keyword,
      type: "keyword",
    })),
  );
  const executeAndCompare = async () => {
    if (!isSelectQuery(sqlCode)) {
      setError("Only SELECT queries are allowed.");
      setStudentResult([]);
      setIsCorrect(false);
      return false;
    }
    const result = await fetchItems(quiz.dataset, sqlCode);
    if (result?.isSuccessful && result.data?.length > 0) {
      const rows = result.data;
      const columns = Object.keys(rows[0]);

      // 2. Extract Values (convert each object into an array of its values)
      const values = rows.map((row) => Object.values(row));

      // 3. Format it for your JSX
      const formattedData = {
        lc: columns,
        values: values,
      };

      setError("");
      setStudentResult([formattedData]);

      console.log(expectedResult);

      console.log(expectedResult.length);
      const correct = compareQueryResult(
        expectedResult,
        [formattedData],
        quiz?.orderMatters,
        quiz?.aliasStrict,
      );
      setIsCorrect(correct);
      return correct;
    } else {
      setStudentResult([]);
      setError(
        result?.data?.length === 0 ? "No rows returned." : "Query failed.",
      );
      return false;
    }
  };

  const runQuery = async () => {
    if (!sqlCode.trim()) {
      setError("Please write your answer first.");
      setShowResults(true);
      return;
    }
    setShowResults(true);
    const correct = await executeAndCompare();
    if (!correct) {
      setAttemptsLeft((prev) => prev - 1);
      return;
    }
  };

  const submitQuery = async () => {
    const user = userSession.uid;
    if (!user || submitted || lost) return;
    setShowResults(true);
    const correct  = await executeAndCompare();
    const createdOn = new Date(
      quiz.created_on?.seconds
        ? quiz.created_on.seconds * 1000
        : quiz.created_on,
    );
    const createdDay = new Date(
      createdOn.getFullYear(),
      createdOn.getMonth(),
      createdOn.getDate(),
    );
    const todayDay = new Date(
      new Date().getFullYear(),
      new Date().getMonth(),
      new Date().getDate(),
    );
    const isLate = createdDay < todayDay;
    const calculatedMark = isLate
      ? Math.floor((quiz.mark || 1) * 0.5)
      : quiz.mark || 1;
    setEarnedMark(calculatedMark);
    await submitStudentQuiz({
      quiz_id: quiz.quiz_id,
      student_user_id: user,
      submitted_sql: sqlCode,
      is_correct: true,
      mark: calculatedMark,
    });
    setSubmitted(true);
  };

  const [earnedMark, setEarnedMark] = useState(0);
  const [attemptsLeft, setAttemptsLeft] = useState(quiz?.max_attempts || 1);
  const lost = attemptsLeft <= 0;

  if (!quiz)
    return (
      <p>
        Quiz not found.{" "}
        <button onClick={() => navigate("/dashboard/quizzes")}>Go back</button>
      </p>
    );

  return (
    <div className="workspace-container">
      <div className="workspace-content">
        <div className="instructions-panel">
          <div className="panel-header">
            <button
              className="back-btn"
              onClick={() => navigate("/dashboard/quizzes")}
            >
              ← Quizzes
            </button>
          </div>
          <div className="panel-content">
            <span className="badge-problem">{quiz.title}</span>
            <p>{quiz.questionText}</p>
            <p>
              <strong>Order Matters: </strong>
              {quiz.orderMatters ? "Yes" : "No"} |{" "}
              <strong>Alias Strict: </strong>
              {quiz.aliasStrict ? "Yes" : "No"}
            </p>
            <p>
              <strong>Difficulty:</strong> {quiz.difficulty} |{" "}
              <strong>Mark:</strong> {quiz.mark}{" "}
            </p>
            {!submitted && (
              <p>
                <strong>Attempts left:</strong> {attemptsLeft} /{" "}
                {quiz.max_attempts}
              </p>
            )}
            {Object.entries(tableSchemas).map(([table, schema]) => (
              <>
                <p style={{ marginTop: "20px" }}>
                  <strong>{table}</strong>
                </p>
                <TableSchema key={table} info={schema} />
              </>
            ))}
          </div>
        </div>

        <div className="editor-panel">
          {/* <div className="editor-section">
            <div className="editor-header">
              <span>SQL Query Editor</span>
            </div>
            <textarea
              className="code-input"
              value={sqlCode}
              onChange={(e) => setSqlCode(e.target.value)}
              style={{
                width: "100%",
                height: "200px",
                fontFamily: "monospace",
                padding: "8px",
              }}
              spellCheck="false"
            />
          </div> */}
          <div className="editor-section">
            <div className="editor-header">
                <span>SQL Query Editor</span>
              </div>
              <CodeMirror
                value={sqlCode}
                className="code-input"
                height="200px"
                basicSetup={{ lineNumbers: true, foldGutter: false }}
                extensions={[
                  sql(),
                  autocompletion({ override: [sqlKeywordCompletions] }),
                  EditorView.lineWrapping,
                  keymap.of([
                    { key: "Mod-v", run: () => true },
                    { key: "Mod-c", run: () => true },
                  ]),
                ]}
                onChange={(value) => setSqlCode(value)}
              />
            </div>
          <div className="editor-btns">
            {lost && !submitted && (
              <p style={{ color: "red", margin: 0, fontWeight: "bold" }}>
                No attempts left — you cannot submit.
              </p>
            )}
            <button className="btn-run" onClick={runQuery}>
              Run Code
            </button>
            <button
              className="btn-submit"
              onClick={submitQuery}
              disabled={lost || submitted}
            >
              {submitted ? "Submitted" : lost ? "No Attempts Left" : "Submit"}
            </button>
          </div>
          {lost && !submitted && (
            <div
              className="result-status-bar"
              style={{ background: "#fee2e2" }}
            >
              <p className="compile-error">
                You have used all attempts. You lost this quiz.
              </p>
            </div>
          )}

          {showResults && (
            <div className="result-section">
              {submitted && isCorrect && !viewSql && (
                <section className="points-banner">
                  <h3>You earned {earnedMark} points!</h3>
                </section>
              )}
              <div className="result-status-bar">
                {isCorrect ? (
                  <p className="compile-success">Correct!</p>
                ) : error ? (
                  <p className="compile-error">Runtime Error</p>
                ) : (
                  <>
                    <p className="compile-error">Wrong Answer</p>
                    {!(lost || submitted) && (
                      <p>
                        Attempts left: <strong>{attemptsLeft}</strong>
                      </p>
                    )}
                  </>
                )}
              </div>
              {error && (
                <div className="result-status-bar">
                  <p>{error}</p>
                </div>
              )}
              {!error && (
                <>
                  <div className="result-table">
                    <h6>Your Output</h6>
                    {studentResult.length > 0 ? (
                      <table
                        style={{ width: "100%", borderCollapse: "collapse" }}
                      >
                        <thead>
                          <tr>
                            {studentResult[0].lc.map((c) => (
                              <th
                                key={c}
                                style={{
                                  padding: "8px",
                                  border: "1px solid #ddd",
                                }}
                              >
                                {c}
                              </th>
                            ))}
                          </tr>
                        </thead>
                        <tbody>
                          {(studentResult[0].values || []).map((row, i) => (
                            <tr key={i}>
                              {row.map((v, j) => (
                                <td
                                  key={j}
                                  style={{
                                    border: "1px solid #ddd",
                                    padding: "8px",
                                  }}
                                >
                                  {v !== null ? String(v) : ""}
                                </td>
                              ))}
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    ) : (
                      <span className="empty-state">~ no output ~</span>
                    )}
                  </div>
                  <div className="result-table">
                    <h6>Expected Output</h6>
                    {expectedResult.length > 0 ? (
                      <table
                        style={{ width: "100%", borderCollapse: "collapse" }}
                      >
                        <thead>
                          <tr>
                            {expectedResult[0].lc.map((c) => (
                              <th
                                key={c}
                                style={{
                                  padding: "8px",
                                  border: "1px solid #ddd",
                                }}
                              >
                                {c}
                              </th>
                            ))}
                          </tr>
                        </thead>
                        <tbody>
                          {(expectedResult[0].values || []).map((row, i) => (
                            <tr key={i}>
                              {row.map((v, j) => (
                                <td
                                  key={j}
                                  style={{
                                    border: "1px solid #ddd",
                                    padding: "8px",
                                  }}
                                >
                                  {v !== null ? String(v) : ""}
                                </td>
                              ))}
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    ) : (
                      <span className="empty-state">~ no output ~</span>
                    )}
                  </div>
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default QuizDetail;
