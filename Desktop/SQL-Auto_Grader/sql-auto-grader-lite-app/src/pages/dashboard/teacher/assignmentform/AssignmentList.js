import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { getAllAssignmentByOwner } from "../../../../components/model/assignments";
import { sendReminderEmail, sendAssignmentEmailsToStudents } from "../../../../components/services/email";
import { getAllStudents, getCohortsByOwner, getAllCohorts } from "../../../../components/model/cohorts";
import { publishAssignmentToStudents, isAssignmentPublished } from "../../../../components/model/studentAssignments";
import CollapsiblePanel from "../assignmentform/collapsiblepanel/CollapsiblePanel";
import userSession from "../../../../components/services/UserSession";
import { deleteAssignment } from "../../../../components/model/assignments";



import "./AssignmentForm.css"; 

function AssignmentList({ onCreate }) {
  const [assignments, setAssignments] = useState([]);
  const [expanded, setExpanded] = useState(null);
  const [cohortMap, setCohortMap] = useState({});
  const [collapsedQuestions, setCollapsedQuestions] = useState({});
  const [reloadKey, setReloadKey] = useState(0);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchData = async () => {
      console.log(userSession.uid);
      const data = await getAllAssignmentByOwner(userSession.uid);
      const today = new Date().toISOString().split("T")[0];
      
      const withPublished = await Promise.all(
        data
          .filter(a => {
            const due = a.due_date || a.dueDate;
            return !due || due >= today;
          })
          .map(async (a) => ({ 
          ...a, 
          published: await isAssignmentPublished(a.assignment_id) 
        }))
      );
      setAssignments(withPublished);

      const cohorts = await getAllCohorts();
      const map = {};
      cohorts.forEach(c => { map[c.cohort_id] = c; });
      setCohortMap(map);
    };
    fetchData();
  }, [reloadKey]);

  const toggleQuestion = (id) => setCollapsedQuestions(prev => ({ ...prev, [id]: !prev[id] }));
  const toggleAssignment = (id) => setExpanded(expanded === id ? null : id);

  return (
    <div className="container-fluid p-0">
    
      <div className="d-sm-flex align-items-center justify-content-between mb-4 px-3 pt-3">
        <h1 className="h3 mb-0 text-gray-800 font-weight-bold">Assignments</h1>
        <button 
          onClick={onCreate} 
          className="btn btn-success btn-icon-split shadow-sm"
        >
          <span className="icon text-white-50">
            <i className="fas fa-plus"></i>
          </span>
          <span className="text font-weight-bold">New Assignment</span>
        </button>
      </div>

      <div className="px-3 pb-4">
        {assignments.length === 0 && (
          <div className="card shadow mb-4 py-5 text-center border-left-secondary">
            <i className="fas fa-clipboard-list fa-3x text-gray-300 mb-3"></i>
            <p className="text-gray-500 mb-0">No active assignments found.</p>
          </div>
        )}

        {assignments.map((a) => {
          const needsReminder = !!a.reminder_interval;
          const isExpanded = expanded === a.assignment_id;

          return (
            <div 
              key={a.assignment_id} 
              className={`card shadow mb-3 ${needsReminder ? 'border-left-warning' : 'border-left-primary'}`}
            >
         
              <div 
                className="card-header py-3 d-flex flex-row align-items-center justify-content-between"
                onClick={() => toggleAssignment(a.assignment_id)}
                style={{ cursor: "pointer", backgroundColor: needsReminder ? "#fffdf5" : "#fff" }}
              >
                <div className="d-flex align-items-center">
                  <h6 className={`m-0 font-weight-bold ${needsReminder ? 'text-warning' : 'text-primary'}`}>
                    {a.title}
                  </h6>
                  {a.student_class && (
                    <span className="badge badge-info ml-3 text-uppercase px-2 py-1" style={{ fontSize: '10px' }}>
                      <i className="fas fa-users mr-1"></i>
                      {cohortMap[a.student_class]?.name || a.student_class}
                    </span>
                  )}
                  {needsReminder && (
                    <button
                      className="btn btn-warning btn-sm ml-3 shadow-sm py-0 px-2"
                      style={{ fontSize: '11px', height: '22px' }}
                      onClick={async (e) => {
                        e.stopPropagation();
                        const allStudentsList = await getAllStudents();
                        const cohorts = await getCohortsByOwner(userSession.uid);
                        const cohort = cohorts.find(c => c.cohort_id === a.student_class);
                        const cohortStudents = allStudentsList.filter(s => cohort?.student_uids?.includes(s.uid));
                        await Promise.all(cohortStudents.map(s => sendReminderEmail(s, a.title, a.due_date, a.assignment_id)));
                        alert("Reminder emails sent!");
                      }}
                    >
                      <i className="fas fa-bell mr-1"></i> Send Reminder
                    </button>
                  )}
                </div>

                <div className="d-flex align-items-center">
                  {!a.published ? (
                    <button
                      className="btn btn-outline-success btn-sm mr-3 font-weight-bold"
                      onClick={async (e) => {
                        e.stopPropagation();
                        const result = await publishAssignmentToStudents(a.assignment_id, a.student_class, a.due_date || a.dueDate || null);
                        if (result.success) {
                          const allStudentsList = await getAllStudents();
                          const cohorts = await getCohortsByOwner(userSession.uid);
                          const cohort = cohorts.find(c => c.cohort_id === a.student_class);
                          const cohortStudents = allStudentsList.filter(s => cohort?.student_uids?.includes(s.uid));
                          await Promise.all(cohortStudents.map(s => sendReminderEmail(s, a.title, a.due_date, a.assignment_id)));
                          // await sendAssignmentEmailsToStudents(a, a.assignment_id);
                      alert("Assignment published!");
                          setAssignments(prev => prev.map(x => x.assignment_id === a.assignment_id ? { ...x, published: true } : x));
                        } else alert("Failed: " + result.message);
                      }}
                    >
                      Publish Now
                    </button>
                  ) : (
                    <span className="badge badge-light border mr-3 text-gray-600">
                      <i className="fas fa-check-circle text-success mr-1"></i> Published
                    </span>
                  )}
                  <div className="d-flex align-items-center">
                    <span className="icon text-white-50">
                      <i className="fas fa-plus"></i>
                    </span>
                    <button className="btn btn-outline-info btn-sm mr-3 font-weight-bold"
                      onClick={async (e) => {
                        e.stopPropagation();
                        if(window.confirm('Are you sure you want to delete this item?')){
                          await deleteAssignment(a.assignment_id);
                          setReloadKey(k => k + 1);
                          //window.location.reload();                          
                        }
                      }}>                      
                        <span>
                          <i className="fas fa-trash"></i>
                        </span>
                    </button>
                  </div>
                  <span className="text-gray-600 small mr-3">
                    Due: <strong>{a.due_date || a.dueDate || "—"}</strong>
                  </span>
                  <i className={`fas fa-chevron-${isExpanded ? 'up' : 'down'} text-gray-400 transition-icon`}></i>
                </div>
              </div>

           
              {isExpanded && (
                <div className="card-body bg-light rounded-bottom border-top">
                  <div className="mb-4">
                    <label className="small font-weight-bold text-gray-500 text-uppercase mb-1">Description</label>
                    <p className="text-gray-800 p-3 bg-white border rounded shadow-sm mb-0">{a.description || "No description provided."}</p>
                  </div>

                  <div className="row mb-4">
                    <div className="col-md-4">
                      <div className="p-2 bg-white border rounded shadow-sm text-center">
                        <div className="small text-gray-500">Students</div>
                        <div className="h6 mb-0 font-weight-bold text-gray-800">{cohortMap[a.student_class]?.student_uids?.length || 0}</div>
                      </div>
                    </div>
                    <div className="col-md-4">
                      <div className="p-2 bg-white border rounded shadow-sm text-center">
                        <div className="small text-gray-500">Notifications</div>
                        <div className={`h6 mb-0 font-weight-bold ${a.enable_submission_notification ? 'text-success' : 'text-gray-400'}`}>
                          {a.enable_submission_notification ? "Enabled" : "Disabled"}
                        </div>
                      </div>
                    </div>
                    <div className="col-md-4">
                      <div className="p-2 bg-white border rounded shadow-sm text-center">
                        <div className="small text-gray-500">Reminders</div>
                        <div className={`h6 mb-0 font-weight-bold ${a.reminder_interval ? 'text-warning' : 'text-gray-400'}`}>
                          {a.reminder_interval ? "Active" : "Inactive"}
                        </div>
                      </div>
                    </div>
                  </div>

                  <h6 className="font-weight-bold text-gray-800 mb-3">
                    <i className="fas fa-list-ol mr-2 text-primary"></i> Questions Included
                  </h6>

                  {(a.questions || []).map((q, i) => (
                    <div key={q.question_id || i} className="mb-2">
                      <CollapsiblePanel
                        title={`Q${i + 1}: ${q.questionText?.substring(0, 40)}...`}
                        isCollapsed={!collapsedQuestions[q.question_id]}
                        onToggle={() => toggleQuestion(q.question_id)}
                      >
                        <div className="p-3 bg-white border rounded mt-2 shadow-sm">
                           <div className="row">
                              <div className="col-md-6 mb-3">
                                <label className="small font-weight-bold text-primary text-uppercase">Question Prompt</label>
                                <textarea className="form-control bg-light" rows="3" readOnly value={q.questionText} />
                              </div>
                              <div className="col-md-6 mb-3">
                                <label className="small font-weight-bold text-success text-uppercase">SQL Reference</label>
                                <textarea className="form-control bg-light font-italic text-primary" rows="3" readOnly value={q.answer} />
                              </div>
                           </div>
                           <div className="d-flex flex-wrap gap-2 mt-2 pt-2 border-top">
                             <span className="badge badge-secondary mr-2 px-2 py-1">Level: {q.difficulty}</span>
                             <span className="badge badge-secondary mr-2 px-2 py-1">Points: {q.mark}</span>
                             <span className="badge badge-secondary px-2 py-1">Attempts: {q.max_attempts}</span>
                           </div>
                        </div>
                      </CollapsiblePanel>
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

export default AssignmentList;