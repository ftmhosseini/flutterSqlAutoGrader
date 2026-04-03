import "./CollapsiblePanel.css";

function CollapsiblePanel({ title, preview, children, isCollapsed, onToggle }) {

  return (
    <div className="panel-container">
      <div 
        className="panel-header"
        onClick={onToggle}
      >
        <strong>{title}</strong>

        <span 
          className="panel-arrow"
          style={{ transform: isCollapsed  ? "rotate(0deg)" : "rotate(90deg)" }}
        >
          ▶
        </span>
      </div>

      {isCollapsed  && (
        <div className="panel-preview">
          {preview}
        </div>
      )}

      {!isCollapsed  && (
        <div className="panel-body">
          {children}
        </div>
      )}
    </div>
  );
}

export default CollapsiblePanel;
