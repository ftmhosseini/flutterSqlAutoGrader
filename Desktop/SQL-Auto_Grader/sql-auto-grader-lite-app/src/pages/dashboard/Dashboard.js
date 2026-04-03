import { useEffect, useState } from "react";
import "./Dashboard.css";
import CardDashboard from "./CardDashboard";
import StudentSubmissionDashboard from "./StudentSubmissionDashboard";
import userSession from "../../components/services/UserSession";
import {
  getDashboardDataForTeacher,
  getAllAssignmentByStudent,
} from "../../components/model/studentAssignments";
import { getQuizzesForStudent } from "../../components/model/quizzes";
import { useNavigate } from "react-router-dom";
import { getAllUsers } from "../../components/model/users";

const Dashboard = ({ role }) => {
  const [teacherData, setTeacherData] = useState(null);
  const [studentCards, setStudentCards] = useState([]);
  // const [assignments, setAssignment] = useState([]);
  const [completedAssignment, setCompletedAssignment] = useState([]);
  const navigate = useNavigate();

  useEffect(() => {
    if (role === "teacher") {
      const loadTeacherData = async () => {
        try {
          const data = await getDashboardDataForTeacher(userSession.uid);

          const usersData = await getAllUsers();

          setTeacherData({ ...data, users: usersData });
        } catch (error) {
          console.error("Error loading teacher dashboard:", error);
        }
      };
      loadTeacherData();
    }

    if (role === "student") {
      const loadStudentData = async () => {
        try {
          let allAssignments = await getAllAssignmentByStudent(
            userSession.uid,
            ["assigned", "submitted", "completed"],
          );

          //getAllCompleted Assignments
          let completedAss = allAssignments.filter(
            (assignment) =>
              assignment.status === "submitted" ||
              assignment.status === "completed",
          );
          // setAssignment(allAssignments);
          const quizzes = await getQuizzesForStudent(userSession.uid);
          setCompletedAssignment(completedAss);
          const totalMarks = completedAss.reduce(
            (sum, assignment) => sum + assignment.total_marks,
            0,
          );

          const earnedMarks = completedAss.reduce(
            (sum, assignment) =>
              typeof assignment.earned_point !== "undefined"
                ? sum + assignment.earned_point
                : sum,
            0,
          );

          setStudentCards([
            {
              label: "Assignments (Total)",
              value: allAssignments?.length ?? 0,
              color: "primary",
              icon: "fa-clipboard-list",
              path: "/dashboard/assignments",
            },
            {
              label: "Result (Marks)",
              value: totalMarks>0?`${earnedMarks} / ${totalMarks} (${(earnedMarks / totalMarks * 100).toFixed(2)}%)`:0,
              color: "success",
              icon: "fa-percent",
              path: "/dashboard/results",
            },
            {
              label: "Total Quizzes",
              value: quizzes.length ?? 0,
              color: "warning",
              icon: "fa-comments",
              path: "/dashboard/quizzes",
            },
          ]);
        } catch (err) {
          console.error("Error loading student dashboard:", err);
        }
      };
      loadStudentData();
    }
  }, [role]);

  if (role === "student") {
    if (studentCards.length === 0) return <p>Loading student dashboard...</p>;

    return (
      <div className="dashboard">
        <h2 className="dashboard-title">Student Dashboard</h2>
        <CardDashboard cards={studentCards} />
        <StudentSubmissionDashboard completedAssignment={completedAssignment} />
      </div>
    );
  }

  if (role === "teacher" && !teacherData)
    return <p>Loading teacher dashboard...</p>;

  return (
    <div className="dashboard">
      <h2 className="dashboard-title">Teacher Dashboard</h2>

      {/* Cards */}
      <div className="cards">
        <div className="card" onClick={()=>navigate('/dashboard/cohorts')}>
          <p className="blue">Students</p>
          <h3>{teacherData.studentsCount}</h3>
        </div>
        <div className="card" onClick={()=>navigate('/dashboard/assignments')}>
          <p className="green">Assignments</p>
          <h3>{teacherData.assignments.length}</h3>
        </div>
        <div className="card" onClick={()=>navigate('/dashboard/submissionstatus')}>
          <p className="cyan">Needs Grading</p>
          <h3>{teacherData.needsGrading.length}</h3>
        </div>
      </div>

      {/* Needs Grading */}
      <div className="needs-grading">
        <h4>Needs Grading ({teacherData.needsGrading.length})</h4>
        {teacherData.needsGrading.length > 0 ? (
          <ul>
            {teacherData.needsGrading.map((a, i) => {
              const studentIds = Array.isArray(a.student_user_id)
                ? a.student_user_id
                : [a.student_user_id];

              const studentNames = studentIds.map((uid) => {
                const student = teacherData.users.find((u) => u.uid === uid);
                return student
                  ? student.fullName || student.email
                  : "Unknown Student";
              });

              const assignmentTitle =
                teacherData.assignments.find(
                  (asg) => asg.assignment_id === a.assignment_id,
                )?.title || a.assignment_id;

              return (
                <li
                  key={i}
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                  }}
                >
                  <span>
                    {studentNames.join(", ")} — {assignmentTitle}
                  </span>
                  <button
                    className="grade-button"
                    onClick={() =>
                      navigate(`/dashboard/submissionstatus`, {
                        state: {
                          student_assignment_id: a.student_assignment_id,
                        },
                      })
                    }
                  >
                    Grade
                  </button>
                </li>
              );
            })}
          </ul>
        ) : (
          <p>No assignments waiting for grading.</p>
        )}
      </div>

      {/* Recent Assignments */}
      <div className="table-container">
        <h4 className="table-title">Recent Assignments</h4>
        <table className="table">
          <thead>
            <tr>
              <th>Assignment</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {teacherData.assignments.map((a, index) => {
              const allForAssignment = teacherData.studentAssignments.filter(
                (sa) => sa.assignment_id === a.assignment_id,
              );
              const submittedCount = allForAssignment.filter(
                (sa) => sa.status === "submitted" || sa.status === "completed",
              ).length;
              const totalStudents = allForAssignment.length;
              const percent = totalStudents
                ? Math.round((submittedCount / totalStudents) * 100)
                : 0;

              return totalStudents?  (<tr key={index} onClick={()=> navigate(`/dashboard/assignments/${a.assignment_id}/cohort-results`)}>
                  <td>{a.title || a.description}</td>
                  <td>
                    {submittedCount}/{totalStudents} ({percent}%)
                  </td>
                </tr>
              ): null;
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Dashboard;
