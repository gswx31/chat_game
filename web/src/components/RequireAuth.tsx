import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../store/auth";
import { useTerms } from "../store/terms";
import { TermsGate } from "./TermsGate";

/**
 * Signed-out visitors go to the nickname screen and come back to where they were headed.
 * Players who have a session but have not agreed to the terms yet see the agreement first.
 */
export function RequireAuth() {
  const user = useAuth((s) => s.user);
  const accepted = useTerms((s) => s.accepted);
  const loc = useLocation();
  if (!user) return <Navigate to="/" replace state={{ from: loc.pathname + loc.search }} />;
  if (!accepted) return <TermsGate />;
  return <Outlet />;
}
