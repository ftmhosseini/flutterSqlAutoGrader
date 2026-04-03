import { useState } from "react";
import { useParams, useNavigate, useLocation } from "react-router-dom";
import "./AssignmentDetail.css";

const AssignmentDetail = () => {
  const { question_id } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const question = location.state?.question;
  const [sqlCode, setSqlCode] = useState("SELECT * FROM City;");

  return (
    <div className="workspace-container">
      <div className="instructions-panel">
        <div className="panel-header">
          <button className="back-btn" onClick={() => navigate(-1)}>
            ← Assignments
          </button>
        </div>
        <div className="panel-content">
          <span className="badge-problem">Problem {question_id}</span>
          <h4>{question?.questionText || "Query City Names"}</h4>
          <p>
            {question?.description || (
              <>
                Query the <b>NAME</b> field for all American cities in the{" "}
                <b>CITY</b> table with populations larger than 120,000.
              </>
            )}
          </p>

          <div className="table-schema">
            <h3>Table: CITY</h3>
            <table>
              <thead>
                <tr>
                  <th>Field</th>
                  <th>Type</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>ID</td>
                  <td>NUMBER</td>
                </tr>
                <tr>
                  <td>NAME</td>
                  <td>VARCHAR2(17)</td>
                </tr>
                <tr>
                  <td>COUNTRYCODE</td>
                  <td>VARCHAR2(3)</td>
                </tr>
                <tr>
                  <td>POPULATION</td>
                  <td>NUMBER</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div className="editor-panel">
        <div className="editor-section">
          <div className="editor-header">
            <span>SQL Query Editor</span>
            <div className="editor-btns">
              <button className="btn-run">Run Query</button>
              <button className="btn-submit">Submit</button>
            </div>
          </div>
          <textarea
            className="code-input"
            value={sqlCode}
            onChange={(e) => setSqlCode(e.target.value)}
            spellCheck="false"
          />
        </div>

        <div className="result-section">
          <div className="result-status-bar alert-wrong">
            ✖ Query is Incorrect. Your result doesn't match the expected output.
          </div>
          <div className="results-grid">
            <div className="result-table">
              <h4>Expected Result</h4>
              <div className="table-placeholder">Data grid here...</div>
            </div>
            <div className="result-table">
              <h4>Your Result</h4>
              <div className="table-placeholder">Data grid here...</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AssignmentDetail;
