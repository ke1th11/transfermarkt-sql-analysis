/* =====================================================================
   07_create_clean_facts.sql
   Builds the clean "fact" tables: games, club_games, appearances,
   player_valuations and transfers. Run 06_create_clean_dimensions.sql first.
   It can take a few minutes (appearances has 1.9M rows).

   Decisions applied (see docs/data_quality_notes.md):
   - Text: replace non-breaking spaces (code 160), trim, empty -> NULL
   - Numbers via FLOAT -> INT; dates via TRY_CAST to DATE
   - 2 appearances whose player does not exist are excluded
   - Transfers dated after the snapshot (latest game date) get is_scheduled = 1
   - Clubs found only in transfers/valuations are added to clean.clubs
   - Results (win/draw/loss) are derived from the goals
   Safe to re-run: the fact tables are dropped and rebuilt.
   ===================================================================== */

USE TransfermarktDB;
GO

/* =====================================================================
   0) Add clubs that only appear in transfers / valuations to clean.clubs
   ===================================================================== */
WITH transfer_clubs AS (
    SELECT from_club_id    AS club_id, from_club_name    AS club_name FROM staging.transfers
    UNION ALL
    SELECT to_club_id,                 to_club_name                   FROM staging.transfers
    UNION ALL
    SELECT current_club_id,            current_club_name              FROM staging.player_valuations
),
one_name_per_club AS (
    SELECT TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT) AS club_id,
           MAX(NULLIF(LTRIM(RTRIM(REPLACE(club_name, NCHAR(160), N' '))), N'')) AS club_name
    FROM transfer_clubs
    WHERE TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT) IS NOT NULL
    GROUP BY TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT)
)
INSERT INTO clean.clubs (club_id, club_name, club_type, in_clubs_table)
SELECT o.club_id, o.club_name, 'other (name from transfers)', 0
FROM one_name_per_club o
WHERE NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = o.club_id);
GO

/* =====================================================================
   1) clean.games
   ===================================================================== */
DROP TABLE IF EXISTS clean.games;
CREATE TABLE clean.games (
    game_id                 INT           NOT NULL PRIMARY KEY,
    competition_id          NVARCHAR(20)  NULL,
    season                  INT           NULL,   -- start year (2025 = 2025/26); national tournaments use the year before
    [round]                 NVARCHAR(100) NULL,
    game_date               DATE          NULL,
    home_club_id            INT           NULL,
    away_club_id            INT           NULL,
    home_club_goals         INT           NULL,
    away_club_goals         INT           NULL,
    home_club_position      INT           NULL,
    away_club_position      INT           NULL,
    home_club_manager_name  NVARCHAR(200) NULL,
    away_club_manager_name  NVARCHAR(200) NULL,
    stadium                 NVARCHAR(200) NULL,
    attendance              INT           NULL,
    referee                 NVARCHAR(200) NULL,
    home_club_formation     NVARCHAR(50)  NULL,
    away_club_formation     NVARCHAR(50)  NULL,
    home_club_name          NVARCHAR(200) NULL,
    away_club_name          NVARCHAR(200) NULL,
    aggregate_score         NVARCHAR(50)  NULL,
    -- derived columns (computed from the goals)
    total_goals AS (home_club_goals + away_club_goals) PERSISTED,
    home_result AS (CASE WHEN home_club_goals IS NULL OR away_club_goals IS NULL THEN NULL
                         WHEN home_club_goals > away_club_goals THEN 'Home win'
                         WHEN home_club_goals = away_club_goals THEN 'Draw'
                         ELSE 'Away win' END) PERSISTED
);

INSERT INTO clean.games
    (game_id, competition_id, season, [round], game_date, home_club_id, away_club_id,
     home_club_goals, away_club_goals, home_club_position, away_club_position,
     home_club_manager_name, away_club_manager_name, stadium, attendance, referee,
     home_club_formation, away_club_formation, home_club_name, away_club_name, aggregate_score)
