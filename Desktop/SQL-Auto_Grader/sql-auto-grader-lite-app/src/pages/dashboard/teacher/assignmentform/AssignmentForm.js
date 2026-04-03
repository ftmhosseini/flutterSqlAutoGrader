// import { useState, useEffect } from 'react';
// import { useNavigate } from 'react-router-dom';
// import { Tabs, TabList, Tab, TabPanel } from 'react-tabs';
// import 'react-tabs/style/react-tabs.css';
// import CreateQuestionSet from './createquestionset/CreateQuestionSet';
// import { createNewAssignment } from "../../../../components/model/assignments";
// import { getCohortsByOwner } from "../../../../components/model/cohorts";
// import { CreateAssignment } from './createquestionset/CreateAssignment';
// import { sendAssignmentEmailsToStudents } from "../../../../components/services/email";
// import { publishAssignmentToStudents } from "../../../../components/model/studentAssignments";
// import userSession from "../../../../components/services/UserSession";

// const AssignmentForm = ({ onDone }) => {
//   const navigate = useNavigate();
//   const [activeTab, setActiveTab] = useState(0);
//   const [db, setDb] = useState("");
//   const [totalMarks, setTotalMarks] = useState(0);
//   const [formData, setFormData] = useState({
//     title: '', total_marks: '', due_date: '', description: '',
//     student_class: '', questions: [],
//     enable_submission_notification: false, reminder_interval: false
//   });
//   const [cohorts, setCohorts] = useState([]);
//   const [cohortsLoaded, setCohortsLoaded] = useState(false);
//   const [assignmentId, setAssignmentId] = useState("");
//   const [error, setError] = useState("");

//   useEffect(() => {
//     getCohortsByOwner(userSession.uid).then(data => {
//       setCohorts(data);
//       setCohortsLoaded(true);
//     });
//   }, []);

//   const handleChange = (e) => {
//     const { name, value, type, checked } = e.target;
//     setFormData(prev => ({ ...prev, [name]: type === 'checkbox' ? checked : value }));
//     if (name === 'due_date') setError("");
//   };

//   const isTabComplete = (tabIndex) => {
//     const required = [['title', 'due_date'], [], ['student_class']];
//     return required[tabIndex]?.every((f) => String(formData[f]).trim() !== '') ?? true;
//   };

//   const handleNext = async () => {
//     setError("");
//     if (activeTab === 0) {
//       if (!formData.title || !formData.due_date) { setError("Please fill in the title and due date."); return; }
//       const today = new Date(); today.setHours(0, 0, 0, 0);
//       if (new Date(formData.due_date) < today) { setError("Due date cannot be in the past."); return; }
//     }
//     setActiveTab(prev => prev + 1);
//   };

//   const buildAssignmentPayload = () => ({
//     ...formData,
//     owner_user_id: userSession.uid,
//     dataset: db,
//     total_marks: totalMarks,
//     dueDate: formData.due_date,
//     created_on: new Date(),
//     updated_on: new Date(),
//   });

//   const validateDueDate = () => {
//     const date = new Date(formData.due_date);
//     const today = new Date(); today.setHours(0, 0, 0, 0);
//     if (date < today) { setError("Due date cannot be in the past."); return false; }
//     if (date.getFullYear() > 2100) { setError("Please enter a valid due date."); return false; }
//     return true;
//   };

//   const handleSave = async () => {
//     if (formData.questions.length === 0) { alert("The assignment needs at least one question."); return; }
//     if (!validateDueDate()) return;
//     try {
//       const id = await createNewAssignment(buildAssignmentPayload());
//       setAssignmentId(id);
//       alert("Assignment saved.");
//     } catch (err) { setError("Failed to save: " + err.message); }
//   };

//   const handlePublish = async () => {
//     if (!window.confirm("Are you sure you want to publish?")) return;
//     if (!validateDueDate()) return;
//     try {
//       let id = assignmentId;
//       if (!id) {
//         if (formData.questions.length === 0) { alert("The assignment needs at least one question."); return; }
//         id = await createNewAssignment(buildAssignmentPayload());
//         setAssignmentId(id);
//       }
//       const result = await publishAssignmentToStudents(id, formData.student_class, formData.due_date);
//       if (result.success) {
//         await sendAssignmentEmailsToStudents({ student_class: formData.student_class, title: formData.title, due_date: formData.due_date }, id);
//         alert("Assignment published!");
//         onDone();
//       } else alert("Failed to publish: " + result.message);
//     } catch (err) { setError("Failed to publish: " + err.message); }
//   };

