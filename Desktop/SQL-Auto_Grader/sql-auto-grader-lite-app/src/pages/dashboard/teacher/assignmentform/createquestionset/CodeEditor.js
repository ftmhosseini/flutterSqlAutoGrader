import { useState } from 'react'
import { useAppContext } from "../../../../../components/db/service/context";

export const CodeEditor = ({ selectedDataset }) => {
    const { runSelectQuery } = useAppContext();
    const [studentQuery, setStudentQuery] = useState("");
    const [queryResult, setQueryResult] = useState("");

    const executeQuery = async (query) => {
        const result = await runSelectQuery(selectedDataset, query);
        if (result.isSuccessful) {
            const values = result.data[0]?.values ?? [];
            setQueryResult(values.map((row) => row.join(" | ")).join("\n"));
        } else {
            setQueryResult(result.message);
        }
    };

    return (
        <div className="card shadow mb-4">
            <div className="card-header py-3">
                <h6 className="m-0 font-weight-bold text-primary">SQL Sandbox</h6>
            </div>
            <div className="card-body">
                <textarea
                    className="form-control mb-2"
                    placeholder="Write SQL here..."
                    value={studentQuery}
                    style={{ height: "150px", fontFamily: 'monospace' }}
                    onChange={(e) => setStudentQuery(e.target.value)}
                />
                <button 
                    className="btn btn-primary btn-block shadow-sm" 
                    onClick={() => executeQuery(studentQuery)}
                >
                    Run Query
                </button>
                <textarea
                    className="form-control mt-3 bg-light"
                    value={queryResult}
                    readOnly
                    placeholder="Results..."
                    style={{ height: "120px", fontFamily: 'monospace', fontSize: '12px' }}
                />
            </div>
        </div>
    )
};