
CREATE TABLE IF NOT EXISTS BOOKMARKS (
url TEXT,
title TEXT,
adddate DATE,
PRIMARY KEY(url)
);

-- Split history schema (Flow-inspired):
--   HISTORY_URLS  — one row per unique URL; tracks visit_count and last_visit.
--   HISTORY_VISITS — one row per individual visit; enables time-range queries.
CREATE TABLE IF NOT EXISTS HISTORY_URLS (
url TEXT NOT NULL,
title TEXT,
visit_count INTEGER NOT NULL DEFAULT 1,
last_visit TEXT NOT NULL,
PRIMARY KEY(url)
);

CREATE TABLE IF NOT EXISTS HISTORY_VISITS (
id INTEGER PRIMARY KEY AUTOINCREMENT,
url TEXT NOT NULL,
visit_time TEXT NOT NULL
);

-- Persisted closed-tabs stack so Ctrl+Shift+T survives crashes and restarts.
-- urls is a newline-separated list (1 or 2 entries for split view).
CREATE TABLE IF NOT EXISTS RECENTLY_CLOSED (
id INTEGER PRIMARY KEY AUTOINCREMENT,
urls TEXT NOT NULL,
closeddate TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ICONS (
url TEXT,
icon TEXT,
PRIMARY KEY(url)
);
