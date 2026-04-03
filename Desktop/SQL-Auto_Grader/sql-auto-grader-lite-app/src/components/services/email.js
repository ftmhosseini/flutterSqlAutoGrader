
import emailjs from "@emailjs/browser";
import { getCohortsByOwner, getAllStudents } from "../model/cohorts";
import userSession from "./UserSession";

const SERVICE_ID = process.env.REACT_APP_EMAILJS_SERVICE_ID;
const TEMPLATE_ID_STUDENT = process.env.REACT_APP_EMAILJS_TEMPLATE_ID_STUDENT;
const TEMPLATE_ID_TEACHER = process.env.REACT_APP_EMAILJS_TEMPLATE_ID_TEACHER;
const PUBLIC_KEY = process.env.REACT_APP_EMAILJS_PUBLIC_KEY;


export const sendAssignmentEmail = async (student, assignmentTitle, assignmentDueDate, assignmentId) => {

  if (!student?.email) {
    console.error("Cannot send email: student email is empty!", student);
    return;
  }

  try {
    await emailjs.send(
          SERVICE_ID,
          TEMPLATE_ID_STUDENT,
          {
            from:'info@sql-grader.com',
        name: student.fullName,
        email: student.email,
        title: assignmentTitle,
        date: assignmentDueDate,
        link: `${window.location.origin}/dashboard/questions/${assignmentId}`,
          },
          PUBLIC_KEY
        );
    console.log(`Email sent to ${student.email}`);
  } catch (error) {
    console.error("Error sending email:", error);
  }
};


export const sendQuizEmail = async (student, assignmentTitle, assignmentId) => {

  if (!student?.email) {
    console.error("Cannot send email: student email is empty!", student);
    return;
  }

  try {
    await emailjs.send(
          SERVICE_ID,
          TEMPLATE_ID_STUDENT,
          {
            from:'info@sql-grader.com',
        name: student.fullName,
        email: student.email,
        title: assignmentTitle,
        date: new Date().toLocaleDateString("en-CA"),
        link: `${window.location.origin}/dashboard/quizzes/${assignmentId}`,
          },
          PUBLIC_KEY
        );
    console.log(`Email sent to ${student.email}`);
  } catch (error) {
    console.error("Error sending email:", error);
  }
};

export const sendSubmissionNotificationEmail = async (teacher, studentName, assignmentTitle) => {
  if (!teacher?.email) return;
  try {
    await emailjs.send(
          SERVICE_ID,
          TEMPLATE_ID_TEACHER,
          {
            from:'info@sql-grader.com',
            name: teacher.fullName,
            email: teacher.email,
            title: `${studentName} has submitted: ${assignmentTitle}`,
            link: `${window.location.origin}/dashboard/submissionstatus`,
          },
          PUBLIC_KEY
        );
  } catch (error) {
    console.error("Error sending submission notification:", error);
  }
};

export const sendReminderEmail = async (student, assignmentTitle, assignmentDueDate, assignmentId) => {
  if (!student?.email) return;
  try {
    await emailjs.send(
          SERVICE_ID,
          TEMPLATE_ID_STUDENT,
          {
            from:'info@sql-grader.com',
            name: student.fullName,
            email: student.email,
            title: `Reminder: ${assignmentTitle}`,
            date: assignmentDueDate,
        link: `${window.location.origin}/dashboard/questions/${assignmentId}`,
          },
          PUBLIC_KEY
        );
    console.log(`Reminder sent to ${student.email}`);
  } catch (error) {
    console.error("Error sending reminder:", error);
  }
};

// // Shared helper — send assignment notification emails to all students in the assignment's cohort
// export const sendAssignmentEmailsToStudents = async (assignment, assignmentId) => {
//   const allCohorts = await getCohortsByOwner(userSession.uid);
//   const cohort = allCohorts.find(c => c.cohort_id === assignment.student_class);
//   if (!cohort?.student_uids?.length) return;
//   const allStudents = await getAllStudents();
//   const cohortStudents = allStudents.filter(s => cohort.student_uids.includes(s.uid));
//   await Promise.all(cohortStudents.map(s => sendAssignmentEmail(s, assignment.title, assignment.dueDate || assignment.due_date, assignmentId)));
// };
