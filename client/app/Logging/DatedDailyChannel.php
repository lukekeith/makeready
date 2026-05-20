<?php

namespace App\Logging;

use Monolog\Logger;

/**
 * Custom log channel factory wired into config/logging.php.
 *
 * Produces a Monolog Logger with a single DatedDailyHandler that writes
 * JSON Lines into `storage/logs/YYYY/MM/DD/app.log`. One file per UTC day.
 *
 * Usage in config/logging.php:
 *
 *   'dated' => [
 *     'driver' => 'custom',
 *     'via'    => App\Logging\DatedDailyChannel::class,
 *     'level'  => env('LOG_LEVEL', 'debug'),
 *   ],
 */
class DatedDailyChannel
{
    public function __invoke(array $config): Logger
    {
        $level = $config['level'] ?? 'debug';
        $baseDir = storage_path('logs');

        $handler = new DatedDailyHandler($baseDir, 'app.log', $level);
        $handler->setFormatter(new JsonLineFormatter());

        return new Logger('dated', [$handler]);
    }
}
