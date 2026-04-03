import React from 'react';
import {useNavigate } from "react-router-dom";

const projects = [
  { name: "Server Migration", progress: 20, color: "danger" },
  { name: "Sales Tracking", progress: 40, color: "warning" },
  { name: "Customer Database", progress: 60, color: "primary" },
  { name: "Payout Details", progress: 80, color: "info" },
  { name: "Account Setup", progress: 100, color: "success" },
];

const CardDashboard = ({ cards = [] }) => {
    const navigate = useNavigate();
  return(
    <>
    <div className="row">
      {cards.map(({ label, value, color, icon ,path }) => (
        <div className="col-xl-4 col-md-4 mb-4" key={label}>
          <div className={`card border-left-${color} shadow h-100 py-2`}
            style={{ cursor: "pointer" }}
            onClick={() => navigate(path)}
          >
            <div className="card-body">
              <div className="row no-gutters align-items-center">
                <div className="col mr-2">
                  <div className={`text-xs font-weight-bold text-${color} text-uppercase mb-1`}>{label}</div>
                  <div className="h5 mb-0 font-weight-bold text-gray-800">{value}</div>
                </div>
                <div className="col-auto">
                  <i className={`fas ${icon} fa-2x text-gray-300`}></i>
                </div>
              </div>
            </div>
          </div>
        </div> 
    ))}
  </div>  
  


  </>
  )
};

export default CardDashboard;