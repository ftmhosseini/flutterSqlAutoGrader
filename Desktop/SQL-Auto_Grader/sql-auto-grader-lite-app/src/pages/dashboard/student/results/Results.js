import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DataTable from "react-data-table-component";
import Breadcrumb from "../Breadcrumb";
import LoadingOverlay from "../LoadingOverlay";

import userSession from "../../../../components/services/UserSession";
import { getAllAssignmentByStudent } from "../../../../components/model/studentAssignments";
import { getBestAttemptByUserQuestion } from "../../../../components/model/questionAttempts";

/**
 * Results component
 * Displays Student result list in a DataTable
 */
const Results = () => {
  const navigate = useNavigate();
  const [submissionsdata, setsubmissionsdata] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  useEffect(() => {
    // Get data from student assignments table from firebase
    const fetchdata = async () => {
      try {
        const data = await getAllAssignmentByStudent(userSession.uid, [
          "completed",
          "submitted",
        ]);
        // console.log(
        //   "Submissions page - student_assignment records:",
        //   data.map((a) => ({
        //     assignment_id: a.assignment_id,
        //     status: a.status,
        //     student_assignment_id: a.student_assignment_id,
        //   })),
        // );
        setsubmissionsdata(data);
      } catch (error) {
        console.error("Error:", error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchdata();
  }, []);

  /**
   * Column configuration for the Results DataTable
   * Each object represents one column in the table
   */
  const columns = [
    {
      name: "Sr no.",
      selector: (row, index) => index + 1,
      sortable: true,
    },
    {
      name: "Title",
      selector: (row) => row.title,
      sortable: true,
      cell: (row) => capitalizeFirstLetter(row.title),
    },
    {
      name: "Marks Obtained / Total Marks",
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
      cell: (row) => (
        <button
          className="btn btn-primary btn-sm"
          style={{ borderRadius: "4px", fontSize: "12px" }}
          onClick={() => navigate(`/dashboard/results/${row.assignment_id}`)}
        >
          View Detail
        </button>
      ),
    },
  ];

  // First letter captial for Assignments title
  const capitalizeFirstLetter = (str) => {
    if (!str) return "";
    return str.charAt(0).toUpperCase() + str.slice(1);
  };

  return (
    <>
      <LoadingOverlay isOpen={isLoading} message="Loading..." />
      <div className="d-sm-flex align-items-center justify-content-between mb-4">
        <h2>Submitted Assignments</h2>
        <Breadcrumb
          items={[
            { label: "Dashboard", link: "/dashboard" },
            { label: "Submitted Assignments", active: true },
          ]}
        />
      </div>
      <div className="card shadow mb-4">
        <DataTable
          columns={columns}
          data={submissionsdata}
          pagination
          highlightOnHover
          striped
          responsive
        />
      </div>
    </>
  );
};

export default Results;
