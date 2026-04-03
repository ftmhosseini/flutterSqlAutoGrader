import React, { useState } from "react";

function HintPopup() {
  const [open, setOpen] = useState(false);

  return (
    <span className="hint-wrapper">
      <span className="hint-circle" onClick={() => setOpen(!open)}>
        ?
      </span>
      {open && (
        <div className="hint-popup">
          <h3>Database Manager Guide</h3>
          <p>
            <b>Purpose:</b> Manage datasets and tables visually without writing
            complex SQL.
          </p>
          <ul>
            <li>
              <b>Select Dataset</b> - Choose an existing dataset from the
              dropdown to see its tables.
            </li>
            <li>
              <b>Create Dataset</b> - Enter a name and click `Create Dataset`
              to add a new dataset.
            </li>
            <li>
              <b>Select Table</b> - Choose a table from the selected dataset to
              view or edit its schema and data.
            </li>
            <li>
              <b>Create Table</b> - Enter a table name, add columns, define
              types, keys, and nullability, then click `Create Table`.
            </li>
            <li>
              <b>Add Columns</b> - Click `Add Column` to add a new column to
              your table.
            </li>
            <li>
              <b>Choose Data Type</b> - Select the correct data type such as
              `VARCHAR`, `INT`, or `DATE`.
            </li>
            <li>
              <b>Set Nullability</b> - Decide if the column can be `NULL` or
              `NOT NULL`.
            </li>
            <li>
              <b>Define Keys</b> - Choose `Primary Key` for unique identifiers
              or `Foreign Key` to reference another table.
            </li>
            <li>
              <b>Reference Table</b> - If a foreign key is selected, choose the
              referenced table.
            </li>
            <li>
              <b>View Schema</b> - After creation, review the current schema of
              your table.
            </li>
            <li>
              <b>Insert Data</b> - Click `Insert Data` to add rows via SQL
              `INSERT` statements.
            </li>
            <li>
              <b>Fetch Data</b> - Click `Fetch Data` to view existing rows in
              the table.
            </li>
          </ul>
        </div>
      )}
    </span>
  );
}

export default HintPopup;
