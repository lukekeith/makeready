<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class ViteHot extends Command
{
    protected $signature = 'vite:hot {--port=5173 : Vite dev server port}';
    protected $description = 'Recreate the public/hot file so Laravel loads assets from Vite';

    public function handle(): int
    {
        $port = $this->option('port');
        $path = public_path('hot');

        file_put_contents($path, "http://localhost:{$port}");

        $this->info("Wrote public/hot → http://localhost:{$port}");

        return 0;
    }
}
