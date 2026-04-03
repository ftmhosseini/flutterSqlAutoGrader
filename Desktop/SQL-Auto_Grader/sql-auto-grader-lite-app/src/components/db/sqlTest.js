
import { useState } from "react";
import { useDatabase } from '../hooks/useDatabase';
import { isSelectQuery } from './queryValidation';
import { useAppContext } from "./service/context";

const SQLtest = () => {
  const { runSelectQuery } = useAppContext()

  const { databases, loading, error } = useDatabase();
  const [selectedDb, setSelectedDb] = useState("datasetA");
  const [selectedTable, setSelectedTable] = useState("");
  const [query, setQuery] = useState("SELECT * FROM Employees LIMIT 5;");
  const [results, setResults] = useState(null);
  const [queryError, setQueryError] = useState("");

  const getTables = (dbKey) => {
    const db = databases[dbKey];
    if (!db) return [];
    const res = db.exec("SELECT name FROM sqlite_master WHERE type='table'");
    return res[0]?.values.map(r => r[0]) || [];
  };

  const handleDbChange = (dbKey) => {
    setSelectedDb(dbKey);
    setSelectedTable("");
    setResults(null);
    setQueryError("");
  };

  const handleTableChange = (table) => {
    setSelectedTable(table);
    setQuery(`SELECT * FROM ${table} LIMIT 5;`);
    setResults(null);
  };

  const handleRun = async () => {
    setQueryError("");
    setResults(null);
    if (!isSelectQuery(query)) {
      setQueryError("Only SELECT queries are allowed.");
      return;
    }

    if (!databases[selectedDb]) { setQueryError("Database not loaded."); return; }
    const res = await runSelectQuery(selectedDb, query);
    console.log(res);
    if(res.isSuccessful)
      setResults(res.data);
    console.log(res.message);
    
  };
  return (
    <div className="card shadow mb-4">
      <div className="card-header font-weight-bold">SQL Tester</div>
      <div className="card-body">
        {loading && <p>Loading databases...</p>}
        {error && <p style={{ color: 'red' }}>Error loading databases.</p>}
        {!loading && !error && (
          <>
            <div style={{ display: 'flex', gap: '10px', marginBottom: '10px' }}>
              <select value={selectedDb} onChange={e => handleDbChange(e.target.value)}>
                {Object.keys(databases).filter(k => k !== 'db').map(k => (
                  <option key={k} value={k}>{k}</option>
                ))}
              </select>
              <select value={selectedTable} onChange={e => handleTableChange(e.target.value)}>
                <option value="">-- select table --</option>
                {getTables(selectedDb).map(t => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </select>
              <textarea
                value={query}
                onChange={e => setQuery(e.target.value)}
                rows={2}
                style={{ flex: 1, fontFamily: 'monospace' }}
              />
              <button className="btn btn-primary" onClick={handleRun}>Run</button>
            </div>
            {queryError && <p style={{ color: 'red' }}>{queryError}</p>}
            {results && results.length > 0 && (
              <div style={{ overflowX: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr>
                      {results[0]?.lc?.map((col) => (
                        <th key={col} style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>
                          {col}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {results[0].values.map((row, i) => (
                      <tr key={i}>{row.map((val, j) => (
                        <td key={j} style={{ border: '1px solid #ddd', padding: '8px' }}>{val}</td>
                      ))}</tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            {results && results.length === 0 && <p>No results.</p>}
          </>
        )}
      </div>
    </div>
  )
}

export default SQLtest