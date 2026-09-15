-- Einmalig ausfuehren, erst nach einem aktuellen Backup von raffle_entries.
-- Abgeglichen mit SHOW CREATE TABLE raffle_entries vom 14.09.2026:
-- PRIMARY KEY (id), UNIQUE KEY uniq_install_id (install_id), KEY idx_email (email).
-- Vor Ausfuehrung nochmals pruefen, dass dieses Schema noch gilt und dass
-- analytics_events bereits eine season_id-Spalte hat.
-- MySQL/MariaDB-DDL fuehrt implizite Commits aus; ein ROLLBACK hilft hier nicht.

ALTER TABLE raffle_entries
    ADD COLUMN season_id VARCHAR(32) NOT NULL DEFAULT 'bergschein-2026' AFTER install_id,
    DROP INDEX uniq_install_id,
    ADD UNIQUE KEY uniq_raffle_season_install (season_id, install_id),
    ADD KEY idx_raffle_season_consent (season_id, contact_consent, age_confirmed);

-- Alle Bestandszeilen bleiben der produktiven Saison 2026 zugeordnet.
-- Ohne separate, verlaessliche Herkunftsdaten erfolgt keine nachtraegliche
-- Umordnung einzelner Verlosungsteilnahmen in eine Testsaison.
SELECT season_id, COUNT(*) AS entry_count
FROM raffle_entries
GROUP BY season_id;

SHOW INDEX FROM raffle_entries;
