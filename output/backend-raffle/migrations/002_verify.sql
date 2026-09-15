-- Nach 001_raffle_seasons.sql ausfuehren und mit 000_preflight.sql vergleichen.
SHOW CREATE TABLE raffle_entries;

SELECT season_id, COUNT(*) AS entry_count
FROM raffle_entries
GROUP BY season_id
ORDER BY season_id;

SELECT COUNT(*) AS entry_count,
       COUNT(DISTINCT install_id) AS distinct_install_count,
       COALESCE(SUM(season_id <> 'bergschein-2026'), 0) AS non_2026_entry_count
FROM raffle_entries;

-- Erwartung direkt nach der Migration: gleiche Gesamtzahl wie davor,
-- non_2026_entry_count = 0, UNIQUE (season_id, install_id), idx_email erhalten.