SELECT
    TRY_CAST(TRY_CAST(game_id AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(competition_id, NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(season AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE([round], NCHAR(160), N' '))), N''),
    TRY_CAST([date] AS DATE),
    TRY_CAST(TRY_CAST(home_club_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(away_club_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(home_club_goals AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(away_club_goals AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(home_club_position AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(away_club_position AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(home_club_manager_name, NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(away_club_manager_name, NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(stadium,                NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(attendance AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(referee,                NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(home_club_formation,    NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(away_club_formation,    NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(home_club_name,         NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(away_club_name,         NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE([aggregate],            NCHAR(160), N' '))), N'')
FROM staging.games
WHERE TRY_CAST(TRY_CAST(game_id AS FLOAT) AS INT) IS NOT NULL;
GO

/* =====================================================================
   2) clean.club_games (one row per club per game)
   ===================================================================== */
DROP TABLE IF EXISTS clean.club_games;
CREATE TABLE clean.club_games (
    game_id                INT           NOT NULL,
    club_id                INT           NOT NULL,
    own_goals              INT           NULL,
    own_position           INT           NULL,
    own_manager_name       NVARCHAR(200) NULL,
    opponent_id            INT           NULL,
    opponent_goals         INT           NULL,
    opponent_position      INT           NULL,
    opponent_manager_name  NVARCHAR(200) NULL,
    hosting                NVARCHAR(10)  NULL,   -- Home / Away
    is_win                 BIT           NULL,   -- from the source: 0 = draw or loss
    result AS (CASE WHEN own_goals IS NULL OR opponent_goals IS NULL THEN NULL
                    WHEN own_goals > opponent_goals THEN 'Win'
                    WHEN own_goals = opponent_goals THEN 'Draw'
                    ELSE 'Loss' END) PERSISTED,
    CONSTRAINT PK_club_games PRIMARY KEY (game_id, club_id)
);

INSERT INTO clean.club_games
    (game_id, club_id, own_goals, own_position, own_manager_name, opponent_id,
     opponent_goals, opponent_position, opponent_manager_name, hosting, is_win)
SELECT
    TRY_CAST(TRY_CAST(game_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(own_goals AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(own_position AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(own_manager_name,      NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(opponent_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(opponent_goals AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(opponent_position AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(opponent_manager_name, NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(hosting,               NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(is_win AS FLOAT) AS INT)
FROM staging.club_games
WHERE TRY_CAST(TRY_CAST(game_id AS FLOAT) AS INT) IS NOT NULL
  AND TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT) IS NOT NULL;
GO

/* =====================================================================
   3) clean.appearances (the 2 rows with an unknown player are excluded)
   ===================================================================== */
DROP TABLE IF EXISTS clean.appearances;
CREATE TABLE clean.appearances (
    appearance_id           NVARCHAR(50) NOT NULL PRIMARY KEY,
    game_id                 INT          NOT NULL,
    player_id               INT          NOT NULL,
    player_club_id          INT          NULL,
    player_current_club_id  INT          NULL,
    appearance_date         DATE         NULL,
    competition_id          NVARCHAR(20) NULL,
    yellow_cards            INT          NULL,
    red_cards               INT          NULL,
    goals                   INT          NULL,
    assists                 INT          NULL,
    minutes_played          INT          NULL
);

INSERT INTO clean.appearances WITH (TABLOCK)
SELECT
    NULLIF(LTRIM(RTRIM(REPLACE(a.appearance_id, NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(a.game_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(a.player_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(a.player_club_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(a.player_current_club_id AS FLOAT) AS INT),
    TRY_CAST(a.[date] AS DATE),
    NULLIF(LTRIM(RTRIM(REPLACE(a.competition_id, NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(a.yellow_cards AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(a.red_cards AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(a.goals AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(a.assists AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(a.minutes_played AS FLOAT) AS INT)
FROM staging.appearances a
WHERE EXISTS (SELECT 1 FROM clean.players p
              WHERE p.player_id = TRY_CAST(TRY_CAST(a.player_id AS FLOAT) AS INT));
GO

/* =====================================================================
   4) clean.player_valuations
   ===================================================================== */
DROP TABLE IF EXISTS clean.player_valuations;
CREATE TABLE clean.player_valuations (
    player_id                  INT           NOT NULL,
    valuation_date             DATE          NOT NULL,
    market_value_in_eur        DECIMAL(18,2) NULL,
    club_id                    INT           NULL,
    club_domestic_competition  NVARCHAR(20)  NULL,
    CONSTRAINT PK_player_valuations PRIMARY KEY (player_id, valuation_date)
);

INSERT INTO clean.player_valuations
SELECT
    TRY_CAST(TRY_CAST(player_id AS FLOAT) AS INT),
    TRY_CAST([date] AS DATE),
    TRY_CAST(market_value_in_eur AS DECIMAL(18,2)),
    TRY_CAST(TRY_CAST(current_club_id AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(player_club_domestic_competition_id, NCHAR(160), N' '))), N'')
FROM staging.player_valuations
WHERE TRY_CAST(TRY_CAST(player_id AS FLOAT) AS INT) IS NOT NULL
  AND TRY_CAST([date] AS DATE) IS NOT NULL;
GO

/* =====================================================================
   5) clean.transfers
      is_scheduled = 1 when the date is after the snapshot (latest game date)
      transfer_fee NULL means unknown, NOT zero
   ===================================================================== */
DROP TABLE IF EXISTS clean.transfers;
CREATE TABLE clean.transfers (
    transfer_id          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    player_id            INT           NULL,
    transfer_date        DATE          NULL,
    transfer_season      NVARCHAR(10)  NULL,
    from_club_id         INT           NULL,
    to_club_id           INT           NULL,
    from_club_name       NVARCHAR(200) NULL,
    to_club_name         NVARCHAR(200) NULL,
    transfer_fee         DECIMAL(18,2) NULL,
    market_value_in_eur  DECIMAL(18,2) NULL,
    is_scheduled         BIT           NOT NULL
);

INSERT INTO clean.transfers
    (player_id, transfer_date, transfer_season, from_club_id, to_club_id,
     from_club_name, to_club_name, transfer_fee, market_value_in_eur, is_scheduled)
SELECT
    TRY_CAST(TRY_CAST(player_id AS FLOAT) AS INT),
    TRY_CAST(transfer_date AS DATE),
    NULLIF(LTRIM(RTRIM(REPLACE(transfer_season, NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(from_club_id AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(to_club_id AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(from_club_name, NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(to_club_name,   NCHAR(160), N' '))), N''),
    TRY_CAST(transfer_fee AS DECIMAL(18,2)),
    TRY_CAST(market_value_in_eur AS DECIMAL(18,2)),
    CASE WHEN TRY_CAST(transfer_date AS DATE) > (SELECT MAX(game_date) FROM clean.games)
         THEN 1 ELSE 0 END
FROM staging.transfers;
GO

/* =====================================================================
   6) Checks (run after the script; write the results down)
   ===================================================================== */

-- 6a) Row counts. Expected: games 88958, club_games 177916,
--     appearances 1894348 (2 fewer than staging), player_valuations 656301, transfers 175165
SELECT 'clean.games' AS table_name, COUNT(*) AS row_count FROM clean.games
UNION ALL SELECT 'clean.club_games',        COUNT(*) FROM clean.club_games
UNION ALL SELECT 'clean.appearances',       COUNT(*) FROM clean.appearances
UNION ALL SELECT 'clean.player_valuations', COUNT(*) FROM clean.player_valuations
UNION ALL SELECT 'clean.transfers',         COUNT(*) FROM clean.transfers;

-- 6b) Derived result vs the source is_win flag (expected 0 mismatches)
SELECT COUNT(*) AS is_win_mismatches
FROM clean.club_games
WHERE (is_win = 1 AND result <> 'Win') OR (is_win = 0 AND result = 'Win');

-- 6c) Scheduled transfers (expected about 520 with is_scheduled = 1)
SELECT is_scheduled, COUNT(*) AS n_transfers FROM clean.transfers GROUP BY is_scheduled;

-- 6d) Orphan keys in the clean model (ideally all 0)
SELECT 'games.competition_id -> competitions' AS check_name, COUNT(*) AS orphan_rows
FROM clean.games g WHERE NOT EXISTS (SELECT 1 FROM clean.competitions c WHERE c.competition_id = g.competition_id)
UNION ALL SELECT 'games.home_club_id -> clubs', COUNT(*)
FROM clean.games g WHERE NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = g.home_club_id)
UNION ALL SELECT 'games.away_club_id -> clubs', COUNT(*)
FROM clean.games g WHERE NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = g.away_club_id)
UNION ALL SELECT 'club_games.game_id -> games', COUNT(*)
FROM clean.club_games cg WHERE NOT EXISTS (SELECT 1 FROM clean.games g WHERE g.game_id = cg.game_id)
UNION ALL SELECT 'club_games.club_id -> clubs', COUNT(*)
FROM clean.club_games cg WHERE NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = cg.club_id)
UNION ALL SELECT 'appearances.game_id -> games', COUNT(*)
FROM clean.appearances a WHERE NOT EXISTS (SELECT 1 FROM clean.games g WHERE g.game_id = a.game_id)
UNION ALL SELECT 'appearances.player_club_id -> clubs', COUNT(*)
FROM clean.appearances a WHERE a.player_club_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = a.player_club_id)
UNION ALL SELECT 'player_valuations.player_id -> players', COUNT(*)
FROM clean.player_valuations v WHERE NOT EXISTS (SELECT 1 FROM clean.players p WHERE p.player_id = v.player_id)
UNION ALL SELECT 'transfers.player_id -> players', COUNT(*)
FROM clean.transfers t WHERE NOT EXISTS (SELECT 1 FROM clean.players p WHERE p.player_id = t.player_id)
UNION ALL SELECT 'transfers.from_club_id -> clubs', COUNT(*)
FROM clean.transfers t WHERE t.from_club_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = t.from_club_id)
UNION ALL SELECT 'transfers.to_club_id -> clubs', COUNT(*)
FROM clean.transfers t WHERE t.to_club_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = t.to_club_id);

-- 6e) First preview of an insight: results of home games in the 14 core leagues
SELECT g.home_result,
       COUNT(*) AS n_games,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS pct
FROM clean.games g
JOIN clean.competitions c ON c.competition_id = g.competition_id
WHERE c.is_core_league = 1
GROUP BY g.home_result
ORDER BY n_games DESC;

-- 6f) Peek at the results
SELECT TOP 10 * FROM clean.games ORDER BY game_date DESC, game_id;
SELECT TOP 10 * FROM clean.transfers ORDER BY transfer_date DESC;
