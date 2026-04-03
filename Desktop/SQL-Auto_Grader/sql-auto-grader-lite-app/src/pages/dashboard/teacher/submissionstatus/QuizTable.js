import { useEffect, useState } from "react";
import { getQuizSubmissionsWithDetails } from "../../../../components/model/quizzes";
import userSession from "../../../../components/services/UserSession";
import "./Submission.css";

const SortIcon = ({ field, sortField, sortDir }) => {
  if (sortField !== field) return <i className="fas fa-sort text-muted ml-1" style={{ fontSize: "11px" }} />;
  return <i className={`fas fa-sort-${sortDir === "asc" ? "up" : "down"} ml-1`} style={{ fontSize: "11px" }} />;
};

export default function QuizTable() {
  const [data, setData] = useState([]);
  const [sortField, setSortField] = useState("");
  const [sortDir, setSortDir] = useState("asc");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getQuizSubmissionsWithDetails(userSession.uid)
      .then(r => setData(r || []))
      .finally(() => setLoading(false));
  }, []);

  const handleSort = (field) => {
    if (sortField === field) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortField(field); setSortDir("asc"); }
  };

  const sortedData = [...data].sort((a, b) => {
    if (!sortField) return 0;
    const va = (a[sortField] || "").toString().toLowerCase();
    const vb = (b[sortField] || "").toString().toLowerCase();
    return sortDir === "asc" ? va.localeCompare(vb) : vb.localeCompare(va);
  });

  const Th = ({ label, field }) => (
    <th onClick={() => handleSort(field)} style={{ cursor: "pointer", userSelect: "none" }}>
      {label} <SortIcon field={field} sortField={sortField} sortDir={sortDir} />
    </th>
  );

  return (
    <div className="card-body p-0">
      <div className="table-responsive px-3 pt-3">
        <table className="table table-bordered table-hover" width="100%" cellSpacing="0">
          <thead className="bg-light text-primary">
            <tr>
              <Th label="Student Name" field="studentName" />
              <Th label="Quiz Title" field="quizTitle" />
              <Th label="Submission Date" field="submissionDate" />
              <Th label="Status" field="status" />
              <th>Mark</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan="5" className="text-center">Loading...</td></tr>
            ) : sortedData.length > 0 ? (
              sortedData.map(item => (
                <tr key={item.id}>
                  <td className="font-weight-bold text-gray-800">{item.studentName}</td>
                  <td>{item.quizTitle}</td>
                  <td>{item.submissionDate || "-"}</td>
                  <td>
                    <span className={`badge ${item.status === "Submitted" ? "badge-warning" : item.status === "Assigned" ? "badge-secondary" : "badge-success"}`}>
                      {item.status}
                    </span>
                  </td>
                  <td className="font-weight-bold text-primary">{item.mark ?? "-"}</td>
                </tr>
              ))
            ) : (
              <tr><td colSpan="5" className="text-center py-4">No quiz submissions found.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
