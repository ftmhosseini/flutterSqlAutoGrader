import { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { auth } from "../../firebase";
import { signOut } from "firebase/auth";
import userSession from "../../components/services/UserSession";
import "../../App.css"

function NavBar() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const user = auth.currentUser;
  const userName = userSession.fullName || "";
  const dropdownRef = useRef(null);

  useEffect(() => {
    const handler = (e) => { if (dropdownRef.current && !dropdownRef.current.contains(e.target)) setDropdownOpen(false); };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const handleLogout = () => {
    signOut(auth).then(() => {
      userSession.set(null);
      window.location.replace("/");
    }).catch((error) => {
      console.error("Sign out error", error);
    });
  };

  return (
    <nav className="navbar" style={{ zIndex: 1000 }}>
      <div className="nav-container">
        <Link to="/" className="logo">🌐 SQL Practice Platform</Link>
        <button className="hamburger" onClick={() => setMenuOpen(!menuOpen)}>☰</button>

        {/* desktop links */}
        <div className="nav-links">
          <Link to="/" className="nav-item">Home</Link>
          <Link to="/about" className="nav-item">About</Link>
          {user && <Link to="/dashboard" className="nav-item">Dashboard</Link>}
          {user ? (
            <div ref={dropdownRef} style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <div onClick={() => setDropdownOpen(!dropdownOpen)}
                style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <span className="text-gray-600 small" style={{ fontWeight: '500' }}>{userName || "User"}</span>
                <div style={{
                  width: '35px', height: '35px', backgroundColor: '#4e73df',
                  borderRadius: '50%', color: 'white', display: 'flex',
                  alignItems: 'center', justifyContent: 'center',
                  fontWeight: 'bold', fontSize: '14px'
                }}>
                  {userName ? userName.charAt(0).toUpperCase() : "U"}
                </div>
              </div>
              {dropdownOpen && (
                <div style={{
                  position: 'absolute', top: '110%', right: 0,
                  background: '#fff', border: '1px solid #e3e6f0',
                  borderRadius: '0.35rem', boxShadow: '0 0.15rem 1.75rem rgba(58,59,69,0.15)',
                  minWidth: '120px', zIndex: 9999
                }}>
                  <button onClick={handleLogout} style={{
                    display: 'block', width: '100%', padding: '0.5rem 1rem',
                    background: 'none', border: 'none', textAlign: 'left',
                    cursor: 'pointer', color: '#e74a3b', fontSize: '0.85rem'
                  }}>
                    <i className="fas fa-sign-out-alt fa-sm mr-2"></i>Sign Out
                  </button>
                </div>
              )}
            </div>
          ) : (
            <Link to="/login" className="login-button">Login</Link>
          )}
        </div>

        {/* mobile menu */}
        {menuOpen && (
          <div className="mobile-menu">
            {user && (
              <Link to="/dashboard/profile" onClick={() => setMenuOpen(false)}
                style={{ fontWeight: '600', color: '#1a2b4b', fontSize: '15px', borderBottom: '1px solid #eef2f6', paddingBottom: '8px', width: '100%', textDecoration: 'none' }}>
                👤 {userName || "User"}
              </Link>
            )}
            <Link to="/" className="nav-item" onClick={() => setMenuOpen(false)}>Home</Link>
            <Link to="/about" className="nav-item" onClick={() => setMenuOpen(false)}>About</Link>
            {user && <Link to="/dashboard" className="nav-item" onClick={() => setMenuOpen(false)}>Dashboard</Link>}
            {user ? (
              <button onClick={handleLogout} style={{
                background: 'none', border: 'none', padding: 0,
                color: '#e74a3b', fontWeight: '500', fontSize: '18px', cursor: 'pointer', textAlign: 'left'
              }}>Sign Out</button>
            ) : (
              <Link to="/login" className="login-button" onClick={() => setMenuOpen(false)}>Login</Link>
            )}
          </div>
        )}
      </div>
    </nav>
  );
}

export default NavBar;
