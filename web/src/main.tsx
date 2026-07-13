import React from "react";
import ReactDOM from "react-dom/client";
import { RouterProvider, createBrowserRouter } from "react-router-dom";

import App from "./App";
import Join from "./routes/Join";
import Lobby from "./routes/Lobby";
import Room from "./routes/Room";
import SignIn from "./routes/SignIn";
import "./index.css";

const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    children: [
      { index: true, element: <SignIn /> },
      { path: "lobby", element: <Lobby /> },
      { path: "j/:code", element: <Join /> },
      { path: "rooms/:roomId", element: <Room /> },
    ],
  },
]);

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
);
