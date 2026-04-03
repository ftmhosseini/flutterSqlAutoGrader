import { useState, useEffect } from "react";
import { auth } from "../../firebase";
import { onAuthStateChanged } from "firebase/auth";
import { getUser } from "../model/users";
import userSession from "./UserSession";

export function useAuth() {
  const [role, setRole] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser && currentUser.emailVerified) {
        if (!userSession.role) {
          const userData = await getUser(currentUser.uid);
          if (userData) userSession.set(userData);
        }
        setRole(userSession.role);
      } else {
        userSession.clear();
        setRole(null);
      }
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  return { role, loading };
}
