import { defineConfig } from 'vite';
import RubyPlugin from 'vite-plugin-ruby';
import react from '@vitejs/plugin-react';
import path from 'path';
console.log('Loaded Vite config');

export default defineConfig({
  plugins: [
    RubyPlugin(),
    react(),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './app/frontend'), // Alias for javascript folder
      '@components': path.resolve(__dirname, './app/frontend/components'), // Custom alias for components
      '@styles': path.resolve(__dirname, './app/frontend/styles') // Custom alias for styles
    }
  },
  css: {
    postcss: './postcss.config.js', // Use postcss for Tailwind and autoprefixer
  },
  server: {
    hmr: {
      overlay: true, // HMR overlay for errors
    },
    open: true, // Automatically open the browser on server start
  },
  build: {
    outDir: 'public/easy_ml/assets',
    assetsDir: 'assets',
    manifest: true,
    rollupOptions: {
      output: {
        // Put files directly in outDir with no "assets" subfolder
        entryFileNames: 'assets/[name]-[hash].js',
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash][extname]'
      }
    }
  }
});
