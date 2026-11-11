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
   - player_valuations: the source CSV has the right club NAME per date but,
     in many rows, the CURRENT club's id/competition. The club id is rebuilt
     from a name -> id map (clean.club_name_map) built only from reliable rows
     (id different from the player's current club). Names missing from that
     map fall back to an exact, unique name match with clubs.csv (section 4).
   Safe to re-run: the fact tables are dropped and rebuilt.
   NOTE: section 0b adds rows to clean.clubs without dropping it first, so when
   re-running this script run 06_create_clean_dimensions.sql again beforehand.
   ===================================================================== */

USE TransfermarktDB;
GO

/* =====================================================================
   0a) clean.club_name_map: club name (as written in player_valuations) -> club_id

   Why: in player_valuations.csv, current_club_name is historical (correct for
   each date) but current_club_id / player_club_domestic_competition_id are, in
   many rows, the player's CURRENT club copied to the whole history
   (e.g. Klose: "SV Werder Bremen" with the id of Lazio).
   The copy only ever produces the player's current club id, so rows whose id
   is DIFFERENT from clean.players.current_club_id are reliable. The map keeps,
   per name, the most frequent id among those rows (>= 95% of the rows, >= 3 rows).
   ===================================================================== */
DROP TABLE IF EXISTS clean.club_name_map;
CREATE TABLE clean.club_name_map (
    club_name  NVARCHAR(200) NOT NULL PRIMARY KEY,
    club_id    INT           NOT NULL,
    n_rows     INT           NOT NULL,
    share      DECIMAL(5,3)  NOT NULL
);
GO

WITH reliable AS (
    SELECT
        NULLIF(LTRIM(RTRIM(REPLACE(s.current_club_name, NCHAR(160), N' '))), N'') AS club_name,
        TRY_CAST(TRY_CAST(s.current_club_id AS FLOAT) AS INT)                       AS club_id
    FROM staging.player_valuations AS s
    INNER JOIN clean.players AS p
        ON p.player_id = TRY_CAST(TRY_CAST(s.player_id AS FLOAT) AS INT)
    WHERE p.current_club_id IS NOT NULL
      AND TRY_CAST(TRY_CAST(s.current_club_id AS FLOAT) AS INT) <> p.current_club_id
),
votes AS (
    SELECT club_name, club_id, COUNT(*) AS n,
           SUM(COUNT(*)) OVER (PARTITION BY club_name) AS n_total
    FROM reliable
    WHERE club_name IS NOT NULL
      AND club_id   IS NOT NULL
      AND club_name NOT IN (N'Unknown', N'Without Club', N'Retired', N'Career break')  -- not clubs
    GROUP BY club_name, club_id
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY club_name ORDER BY n DESC, club_id ASC) AS rn
    FROM votes
)
INSERT INTO clean.club_name_map (club_name, club_id, n_rows, share)
SELECT club_name, club_id, n, CAST(n * 1.0 / n_total AS DECIMAL(5,3))
FROM ranked
WHERE rn = 1
  AND n >= 3
  AND n * 1.0 / n_total >= 0.95;
GO

/* =====================================================================
   0b) Add clubs that only appear in transfers / valuations to clean.clubs
       (valuations contribute only through the reliable name -> id map; the raw
        id/name pairs of valuations are NOT used, they are contaminated)
   ===================================================================== */
