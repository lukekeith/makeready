<?php

namespace App\Services;

use Symfony\Component\Yaml\Yaml;
use Illuminate\Support\Facades\Cache;

class MarketingContentService
{
    public function load(string $page): array
    {
        $path = resource_path("content/marketing/{$page}.yaml");

        if (app()->environment('local')) {
            return Yaml::parseFile($path);
        }

        return Cache::remember("marketing_content.{$page}", 3600, function () use ($path) {
            return Yaml::parseFile($path);
        });
    }
}
