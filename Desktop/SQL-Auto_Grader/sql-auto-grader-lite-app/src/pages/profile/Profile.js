import React from "react";
import userSession from "../../components/services/UserSession";
import "./Profile.css";

const Profile = () => {
  const userData = userSession.get();

  return (
    <div className="profile-container">
      <div className="profile-card">
        <div className="profile-header">
          <div className="profile-avatar">
            {userData?.fullName?.charAt(0) || "U"}
          </div>
          <h2>{userData?.fullName || "User Name"}</h2>
          <p className="profile-role">{userData?.role?.toUpperCase()}</p>
        </div>

        <div className="profile-info">
          <div className="info-item">
            <label>Email Address</label>
            <span>{userData?.email}</span>
          </div>
          <div className="info-item">
            <label>Member Since</label>
            <span>{userData?.createdAt?.toDate().toLocaleDateString("en-CA") || "Recently"}</span>
          </div>
        </div>

        {/* <div className="profile-stats">
          <div className="stat-box">
            <span className="stat-val">12</span>
            <span className="stat-label">Solved</span>
          </div>
          <div className="stat-box">
            <span className="stat-val">85%</span>
            <span className="stat-label">Accuracy</span>
          </div>
        </div> */}
      </div>
    </div>
  );
};

export default Profile;