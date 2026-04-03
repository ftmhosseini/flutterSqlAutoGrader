import './About.css';

const About = () => {
  return (
    <div className="about-container">
      <div className="about-card">
        <section className="about-section">
          <h1>About SQL Auto Grader</h1>
          <p className="description">
            SQL Auto Grader is an advanced educational framework designed to automate the evaluation 
            of relational database queries.
          </p>
        </section>

        <section className="about-section">
          <h3>Our Mission</h3>
          <p className="description">We believe that database management is a core pillar of modern software engineering.</p>
        </section>

        <div className="contact-grid">
          <div className="contact-item">
            <strong>General Inquiries</strong>
            <a href="mailto:info@sql-grader.com">info@sql-grader.com</a>
          </div>
          <div className="contact-item">
            <strong>Technical Support</strong>
            <a href="mailto:support@sql-grader.com">support@sql-grader.com</a>
          </div>
        </div>
      </div>
    </div>
  );
};

export default About;