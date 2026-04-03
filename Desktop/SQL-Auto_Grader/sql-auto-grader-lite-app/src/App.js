import { useState } from "react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "./components/services/useAuth";

import Home from "./pages/home/Home";
import Register from "./pages/register/Register";
import Login from "./pages/login/Login";
import About from "./pages/about/About";
import Footer from "./components/bars/Footer";
import Profile from "./pages/profile/Profile";
import NavBar from "./components/bars/Navbar";

import Layout from "./pages/dashboard/layout/Layout";
import Dashboard from "./pages/dashboard/Dashboard";
import GradingPage from "./pages/dashboard/GradingPage";
// student
import Assignments from "./pages/dashboard/student/assignments/Assignments";
import QuestionList from "./pages/dashboard/student/assignments/QuestionList";
import Quizzes from "./pages/dashboard/student/quizzes/Quizzes";
import QuizDetail from "./pages/dashboard/student/quizzes/QuizDetail";
import Results from "./pages/dashboard/student/results/Results";
import SubmittedQuestions from "./pages/dashboard/student/results/SubmittedQuestions";
//import AntiCheatingAssignmentDetail from "./pages/dashboard/student/assignments/AntiCheatingAssignmentDetail";
// teacher
import DatabaseLoader from "./pages/dashboard/teacher/datasets/dbLoader"
import AssignmentForm from "./pages/dashboard/teacher/assignmentform/AssignmentForm"
import AssignmentList from "./pages/dashboard/teacher/assignmentform/AssignmentList"
import AssignmentCohortResults from "./pages/dashboard/teacher/assignmentform/AssignmentCohortResults"
import QuizForm from "./pages/dashboard/teacher/quizform/QuizForm"
import QuizList from "./pages/dashboard/teacher/quizform/QuizList"
import CohortManager from "./pages/dashboard/teacher/cohorts/CohortManager"
import SubmissionStatusPage from "./pages/dashboard/teacher/submissionstatus/SubmissionStatusPage";


import "./App.css";
import AssignmentDetail from "./pages/dashboard/student/assignments/AntiCheatingQuestionDetail";
import Cohort from "./pages/dashboard/student/cohort/Cohort";

function TeacherAssignments() {
  const [creating, setCreating] = useState(false);
  return creating
    ? <AssignmentForm onDone={() => setCreating(false)} />
    : <AssignmentList onCreate={() => setCreating(true)} />;
}
function TeacherQuizzes() {
  const [creating, setCreating] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  return creating
    ? <QuizForm onDone={() => { setCreating(false); setRefreshKey(k => k + 1); }} />
    : <QuizList key={refreshKey} onCreate={() => setCreating(true)} />;
}

function App() {
  const { role, loading } = useAuth();

  if (loading) return null;

  const ProtectedRoute = ({ children }) => {
    if (!role) return <Navigate to="/login" />;
    return children;
  };

  return (
    <Router>
      <div className="app-wrapper">
        <NavBar/>

        <main className="main-content">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/register" element={<Register />} />


            <Route path="/dashboard" element={<ProtectedRoute><Layout /></ProtectedRoute>}>
              <Route index element={<Dashboard role={role}/>} />
              <Route path="grade/:student_assignment_id" element={<GradingPage />} />
              <Route path="assignments" element={
                role === "student"
                  ? <Assignments />
                  : <TeacherAssignments />
              } />
              <Route path="assignments/:assignment_id/cohort-results" element={<AssignmentCohortResults />} />
              <Route path="assignments/:id" element={<AssignmentDetail />} />
              <Route path="questions/:assignment_id" element={<QuestionList />} />
              <Route path="questions/:assignment_id/question-view/:question_id" element={<AssignmentDetail />} />
              <Route path="quizzes" element={
                role === "student"
                  ? <Quizzes />
                  : <TeacherQuizzes />
              } />
              <Route path="quizzes/:quiz_id" element={<QuizDetail />} />
              <Route path="results" element={<Results />} />
              <Route path="results/:assignment_id" element={<SubmittedQuestions />} />
              {/* <Route path="questions" element={<CreateQuestionSet />} /> */}
              {/* <Route path="datasets" element={<Datasets />} /> */}
              <Route path="datasets" element={<DatabaseLoader />} />
              <Route path="cohorts" element={
                role === "student"
                  ? <Cohort />
                  : <CohortManager />
              } />
              <Route path="submissionstatus" element={<SubmissionStatusPage />} />
              <Route path="profile" element={<Profile />} />
            </Route>



            <Route path="/login" element={<Login />} />
            <Route path="/about" element={<About />} />
          </Routes>
        </main>
        <Footer/>
      </div>
    </Router>
  );
}

export default App;