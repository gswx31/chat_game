# ChatGame Web

React + TypeScript + Vite. Dev server proxies `/api` and `/ws` to the FastAPI backend on :8000.

## Run locally

```bash
npm install
npm run dev
```

Open <http://localhost:5173>. The backend must be running on <http://localhost:8000> (see `../backend/README.md`).

## Layout

```
src/
  main.tsx                 router setup
  App.tsx                  top bar + <Outlet/>
  index.css                base dark theme
  api/client.ts            REST wrapper (fetch + bearer token)
  store/auth.ts            zustand auth store
  ws/useGameSocket.ts      WebSocket hook for /ws/rooms/:id
  routes/
    SignIn.tsx             guest nickname → JWT
    Lobby.tsx              room list + create modal
    Room.tsx               chat (game engine wires next)
```