//   return (
//     <div style={{ maxWidth: 'auto', margin: '20px auto', padding: '20px' }}>
//       {onDone && <button type="button" onClick={onDone} style={{ marginBottom: "16px" }}>← Back to Assignments</button>}

  //       {cohortsLoaded && cohorts.length === 0 ? (
  //         <div style={{ padding: '20px', border: '1px solid #f5c6cb', borderRadius: '8px', background: '#fff3f3', color: '#721c24' }}>
  //           <strong>No cohorts found.</strong> You need to create at least one cohort before creating an assignment.{" "}
  //           <span onClick={() => navigate("/dashboard/cohorts")} style={{ color: "#0056b3", cursor: "pointer", textDecoration: "underline" }}>
  //             Create a cohort now
  //           </span>
  //         </div>
  //       ) : (
//         <>
//           <Tabs selectedIndex={activeTab} onSelect={(index) => {
//             const unlocked = index === 0 || [...Array(index)].every((_, i) => isTabComplete(i));
//             if (unlocked) setActiveTab(index);
//           }}>
//             <TabList>
//               <Tab>Create Assignment</Tab>
//               <Tab disabled={!isTabComplete(0)}>Add Questions</Tab>
//               <Tab disabled={!isTabComplete(0) || !isTabComplete(1)}>Assign Students</Tab>
//             </TabList>

//             <TabPanel>
//               <CreateAssignment formData={formData} handleChange={handleChange} />
//             </TabPanel>

//             <TabPanel>
//               <CreateQuestionSet
//                 onAddQuestions={(qs) => setFormData(prev => ({ ...prev, questions: qs }))}
//                 setDb={setDb}
//                 existingQuestions={formData.questions}
//                 existingDataset={db}
//                 setTotalMarks={setTotalMarks}
//               />
//             </TabPanel>

//             <TabPanel>
//               <div>
//                 <label>Student Cohort: </label><br />
//                 <select name="student_class" value={formData.student_class} onChange={handleChange}>
//                   <option value="">-- Select Cohort --</option>
//                   {cohorts.map(c => <option key={c.cohort_id} value={c.cohort_id}>{c.name}</option>)}
//                 </select><br /><br />
//                 <label>Would you like to be notified when a student submits this assignment?: </label>
//                 <input name="enable_submission_notification" type="checkbox" checked={formData.enable_submission_notification} onChange={handleChange} /><br />
//                 <label>Would you like to remind students to submit this assignment?: </label>
//                 <input name="reminder_interval" type="checkbox" checked={formData.reminder_interval} onChange={handleChange} />
//                 {/* <div style={{ marginTop: '20px', display: "flex", gap: "12px" }}>
//                   <button type="button" disabled={!isTabComplete(2)} onClick={handleSave}>Save Assignment</button>
//                   <button type="button" disabled={!isTabComplete(2)} onClick={handlePublish}>Create & Publish Assignment</button>
//                 </div>
//                 {error && <span style={{ color: "red" }}>{error}</span>} */}
//               </div>
//             </TabPanel>
//           </Tabs>
// <div style={{ marginTop: '20px' }}>
//             {activeTab > 0 && (
//               <button type="button" style={{ marginRight: '10px' }} onClick={() => setActiveTab(prev => prev - 1)}>
//                 ← Back
//               </button>
//             )}
//             {activeTab < 2 && (
//               <button type="button" onClick={handleNext}>Next →</button>
//             )}
//             {activeTab === 2 && (
//               <>
//                 <button type="button" style={{ marginRight: '10px' }} disabled={!isTabComplete(2)} onClick={handleSave}>Save Assignment</button>
//                 <button type="button" disabled={!isTabComplete(2)} onClick={handlePublish}>Create & Publish Assignment</button>

//               </>
//             )}
//             {error && <span style={{ marginLeft: "12px", color: "red" }}>{error}</span>}</div>
//         </>
//       )}
//     </div>
//   );
// };

