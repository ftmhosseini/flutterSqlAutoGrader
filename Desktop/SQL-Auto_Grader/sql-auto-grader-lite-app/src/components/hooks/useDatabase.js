import { useState, useEffect } from "react";
import { loadSqliteData } from "../db/setup/setupFirebaseDb";

// Returns all in-memory SQLite databases loaded from Firestore config
export function useDatabase() {
  const [databases, setDatabases] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadSqliteData()
      .then(setDatabases)
      .catch(setError)
      .finally(() => setLoading(false));
  }, []);

  return { databases, loading, error };
}
