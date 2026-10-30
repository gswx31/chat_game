import React from "react";
import ReactDOM from "react-dom/client";
import { Navigate, RouterProvider, createBrowserRouter } from "react-router-dom";

import App from "./App";
import { RedirectRoom } from "./components/RedirectRoom";
import { RequireAuth } from "./components/RequireAuth";
import Create from "./routes/Create";
import HistoryPage from "./routes/History";
import Home from "./routes/Home";
import Join from "./routes/Join";
import JoinRooms from "./routes/JoinRooms";
import MapEditor from "./routes/maps/MapEditor";
import MapList from "./routes/maps/MapList";
import MapStore from "./routes/maps/MapStore";
import Profile from "./routes/Profile";
import Room from "./routes/Room";
import Blocked from "./routes/Blocked";
import Settings from "./routes/Settings";
import SignIn from "./routes/SignIn";
import Terms from "./routes/Terms";
import "./styles/app-theme.css";
import "./index.css";

const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    children: [
      { index: true, element: <SignIn /> },
      // the link a friend shares — works signed out too (nickname step, then into the room)
      { path: "j/:code", element: <Join /> },
      { path: "terms", element: <Terms /> }, // public: linked from sign-in and the store listing
      {
        element: <RequireAuth />,
        children: [
          { path: "home", element: <Home /> },
          { path: "lobby", element: <Navigate to="/home" replace /> }, // old address
          { path: "create", element: <Create /> },
          { path: "join", element: <JoinRooms /> },
          { path: "room/:roomId", element: <Room /> },
          { path: "rooms/:roomId", element: <RedirectRoom /> }, // old address (the server owns /rooms/*)
          { path: "history", element: <HistoryPage /> },
          { path: "profile", element: <Profile /> },
          { path: "settings", element: <Settings /> },
          { path: "blocked", element: <Blocked /> },
          { path: "maps", element: <MapList /> },
          { path: "maps/new", element: <MapEditor /> },
          { path: "maps/store", element: <MapStore /> },
          { path: "maps/:id", element: <MapEditor /> },
        ],
      },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
);
