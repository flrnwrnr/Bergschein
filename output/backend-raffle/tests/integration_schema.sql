CREATE TABLE raffle_entries (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    season_id VARCHAR(32) NOT NULL,
    install_id CHAR(36) NOT NULL,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(120) DEFAULT NULL,
    terms_version VARCHAR(32) NOT NULL,
    contact_consent TINYINT(1) NOT NULL DEFAULT 1,
    age_confirmed TINYINT(1) NOT NULL DEFAULT 1,
    consent_at DATETIME NOT NULL,
    badge_count_at_consent TINYINT UNSIGNED NOT NULL DEFAULT 0,
    challenge_count_at_consent TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_perfect_so_far TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_raffle_season_install (season_id, install_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE analytics_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    install_id CHAR(36) NOT NULL,
    season_id VARCHAR(32) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    event_time DATETIME NOT NULL,
    badge_count_after_event TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_analytics_raffle (season_id, install_id, event_type, event_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