// export default AssignmentForm;

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import CreateQuestionSet from './createquestionset/CreateQuestionSet';
import { createNewAssignment } from "../../../../components/model/assignments";
import { getCohortsByOwner } from "../../../../components/model/cohorts";
import { CreateAssignment } from './createquestionset/CreateAssignment';
import { publishAssignmentToStudents } from "../../../../components/model/studentAssignments";
import userSession from "../../../../components/services/UserSession";
import "./AssignmentForm.css"; 

const AssignmentForm = ({ onDone }) => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState(0);
  const [db, setDb] = useState("");
  const [formData, setFormData] = useState({
    title: '', total_marks: '', due_date: '', description: '',
    student_class: '', questions: [],
    enable_submission_notification: false, reminder_interval: false
  });
  const [assignmentId, setAssignmentId] = useState("");
  const [error, setError] = useState("");
  const [totalMarks, setTotalMarks] = useState(0);
  const [cohorts, setCohorts] = useState([]);
  const [cohortsLoaded, setCohortsLoaded] = useState(false);

  useEffect(() => {
    getCohortsByOwner(userSession.uid).then(data => {
      setCohorts(data);
      setCohortsLoaded(true);
    });
  }, []);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({ ...prev, [name]: type === 'checkbox' ? checked : value }));
    if (name === 'due_date') setError("");
  };

  const steps = [
    { id: 0, title: "Assignment Details", icon: "fa-edit" },
    { id: 1, title: "Questions & SQL", icon: "fa-database" },
    { id: 2, title: "Assign & Publish", icon: "fa-users" }
  ];

  const handleNext = () => {
    if (activeTab === 0 && (!formData.title || !formData.due_date)) {
      setError("Please fill in the title and due date.");
      return;
    }
    if (activeTab === 0 && (formData.due_date< new Date().toISOString().split("T")[0])) {
      setError("Due date cannot be in the past.");
      return;
    }
    if (activeTab === 1 && (!formData.questions || formData.questions.length === 0)) {
      setError("Please add at least one question to proceed.");
      return;
    }
    setError("");
    setActiveTab(prev => prev + 1);
  };

  const buildPayload = () => ({
    ...formData,
    owner_user_id: userSession.uid,
    dataset: db,
    total_marks: totalMarks,
    due_date: formData.due_date,
    created_on: new Date(),
    updated_on: new Date(),
  });

  const handleSave = async () => {
    if (formData.questions.length === 0) { alert("Add at least one question."); return; }
    try {
      const id = await createNewAssignment(buildPayload());
      setAssignmentId(id);
      alert("Draft saved!");
      onDone();
    } catch (err) { setError(err.message); }
  };

  const handlePublish = async () => {
    if (!formData.student_class) { setError("Please select a cohort."); return; }
    if (!window.confirm("Publish to students now?")) return;
    try {
      let id = assignmentId;
      if (!id) {
        id = await createNewAssignment(buildPayload());
        setAssignmentId(id);
      }
      const result = await publishAssignmentToStudents(id, formData.student_class, formData.due_date);
      if (result.success) { alert("Published!"); onDone(); }
      else setError("Failed to publish: " + result.message);
    } catch (err) { setError(err.message); }
  };

  if (!cohortsLoaded) {
    return (
      <div className="p-4 text-center">
        <div className="spinner-border text-primary"></div>
      </div>
    );
  }


  if (cohorts.length === 0) {
    return (
      <div style={{ 
        padding: '20px', 
        margin: '20px',
        border: '1px solid #f5c6cb', 
        borderRadius: '8px', 
        background: '#fff3f3', 
        color: '#721c24' 
      }}>
        <strong>No cohorts found.</strong> You need to create at least one cohort before creating an assignment.{" "}
        <span 
          onClick={() => navigate("/dashboard/cohorts")} 
          style={{ color: "#0056b3", cursor: "pointer", textDecoration: "underline", fontWeight: 'bold' }}
        >
          Create a cohort now
        </span>
      </div>
    );
  }

  return (
    <div className="container-fluid py-4 w-100">
    
      <div className="d-sm-flex align-items-center justify-content-between mb-4 px-3">
        <h1 className="h3 mb-0 text-gray-800 font-weight-bold">New Assignment</h1>
        <button className="btn btn-secondary shadow-sm" onClick={onDone}>
          <i className="fas fa-arrow-left mr-2"></i> Cancel
        </button>
      </div>

     
      <div className="row px-3 mb-4">
        {steps.map((step) => (
          <div key={step.id} className="col-md-4 mb-2">
            <div className={`p-2 text-center rounded shadow-sm border-bottom-lg ${activeTab === step.id ? 'bg-primary text-white' : 'bg-white text-gray-500'}`} 
                 style={{ borderBottom: activeTab === step.id ? '4px solid #2e59d9' : '4px solid #eaecf4', transition: '0.3s' }}>
              <i className={`fas ${step.icon} mr-2`}></i>
              <span className="small font-weight-bold text-uppercase">{step.title}</span>
            </div>
          </div>
        ))}
      </div>

      <div className="row px-3">
        <div className="col-12">
          <div className={`card shadow mb-4 ${activeTab === 0 ? 'border-left-primary' : activeTab === 1 ? 'border-left-info' : 'border-left-success'}`}>
            <div className="card-body p-4">
              
            
              {activeTab === 0 && (
                <div className="fade-in">
                  <CreateAssignment formData={formData} handleChange={handleChange} />
                </div>
              )}

        
              {activeTab === 1 && (
                <div className="fade-in">
                  <CreateQuestionSet
                    onAddQuestions={(qs) => setFormData(prev => ({ ...prev, questions: qs }))}
                    setDb={setDb}
                    existingQuestions={formData.questions}
                    existingDataset={db}
                    setTotalMarks={setTotalMarks}
                  />
                </div>
              )}

              
              {activeTab === 2 && (
                <div className="fade-in">
                  <div className="form-group mb-4">
                    <label className="h6 font-weight-bold text-gray-800">Assign to Student Cohort</label>
                    <select className="form-control form-control-lg border-left-primary" name="student_class" value={formData.student_class} onChange={handleChange}>
                      <option value="">-- Choose Cohort --</option>
                      {cohorts.map(c => <option key={c.cohort_id} value={c.cohort_id}>{c.name}</option>)}
                    </select>
                  </div>

                  <div className="bg-light p-4 rounded border mb-4">
                    <div className="custom-control custom-switch mb-3">
                      <input type="checkbox" className="custom-control-input" id="notifCheck" name="enable_submission_notification" checked={formData.enable_submission_notification} onChange={handleChange} />
                      <label className="custom-control-label font-weight-bold cursor-pointer" htmlFor="notifCheck">Notify me via email on submissions</label>
                    </div>
                    <div className="custom-control custom-switch">
                      <input type="checkbox" className="custom-control-input" id="remindCheck" name="reminder_interval" checked={formData.reminder_interval} onChange={handleChange} />
                      <label className="custom-control-label font-weight-bold cursor-pointer" htmlFor="remindCheck">Send reminders to students</label>
                    </div>
                  </div>

                  <div className="d-flex gap-2">
                    <button className="btn btn-outline-primary btn-lg px-4 mr-2" onClick={handleSave} disabled={!formData.student_class}>
                      <i className="fas fa-save mr-2"></i> Save as Draft
                    </button>
                    <button className="btn btn-success btn-lg px-5 shadow" onClick={handlePublish} disabled={!formData.student_class}>
                      <i className="fas fa-paper-plane mr-2"></i> Create & Publish
                    </button>
                  </div>
                </div>
              )}

            </div>

            
            <div className="card-footer bg-white d-flex justify-content-between align-items-center py-3">
              {activeTab > 0 ? (
                <button className="btn btn-light border px-4" onClick={() => setActiveTab(prev => prev - 1)}>
                  <i className="fas fa-chevron-left mr-2"></i> Previous
                </button>
              ) : <div></div>}
              
              <div className="d-flex align-items-center">
                {error && <span className="text-danger small mr-3 font-weight-bold"><i className="fas fa-exclamation-circle mr-1"></i> {error}</span>}
                {activeTab < 2 && (
                  <button className="btn btn-primary px-5 shadow" onClick={handleNext}>
                    Next Step <i className="fas fa-chevron-right ml-2"></i>
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AssignmentForm;