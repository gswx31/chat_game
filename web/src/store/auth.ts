import { create } from "zustand";

interface User {
  user_id: string;
  nickname: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
  signIn: (token: string, user: User) => void;
  signOut: () => void;
}

function loadInitial(): { user: User | null; token: string | null } {
  const token = localStorage.getItem("token");
  const userRaw = localStorage.getItem("user");
  if (!token || !userRaw) return { user: null, token: null };
  try {
    return { token, user: JSON.parse(userRaw) as User };
  } catch {
    return { user: null, token: null };
  }
}

export const useAuth = create<AuthState>((set) => ({
  ...loadInitial(),
  signIn: (token, user) => {
    localStorage.setItem("token", token);
    localStorage.setItem("user", JSON.stringify(user));
    set({ token, user });
  },
  signOut: () => {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    set({ token: null, user: null });
  },
}));
