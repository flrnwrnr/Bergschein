-- Nach dem Backup und unmittelbar vor 001_raffle_seasons.sql ausfuehren.
-- Nur Metadaten und Summen; keine personenbezogenen Zeilen ausgeben.
SHOW CREATE TABLE raffle_entries;
SHOW COLUMNS FROM analytics_events LIKE 'season_id';

SELECT COUNT(*) AS entry_count,
       COUNT(DISTINCT install_id) AS distinct_install_count
FROM raffle_entries;

-- Erwartung gemaess Schema vom 14.09.2026:
-- PRIMARY (id), UNIQUE uniq_install_id (install_id), KEY idx_email (email).
-- entry_count und distinct_install_count muessen gleich sein.