WITH transfer_clubs AS (
    SELECT from_club_id    AS club_id, from_club_name    AS club_name FROM staging.transfers
    UNION ALL
    SELECT to_club_id,                 to_club_name                   FROM staging.transfers
    UNION ALL
    SELECT CAST(club_id AS NVARCHAR(20)), club_name                    FROM clean.club_name_map
),
one_name_per_club AS (
    SELECT TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT) AS club_id,
           MAX(NULLIF(LTRIM(RTRIM(REPLACE(club_name, NCHAR(160), N' '))), N'')) AS club_name
    FROM transfer_clubs
    WHERE TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT) IS NOT NULL
    GROUP BY TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT)
)
INSERT INTO clean.clubs (club_id, club_name, club_type, in_clubs_table)
SELECT o.club_id, o.club_name, 'other (name from transfers/valuations)', 0
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
      club_id / club_domestic_competition are rebuilt (see 0a):
      - name found in clean.club_name_map -> id from the map
                                             (club_fix_status 'ok_confirmed_by_name'
                                              if it equals the raw id, else 'fixed_by_name')
      - name not in the map but equal to ONE club name of clean.clubs
        (clubs.csv)                          -> that club's id
                                             ('ok_confirmed_by_clubs_table' if it equals
                                              the raw id, else 'fixed_by_clubs_table')
      - otherwise, raw id <> player's current club -> raw id is kept
                                             ('kept_original_reliable')
      - name not in the map, raw id = player's current club  -> NULL
                                             ('unresolved_set_null')
      - Unknown / Without Club / Retired / Career break      -> NULL ('not_a_club')
      Competition = clean.clubs.domestic_competition_id of the final club
      (i.e. the club's CURRENT league; NULL for clubs missing in clubs.csv).
   ===================================================================== */
DROP TABLE IF EXISTS clean.player_valuations;
CREATE TABLE clean.player_valuations (
    player_id                  INT           NOT NULL,
    valuation_date             DATE          NOT NULL,
    market_value_in_eur        DECIMAL(18,2) NULL,
    club_id                    INT           NULL,
    club_domestic_competition  NVARCHAR(20)  NULL,
    club_fix_status            NVARCHAR(40)  NULL,   -- audit: how club_id was obtained
    CONSTRAINT PK_player_valuations PRIMARY KEY (player_id, valuation_date)
);
GO

WITH sv AS (
    SELECT
        TRY_CAST(TRY_CAST(player_id AS FLOAT) AS INT)                                  AS player_id,
        TRY_CAST([date] AS DATE)                                                       AS valuation_date,
        TRY_CAST(market_value_in_eur AS DECIMAL(18,2))                                 AS market_value_in_eur,
        NULLIF(LTRIM(RTRIM(REPLACE(current_club_name, NCHAR(160), N' '))), N'')        AS club_name,
        TRY_CAST(TRY_CAST(current_club_id AS FLOAT) AS INT)                            AS club_id_raw,
        NULLIF(LTRIM(RTRIM(REPLACE(player_club_domestic_competition_id, NCHAR(160), N' '))), N'') AS competition_raw
    FROM staging.player_valuations
    WHERE TRY_CAST(TRY_CAST(player_id AS FLOAT) AS INT) IS NOT NULL
      AND TRY_CAST([date] AS DATE) IS NOT NULL
),
resolved AS (
    SELECT
        sv.player_id, sv.valuation_date, sv.market_value_in_eur, sv.competition_raw,
        CASE
            WHEN sv.club_name IN (N'Unknown', N'Without Club', N'Retired', N'Career break') THEN NULL
            WHEN m.club_id IS NOT NULL THEN m.club_id
            WHEN cn.club_id IS NOT NULL THEN cn.club_id
            WHEN p.current_club_id IS NULL OR sv.club_id_raw <> p.current_club_id THEN sv.club_id_raw
            ELSE NULL
        END AS club_id,
        CASE
            WHEN sv.club_name IN (N'Unknown', N'Without Club', N'Retired', N'Career break') THEN 'not_a_club'
            WHEN m.club_id IS NOT NULL AND m.club_id = sv.club_id_raw THEN 'ok_confirmed_by_name'
            WHEN m.club_id IS NOT NULL THEN 'fixed_by_name'
            WHEN cn.club_id IS NOT NULL AND cn.club_id = sv.club_id_raw THEN 'ok_confirmed_by_clubs_table'
            WHEN cn.club_id IS NOT NULL THEN 'fixed_by_clubs_table'
            WHEN p.current_club_id IS NULL OR sv.club_id_raw <> p.current_club_id THEN 'kept_original_reliable'
            ELSE 'unresolved_set_null'
        END AS club_fix_status
    FROM sv
    LEFT JOIN clean.players       AS p ON p.player_id = sv.player_id
    LEFT JOIN clean.club_name_map AS m ON m.club_name = sv.club_name
    -- second source: club names of clubs.csv that identify ONE club (unique name)
    LEFT JOIN (
        SELECT club_name, MIN(club_id) AS club_id
        FROM clean.clubs
        WHERE in_clubs_table = 1 AND club_name IS NOT NULL
        GROUP BY club_name
        HAVING COUNT(*) = 1
    ) AS cn ON cn.club_name = sv.club_name
)
INSERT INTO clean.player_valuations
    (player_id, valuation_date, market_value_in_eur, club_id, club_domestic_competition, club_fix_status)
SELECT
    r.player_id,
    r.valuation_date,
    r.market_value_in_eur,
    r.club_id,
    CASE
        WHEN r.club_id IS NULL THEN NULL
        WHEN r.club_fix_status = 'kept_original_reliable'
            THEN COALESCE(c.domestic_competition_id, r.competition_raw)
        ELSE c.domestic_competition_id
    END,
    r.club_fix_status
FROM resolved AS r
LEFT JOIN clean.clubs AS c
    ON c.club_id = r.club_id;
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
UNION ALL SELECT 'player_valuations.club_id -> clubs', COUNT(*)
FROM clean.player_valuations v WHERE v.club_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = v.club_id)
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

