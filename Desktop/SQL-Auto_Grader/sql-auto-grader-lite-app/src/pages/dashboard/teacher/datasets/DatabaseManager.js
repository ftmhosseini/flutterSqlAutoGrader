import { useEffect, useState, useCallback } from "react";
import { useAppContext } from "../../../../components/db/service/context";
import HintPopup from "./HintPopup";
import "./DatabaseManager.css";

function DatabaseManager() {
  const {
    allDataset,
    allTables,
    addDataset,
    addTable,
    getTable,
    createTable,
    fetchItems,
    insertData,
    runSelectQuery,
  } = useAppContext();
  const [datasets, setDatasets] = useState([]);
  const [tables, setTables] = useState([]);
  const [datasetStore, setDatasetStore] = useState([]);
  const [selectedDataset, setSelectedDataset] = useState("");
  const [selectedTable, setSelectedTable] = useState("");
  const [columns, setColumns] = useState([]);
  const [tableSchema, setTableSchema] = useState(null);
  const [tableNotExists, setTableNotExists] = useState(false);
  const [newDatasetName, setNewDatasetName] = useState("");
  const [newTableName, setNewTableName] = useState("");
  const [datas, setDatas] = useState([]);
  const [showInsertForm, setShowInsertForm] = useState(false);
  const [insertSQL, setInsertSQL] = useState("");
  const [insertResult, setInsertResult] = useState(null);
  const [datasetError, setDatasetError] = useState("");
  const [tableError, setTableError] = useState("");

  const loadDatasets = useCallback(async () => {
    const data = await allDataset();
    const dataset = data.map((d, i) => ({
      id: i,
      content: d.datasetName,
    }));
    setDatasets(dataset);
  }, [allDataset]);

  useEffect(() => {
    loadDatasets();
  }, [loadDatasets]);

  const loadTables = async (datasetName) => {
    const data = await allTables(datasetName);
    const tabless = data.map((d, i) => ({
      id: i,
      content: d.tableName,
    }));
    setTables(tabless);
  };

  const loadSelectedTables = async (dbname, tablename) => {
    const schema = await getTable(dbname, tablename);
    setNewTableName("")
    setNewDatasetName("")
    if (schema.exists) {
      setTableSchema(schema.schema);
      setTableNotExists(false);
    } else {
      setTableSchema(null);
      setTableNotExists(true);
    }
    setColumns([]);
    setDatas([]);
    setInsertResult(null);
  };

  const insertDataset = async () => {
    setDatasetError("");
    setTableError("");
    setInsertResult(null);
    setNewTableName("")
    if (!newDatasetName.trim()) { setDatasetError("Dataset name is required."); return; }
    const result = await runSelectQuery('db', `INSERT INTO Datasets (datasetName) VALUES ('${newDatasetName}')`);
    if (result.isSuccessful) {
      await addDataset(newDatasetName);
      await loadDatasets();
      setSelectedDataset(newDatasetName);
      setSelectedTable("");
      await loadTables(newDatasetName);
      setNewDatasetName("");
    } else {
      setDatasetError(result.message?.includes("UNIQUE") ? "Dataset name already exists." : result.message);
    }
  };

  const insertTable = async () => {
    setTableError("");
    setInsertResult(null);
    if (!newTableName.trim()) { setTableError("Table name is required."); return; }
    if (!selectedDataset) { setTableError("Select a dataset first."); return; }
    const result = await runSelectQuery('db', `INSERT INTO Tables (tableName, datasetName) VALUES ('${newTableName}', '${selectedDataset}')`);
    if (result.isSuccessful) {
      await addTable(newTableName, selectedDataset);
      await loadTables(selectedDataset);
      setSelectedTable(newTableName);
      await loadSelectedTables(selectedDataset, newTableName);
      setNewTableName("");
      loadTables(selectedDataset);
    } else {
      setTableError(result.message?.includes("UNIQUE") ? "Table name already exists in this dataset." : result.message);
    }
  };
  const handleInsertSubmit = async () => {
    const trimmed = insertSQL.trim().toUpperCase();
    if (!trimmed.startsWith("INSERT INTO")) {
      setInsertResult({
        success: false,
        message: "Invalid SQL: must start with INSERT INTO",
      });
      return;
    }
    try {
      const result = await runSelectQuery(selectedDataset, insertSQL);
      if (result.isSuccessful) {
        await insertData(selectedDataset, insertSQL);
        setInsertResult({
          success: true,
          message: "Row inserted successfully!",
        });
      } else {
        setInsertResult({
          success: false,
          message: `Error: ${result.message}`,
        });
      }
      setInsertSQL("");
    } catch (e) {
      setInsertResult({ success: false, message: `Error: ${e.message}` });
    }
  };
  const fetchData = async () => {
    const result = await fetchItems(
      selectedDataset,
      `SELECT * FROM ${selectedTable}`,
    );
    setDatas(result.data);
  };

  const addColumn = () => {
    setColumns([
      ...columns,
      { name: "", type: "VARCHAR", nullable: false, key: "none", refTable: "" },
    ]);
  };

  const updateColumn = (index, field, value) => {
    const updated = [...columns];
    updated[index][field] = value;
    setColumns(updated);
  };

  const removeColumn = (index) => {
    setColumns(columns.filter((_, i) => i !== index));
  };

  const createNewTable = async () => {
    if (!selectedTable || columns.length === 0) {
      alert("Please enter table name and add columns");
      return;
    }
    createTable(selectedDataset, selectedTable, columns);
    await loadSelectedTables(selectedDataset, selectedTable);
    setDatasetStore({
      ...datasetStore,
      [selectedDataset]: {
        ...datasetStore[selectedDataset],
        tables: [
          ...(datasetStore[selectedDataset]?.tables || []),
          { name: selectedTable, columns: [...columns] },
        ],
      },
    });

    console.log("Table created:", {
      dataset: selectedDataset,
      table: selectedTable,
      columns,
    });
    alert(`Table "${selectedTable}" created successfully!`);
    loadSelectedTables(selectedDataset, selectedTable);
  };

  return (
    <div className="dataset-manager">
      <div className="dataset-hero">
        <div>
          <p className="dataset-kicker">Teacher Workspace</p>
          <h1>Dataset Manager</h1>
          <p className="dataset-subtitle">
            create datasets, organize tables, define schemas, and inspect live
            data from one workspace.
          </p>
        </div>
        <HintPopup />
      </div>

      <div className="dataset-grid dataset-grid-one">
        {/* <section className="dataset-card">
          <div className="card-heading">
            <h2>Dataset</h2>
            <span className="card-meta">{datasets.length} available</span>
          </div>
          <select
            value={selectedDataset}
            className="dataset-select"
            onChange={(e) => {
              const id = e.target.value;
              setSelectedDataset(id);
              setSelectedTable("");
              if (id) {
                loadTables(id);
              } else {
                setTables([]);
              }
            }}
          >
            <option value="">Select Dataset</option>
            {datasets.map((ds) => (
              <option key={ds.id} value={ds.content}>
                {ds.content}
              </option>
            ))}
          </select>
        </section> */}
        <section className="dataset-card">
          <div className="card-heading">
            <h2>Datasets in Database</h2>
          </div>
          <div className="table-shell">
            <table className="dataset-table">
              <thead>
                <tr>
                  <th>Name</th>
                </tr>
              </thead>
              <tbody>
                {datasets.map((ds) => (
                  <tr key={ds.id} className={`clickable${selectedDataset === ds.content ? " active" : ""}`} onClick={() => {
                    setSelectedDataset(ds.content);
                    setSelectedTable("");
                    loadTables(ds.content);
                    setDatasetError("");
                    setNewTableName("");
                    setNewDatasetName("")
                    setTableError("");
                    setInsertResult(null);
                  }}>
                    <td>{ds.content}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="insert-message error" style={{ minHeight: "18px", width: '70%' }}>{datasetError}</p>
          <div className="inlineForm">
            <input
              value={newDatasetName}
              onChange={(e) =>
                setNewDatasetName(e.target.value.trim().replace(/\s+/g, ""))
              }
              placeholder="New dataset name"
            />
            <button className="dataset-btn" onClick={insertDataset}>
              Create Dataset
            </button>
          </div>
        </section>
      </div>

      {selectedDataset && (
        <div className="dataset-grid dataset-grid-one">
          {/* <section className="dataset-card">
            <div className="card-heading">
              <h2>Tables in {selectedDataset}</h2>
              <span className="card-meta">{tables.length} found</span>
            </div>
            <select
              value={selectedTable}
              onChange={(e) => {
                const tableId = e.target.value;
                const table = tables.find((t) => t.content === tableId);
                const tableName = table?.content || "";
                setSelectedTable(tableName);
                if (tableName) {
                  loadSelectedTables(selectedDataset, tableName);
                }
              }}
            >
              <option value="">Select Table</option>
              {tables.map((t) => (
                <option key={t.id} value={t.content}>
                  {t.content}
                </option>
              ))}
            </select>
            
          </section> */}
          <section className="dataset-card">
            <div className="card-heading">
              <h2>Tables in {selectedDataset}</h2>
            </div>
            <div className="table-shell">
              <table className="dataset-table">
                <thead>
                  <tr>
                    <th>Name</th>
                  </tr>
                </thead>
                <tbody>
                  {tables.map((t) => (
                    <tr key={t.id} className={`clickable${selectedTable === t.content ? " active" : ""}`} onClick={() => {
                      setSelectedTable(t.content);
                      loadSelectedTables(selectedDataset, t.content);
                      setDatasetError("");
                      setTableError("");
                      setInsertResult(null);
                      setNewTableName("");
                      setNewDatasetName("")
                    }}>
                      <td>{t.content}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="insert-message error" style={{ minHeight: "18px", width: '70%' }}>{tableError}</p>
            <div className="inlineForm">
              <input
                value={newTableName}
                onChange={(e) =>
                  setNewTableName(e.target.value.trim().replace(/\s+/g, ""))
                }
                placeholder="New table name"
              />
              <button className="dataset-btn" onClick={insertTable}>
                Create New Table
              </button>
            </div>

          </section>
        </div>
      )}

      {selectedTable && (
        <section className="dataset-card">
          <div className="card-heading">
            <h2>Define Schema for {selectedTable}</h2>
          </div>
          {tableNotExists && (
            <>
              <div className="table-shell">
                <table className="dataset-table dataset-schema-table">
                  <thead>
                    <tr>
                      <th>Property Name</th>
                      <th>Type</th>
                      <th>Nullable</th>
                      <th>Key Type</th>
                      <th>Reference Table</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {columns.map((col, i) => (
                      <tr key={i}>
                        <td>
                          <input
                            className="tableInput"
                            value={col.name}
                            onChange={(e) =>
                              updateColumn(
                                i,
                                "name",
                                e.target.value.trim().replace(/\s+/g, ""),
                              )
                            }
                            placeholder="column_name"
                          />
                        </td>
                        <td>
                          <select
                            className="tableInput"
                            value={col.type}
                            onChange={(e) =>
                              updateColumn(i, "type", e.target.value)
                            }
                          >
                            <option>VARCHAR</option>
                            <option>INT</option>
                            <option>BIGINT</option>
                            <option>TEXT</option>
                            <option>DATE</option>
                            <option>TIMESTAMP</option>
                            <option>BOOLEAN</option>
                            <option>DECIMAL</option>
                          </select>
                        </td>
                        <td>
                          <select
                            className="tableInput"
                            value={col.nullable}
                            onChange={(e) =>
                              updateColumn(
                                i,
                                "nullable",
                                e.target.value === "true",
                              )
                            }
                          >
                            <option value="false">NOT NULL</option>
                            <option value="true">NULL</option>
                          </select>
                        </td>
                        <td>
                          <select
                            className="tableInput"
                            value={col.key}
                            onChange={(e) =>
                              updateColumn(i, "key", e.target.value)
                            }
                          >
                            <option value="none">None</option>
                            <option value="primary">Primary Key</option>
                            <option value="foreign">Foreign Key</option>
                          </select>
                        </td>
                        <td>
                          {col.key === "foreign" && (
                            <select
                              className="tableInput"
                              value={col.refTable}
                              onChange={(e) =>
                                updateColumn(i, "refTable", e.target.value)
                              }
                            >
                              <option value="">Select table</option>
                              {tables
                                .filter((t) => t.content !== selectedTable)
                                .map((t) => (
                                  <option key={t.id} value={t.content}>
                                    {t.content}
                                  </option>
                                ))}
                            </select>
                          )}
                        </td>
                        <td>
                          <button onClick={() => removeColumn(i)}>
                            Remove
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="schema-actions">
                <button className="dataset-btn" onClick={addColumn}>
                  Add Column
                </button>
                <button
                  className="dataset-btn createBtn"
                  onClick={createNewTable}
                >
                  Create Table
                </button>
              </div>
            </>
          )}
          <div className="schema-preview">
            <strong>Current Store:</strong>
            <pre className="schema-pre">{tableSchema}</pre>
          </div>
        </section>
      )}
      {tableSchema && selectedTable && (
        <section className="dataset-card">
          <h2>DATA INTO {selectedTable}</h2>
          <div className="data-actions">
            <button
              className="dataset-btn"
              onClick={() => {
                setShowInsertForm(false);
                fetchData();
              }}
            >
              Fetch Data
            </button>
            <button
              className="dataset-btn"
              onClick={() => {
                setDatas([]);
                setShowInsertForm(!showInsertForm);
              }}
            >
              Insert Data
            </button>
          </div>
          {datas.length > 0 && (
            <div className="table-shell">
              <table className="dataset-table data-table">
                <thead>
                  <tr>
                    {Object.keys(datas[0]).map((key) => (
                      <th key={key}>{key}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {datas.map((ds, i) => {
                    return (
                      <tr key={ds.id || i}>
                        {Object.values(ds).map((val, index) => (
                          <td key={index}>{val !== null ? String(val) : ""}</td>
                        ))}
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
          {showInsertForm && (
            <div className="inlineForm data-insert-form">
              <input
                type="text"
                value={insertSQL}
                onChange={(e) => setInsertSQL(e.target.value)}
                placeholder={`INSERT INTO ${selectedTable} (...) VALUES (...)`}
                className="insert-input"
              />
              <button className="dataset-btn" onClick={handleInsertSubmit}>
                Submit
              </button>
              {insertResult && (
                <p
                  className={
                    insertResult.success
                      ? "insert-message success"
                      : "insert-message error"
                  }
                >
                  {insertResult.message}
                </p>
              )}
            </div>
          )}
        </section>
      )}
    </div>
  );
}

export default DatabaseManager;
