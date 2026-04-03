import { Link } from "react-router-dom";

const Breadcrumb = ({ items }) => {
  return (
    <nav aria-label="breadcrumb">
      <ol className="breadcrumb">
        {items.map((item, index) => {
          const isActive = item.active || index === items.length - 1;
          const target = item.link || item.path;

          return (
            <li
              key={index}
              className={`breadcrumb-item${isActive ? " active" : ""}`}
              aria-current={isActive ? "page" : undefined}
            >
              {isActive || !target ? (
                item.label
              ) : (
                <Link to={target}>{item.label}</Link>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
};

export default Breadcrumb;
