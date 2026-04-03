import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { getDoc, doc, getDocs, query, collection, where } from "firebase/firestore";
import { db } from "../../../../firebase";
import { getBestAttemptByUserQuestion } from "../../../../components/model/questionAttempts";
import StudentAssignmentPage from "../submissionstatus/studentAssignment/StudentAssignmentPage";

export default function AssignmentCohortResults() {
  const { assignment_id } = useParams();
  const navigate = useNavigate();

  const [assignment, setAssignment] = useState(null);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedStudent, setSelectedStudent] = useState(null);

  useEffect(() => {
    load();
  }, [assignment_id]);

  async function load() {
    setLoading(true);

    // 1. Fetch assignment by doc ID directly
    const aSnap = await getDoc(doc(db, "assignments", assignment_id));
    if (!aSnap.exists()) { setLoading(false); return; }
    const aData = aSnap.data();
    setAssignment(aData);

    const questions = aData.questions || [];
    const totalMarks = questions.reduce((s, q) => s + (Number(q.mark) || 1), 0);

    // 2. Fetch cohort members from student_assignments (already published students)
    const saSnap = await getDocs(
      query(collection(db, "student_assignments"), where("assignment_id", "==", assignment_id))
    );
    const saMap = {};
    saSnap.docs.forEach(d => { saMap[d.data().student_user_id] = d.data(); });
    const studentUids = Object.keys(saMap);

    // fallback: if not published yet, load from cohort
    let cohortUids = studentUids;
    if (cohortUids.length === 0) {
      const cohortId = aData.student_class;
      if (cohortId === "all") {
        const uSnap = await getDocs(query(collection(db, "users"), where("role", "==", "student")));
        cohortUids = uSnap.docs.map(d => d.id);
      } else {
        const cSnap = await getDocs(query(collection(db, "cohorts"), where("cohort_id", "==", cohortId)));
        cohortUids = cSnap.docs[0]?.data().student_uids || [];
      }
    }

    // 4. For each student compute earned marks
    const results = await Promise.all(
      cohortUids.map(async (uid) => {
        const userSnap = await getDoc(doc(db, "users", uid));
        const user = userSnap.exists() ? userSnap.data() : { fullName: "Unknown" };
        const sa = saMap[uid];

        const attempts = await Promise.all(
          questions.map(q => getBestAttemptByUserQuestion(uid, q.question_id))
        );
        const earned = attempts.reduce(
          (s, att, i) => s + (att?.is_correct ? Number(questions[i].mark) || 1 : 0),
          0
        );

        return {
          uid,
          fullName: user.fullName || user.email || uid,
          status: sa?.status || "not started",
          earned,
          totalMarks,
          submissionDate: sa?.submissionDate || null,
        };
      })
    );

    setRows(results);
    setLoading(false);
  }

  if (selectedStudent) {
    return (
      <div className="container-fluid p-4">
        <StudentAssignmentPage
          studentId={selectedStudent}
          assignmentId={assignment_id}
          onBack={() => setSelectedStudent(null)}
        />
      </div>
    );
  }

  const statusBadge = (status) => {
    const map = {
      submitted: "badge-warning",
      completed: "badge-success",
      assigned: "badge-secondary",
      "in_progress": "badge-info",
      "not started": "badge-light border",
    };
    return `badge ${map[status] || "badge-light border"}`;
  };

  return (
    <div className="container-fluid p-4" style={{ background: "#f8f9fc", minHeight: "100vh" }}>

      <div className="d-flex justify-content-between align-items-center"
        style={{marginBottom: '20px' }}>
        <h4 className="mb-0 font-weight-bold text-gray-800 mr-3">
          {assignment?.title || "Assignment"} — Cohort Results
        </h4>
        <small className="text-muted">Due: {assignment?.due_date || assignment?.dueDate}</small>
        <button className="btn btn-secondary shadow-sm" onClick={() => navigate(-1)} style={{ marginBottom: '10px' }}>
          <i className="fas fa-arrow-left mr-2"></i> Back
        </button>
      </div>

      {loading ? (
        <div className="text-center py-5">
          <div className="spinner-border text-primary"></div>
        </div>
      ) : (
        <div className="card shadow border-0">
          <div className="card-body p-0">
            {rows.length === 0 ? (
              <p className="text-center text-muted py-5">No students found in this cohort.</p>
            ) : (
              <div className="table-responsive">
                <table className="table table-hover table-bordered mb-0">
                  <thead className="bg-light text-uppercase small font-weight-bold">
                    <tr>
                      <th>Student</th>
                      <th className="text-center">Status</th>
                      <th className="text-center">Score</th>
                      <th className="text-center">%</th>
                      <th className="text-center">Submitted</th>
                      <th className="text-center">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map(r => {
                      const pct = r.totalMarks > 0 ? Math.round((r.earned / r.totalMarks) * 100) : 0;
                      const isSubmitted = r.status === "submitted" || r.status === "completed";
                      return (
                        <tr key={r.uid}>
                          <td className="font-weight-bold align-middle">{r.fullName}</td>
                          <td className="text-center align-middle">
                            <span className={statusBadge(r.status)}>{r.status}</span>
                          </td>
                          <td className="text-center align-middle font-weight-bold">
                            {isSubmitted
                              ? <span className={r.earned === r.totalMarks ? "text-success" : "text-primary"}>{r.earned} / {r.totalMarks}</span>
                              : <span className="text-muted">—</span>
                            }
                          </td>
                          <td className="text-center align-middle">
                            {isSubmitted ? (
                              <div className="d-flex align-items-center justify-content-center">
                                <div className="progress flex-grow-1 mr-2" style={{ height: "8px", maxWidth: "80px" }}>
                                  <div
                                    className={`progress-bar ${pct >= 70 ? "bg-success" : pct >= 40 ? "bg-warning" : "bg-danger"}`}
                                    style={{ width: `${pct}%` }}
                                  />
                                </div>
                                <small>{pct}%</small>
                              </div>
                            ) : <span className="text-muted">—</span>}
                          </td>
                          <td className="text-center align-middle small text-muted">
                            {r.submissionDate ? new Date(r.submissionDate?.seconds ? r.submissionDate.seconds * 1000 : r.submissionDate).toLocaleDateString() : "—"}
                          </td>
                          <td className="text-center align-middle">
                            {isSubmitted ? (
                              <button
                                className="btn btn-primary btn-sm px-3"
                                onClick={() => setSelectedStudent(r.uid)}
                              >
                                View
                              </button>
                            ) : (
                              <span className="text-muted small">—</span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
