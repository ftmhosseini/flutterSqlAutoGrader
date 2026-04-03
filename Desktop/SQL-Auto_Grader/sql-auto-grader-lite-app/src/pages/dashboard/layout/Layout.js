import { Outlet, Navigate } from "react-router-dom";
import userSession from "../../../components/services/UserSession";
import "../Dashboard.css";
import LeftMenu from "../leftmenu/LeftMenu";

const studentNavItems = [
  { name: "Dashboard", address: "/dashboard", icon: "fa-tachometer-alt" },
  { name: "Cohorts", address: "/dashboard/cohorts", icon: "fa-users" },
  { name: "Assignments", address: "/dashboard/assignments", icon: "fa-book" },
  { name: "Quizzes", address: "/dashboard/quizzes", icon: "fa-question" },
  { name: "Submission", address: "/dashboard/results", icon: "fa-chart-area" },
  { name: "Profile", address: "/dashboard/profile", icon: "fa-user" },
];

const teacherNavItems = [
  { name: "Dashboard", address: "/dashboard", icon: "fa-tachometer-alt" },
  { name: "Cohorts", address: "/dashboard/cohorts", icon: "fa-users" },
  { name: "Assignments", address: "/dashboard/assignments", icon: "fa-book" },
  { name: "Quizzes", address: "/dashboard/quizzes", icon: "fa-question" },
  {
    name: "Submission Status",
    address: "/dashboard/submissionstatus",
    icon: "fa-check",
  },
  {
    name: "Dataset Manager",
    address: "/dashboard/datasets",
    icon: "fa-database",
  },
  { name: "Profile", address: "/dashboard/profile", icon: "fa-user" },
];

const Layout = () => {
  const userRole = userSession.role;

  if (!userSession.uid) return <Navigate to="/login" />;

  const navItems = userRole === "teacher" ? teacherNavItems : studentNavItems;
  const dashboardName =
    userRole === "teacher" ? "Teacher Dashboard" : "Student Dashboard";

  return (
    <div id="wrapper">
      <LeftMenu name={dashboardName} navItems={navItems} />
      <div id="content-wrapper" className="d-flex flex-column">
        <div id="content">
          <div className="container-fluid">
            <Outlet context={{ userRole }} />
          </div>
        </div>
      </div>
    </div>
  );
};

export default Layout;
