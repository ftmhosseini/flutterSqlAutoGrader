import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DataTable from "react-data-table-component";

import userSession from "../../../../components/services/UserSession";
import { getQuizzesForStudent } from "../../../../components/model/quizzes";
import LoadingOverlay from "../LoadingOverlay";

const Quizzes = () => {
  const navigate = useNavigate();
  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetch = async () => {
      const quizzes = await getQuizzesForStudent(userSession.uid);

      setData(quizzes);
      setIsLoading(false);
    };
    fetch();
  }, []);

  const today = new Date();
  const sortedData = [...data].sort((a, b) => {
    const aDate = a.due_date ? new Date(a.due_date) : new Date(a.created_on?.seconds ? a.created_on.seconds * 1000 : a.created_on);
    const bDate = b.due_date ? new Date(b.due_date) : new Date(b.created_on?.seconds ? b.created_on.seconds * 1000 : b.created_on);
    return aDate - bDate;
  });
  

  const columns = [
    { name: "S.No", selector: (_, i) => i + 1, width: "70px" },
    { name: "Title", selector: r => r.title, sortable: true },
    {
      name: "Status",
      cell: r => {
        const createdOn = new Date(r.created_on?.seconds ? r.created_on.seconds * 1000 : r.created_on);
        const createdDay = new Date(createdOn.getFullYear(), createdOn.getMonth(), createdOn.getDate());
        const todayDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        const isPast = r.status !== "Completed" && createdDay < todayDay;
        const isToday = r.status !== "Completed" && createdDay.getTime() === todayDay.getTime();
        const label = r.status === "Completed" ? "Completed" : isPast ? "Due" : isToday ? "New" : r.status;
        const color = r.status === "Completed" ? "bg-success" : isPast ? "bg-danger" : "bg-primary";
        return (
          <span className={`badge ${color}`}
            style={{ color: "white", padding: "5px 10px", borderRadius: "12px", fontSize: "11px" }}>
            {label}
          </span>
        );
      }
    },

    { name: "Mark", selector: r => r.achievedMark !== null && r.achievedMark !== undefined ? `${r.achievedMark} / ${r.mark}` : "-" },
    {
      name: "Action",
      cell: r => r.status === "Completed"
        ? <button className="btn btn-sm btn-secondary" style={{ fontSize: "12px" }}
            onClick={() => navigate(`/dashboard/quizzes/${r.quiz_id}`, { state: { quiz: r } })}>
            View
          </button>
        : <button className="btn btn-sm btn-primary" style={{ fontSize: "12px" }}
            onClick={() => navigate(`/dashboard/quizzes/${r.quiz_id}`, { state: { quiz: r } })}>
            Start
          </button>
    },
  ];
  return (
    <>
      <LoadingOverlay isOpen={isLoading} message="Loading..." />
      <h2>Quizzes</h2>
      <div className="card shadow mb-4">
        <DataTable columns={columns} data={sortedData} pagination highlightOnHover striped responsive />
      </div>
    </>
  );
};

export default Quizzes;
