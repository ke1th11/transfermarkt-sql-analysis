/* =====================================================================
   03_validate_staging.sql
   Read-only checks on the staging tables (nothing is changed).
   Run each numbered block on its own (select it, then Execute).
   Some blocks may take a minute: the staging tables have no indexes.
   Write down anything that is not 0 / not expected: it feeds the cleaning.
   ===================================================================== */

USE TransfermarktDB;
GO

/* ---------------------------------------------------------------------
   0) Quick look at the data (first rows of the main tables)
   --------------------------------------------------------------------- */
SELECT TOP 10 * FROM staging.players;
SELECT TOP 10 * FROM staging.games;
SELECT TOP 10 * FROM staging.appearances;
SELECT TOP 10 * FROM staging.transfers;


/* ---------------------------------------------------------------------
   1) Duplicate keys: duplicate_rows should be 0 for primary keys
   --------------------------------------------------------------------- */
SELECT 'players.player_id'              AS check_name, COUNT(*) - COUNT(DISTINCT player_id)      AS duplicate_rows FROM staging.players
UNION ALL SELECT 'clubs.club_id',                      COUNT(*) - COUNT(DISTINCT club_id)        FROM staging.clubs
UNION ALL SELECT 'games.game_id',                      COUNT(*) - COUNT(DISTINCT game_id)        FROM staging.games
UNION ALL SELECT 'competitions.competition_id',        COUNT(*) - COUNT(DISTINCT competition_id) FROM staging.competitions
UNION ALL SELECT 'countries.country_id',               COUNT(*) - COUNT(DISTINCT country_id)     FROM staging.countries
UNION ALL SELECT 'appearances.appearance_id',          COUNT(*) - COUNT(DISTINCT appearance_id)  FROM staging.appearances
UNION ALL SELECT 'game_events.game_event_id',          COUNT(*) - COUNT(DISTINCT game_event_id)  FROM staging.game_events
UNION ALL SELECT 'game_lineups.game_lineups_id',       COUNT(*) - COUNT(DISTINCT game_lineups_id) FROM staging.game_lineups;

-- Composite keys (a pair of columns identifies the row)
SELECT 'club_games (game_id, club_id)' AS check_name,
       COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT game_id, club_id FROM staging.club_games) d) AS duplicate_rows
FROM staging.club_games;

SELECT 'player_valuations (player_id, date)' AS check_name,
       COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT player_id, [date] FROM staging.player_valuations) d) AS duplicate_rows
FROM staging.player_valuations;


/* ---------------------------------------------------------------------
   2) Orphan keys: rows that point to something that does not exist
      (NULL / empty keys are ignored here)
   --------------------------------------------------------------------- */
SELECT 'appearances -> players' AS check_name, COUNT(*) AS orphan_rows
FROM staging.appearances a
WHERE NULLIF(a.player_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.players p WHERE p.player_id = a.player_id);

SELECT 'appearances -> games' AS check_name, COUNT(*) AS orphan_rows
FROM staging.appearances a
WHERE NULLIF(a.game_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.games g WHERE g.game_id = a.game_id);

SELECT 'games -> competitions' AS check_name, COUNT(*) AS orphan_rows
FROM staging.games g
WHERE NULLIF(g.competition_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.competitions c WHERE c.competition_id = g.competition_id);

SELECT 'games.home_club_id -> clubs' AS check_name, COUNT(*) AS orphan_rows
FROM staging.games g
WHERE NULLIF(g.home_club_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.clubs c WHERE c.club_id = g.home_club_id);

SELECT 'club_games -> games' AS check_name, COUNT(*) AS orphan_rows
FROM staging.club_games cg
WHERE NULLIF(cg.game_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.games g WHERE g.game_id = cg.game_id);

SELECT 'player_valuations -> players' AS check_name, COUNT(*) AS orphan_rows
FROM staging.player_valuations v
WHERE NULLIF(v.player_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.players p WHERE p.player_id = v.player_id);

SELECT 'transfers -> players' AS check_name, COUNT(*) AS orphan_rows
FROM staging.transfers t
WHERE NULLIF(t.player_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.players p WHERE p.player_id = t.player_id);


/* ---------------------------------------------------------------------
   3) Empty values: did they arrive as NULL or as '' (empty text)?
      Also look for placeholder text such as 'NA', 'N/A', 'null'.
   --------------------------------------------------------------------- */
SELECT 'players.date_of_birth' AS column_name,
       SUM(CASE WHEN date_of_birth IS NULL THEN 1 ELSE 0 END)                       AS null_values,
       SUM(CASE WHEN date_of_birth = '' THEN 1 ELSE 0 END)                          AS empty_text,
       SUM(CASE WHEN date_of_birth IN ('NA','N/A','null','NULL') THEN 1 ELSE 0 END) AS placeholders
FROM staging.players
UNION ALL
SELECT 'players.market_value_in_eur',
       SUM(CASE WHEN market_value_in_eur IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN market_value_in_eur = '' THEN 1 ELSE 0 END),
       SUM(CASE WHEN market_value_in_eur IN ('NA','N/A','null','NULL') THEN 1 ELSE 0 END)
FROM staging.players
UNION ALL
SELECT 'players.foot',
       SUM(CASE WHEN foot IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN foot = '' THEN 1 ELSE 0 END),
       SUM(CASE WHEN foot IN ('NA','N/A','null','NULL') THEN 1 ELSE 0 END)
FROM staging.players
UNION ALL
SELECT 'games.attendance',
       SUM(CASE WHEN attendance IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN attendance = '' THEN 1 ELSE 0 END),
       SUM(CASE WHEN attendance IN ('NA','N/A','null','NULL') THEN 1 ELSE 0 END)
