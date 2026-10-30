import { useEffect } from "react";
import { Outlet, useLocation } from "react-router-dom";
import { DialogHost, ToastHost } from "./components/feedback";
import { UpdateBanner } from "./components/UpdateBanner";

/** Root layout: every screen draws its own app bar, so this only hosts the shared overlays. */
export default function App() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  return (
    <>
      <Outlet />
      <UpdateBanner />
      <ToastHost />
      <DialogHost />
    </>
  );
}
