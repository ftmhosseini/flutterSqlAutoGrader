import Loader from "./Loader";

export default function LoadingOverlay({
  isOpen,
  message = "Loading...",
  zIndex = 1050,
}) {
  if (!isOpen) return null;

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        backgroundColor: "rgba(15, 23, 42, 0.35)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        zIndex,
      }}
    >
      <div
        style={{
          minWidth: "160px",
          minHeight: "120px",
          backgroundColor: "#ffffff",
          borderRadius: "16px",
          boxShadow: "0 18px 48px rgba(15, 23, 42, 0.18)",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: "10px",
          padding: "24px",
        }}
      >
        <Loader />
        <span style={{ color: "#4b5563", fontSize: "14px" }}>{message}</span>
      </div>
    </div>
  );
}
