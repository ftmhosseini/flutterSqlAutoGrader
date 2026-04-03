import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import DataTable from "react-data-table-component";
import Breadcrumb from "../Breadcrumb";
import userSession from "../../../../components/services/UserSession";
import { useParams } from "react-router-dom";
import { getAllActiveAssignmnetByStudent } from "../../../../components/model/questions";
import LoadingOverlay from "../LoadingOverlay";
import {
  updateStudentAssignment,
  getAllAssignmentByStudent,
} from "../../../../components/model/studentAssignments";
import { getUser } from "../../../../components/model/users";
import { sendSubmissionNotificationEmail } from "../../../../components/services/email";

const QuestionList = () => {
  const { assignment_id } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const [assignment, setAssignment] = useState(
    location.state?.assignment || null,
  );
  const [accessDenied, setAccessDenied] = useState(false);
  const [questiondata, setquestiondata] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  const [refreshKey, setRefreshKey] = useState(0);

  // Refetch every time we navigate back to this page
  useEffect(() => {
    setRefreshKey((k) => k + 1);
  }, [location.key]);

  useEffect(() => {
    const fetchdata = async () => {
      setIsLoading(true);
      try {
        let resolvedAssignment = assignment;

        // Direct link from email — no location.state, fetch and verify ownership
        if (!resolvedAssignment) {
          const studentAssignments = await getAllAssignmentByStudent(
            userSession.uid,["assigned"]
          );
          resolvedAssignment = studentAssignments.find(
            (a) => a.assignment_id === assignment_id,
          );
          if (!resolvedAssignment) {
            setAccessDenied(true);
            setIsLoading(false);
            return;
          }
          setAssignment(resolvedAssignment);
        }

        const data = await getAllActiveAssignmnetByStudent(
          resolvedAssignment.questions,
          userSession.uid,
        );
        setquestiondata(data);

        // Auto-submit if all questions are attempted
        const allAttempted =
          data.length > 0 && data.every((q) => q.attemptTime > 0);
        if (allAttempted && resolvedAssignment.status === "assigned") {
          await updateStudentAssignment({
            student_user_id: userSession.uid,
            assignment_id: resolvedAssignment.assignment_id,
            status: "completed",
            submissionDate: new Date().toLocaleDateString("en-CA"),
          });
          if (
            resolvedAssignment.enable_submission_notification &&
            resolvedAssignment.owner_user_id
          ) {
            const teacher = await getUser(resolvedAssignment.owner_user_id);
            await sendSubmissionNotificationEmail(
              teacher,
              userSession.fullName,
              resolvedAssignment.title,
            );
          }
        }
      } catch (error) {
        console.error("Error:", error);
      } finally {
        setIsLoading(false);
      }
    };
    fetchdata();
  }, [refreshKey]);

  if (accessDenied)
    return (
      <div style={{ padding: "40px", textAlign: "center" }}>
        <h3>Access Denied</h3>
        <p>This assignment is not assigned to your account.</p>
        <button onClick={() => navigate("/dashboard/assignments")}>
          Go to My Assignments
        </button>
      </div>
    );

  const dataset = assignment?.dataset;

  async function markComplele() {
    const assignmentId = assignment?.assignment_id;
    if (!assignmentId) return;
    await updateStudentAssignment({
      student_user_id: userSession.uid,
      assignment_id: assignmentId,
      status: "completed",
      submissionDate: new Date().toLocaleDateString("en-CA"),
    });
    if (
      assignment?.enable_submission_notification &&
      assignment?.owner_user_id
    ) {
      const teacher = await getUser(assignment.owner_user_id);
      await sendSubmissionNotificationEmail(
        teacher,
        userSession.fullName,
        assignment.title,
      );
    }
    navigate("/dashboard/assignments");
  }
  const capitalizeFirstLetter = (str) => {
    if (!str) return "";
    return str.charAt(0).toUpperCase() + str.slice(1);
  };

  const columns = [
    {
      name: "S.No",
      selector: (row, index) => index + 1,
      sortable: true,
    },
    {
      name: "Question",
      selector: (row) => row.questionText,
      sortable: true,
      cell: (row) => capitalizeFirstLetter(row.questionText),
    },
    {
      name: "Marks",
      selector: (row) => (row.isSolved ? row.mark : 0),
      cell: (row) => `${row.isSolved ? row.mark : 0} / ${row.mark}`,
    },
    {
      name: "Status",
      selector: (row) => "row.status",
      sortable: true,
      cell: (row) => {
        const statusClass = (() => {
          switch (row.status) {
            case "Correct":
              return "bg-success";
            case "Incorrect":
              return "bg-warning text-dark";
            case "Not Started":
              return "bg-secondary";
            case "Skipped":
              return "bg-purple text-white";
            case "Answered":
              return "bg-primary";
            default:
              return "bg-light text-dark";
          }
        })();

        return (
          <span className={`badge ${statusClass} btn-status`}>
            {row.status}
          </span>
        );
      },
    },
    {
      name: "Attemption",
      selector: (row) => `${row.attemptTime ?? 0} / 1`,
    },
    {
      name: "Action",
      cell: (row) => {
        const isAttemptLimitReached = row.attemptTime >= 1;
        return (
          <button
            // className="btn btn-sm btn-primary"
            // disabled={isAttemptLimitReached}
            className={`btn btn-sm btn-primary ${isAttemptLimitReached ? "disabled" : ""}`}
            onClick={() =>
              navigate(
                `/dashboard/questions/${assignment_id}/question-view/${row.question_id}`,
                {
                  state: {
                    question: row,
                    dataset: dataset,
                    assignment_id,
                    assignment: location.state?.assignment,
                  },
                },
              )
            }
          >
            {isAttemptLimitReached ? "Done" : "Start"}
          </button>
        );
      },
    },
  ];

  return (
    <>
      <LoadingOverlay isOpen={isLoading} message="Loading..." />
      <div className="d-sm-flex justify-content-between align-items-center mb-0 al">
        <h2>{assignment?.title || "Questions List"}</h2>
        <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
          {/* <button
            onClick={() => setRefreshKey((k) => k + 1)}
            className="btn btn-sm btn-outline-secondary"
          >
            ↻ Refresh
          </button> */}
          <Breadcrumb
            items={[
              { label: "Dashboard", link: "/dashboard" },
              { label: "Assignments", link: "/dashboard/assignments" },
              { label: "Questions List", active: true },
            ]}
          />
        </div>
      </div>

      <div
        style={{
          display: "flex",
          justifyContent: "flex-end",
          marginBottom: "12px",
        }}
      >
        <button
          style={{
            backgroundColor: "#28A745",
            color: "#fff",
            border: "none",
            borderRadius: "6px",
            padding: "10px 18px",
            fontSize: "14px",
            fontWeight: 600,
            lineHeight: 1.2,
            cursor: "pointer",
          }}
          onClick={markComplele}
        >
          Mark Finished
        </button>
      </div>

      <div className="card shadow mb-4">
        <DataTable
          columns={columns}
          data={questiondata}
          pagination
          highlightOnHover
          striped
          responsive
          pointerOnHover
          onRowClicked={(row) => {
            const isAttemptLimitReached = row.attemptTime >= 1;
            if (!isAttemptLimitReached) {
              navigate(
                `/dashboard/questions/${assignment_id}/question-view/${row.question_id}`,
                {
                  state: {
                    question: row,
                    dataset: dataset,
                    assignment_id,
                    assignment: location.state?.assignment,
                  },
                },
              );
            }
          }}
        />
      </div>
    </>
  );
};

export default QuestionList;
