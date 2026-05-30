import path from 'path'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/css/app.scss',
                'resources/js/app.js',
                'resources/js/preview-entry.ts',
            ],
            refresh: true,
        }),
        vue({
            template: {
                transformAssetUrls: {
                    base: null,
                    includeAbsolute: false,
                },
            },
        }),
    ],
    resolve: {
        alias: {
            vue: 'vue/dist/vue.esm-bundler.js',
            '@': path.resolve(__dirname, 'resources/js'),
        },
    },
    css: {
        preprocessorOptions: {
            scss: {
                // Component SCSS files from archive use @use '@/styles/colors'.
                // We inject the file resolution by adding additionalData that
                // sets up the load path. The @/ alias in SCSS maps to resources/css/.
                additionalData: (source, fp) => {
                    // Replace @/styles/ with the absolute path for sass resolution
                    // This is done via loadPaths — @use 'styles/colors' resolves
                    // when resources/css is on the load path.
                    // But for @use '@/styles/colors', we need a custom approach.
                    return source
                },
                loadPaths: [
                    path.resolve(__dirname, 'resources/css'),
                    path.resolve(__dirname, 'resources'),
                ],
            },
        },
    },
    server: {
        host: process.env.VITE_HOST || 'localhost',
        port: parseInt(process.env.VITE_PORT || '5173'),
        cors: true,
        ...(process.env.VITE_HOST ? { hmr: { host: process.env.VITE_HOST } } : {}),
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
