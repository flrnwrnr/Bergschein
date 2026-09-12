-- Einmalig ausführen, nach vollständiger Sicherung und Bestandsprüfung.
-- MySQL-DDL führt implizite Commits aus; kein transaktionales Rollback!
-- Erwarteter geprüfter Bestand: 404 Ereignisse 2026, 4 Testereignisse 2027.
ALTER TABLE analytics_events
    ADD COLUMN season_id VARCHAR(32) NOT NULL DEFAULT 'bergschein-2026' AFTER install_id,
    DROP INDEX uniq_install_event_day,
    ADD UNIQUE KEY uniq_season_install_event_day
        (season_id, install_id, event_type, day_key);

-- Nur die vom Nutzer bestätigten vorhandenen Testereignisse umordnen.
-- Vorher muss die entsprechende SELECT-Abfrage genau vier Zeilen ergeben.
UPDATE analytics_events
SET season_id = 'test-bergschein-2027'
WHERE season_id = 'bergschein-2026'
  AND id IN (572, 573, 574, 575)
  AND event_time >= '2027-05-13 15:00:00'
  AND event_time <= '2027-05-14 15:17:00';

SELECT season_id, COUNT(*) AS event_count
FROM analytics_events GROUP BY season_id ORDER BY season_id;
