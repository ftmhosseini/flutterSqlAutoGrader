import "./tableSchema.css"
const TableSchema = (({info}) => {
    if (!info || !Array.isArray(info)) return null;
    return (
    <table className="table-schema" style={{ marginTop: "6px", borderCollapse: "collapse", fontSize: "13px" }}>
        <thead>
            <tr style={{ backgroundColor: "#f0f0f0" }}>
                <th className="thStyle">Column</th>
                <th className="thStyle">Type</th>
                <th className="thStyle">Constraints</th>
            </tr>
        </thead>
        <tbody>
            {info.map((col) => (
                <tr key={col.name}>
                    <td className="thStyle">{col.name}</td>
                    <td className="thStyle">{col.type}</td>
                    <td className="thStyle">
                        {[col.primaryKey && "Primary Key", col.foreignKey && "Foreign Key", col.notNull && "Not Null"]
                            .filter(Boolean).join(", ")}
                    </td>
                </tr>
            ))}
        </tbody>
    </table>
    );
})
export default TableSchema;