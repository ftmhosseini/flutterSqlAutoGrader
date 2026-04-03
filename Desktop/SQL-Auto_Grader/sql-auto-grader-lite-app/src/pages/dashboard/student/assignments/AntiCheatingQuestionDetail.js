import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import "./AssignmentDetail.css";
import { useAppContext } from "../../../../components/db/service/context";
import CodeMirror from "@uiw/react-codemirror";
import { sql } from "@codemirror/lang-sql";
import { SQL_KEYWORDS } from "../../../../components/db/common";
import { autocompletion, completeFromList } from "@codemirror/autocomplete";
import { EditorView, keymap } from "@codemirror/view";
import {
  isSelectQuery,
  normalizeQuery,
} from "../../../../components/db/queryValidation";
import { createAttempt } from "../../../../components/model/questionAttempts";
import { compareQueryResult } from "../../../../components/comparison/sqlComparison";
import LoadingOverlay from "../LoadingOverlay";
import userSession from "../../../../components/services/UserSession";
import { useAntiCheat } from "../../../../components/hooks/useAntiCheat";
import { updateStudentAssignment } from "../../../../components/model/studentAssignments";
import ResultTable from "./ResultTable";

const AntiCheatingQuestionDetail = () => {
  const { fetchItems, getTableSchemaInTable, allTables } = useAppContext();
  const navigate = useNavigate();
  const location = useLocation();
  const assignment_id = location.state?.assignment_id;
  const question = location.state?.question;
  const dataset = location.state?.dataset;
  const [sqlCode, setSqlCode] = useState("");
  const [expectedResult, setExpectedResult] = useState([]);
  const [studentResult, setStudentResult] = useState([]);
  const [isCorrect, setIsCorrect] = useState(false);
  const [error, setError] = useState("");
  const [tableSchemas, setTableSchemas] = useState([]);
  const [isSubmit, setIsSubmmit] = useState(false);
  const [showResults, setShowResults] = useState(false);
  const [currentAttempt, setCurrentAttempt] = useState(question?.attemptTime);
  const [isLoading, setIsLoading] = useState(true);
  const [antiCheatMessage, setAntiCheatMessage] = useState("");
  const { violations, isFullscreen, requestFullscreen } = useAntiCheat((violation) => {
    setAntiCheatMessage(
      `Anti-cheat violation detected: ${violation.type.replaceAll("_", " ")}`,
    );
  }, { enableFullscreen: true });

  useEffect(() => {
    if (!dataset || !question?.answer) return;

    const loadExpectedResult = async () => {
      const result = await fetchItems(dataset, question.answer);
      if (result?.isSuccessful && result.data?.length > 0) {
        const columns = Object.keys(result.data[0]);
        const values = result.data.map((row) => Object.values(row));
        const formatted = [{ lc: columns, values }];
        setExpectedResult(formatted);
        setIsLoading(false);
      }
    };

    loadExpectedResult();
  }, [dataset, question?.answer, fetchItems]);

  useEffect(() => {
    // If new `tables` array exists and is non-empty, use it directly.
    // Otherwise always auto-detect from the answer SQL against all dataset tables
    // (this also fixes old questions that only stored a single `table` string).
    if (!dataset) return;

    const loadSchema = async () => {
      console.log('[schema] question:', { tables: question?.tables, answer: question?.answer, dataset });
      let tableList = Array.isArray(question?.tables) && question.tables.length > 0
        ? question.tables
        : null;

      if (!tableList) {
        const all = await allTables(dataset);
        const allNames = all.map((t) => t.tableName);
        console.log('[schema] all table names in dataset:', allNames);
        tableList = allNames.filter(t => question?.answer?.toLowerCase().includes(t.toLowerCase()));
        console.log('[schema] matched tables from answer:', tableList);
      }

      if (tableList.length === 0) return;
      const results = await Promise.all(
        tableList.map(async (table) => {
          const schema = await getTableSchemaInTable(dataset, table);
          return [table, schema];
        }),
      );
      setTableSchemas(results);
      setIsLoading(false);
    };
    loadSchema();
  }, [dataset, question?.tables]);

  async function excuteQueryAndCompare() {
    if (!isSelectQuery(sqlCode)) {
      setError("Only SELECT queries are allowed.");
      setStudentResult([]);
      setIsCorrect(false);
      return false;
    }

    const result = await fetchItems(dataset, normalizeQuery(sqlCode));
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
      const correct = compareQueryResult(
        expectedResult,
        [formattedData],
        question?.orderMatters,
        question?.aliasStrict,
      );
      setIsCorrect(correct);
      return correct;
    } else {
      setStudentResult([]);
      setError(result.message);
      setIsCorrect(false);
      return false;
    }
  }

  async function runQuery() {
    setIsSubmmit(false);
    await excuteQueryAndCompare();
    setIsLoading(false);
    setShowResults(true);
  }

  async function submitQuery() {
    const nextAttempt = (currentAttempt ?? 0) + 1;
    if (currentAttempt >= 1) {
      alert("You have reached the max attempt");
      return;
    }
    setShowResults(true);
    setCurrentAttempt(nextAttempt);
    const comparationResult = await excuteQueryAndCompare();
    const attemptObj = {
      question_id: question?.question_id,
      student_user_id: userSession.uid,
      submitted_on: new Date().toLocaleDateString("en-CA"),
      submitted_sql: sqlCode,
      is_correct: comparationResult,
    };

    await createAttempt(attemptObj);
    await updateEaredPoint();
    setIsSubmmit(true);
    alert("Your code has been submitted");
  }

  async function updateEaredPoint() {
    if (!assignment_id) return;
    await updateStudentAssignment({
      student_user_id: userSession.uid,
      assignment_id: assignment_id,
      earned_point: isCorrect ? question.mark : 0,
    });
  }

  const sqlKeywordCompletions = completeFromList(
    SQL_KEYWORDS.map((keyword) => ({
      label: keyword,
      type: "keyword",
    })),
  );

  return (
    <>
      <LoadingOverlay isOpen={isLoading} message="Loading..." />
      {!isFullscreen && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, zIndex: 9999, background: '#1a1a2e', color: '#fff', padding: '12px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span>⚠️ This assignment requires fullscreen mode.</span>
          <button onClick={requestFullscreen} style={{ background: '#4A76C5', color: '#fff', border: 'none', borderRadius: '6px', padding: '8px 18px', cursor: 'pointer', fontWeight: 700 }}>
            Enter Fullscreen
          </button>
        </div>
      )}
      <div className="workspace-container">
        <div className="workspace-content">
          <div className="instructions-panel">
            <div className="panel-header">
              <button
                className="back-btn"
                onClick={() =>
                  navigate(`/dashboard/questions/${assignment_id}`, {
                    state: { assignment: location.state?.assignment },
                  })
                }
              >
                Back to Assignment
              </button>
            </div>

            <div className="panel-content">
              <div className="problem-badge-group">
                <span className="badge-problem">
                  Problem {question?.question_id}
                </span>

                <div className="problem-rule-badges">
                  {question?.orderMatters === true && (
                    <span className="badge-problem">Order Matter</span>
                  )}

                  {question?.aliasStrict === true && (
                    <span className="badge-problem">Alias Strict</span>
                  )}
                </div>
              </div>

              <p>{question?.questionText}</p>

              {tableSchemas.map((schema) => (
                <div className="table-schema" key={schema[0]}>
                  <h3 style={{marginTop:'20px'}}>{`Table: ${schema[0]}`}</h3>
                  <table>
                    <thead>
                      <tr>
                        <th>Field</th>
                        <th>Type</th>
                      </tr>
                    </thead>
                    <tbody>
                      {schema[1].map((row) => (
                        <tr key={`${schema[0]}-${row.name}`}>
                          <td>{row.name}</td>
                          <td>{row.type}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ))}
            </div>
          </div>

          <div className="editor-panel">
            {antiCheatMessage && (
              <div className="result-status-bar">
                <p className="compile-error">{antiCheatMessage}</p>
              </div>
            )}
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
              <button className="btn-run" onClick={runQuery}>
                Run Code
              </button>
              <button className="btn-submit" onClick={submitQuery}>
                Submit Code
              </button>
            </div>
            {showResults && (
              <div className="result-section">
                {isSubmit && isCorrect && (
                  <section className="points-banner">
                    <div className="points-copy">
                      <h4>You have earned {question.mark} points!</h4>
                    </div>
                  </section>
                )}

                <div className="result-status-bar">
                  {isCorrect ? (
                    <>
                      <p className="compile-success">Congratulations!</p>
                      <p>You have passed the sample test cases.</p>
                    </>
                  ) : error ? (
                    <>
                      <p className="compile-error">Runtime Error</p>
                    </>
                  ) : (
                    <>
                      <p className="compile-error">Wrong Answer</p>
                      <p>Your result doesn&apos;t match the expected output.</p>
                    </>
                  )}
                </div>

                {error && (
                  <div className="result-status-bar">
                    <h6>Compiler Message</h6>
                    <p>{error}</p>
                  </div>
                )}

                {showResults && !error && (
                  <>
                    <ResultTable
                      title="Your Output (stdout)"
                      result={studentResult}
                    />
                    <ResultTable
                      title="Expected Output"
                      result={expectedResult}
                    />
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
};

export default AntiCheatingQuestionDetail;