-- 6f) player_valuations club fix: how each row got its club_id
--     (about: ok_confirmed_by_name 62%, fixed_by_name 31%, unresolved_set_null 4%,
--      not_a_club 1%, *_by_clubs_table <1% together, kept_original_reliable <1%)
SELECT club_fix_status, COUNT(*) AS n,
       CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM clean.player_valuations
GROUP BY club_fix_status
ORDER BY n DESC;

-- 6g) Klose (player 10): expected Werder Bremen (86) -> Bayern (27) -> Lazio (398)
SELECT v.valuation_date, c.club_name, v.club_id, v.club_domestic_competition, v.club_fix_status
FROM clean.player_valuations AS v
LEFT JOIN clean.clubs AS c ON c.club_id = v.club_id
WHERE v.player_id = 10
ORDER BY v.valuation_date;

-- 6h) Valuation rows with a club but no competition (clubs absent from clubs.csv;
--     they drop out of the top-15 analysis, expected about a quarter of the rows)
SELECT COUNT(*) AS rows_club_without_competition
FROM clean.player_valuations
WHERE club_id IS NOT NULL AND club_domestic_competition IS NULL;

-- 6i) Names left unresolved, by impact (review the top ones)
SELECT TOP 30 s.current_club_name, COUNT(*) AS n_rows
FROM clean.player_valuations AS v
INNER JOIN staging.player_valuations AS s
    ON TRY_CAST(TRY_CAST(s.player_id AS FLOAT) AS INT) = v.player_id
   AND TRY_CAST(s.[date] AS DATE) = v.valuation_date
WHERE v.club_fix_status = 'unresolved_set_null'
GROUP BY s.current_club_name
ORDER BY n_rows DESC;

-- 6e) First preview of an insight: results of home games in the 14 core leagues
SELECT g.home_result,
       COUNT(*) AS n_games,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS pct
FROM clean.games g
JOIN clean.competitions c ON c.competition_id = g.competition_id
WHERE c.is_core_league = 1
GROUP BY g.home_result
ORDER BY n_games DESC;

-- 6j) Peek at the results
SELECT TOP 10 * FROM clean.games ORDER BY game_date DESC, game_id;
SELECT TOP 10 * FROM clean.transfers ORDER BY transfer_date DESC;