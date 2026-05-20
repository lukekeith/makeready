<?php

namespace App\Logging;

use Monolog\Handler\StreamHandler;
use Monolog\Level;
use Monolog\LogRecord;

/**
 * Stream handler that resolves its target path per log record using the
 * record's date — `{baseDir}/YYYY/MM/DD/app.log`. Rotates at UTC midnight.
 *
 * StreamHandler caches its open file resource; we override write() so each
 * record's date is checked and the stream re-opened only when the day
 * boundary crosses.
 */
class DatedDailyHandler extends StreamHandler
{
    private string $baseDir;
    private string $filename;
    private string $currentDate = '';

    public function __construct(string $baseDir, string $filename = 'app.log', int|string|Level $level = Level::Debug, bool $bubble = true)
    {
        $this->baseDir = rtrim($baseDir, '/\\');
        $this->filename = $filename;

        // Initialise with today's path; write() flips it as days roll over.
        parent::__construct($this->resolvePathForDate(date('Y-m-d')), $level, $bubble);
    }

    protected function write(LogRecord $record): void
    {
        $recordDate = $record->datetime->format('Y-m-d');

        if ($recordDate !== $this->currentDate) {
            $this->currentDate = $recordDate;
            $path = $this->resolvePathForDate($recordDate);
            $this->ensureDirectory(dirname($path));
            $this->close();
            $this->url = $path;
        }

        parent::write($record);
    }

    private function resolvePathForDate(string $ymd): string
    {
        [$y, $m, $d] = explode('-', $ymd);
        return "{$this->baseDir}/{$y}/{$m}/{$d}/{$this->filename}";
    }

    private function ensureDirectory(string $dir): void
    {
        if (! is_dir($dir)) {
            @mkdir($dir, 0775, true);
        }
    }
}
