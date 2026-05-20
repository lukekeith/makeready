<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

/**
 * Walks `storage/logs/YYYY/MM/DD/` and removes folders older than the
 * retention window. Empty year/month parents are removed as a final pass
 * so the tree never accumulates dead branches.
 *
 * Defaults to LOG_RETENTION_DAYS (30). Override with --days=N for ad-hoc
 * cleanup. Pass --dry-run to print what would be deleted without removing.
 */
class PruneLogs extends Command
{
    protected $signature = 'logs:prune
                            {--days= : Override the retention window in days (default LOG_RETENTION_DAYS or 30)}
                            {--dry-run : Print folders that would be deleted, but do not delete}';

    protected $description = 'Delete dated log folders older than the retention window';

    public function handle(): int
    {
        $days = (int) ($this->option('days') ?? env('LOG_RETENTION_DAYS', 30));
        if ($days < 1) {
            $this->error("Retention must be >= 1 day (got {$days})");
            return self::FAILURE;
        }

        $cutoff = strtotime("-{$days} days 00:00:00");
        if ($cutoff === false) {
            $this->error('Could not compute cutoff date');
            return self::FAILURE;
        }

        $base = storage_path('logs');
        if (! is_dir($base)) {
            $this->info("No log directory at {$base}; nothing to do.");
            return self::SUCCESS;
        }

        $dryRun = (bool) $this->option('dry-run');
        $deleted = 0;

        foreach ($this->iterateDayFolders($base) as [$path, $dayTs]) {
            if ($dayTs >= $cutoff) continue;

            if ($dryRun) {
                $this->line("[dry-run] would delete: {$path}");
            } else {
                $this->removeTree($path);
                $this->line("deleted: {$path}");
            }
            $deleted++;
        }

        // Clean up empty month / year shells.
        if (! $dryRun) {
            $this->pruneEmptyParents($base);
        }

        $this->info($dryRun
            ? "Dry run: {$deleted} folder(s) would be deleted (retention: {$days} days)"
            : "Pruned {$deleted} folder(s) (retention: {$days} days)");

        return self::SUCCESS;
    }

    /**
     * Yield [absolutePath, dayTimestamp] for each YYYY/MM/DD/ folder under $base.
     */
    private function iterateDayFolders(string $base): \Generator
    {
        foreach (glob($base . '/*', GLOB_ONLYDIR) ?: [] as $yearDir) {
            $year = basename($yearDir);
            if (! preg_match('/^\d{4}$/', $year)) continue;

            foreach (glob($yearDir . '/*', GLOB_ONLYDIR) ?: [] as $monthDir) {
                $month = basename($monthDir);
                if (! preg_match('/^\d{2}$/', $month)) continue;

                foreach (glob($monthDir . '/*', GLOB_ONLYDIR) ?: [] as $dayDir) {
                    $day = basename($dayDir);
                    if (! preg_match('/^\d{2}$/', $day)) continue;

                    $ts = strtotime("{$year}-{$month}-{$day} 00:00:00");
                    if ($ts === false) continue;
                    yield [$dayDir, $ts];
                }
            }
        }
    }

    private function removeTree(string $dir): void
    {
        if (! is_dir($dir)) return;
        foreach (scandir($dir) ?: [] as $entry) {
            if ($entry === '.' || $entry === '..') continue;
            $path = $dir . DIRECTORY_SEPARATOR . $entry;
            is_dir($path) ? $this->removeTree($path) : @unlink($path);
        }
        @rmdir($dir);
    }

    private function pruneEmptyParents(string $base): void
    {
        foreach (glob($base . '/*', GLOB_ONLYDIR) ?: [] as $yearDir) {
            foreach (glob($yearDir . '/*', GLOB_ONLYDIR) ?: [] as $monthDir) {
                if (count(glob($monthDir . '/*') ?: []) === 0) {
                    @rmdir($monthDir);
                }
            }
            if (count(glob($yearDir . '/*') ?: []) === 0) {
                @rmdir($yearDir);
            }
        }
    }
}
