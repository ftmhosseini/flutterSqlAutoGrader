function ResultTable({ title, result }) {
  const tableResult = result?.[0];

  return (
    <div className="result-table">
      <h6>{title}</h6>
      {!tableResult?.lc ? (
        <span className="empty-state">~ no response on stdout ~</span>
      ) : (
        <div className="table-placeholder">
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr>
                {tableResult.lc.map((col) => (
                  <th
                    key={col}
                    style={{
                      padding: "10px",
                      border: "1px solid #ddd",
                      whiteSpace: "nowrap",
                    }}
                  >
                    {col}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {tableResult.values?.map((row, i) => (
                <tr key={i}>
                  {row.map((val, j) => (
                    <td
                      key={j}
                      style={{
                        border: "1px solid #ddd",
                        padding: "8px",
                      }}
                    >
                      {val}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export default ResultTable;
