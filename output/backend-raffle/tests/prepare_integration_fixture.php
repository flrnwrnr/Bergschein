<?php
declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "Usage: php prepare_integration_fixture.php <source-directory> <fixture-directory>\n");
    exit(64);
}

[$script, $sourceDirectory, $fixtureDirectory] = $argv;
$source = $sourceDirectory . '/raffle_seasons.php';
$destination = $fixtureDirectory . '/raffle_seasons.php';
$contents = file_get_contents($source);
if ($contents === false) {
    throw new RuntimeException("Could not read {$source}");
}

// The production rules remain closed in the fixture. These additional IDs
// exist only in the temporary test copy, so an HTTP test can exercise an open
// registration window without preparing a production season.
$marker = "        // Test IDs are deliberately separate from production. They are closed\n";
$extraRules = <<<'PHP'
        // Integration fixture only: never copy these rules to production.
        'local-open-production' => [
            'registration_enabled' => true,
            'registration_opens_at' => $at('2020-01-01 00:00:00'),
            'registration_closes_at' => $at('2099-01-01 00:00:00'),
            'draw_available_at' => null,
            'terms_version' => 'integration-v1',
            'event_starts_at' => $at('2020-05-01 17:00:00'),
            'event_ends_at' => $at('2020-05-02 23:00:00'),
            'is_test' => false,
        ],
        'local-open-test' => [
            'registration_enabled' => true,
            'registration_opens_at' => $at('2020-01-01 00:00:00'),
            'registration_closes_at' => $at('2099-01-01 00:00:00'),
            'draw_available_at' => null,
            'terms_version' => 'integration-v1',
            'event_starts_at' => $at('2020-05-01 17:00:00'),
            'event_ends_at' => $at('2020-05-02 23:00:00'),
            'is_test' => true,
        ],
        'local-draw-test' => [
            'registration_enabled' => false,
            'registration_opens_at' => null,
            'registration_closes_at' => null,
            'draw_available_at' => $at('2020-05-03 00:00:00'),
            'terms_version' => 'integration-v1',
            'event_starts_at' => $at('2020-05-01 17:00:00'),
            'event_ends_at' => $at('2020-05-02 23:00:00'),
            'is_test' => true,
        ],

PHP;

if (!str_contains($contents, $marker)) {
    throw new RuntimeException('Could not find the stable fixture insertion point. Update this helper with raffle_seasons.php.');
}
$contents = str_replace($marker, $extraRules . $marker, $contents);
if (file_put_contents($destination, $contents) === false) {
    throw new RuntimeException("Could not write {$destination}");
}
