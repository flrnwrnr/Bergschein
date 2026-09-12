-- Nach 001_seasons.sql auf einer lokalen Testkopie ausführen.
-- Jede Prüfung liefert 1 in der Spalte `passed`, wenn sie erfolgreich ist.

SELECT 'total_event_count_is_408' AS test,
       COUNT(*) = 408 AS passed
FROM analytics_events;

SELECT 'production_2026_count_is_404' AS test,
       COUNT(*) = 404 AS passed
FROM analytics_events
WHERE season_id = 'bergschein-2026';

SELECT 'test_2027_count_is_4' AS test,
       COUNT(*) = 4 AS passed
FROM analytics_events
WHERE season_id = 'test-bergschein-2027';

SELECT 'production_2027_is_empty' AS test,
       COUNT(*) = 0 AS passed
FROM analytics_events
WHERE season_id = 'bergschein-2027';

SELECT 'season_column_has_expected_default' AS test,
       COUNT(*) = 1 AS passed
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'analytics_events'
  AND column_name = 'season_id'
  AND column_type = 'varchar(32)'
  AND is_nullable = 'NO'
  AND column_default IN (
      'bergschein-2026',
      QUOTE('bergschein-2026')
  );

SELECT 'season_unique_index_has_expected_columns' AS test,
       COUNT(*) = 4
       AND GROUP_CONCAT(column_name ORDER BY seq_in_index) =
           'season_id,install_id,event_type,day_key' AS passed
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'analytics_events'
  AND index_name = 'uniq_season_install_event_day'
  AND non_unique = 0;

SELECT 'legacy_unique_index_was_removed' AS test,
       COUNT(*) = 0 AS passed
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'analytics_events'
  AND index_name = 'uniq_install_event_day';

START TRANSACTION;

-- Simuliert einen alten Client, der season_id nicht mitsendet.
INSERT INTO analytics_events
    (install_id, event_type, event_time, day_key,
     badge_count_after_event, is_perfect_so_far,
     challenge_count_after_event)
VALUES
    ('00000000-0000-4000-8000-000000000001', 'badge_claimed',
     '2099-01-01 12:00:00', '2099-01-01', 1, 1, 0);

SELECT 'legacy_insert_defaults_to_2026' AS test,
       COUNT(*) = 1 AS passed
FROM analytics_events
WHERE install_id = '00000000-0000-4000-8000-000000000001'
  AND event_type = 'badge_claimed'
  AND day_key = '2099-01-01'
  AND season_id = 'bergschein-2026';

-- Derselbe fachliche Schlüssel darf in einer anderen Saison koexistieren.
INSERT INTO analytics_events
    (season_id, install_id, event_type, event_time, day_key,
     badge_count_after_event, is_perfect_so_far,
     challenge_count_after_event)
VALUES
    ('bergschein-2027', '00000000-0000-4000-8000-000000000001',
     'badge_claimed', '2099-01-01 12:01:00', '2099-01-01', 1, 1, 0);

SELECT 'same_event_key_coexists_across_seasons' AS test,
       COUNT(*) = 2 AND COUNT(DISTINCT season_id) = 2 AS passed
FROM analytics_events
WHERE install_id = '00000000-0000-4000-8000-000000000001'
  AND event_type = 'badge_claimed'
  AND day_key = '2099-01-01';

-- Derselbe Schlüssel derselben Saison muss aktualisiert statt dupliziert werden.
INSERT INTO analytics_events
    (season_id, install_id, event_type, event_time, day_key,
     badge_count_after_event, is_perfect_so_far,
     challenge_count_after_event)
VALUES
    ('bergschein-2027', '00000000-0000-4000-8000-000000000001',
     'badge_claimed', '2099-01-01 12:02:00', '2099-01-01', 2, 0, 1)
ON DUPLICATE KEY UPDATE
    event_time = VALUES(event_time),
    badge_count_after_event = VALUES(badge_count_after_event),
    is_perfect_so_far = VALUES(is_perfect_so_far),
    challenge_count_after_event = VALUES(challenge_count_after_event);

SELECT 'same_season_upsert_updates_one_row' AS test,
       COUNT(*) = 1
       AND MAX(event_time) = '2099-01-01 12:02:00'
       AND MAX(badge_count_after_event) = 2
       AND MAX(is_perfect_so_far) = 0
       AND MAX(challenge_count_after_event) = 1 AS passed
FROM analytics_events
WHERE season_id = 'bergschein-2027'
  AND install_id = '00000000-0000-4000-8000-000000000001'
  AND event_type = 'badge_claimed'
  AND day_key = '2099-01-01';

ROLLBACK;

SELECT 'synthetic_rows_were_rolled_back' AS test,
       COUNT(*) = 0 AS passed
FROM analytics_events
WHERE install_id = '00000000-0000-4000-8000-000000000001';
