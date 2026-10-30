import type { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../store/auth";

/** Sends visitors who have not entered a nickname yet to the sign-in screen. */
export function RequireUser({ children }: { children: ReactNode }) {
  const user = useAuth((s) => s.user);
  if (!user) return <Navigate to="/" replace />;
  return <>{children}</>;
}
