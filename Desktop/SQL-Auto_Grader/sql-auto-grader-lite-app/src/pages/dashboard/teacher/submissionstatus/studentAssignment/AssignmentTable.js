import { useEffect, useState } from "react";
import { useLocation } from "react-router-dom";
import { getStudentAssignmentsWithDetails } from "../../../../../components/model/studentAssignments";
import userSession from "../../../../../components/services/UserSession";
import StudentAssignmentPage from "./StudentAssignmentPage";
import "./../Submission.css";

const SortIcon = ({ field, sortField, sortDir }) => {
  if (sortField !== field) return <i className="fas fa-sort text-muted ml-1" style={{ fontSize: "11px" }} />;
  return <i className={`fas fa-sort-${sortDir === "asc" ? "up" : "down"} ml-1`} style={{ fontSize: "11px" }} />;
};

export default function AssignmentTable({ onSelectStudent, onselectAssignmentId }) {
  const [data, setData] = useState([]);
  const [sortField, setSortField] = useState("");
  const [sortDir, setSortDir] = useState("asc");
  const [selected, setSelected] = useState(null);
  const [preselectedUsed, setPreselectedUsed] = useState(false);

  const location = useLocation();
  const preselectedId = location.state?.student_assignment_id;

  useEffect(() => {
    const fetchData = async () => {
      const merged = await getStudentAssignmentsWithDetails(userSession.uid);
      setData(merged);
      if (preselectedId && !preselectedUsed) {
        const match = merged.find(item => item.student_assignment_id === preselectedId || item.id === preselectedId);
        if (match) setSelected(match);
        setPreselectedUsed(true);
      }
    };
    if (!selected) fetchData();
  }, [selected, preselectedId, preselectedUsed]);

  const handleSort = (field) => {
    if (sortField === field) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortField(field); setSortDir("asc"); }
  };

  const sortedData = [...data]
    .filter(item => item.status !== "created")
    .sort((a, b) => {
      if (!sortField) {
        const aTime = a.submissionDate && a.submissionDate !== "-" ? new Date(a.submissionDate) : new Date(a.assigned_on);
        const bTime = b.submissionDate && b.submissionDate !== "-" ? new Date(b.submissionDate) : new Date(b.assigned_on);
        return bTime - aTime;
      }
      const va = a[sortField]?.toString().toLowerCase() ?? "";
      const vb = b[sortField]?.toString().toLowerCase() ?? "";
      return sortDir === "asc" ? va.localeCompare(vb) : vb.localeCompare(va);
    });

  if (selected) return (
    <StudentAssignmentPage
      studentId={selected.student_user_id}
      assignmentId={selected.assignment_id}
      assignmentTitle={selected.assignmentTitle}
      onBack={() => setSelected(null)}
    />
  );

  const Th = ({ label, field }) => (
    <th onClick={() => handleSort(field)} style={{ cursor: "pointer", userSelect: "none" }}>
      {label} <SortIcon field={field} sortField={sortField} sortDir={sortDir} />
    </th>
  );

  return (
    <div className="card-body p-0">
      <div className="table-responsive px-3 pt-3">
        <table className="table table-hover table-bordered" width="100%" cellSpacing="0">
          <thead className="bg-light">
            <tr>
              <Th label="Student Name" field="studentName" />
              <Th label="Assignment Title" field="assignmentTitle" />
              <th>Mark</th>
              <Th label="Due Date" field="dueDate" />
              <Th label="Status" field="status" />
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {sortedData.map(item => {
              const isLate = item.dueDate && item.updated_on && new Date(item.updated_on) > new Date(item.dueDate);
              const isSubmitted = item.status === "submitted" || item.status === "completed";
              return (
                <tr key={item.id} className={isLate ? "table-danger" : ""}>
                  <td className="font-weight-bold">{item.studentName}</td>
                  <td>{item.assignmentTitle}</td>
                  <td>{isSubmitted ? `${item.earnedMarks ?? 0} / ${item.totalMarks ?? 0}` : "-"}</td>
                  <td>{item.due_on || item.dueDate || "-"}</td>
                  <td>
                    <span className={`badge ${item.status === "submitted" ? "badge-warning" : item.status === "completed" ? "badge-success" : "badge-secondary"}`}>
                      {item.status}
                    </span>
                  </td>
                  <td>
                    {isSubmitted ? (
                      <button className="btn btn-primary btn-sm btn-block"
                        onClick={() => { onSelectStudent(item.student_user_id); onselectAssignmentId(item.assignment_id); }}>
                        Check & Grade
                      </button>
                    ) : (
                      <span className="text-muted small text-uppercase font-weight-bold">{item.status}</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
