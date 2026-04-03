export const CreateAssignment = ({ formData, handleChange }) => {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
      <div>
        <label>Title</label><br />
        <input
          id="title" name="title" placeholder="Assignment title"
          value={formData.title} onChange={handleChange}
          style={{ width: '100%', padding: '8px', boxSizing: 'border-box' }}
        />
      </div>
      <div>
        <label>Description</label><br />
        <textarea
          id="description" name="description" placeholder="Describe the assignment..."
          value={formData.description} onChange={handleChange}
          rows={4}
          style={{ width: '100%', padding: '8px', boxSizing: 'border-box', resize: 'vertical' }}
        />
      </div>
      <div>
        <label>Due Date</label><br />
        <input
          id="due_date" type="date" name="due_date"
          value={formData.due_date} onChange={handleChange}
          min={new Date().toISOString().split("T")[0]}
          style={{ padding: '8px' , width: '100%'}}
        />
      </div>
    </div>
  );
};
