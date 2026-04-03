import { useNavigate } from "react-router-dom";

const StudentSubmissionDashboard = ({ completedAssignment }) => {
  const Navigate = useNavigate();
  return (
    <>
      <div className="row">
        <div className="col-lg-12 mb-4">
          <div className="card shadow mb-4">
            <div className="card-header py-3">
              <h6 className="m-0 font-weight-bold text-primary">
                Five Recent Assignment Score
              </h6>
            </div>

            <div className="card-body">
              {completedAssignment.slice(0, 5).map((item, index) => {
                const percent =
                  parseInt(
                    (item.earned_point / item.total_marks).toFixed(2) * 100,
                  ) || 0;

                // Optional color logic
                const getColor = (p) => {
                  if (p < 30) return "danger";
                  if (p < 60) return "warning";
                  if (p < 90) return "info";
                  return "success";
                };

                const color = getColor(percent);

                return (
                  <div key={item.assignment_id || index} onClick={()=>Navigate(`/dashboard/results/${item.assignment_id}`)}>
                    <h4 className="small font-weight-bold">
                      {item.title || `Assignment ${index + 1}`}{" "}
                      <span className="float-right">
                        {item.earned_point} / {item.total_marks}{" "}
                        {percent === 100 ? "— Complete!" : `(${percent}%)`}
                      </span>
                    </h4>

                    <div className="progress mb-4">
                      <div
                        className={`progress-bar bg-${color}`}
                        role="progressbar"
                        style={{ width: `${percent}%` }}
                        aria-valuenow={percent}
                        aria-valuemin="0"
                        aria-valuemax="100"
                      ></div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default StudentSubmissionDashboard;
