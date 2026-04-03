import { useState, useEffect } from "react";
import { getStudentCohorts, JoinCohort } from "../../../../components/model/cohorts";
import CollapsiblePanel from "../../teacher/assignmentform/collapsiblepanel/CollapsiblePanel";
import userSession from "../../../../components/services/UserSession";
import "../../teacher/cohorts/CohortManager.css";

function Cohort() {
  const [cohorts, setCohorts] = useState([]);
  const [code, setCode] = useState("");
  const [expanded, setExpanded] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    getStudentCohorts(userSession.uid).then(setCohorts);
  }, []);

  const handleJoin = async () => {
    if (!code.trim()) return setError("Enter a cohort code.");
    try {
      const cohort = await JoinCohort(code, userSession.uid);
      setCohorts(prev => [...prev, cohort]);
      setCode("");
      setExpanded(null);
      setError("");
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <div className="container-fluid py-4">
      <div className="d-sm-flex align-items-center justify-content-between mb-4 px-3">
        <h1 className="h3 mb-0 text-gray-800 font-weight-bold">My Cohorts</h1>
        <button
          onClick={() => { setCode(""); setError(""); setExpanded(prev => prev === "join" ? null : "join"); }}
          className={`btn ${expanded === "join" ? "btn-secondary" : "btn-success"} btn-icon-split shadow-sm`}
        >
          <span className="icon text-white-50">
            <i className={`fas ${expanded === "join" ? "fa-times" : "fa-plus"}`}></i>
          </span>
          <span className="text">{expanded === "join" ? "Cancel" : "Join Cohort"}</span>
        </button>
      </div>

      <div className="cohort-list-container px-3">
        {expanded === "join" && (
          <div className="card shadow mb-4 border-left-success">
            <div className="card-header py-3 bg-white">
              <h6 className="m-0 font-weight-bold text-success text-uppercase">Join a Cohort</h6>
            </div>
            <div className="card-body bg-light">
              <label className="small font-weight-bold text-gray-600">COHORT CODE</label>
              <input
                className="form-control mb-2"
                placeholder="Enter cohort code..."
                value={code}
                onChange={e => setCode(e.target.value.toUpperCase())}
              />
              {error && <p className="text-danger small mb-2">{error}</p>}
              <button onClick={handleJoin} className="btn btn-success btn-block mt-2 shadow-sm">
                <i className="fas fa-check mr-2"></i> Join Cohort
              </button>
            </div>
          </div>
        )}

        {cohorts.length === 0 && expanded !== "join" && (
          <p className="text-gray-500 px-3">You haven't joined any cohorts yet.</p>
        )}

        {cohorts.map((c) => (
          <div key={c.cohort_id} className="card shadow mb-3 border-left-primary">
            <CollapsiblePanel
              title={c.name}
              preview={`Code: ${c.cohort_id}`}
              isCollapsed={expanded !== c.cohort_id}
              onToggle={() => setExpanded(prev => prev === c.cohort_id ? null : c.cohort_id)}
            >
              <div className="card-body bg-light border-top">
                <p className="mb-1"><strong>Code:</strong> {c.cohort_id}</p>
                <p className="mb-0"><strong>Members:</strong> {c.student_uids?.length || 0}</p>
              </div>
            </CollapsiblePanel>
          </div>
        ))}
      </div>
    </div>
  );
}

export default Cohort;
