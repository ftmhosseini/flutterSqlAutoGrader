import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DataTable from "react-data-table-component";
import { Tabs, TabList, Tab, TabPanel } from "react-tabs";
import "react-tabs/style/react-tabs.css";

import Breadcrumb from "../Breadcrumb";
import userSession from "../../../../components/services/UserSession";
import {
  getAllAssignmentByStudent,
  updateStudentAssignment,
} from "../../../../components/model/studentAssignments";
import LoadingOverlay from "../LoadingOverlay";
import { getUser } from "../../../../components/model/users";
import { sendSubmissionNotificationEmail } from "../../../../components/services/email";

const Assignments = () => {
  const navigate = useNavigate();
  const [assignmentsdata, setAssignmentsdata] = useState([]);
  const [submissionsdata, setSubmissionsdata] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const todayDate = new Date().toLocaleDateString("en-CA");

  useEffect(() => {
    const fetchdata = async () => {
      try {
        const allAssigments = await getAllAssignmentByStudent(userSession.uid, [
          "assigned",
          "completed",
          "submitted",
        ]);
        const completedAssignment = allAssigments.filter(
          (assignment) =>
            assignment.status === "completed" ||
            assignment.status === "submitted",
        );

        setSubmissionsdata(completedAssignment);
        const pendingAssignment = allAssigments.filter(
          (assignment) => assignment.status === "assigned",
        );
        setAssignmentsdata(pendingAssignment);
      } catch (error) {
        console.error("Error:", error);
      } finally {
        setIsLoading(false);
      }
    };
    fetchdata();
  }, []);

  const cap = (str) => (str ? str.charAt(0).toUpperCase() + str.slice(1) : "");

  async function markComplele(assignment) {
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
    setAssignmentsdata((prev) =>
      prev.filter((item) => item.assignment_id !== assignmentId),
    );
    alert("Assignment updated successfully!");
  }

  const activeColumns = [
    {
      name: "S.No",
      selector: (row) => row.assignment_id,
      cell: (row, index) => index + 1,
    },
    {
      name: "Title",
      selector: (row) => row.title,
      sortable: true,
      cell: (row) => cap(row.title),
    },
    {
      name: "Due Date",
      id: "dueDate",
      selector: (row) => typeof row?.dueDate !== "undefined" ? row?.dueDate : row?.due_date,
      sortable: true,
    },
    {
      name: "Status",
      selector: (row) => row.status,
      cell: (row) => {
        const dueDate = typeof row?.dueDate !== "undefined" ? row?.dueDate : row?.due_date
        const isOverDue =
          new Date(dueDate) < new Date(todayDate) ? true : false;
        return (
          <>
            <span
              className={`badge ${isOverDue ? "bg-warning text-dark" : "bg-primary"}`}
              style={{
                color: "white",
                padding: "5px 10px",
                borderRadius: "12px",
                fontSize: "11px",
              }}
            >
              {isOverDue ? "over due" : row.status}
            </span>
          </>
        );
      },
    },
    {
      name: "Action",
      button: true,
      cell: (row) => {
        const dueDate = typeof row?.dueDate !== "undefined" ? row?.dueDate : row?.due_date
        const isOverDue =
          new Date(dueDate) < new Date(todayDate) ? true : false;
        return (
          <button
            className={`btn btn-sm ${isOverDue ? "btn-danger" : "btn-primary"}`}
            style={{ borderRadius: "4px", fontSize: "12px" }}
            onClick={() => {
              if (isOverDue) {
                markComplele(row);
              } else {
                navigate(`/dashboard/questions/${row.assignment_id}`, {
                  state: { assignment: row },
                });
              }
            }}
          >
            {isOverDue ? "Mark Finished" : "Continue"}
          </button>
        );
      },
    },
  ];

  const submittedColumns = [
    {
      name: "S.No",
      selector: (row) => row.assignment_id,
      cell: (row, index) => index + 1,
    },
    {
      name: "Title",
      selector: (row) => row.title,
      sortable: true,
      cell: (row) => cap(row.title),
    },
    {
      name: "Due Date",
      id: "dueDate",
      selector: (row) => typeof row?.dueDate !== "undefined" ? row?.dueDate : row?.due_date,
      sortable: true,
    },
    {
      name: "Marks Obtained / Total",
      selector: (row) =>
        `${typeof row.earned_point !== "undefined" ? row.earned_point : 0} / ${row.total_marks}`,
      sortable: true,
    },
    {
      name: "Percentage",
      selector: (row) =>
        `${Math.round(
          ((typeof row.earned_point !== "undefined" ? row.earned_point : 0) /
            row.total_marks) *
            100,
        )} %`,
    },
    {
      name: "Action",
      ignoreRowClick: true,
      cell: (row) => (
        <button
          className="btn btn-sm btn-primary"
          style={{ borderRadius: "4px", fontSize: "12px" }}
          onClick={() => navigate(`/dashboard/results/${row.assignment_id}`)}
        >
          View Detail
        </button>
      ),
    },
  ];

  return (
    <>
      <LoadingOverlay isOpen={isLoading} message="Loading..." />
      <div className="d-sm-flex justify-content-between mb-0">
        <h2>Assignments</h2>
        <Breadcrumb
          items={[
            { label: "Dashboard", link: "/dashboard" },
            { label: "Assignments", active: true },
          ]}
        />
      </div>
      <div className="card shadow mb-4">
        <Tabs>
          <TabList>
            <Tab>Assignments</Tab>
            <Tab>Submitted Assignments</Tab>
          </TabList>
          <TabPanel>
            <DataTable
              columns={activeColumns}
              data={assignmentsdata}
              pagination
              highlightOnHover
              striped
              responsive
              defaultSortFieldId="dueDate"
              defaultSortAsc={true}
            />
          </TabPanel>
          <TabPanel>
            <DataTable
              columns={submittedColumns}
              data={submissionsdata}
              pagination
              highlightOnHover
              striped
              responsive
              defaultSortFieldId="dueDate"
              defaultSortAsc={false}
            />
          </TabPanel>
        </Tabs>
      </div>
    </>
  );
};

export default Assignments;
