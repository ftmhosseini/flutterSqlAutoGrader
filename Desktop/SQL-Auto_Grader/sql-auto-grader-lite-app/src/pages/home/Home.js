import { useNavigate } from "react-router-dom";
import userSession from "../../components/services/UserSession";
import "./Home.css";

function Home() {
  const navigate = useNavigate();
  const userRole = userSession.role;

  return (
    <div className="home-container">
    
    
    
      <section className="hero">
        <h1>SQL Practice Platform</h1>
        <p>Learn SQL interactively in your browser using real datasets.</p>
        <button className="start-btn" onClick={() => userRole? navigate("dashboard"):navigate("/login")}>
          Start Practicing
        </button>
      </section>

     
      <section className="features">
        <h2>Explore Features</h2>
        <div className="features-grid">
          <div className="feature-card">
            <div className="icon">📄</div>
            <h3>Real Datasets</h3>
            <p>Instant access to datasets: Employees, Customers, Movies.</p>
          </div>
          <div className="feature-card">
            <div className="icon">⌨️</div>
            <h3>Instant Query Execution</h3>
            <p>Real Database deploys right in your browser.</p>
          </div>
          <div className="feature-card">
            <div className="icon">🤖</div>
            <h3>Automatic Grading</h3>
            <p>Get instant feedback on your SQL queries.</p>
          </div>
        </div>
      </section>
    </div>
  );
}

export default Home;