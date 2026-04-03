import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { createNewQuiz, getAllQuizByOwner } from "../../../../components/model/quizzes";
import { getCohortsByOwner, getAllStudents } from "../../../../components/model/cohorts";
import { getPresetQuestions } from "../../../../components/model/presetQuestions";
import { useAppContext } from "../../../../components/db/service/context";
import { sendQuizEmail } from "../../../../components/services/email";
import TableSchema from "../../tableView/TableSchema";
import { CodeEditor } from '../assignmentform/createquestionset/CodeEditor';
import userSession from "../../../../components/services/UserSession";
import "./QuizManager.css";

const QuizForm = ({ onDone }) => {
  const navigate = useNavigate();
  const { allDataset, allTables, getTableSchemaInTable, runSelectQuery } = useAppContext();

  const [datasets, setDatasets] = useState([]);
  const [availableTables, setAvailableTables] = useState([]);
  const [tableSchemas, setTableSchemas] = useState({});
  const [selectedTableForSchema, setSelectedTableForSchema] = useState("");
  const [selectedTables, setSelectedTables] = useState([]);
  const [presets, setPresets] = useState([]);
  const [cohorts, setCohorts] = useState([]);
  const [error, setError] = useState("");

  const [formData, setFormData] = useState({
    title: '',
    dataset: '',
    selectedPreset: null,
    questionText: '',
    answer: '',
    difficulty: 'easy',
    max_attempts: 1,
    mark: 1,
    orderMatters: false,
    aliasStrict: false,
    student_class: '',
    due_date: '',
  });

  useEffect(() => {
    allDataset().then((data) => setDatasets(data.map((d) => d.datasetName)));
    getCohortsByOwner(userSession.uid).then(setCohorts);
    getAllQuizByOwner(userSession.uid).then(quizzes => {
      const today = new Date();
      const todayStr = today.toLocaleDateString("en-US", { month: "long", day: "numeric" });
      const todayCount = quizzes.filter(q => {
        const d = new Date(q.created_on?.seconds ? q.created_on.seconds * 1000 : q.created_on);
        return d.toLocaleDateString("en-US", { month: "long", day: "numeric" }) === todayStr;
      }).length;
      setFormData(prev => ({ ...prev, title: `${todayStr}-${todayCount + 1}` }));
    });
  }, [allDataset]);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({ ...prev, [name]: type === 'checkbox' ? checked : value }));
  };

  const handleDatasetChange = (e) => {
    const dataset = e.target.value;
    setFormData(prev => ({ ...prev, dataset, selectedPreset: null }));
    setSelectedTables([]);
    setSelectedTableForSchema("");
    setAvailableTables([]);
    setTableSchemas({});
    setPresets([]);
    if (!dataset) return;
    allTables(dataset).then((tables) => {
      const names = tables.map((t) => t.tableName);
      setAvailableTables(names);
      names.forEach((table) =>
        getTableSchemaInTable(dataset, table).then((schema) =>
          setTableSchemas((prev) => ({ ...prev, [table]: schema }))
        )
      );
    });
    getPresetQuestions(dataset).then(setPresets);
  };

  const toggleTable = (table, checked) => {
    setSelectedTables(prev => checked ? [...prev, table] : prev.filter(t => t !== table));
  };

  const filteredPresets = selectedTables.length > 0
    ? presets.filter(p => selectedTables.every(t => p.answer?.toLowerCase().includes(t.toLowerCase())))
    : presets;

  const handlePresetChange = (e) => {
    const preset = e.target.value ? JSON.parse(e.target.value) : null;
    setFormData(prev => ({
      ...prev,
      selectedPreset: preset,
      questionText: preset?.question || '',
      answer: preset?.answer || '',
      difficulty: preset?.difficulty || 'easy',
      max_attempts: preset?.max_attempts || 1,
      mark: preset?.mark || 1,
      orderMatters: preset?.orderMatters || false,
      aliasStrict: preset?.aliasStrict || false,
    }));
  };

  const handleSubmit = async () => {
    setError("");
    if (!formData.title.trim()) return setError("Title is required.");
    if (!formData.questionText.trim()) return setError("Question text is required.");
    if (!formData.answer.trim()) return setError("Answer is required.");
    if (!formData.student_class) return setError("Please select a cohort.");

    try {
      const validation = await runSelectQuery(formData.dataset, formData.answer);
      if (!validation?.isSuccessful) return setError(`Invalid SQL: ${validation?.message || "query failed"}`);
      
      const id = await createNewQuiz({
        ...formData,
        owner_user_id: userSession.uid,
        tables: availableTables.filter((t) => formData.answer.toLowerCase().includes(t.toLowerCase())),
        created_on: new Date(),
      });
      
      const cohort = cohorts.find((c) => c.cohort_id === formData.student_class);
      if (cohort?.student_uids?.length) {
        const allStudentsList = await getAllStudents();
        const cohortStudents = allStudentsList.filter((s) => cohort.student_uids.includes(s.uid));
        await Promise.all(cohortStudents.map((s) => sendQuizEmail(s, formData.title, id)));
      }
      onDone();
    } catch (err) {
      setError("Error: " + err.message);
    }
  };

  return (
    <div className="container-fluid py-4 w-100">
    
      <div className="d-sm-flex align-items-center justify-content-between mb-4">
        <h1 className="h3 mb-0 text-gray-800 font-weight-bold">Create New Quiz</h1>
        {onDone && (
          <button className="btn btn-secondary btn-icon-split shadow-sm" onClick={onDone}>
            <span className="icon text-white-50"><i className="fas fa-arrow-left"></i></span>
            <span className="text">Back to Quizzes</span>
          </button>
        )}
      </div>

      <div className="row">
       
        <div className="col-xl-4 col-lg-5">
          <div className="card shadow mb-4 border-left-primary">
            <div className="card-header py-3"><h6 className="m-0 font-weight-bold text-primary">Settings</h6></div>
            <div className="card-body">
              <div className="form-group">
                <label className="small font-weight-bold text-gray-600">QUIZ TITLE</label>
                <input name="title" value={formData.title} onChange={handleChange} className="form-control" />
              </div>

              <div className="form-group">
                <label className="small font-weight-bold text-gray-600">DATASET</label>
                <select name="dataset" value={formData.dataset} onChange={handleDatasetChange} className="form-control">
                  <option value="">-- Select Dataset --</option>
                  {datasets.map(ds => <option key={ds} value={ds}>{ds}</option>)}
                </select>
              </div>

              {formData.dataset && (
                <div className="form-group">
                  <label className="small font-weight-bold text-gray-600">ASSIGN TO COHORT</label>
                  {cohorts.length === 0 ? (
                    <div className="alert alert-warning small p-2">
                      No cohorts found. <span onClick={() => navigate('/dashboard/cohorts')} className="text-primary cursor-pointer font-weight-bold">Create one</span>
                    </div>
                  ) : (
                    <select name="student_class" value={formData.student_class} onChange={handleChange} className="form-control">
                      <option value="">-- Select Cohort --</option>
                      {cohorts.map(c => <option key={c.cohort_id} value={c.cohort_id}>{c.name}</option>)}
                    </select>
                  )}
                </div>
              )}
           </div>
          </div>

          {formData.dataset && (
            <div className="card shadow mb-4">
              <div className="card-header py-3"><h6 className="m-0 font-weight-bold text-gray-800">Database Tools</h6></div>
              <div className="card-body">
                <label className="small font-weight-bold text-gray-600">VIEW SCHEMA</label>
                <select value={selectedTableForSchema} onChange={e => setSelectedTableForSchema(e.target.value)} className="form-control mb-3">
                  <option value="">-- Select Table --</option>
                  {availableTables.map(t => <option key={t} value={t}>{t}</option>)}
                </select>
                {selectedTableForSchema && <div className="border rounded p-2 bg-white"><TableSchema info={tableSchemas[selectedTableForSchema]} /></div>}
                
                <hr />
              </div>
            </div>
          )}
        </div>

       
        <div className="col-xl-8 col-lg-7">
          {formData.dataset ? (
            <>
              <div className="card shadow mb-4 border-left-success">
                <div className="card-header py-3 bg-white d-flex justify-content-between align-items-center">
                  <h6 className="m-0 font-weight-bold text-success">Question Designer</h6>
                  <label className="small font-weight-bold text-gray-600">FILTER BY TABLES</label>
                <div className="d-flex flex-wrap gap-2 mt-1">
                  {availableTables.map(table => (
                    <div key={table} className="custom-control custom-checkbox mr-3 mb-2">
                      <input type="checkbox" className="custom-control-input" id={`chk-${table}`} checked={selectedTables.includes(table)} onChange={e => toggleTable(table, e.target.checked)} />
                      <label className="custom-control-label small cursor-pointer" htmlFor={`chk-${table}`}>{table}</label>
                    </div>
                  ))}
                </div>
                  
                </div>
                <div className="card-body">
                  <div className="form-group">
                    <select onChange={handlePresetChange} className="form-control form-control-sm border-success">
                      <option value="">-- Use a Preset Question --</option>
                      {filteredPresets.map(p => <option key={p.id} value={JSON.stringify(p)}>{p.question}</option>)}
                    </select>
                  </div>
                  <div className="form-group">
                    <label className="small font-weight-bold text-gray-600">QUESTION PROMPT</label>
                    <textarea name="questionText" value={formData.questionText} onChange={handleChange} className="form-control" rows="3" placeholder="Explain what the student needs to find..." />
                  </div>

                  <div className="form-group">
                    <label className="small font-weight-bold text-gray-600">EXPECTED SQL QUERY</label>
                    <textarea name="answer" value={formData.answer} onChange={handleChange} className="form-control font-italic text-primary bg-light" rows="4" placeholder="SELECT * FROM..." />
                  </div>

                  <div className="row">
                    <div className="col-md-4">
                      <label className="small font-weight-bold text-gray-600">DIFFICULTY</label>
                      <select name="difficulty" value={formData.difficulty} onChange={handleChange} className="form-control text-capitalize">
                        <option value="easy">Easy</option>
                        <option value="medium">Medium</option>
                        <option value="hard">Hard</option>
                      </select>
                    </div>
                    <div className="col-md-4">
                      <label className="small font-weight-bold text-gray-600">MAX ATTEMPTS</label>
                      <input type="number" name="max_attempts" value={formData.max_attempts} onChange={handleChange} className="form-control" />
                    </div>
                    <div className="col-md-4">
                      <label className="small font-weight-bold text-gray-600">POINTS (MARK)</label>
                      <input type="number" name="mark" value={formData.mark} onChange={handleChange} className="form-control" />
                    </div>
                  </div>

                  <div className="mt-4 p-3 bg-light rounded border">
                    <div className="custom-control custom-switch mb-2">
                      <input type="checkbox" className="custom-control-input" id="orderMatters" name="orderMatters" checked={formData.orderMatters} onChange={handleChange} />
                      <label className="custom-control-label small font-weight-bold" htmlFor="orderMatters">Result Order Matters</label>
                    </div>
                    <div className="custom-control custom-switch">
                      <input type="checkbox" className="custom-control-input" id="aliasStrict" name="aliasStrict" checked={formData.aliasStrict} onChange={handleChange} />
                      <label className="custom-control-label small font-weight-bold" htmlFor="aliasStrict">Enforce Strict Aliasing</label>
                    </div>
                  </div>
                </div>
              </div>

          
              <div className="card shadow mb-4">
                <div className="card-header py-3 border-bottom-0"><h6 className="m-0 font-weight-bold text-gray-800">Sandbox / Code Editor</h6></div>
                <div className="p-0"><CodeEditor selectedDataset={formData.dataset} /></div>
              </div>

              {error && <div className="alert alert-danger shadow-sm border-left-danger">{error}</div>}

              <button type="button" onClick={handleSubmit} className="btn btn-success btn-block btn-lg shadow-sm mb-5">
                <i className="fas fa-paper-plane mr-2"></i> Create and Distribute Quiz
              </button>
            </>
          ) : (
            <div className="card shadow mb-4 py-5 text-center">
              <i className="fas fa-database fa-3x text-gray-300 mb-3"></i>
              <h5 className="text-gray-500">Please select a dataset to start building the quiz</h5>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default QuizForm;