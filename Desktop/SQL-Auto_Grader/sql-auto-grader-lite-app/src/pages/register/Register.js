import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { auth } from "../../firebase";
import { createUserWithEmailAndPassword, sendEmailVerification } from "firebase/auth";
import { createUser } from "../../components/model/users";
import "./Register.css";

function Register() {
  const navigate = useNavigate();

  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState("student");
  const [error, setError] = useState("");

  const [isWaitingForVerify, setIsWaitingForVerify] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");


    try {

      const res = await createUserWithEmailAndPassword(auth, email, password);

      await sendEmailVerification(res.user); //send verif email

      await createUser(res.user.uid, {
        uid: res.user.uid,
        fullName: fullName,
        email: email,
        role: role,
        createdAt: new Date(),
      });

      console.log("Success! Account created.");

      setIsWaitingForVerify(true);


    } catch (err) {
      setError("This email is already existes. Try logging in.");
    }
  };


  const handleResend = async () => {
    try {
      if (auth.currentUser) {
        await sendEmailVerification(auth.currentUser);
        alert("Verification email sent again!");
      }
    } catch (err) {
      setError("Too many requests. Please wait a moment.");
    }
  };

  if (isWaitingForVerify) {
    return (
      <div className="auth-container">
        <div className="auth-card">
          <div className="verify-icon">✉️</div>
          <h2>Check your email</h2>
          <p className="auth-subtitle">
            We've sent a verification link to <b>{email}</b>.
            Please check your inbox (and spam folder).
          </p>

          <p className="auth-footer">
            Verified already? <span onClick={() => navigate("/login")}>Go to Login</span>
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="auth-container">
      <div className="auth-card">
        <h2>Create Account</h2>
        <p className="auth-subtitle">Join the SQL Practice Platform</p>

        {error && <p style={{ color: "red", textAlign: "center", fontSize: "14px" }}>{error}</p>}



        <form className="auth-form" onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Full Name</label>
            <input type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              required />
          </div>
          <div className="form-group">
            <label>Email</label>
            <input type="email" placeholder="name@example.com" value={email}
              onChange={(e) => setEmail(e.target.value)}
              required />
          </div>


          <div className="form-group">
            <label>I am registering as:</label>
            <select
              className="role-select"
              value={role}
              onChange={(e) => setRole(e.target.value)}
              required
            >
              <option value="student">Student</option>
              <option value="teacher">Teacher</option>
            </select>
          </div>



          <div className="form-group">
            <label>Password</label>
            <input type="password" placeholder="••••••••" value={password}
              onChange={(e) => setPassword(e.target.value)}
              required />
          </div>
          <button type="submit" className="auth-btn">Sign Up</button>
        </form>

        <p className="auth-footer">
          Already have an account? <span onClick={() => navigate("/login")}>Login</span>
        </p>
      </div>
    </div>
  );
}

export default Register;