FROM staging.games
UNION ALL
SELECT 'games.referee',
       SUM(CASE WHEN referee IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN referee = '' THEN 1 ELSE 0 END),
       SUM(CASE WHEN referee IN ('NA','N/A','null','NULL') THEN 1 ELSE 0 END)
FROM staging.games
UNION ALL
SELECT 'transfers.transfer_fee',
       SUM(CASE WHEN transfer_fee IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN transfer_fee = '' THEN 1 ELSE 0 END),
       SUM(CASE WHEN transfer_fee IN ('NA','N/A','null','NULL') THEN 1 ELSE 0 END)
FROM staging.transfers
UNION ALL
SELECT 'appearances.minutes_played',
       SUM(CASE WHEN minutes_played IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN minutes_played = '' THEN 1 ELSE 0 END),
       SUM(CASE WHEN minutes_played IN ('NA','N/A','null','NULL') THEN 1 ELSE 0 END)
FROM staging.appearances;


/* ---------------------------------------------------------------------
   4) Type-conversion failures: values that are NOT empty but cannot be
      converted. FLOAT is used for numbers because CSV exports often write
      whole numbers as '185.0', which TRY_CAST(... AS INT) rejects.
      A non-zero count here can also reveal shifted columns.
   --------------------------------------------------------------------- */
SELECT 'games.date -> DATE' AS check_name, COUNT(*) AS failed_rows
FROM staging.games
WHERE NULLIF([date], '') IS NOT NULL AND TRY_CAST([date] AS DATE) IS NULL
UNION ALL
SELECT 'games.home_club_goals -> FLOAT', COUNT(*)
FROM staging.games
WHERE NULLIF(home_club_goals, '') IS NOT NULL AND TRY_CAST(home_club_goals AS FLOAT) IS NULL
UNION ALL
SELECT 'games.attendance -> FLOAT', COUNT(*)
FROM staging.games
WHERE NULLIF(attendance, '') IS NOT NULL AND TRY_CAST(attendance AS FLOAT) IS NULL
UNION ALL
SELECT 'players.date_of_birth -> DATE', COUNT(*)
FROM staging.players
WHERE NULLIF(date_of_birth, '') IS NOT NULL AND TRY_CAST(date_of_birth AS DATE) IS NULL
UNION ALL
SELECT 'players.height_in_cm -> FLOAT', COUNT(*)
FROM staging.players
WHERE NULLIF(height_in_cm, '') IS NOT NULL AND TRY_CAST(height_in_cm AS FLOAT) IS NULL
UNION ALL
SELECT 'players.market_value_in_eur -> FLOAT', COUNT(*)
FROM staging.players
WHERE NULLIF(market_value_in_eur, '') IS NOT NULL AND TRY_CAST(market_value_in_eur AS FLOAT) IS NULL
UNION ALL
SELECT 'player_valuations.date -> DATE', COUNT(*)
FROM staging.player_valuations
WHERE NULLIF([date], '') IS NOT NULL AND TRY_CAST([date] AS DATE) IS NULL
UNION ALL
SELECT 'player_valuations.market_value_in_eur -> FLOAT', COUNT(*)
FROM staging.player_valuations
WHERE NULLIF(market_value_in_eur, '') IS NOT NULL AND TRY_CAST(market_value_in_eur AS FLOAT) IS NULL
UNION ALL
SELECT 'transfers.transfer_date -> DATE', COUNT(*)
FROM staging.transfers
WHERE NULLIF(transfer_date, '') IS NOT NULL AND TRY_CAST(transfer_date AS DATE) IS NULL
UNION ALL
SELECT 'transfers.transfer_fee -> FLOAT', COUNT(*)
FROM staging.transfers
WHERE NULLIF(transfer_fee, '') IS NOT NULL AND TRY_CAST(transfer_fee AS FLOAT) IS NULL
UNION ALL
SELECT 'appearances.date -> DATE', COUNT(*)
FROM staging.appearances
WHERE NULLIF([date], '') IS NOT NULL AND TRY_CAST([date] AS DATE) IS NULL
UNION ALL
SELECT 'appearances.minutes_played -> FLOAT', COUNT(*)
FROM staging.appearances
WHERE NULLIF(minutes_played, '') IS NOT NULL AND TRY_CAST(minutes_played AS FLOAT) IS NULL;


/* ---------------------------------------------------------------------
   5) Categorical columns: list the distinct values and how often each
      appears. Look for typos, mixed case, unexpected values.
   --------------------------------------------------------------------- */
SELECT [position], COUNT(*) AS n FROM staging.players GROUP BY [position] ORDER BY n DESC;
SELECT foot, COUNT(*) AS n FROM staging.players GROUP BY foot ORDER BY n DESC;
SELECT hosting, is_win, COUNT(*) AS n FROM staging.club_games GROUP BY hosting, is_win ORDER BY n DESC;
SELECT [type], COUNT(*) AS n FROM staging.game_events GROUP BY [type] ORDER BY n DESC;
SELECT [type], sub_type, COUNT(*) AS n FROM staging.competitions GROUP BY [type], sub_type ORDER BY n DESC;
SELECT season, COUNT(*) AS n FROM staging.games GROUP BY season ORDER BY season;


/* ---------------------------------------------------------------------
   6) Does Portugal's league exist? (useful for the analysis)
   --------------------------------------------------------------------- */
SELECT competition_id, [name], country_name, [type], sub_type
FROM staging.competitions
WHERE country_name LIKE '%Portugal%' OR [name] LIKE '%Liga Portugal%';
