import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";

// Stamped into the bundle AND written to dist/version.json, so a running page can notice that a
// newer build has been deployed (see src/lib/version.ts) instead of keeping stale code alive in
// an open tab for hours.
const BUILD_ID = new Date().toISOString().replace(/[-:]/g, "").slice(0, 15);

function versionFile(): Plugin {
  return {
    name: "version-file",
    generateBundle() {
      this.emitFile({ type: "asset", fileName: "version.json", source: JSON.stringify({ build: BUILD_ID }) });
    },
  };
}

export default defineConfig({
  plugins: [react(), versionFile()],
  define: { __BUILD_ID__: JSON.stringify(BUILD_ID) },
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:8000",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ""),
      },
      "/ws": {
        target: "ws://localhost:8000",
        ws: true,
      },
    },
  },
});
