import path from "path"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "ui": path.resolve(__dirname, "../ui"),
      "util": path.resolve(__dirname, "../util"),
      "shared": path.resolve(__dirname, "../shared"),
    },
  },
})
