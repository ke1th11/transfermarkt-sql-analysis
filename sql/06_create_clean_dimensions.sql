/* =====================================================================
   06_create_clean_dimensions.sql
   Builds the clean schema and the three "dimension" tables:
   competitions, clubs and players. Facts (games, appearances, transfers...)
   come in the next script.

   Cleaning rules used here (see docs/data_quality_notes.md):
   - Text: replace non-breaking spaces (code 160), trim, empty -> NULL
   - Numbers: TRY_CAST via FLOAT for integers (the CSV has values like 185.0)
   - Dates: TRY_CAST to DATE
   - 'Missing' in players.position -> NULL
   Safe to re-run: the clean tables are dropped and rebuilt.
   ===================================================================== */

USE TransfermarktDB;
GO

IF SCHEMA_ID('clean') IS NULL
    EXEC('CREATE SCHEMA clean');
GO

/* =====================================================================
   1) clean.competitions
   ===================================================================== */
DROP TABLE IF EXISTS clean.competitions;
CREATE TABLE clean.competitions (
    competition_id     NVARCHAR(20)  NOT NULL PRIMARY KEY,
    competition_name   NVARCHAR(200) NULL,
    competition_group  NVARCHAR(50)  NULL,   -- our own classification
    raw_type           NVARCHAR(100) NULL,
    raw_sub_type       NVARCHAR(100) NULL,
    country_name       NVARCHAR(100) NULL,
    is_core_league     BIT           NOT NULL DEFAULT 0,  -- one of the leagues present since 2012
    in_source_table    BIT           NOT NULL             -- 0 = added by us (missing in competitions.csv)
);

-- 1a) From the source table
INSERT INTO clean.competitions
    (competition_id, competition_name, competition_group, raw_type, raw_sub_type, country_name, in_source_table)
SELECT
    NULLIF(LTRIM(RTRIM(REPLACE(competition_id, NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE([name],         NCHAR(160), N' '))), N''),
    CASE
        WHEN [type] = 'domestic_league'                          THEN 'Domestic league'
        WHEN [type] = 'domestic_cup'                             THEN 'Domestic cup'
        WHEN sub_type = 'domestic_super_cup'                     THEN 'Domestic super cup'
        WHEN sub_type = 'play_off'                               THEN 'League play-off'
        WHEN sub_type LIKE 'uefa[_]%' AND sub_type <> 'uefa_euro' THEN 'UEFA club competition'
        WHEN [type] = 'national_team_competition'                THEN 'National team tournament'
        ELSE 'Other'
    END,
    NULLIF(LTRIM(RTRIM(REPLACE([type],        NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(sub_type,      NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(country_name,  NCHAR(160), N' '))), N''),
    1
FROM staging.competitions
WHERE NULLIF(LTRIM(RTRIM(competition_id)), N'') IS NOT NULL;

-- 1b) Competitions that exist in games but not in the source table
--     (identified from the club names, see data_quality_notes.md)
INSERT INTO clean.competitions
    (competition_id, competition_name, competition_group, raw_type, raw_sub_type, country_name, in_source_table)
VALUES
    ('POCP', 'taca-de-portugal',      'Domestic cup',                  NULL, NULL, 'Portugal', 0),
    ('CGB',  'efl-cup-to-confirm',    'Domestic cup',                  NULL, NULL, 'England',  0),
    ('COL1', 'categoria-primera-a',   'Domestic league',               NULL, NULL, 'Colombia', 0),
    ('KLUB', 'fifa-club-world-cup',   'International club tournament', NULL, NULL, NULL,       0),
    ('UKRS', 'ukrainian-super-cup',   'Domestic super cup',            NULL, NULL, 'Ukraine',  0);

-- 1c) Core leagues = domestic leagues that already have games in season 2012
UPDATE c
SET is_core_league = 1
FROM clean.competitions c
WHERE c.competition_group = 'Domestic league'
  AND EXISTS (SELECT 1
              FROM staging.games g
              WHERE g.competition_id = c.competition_id
                AND g.season = '2012');
GO

ALTER TABLE clean.competitions ADD is_top15_league BIT NOT NULL DEFAULT 0;
GO
UPDATE clean.competitions
SET is_top15_league = 1
WHERE competition_id IN ('GB1','L1','ES1','IT1','FR1','BRA1','BE1','PO1',
                         'ARG1','NO1','NL1','MEX1','MLS1','COL1');
GO

/* =====================================================================
   2) clean.clubs
      = clubs table + national teams + clubs found only in games
   ===================================================================== */
DROP TABLE IF EXISTS clean.clubs;
CREATE TABLE clean.clubs (
    club_id                  INT           NOT NULL PRIMARY KEY,
    club_name                NVARCHAR(200) NULL,
    club_type                NVARCHAR(40)  NOT NULL,  -- club / national team / other (name from games)
    domestic_competition_id  NVARCHAR(20)  NULL,
    squad_size               INT           NULL,
    average_age              DECIMAL(4,1)  NULL,
    total_market_value       DECIMAL(18,2) NULL,
    stadium_name             NVARCHAR(200) NULL,
    stadium_seats            INT           NULL,
    in_clubs_table           BIT           NOT NULL   -- 1 = full details come from clubs.csv
);

-- 2a) Clubs from the source table
INSERT INTO clean.clubs
    (club_id, club_name, club_type, domestic_competition_id, squad_size, average_age,
     total_market_value, stadium_name, stadium_seats, in_clubs_table)
SELECT
    TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE([name],        NCHAR(160), N' '))), N''),
    'club',
    NULLIF(LTRIM(RTRIM(REPLACE(domestic_competition_id, NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(squad_size AS FLOAT) AS INT),
    TRY_CAST(average_age AS DECIMAL(4,1)),
    TRY_CAST(total_market_value AS DECIMAL(18,2)),
    NULLIF(LTRIM(RTRIM(REPLACE(stadium_name,  NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(stadium_seats AS FLOAT) AS INT),
    1
FROM staging.clubs
WHERE TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT) IS NOT NULL;

-- 2b) National teams (only ids not already present)
INSERT INTO clean.clubs (club_id, club_name, club_type, in_clubs_table)
SELECT
    TRY_CAST(TRY_CAST(n.national_team_id AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(n.[name], NCHAR(160), N' '))), N''),
    'national team',
    0
FROM staging.national_teams n
WHERE TRY_CAST(TRY_CAST(n.national_team_id AS FLOAT) AS INT) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM clean.clubs c
                  WHERE c.club_id = TRY_CAST(TRY_CAST(n.national_team_id AS FLOAT) AS INT));

-- 2c) Clubs that only appear in games (home or away): take the name from the game
WITH game_clubs AS (
    SELECT home_club_id AS club_id, home_club_name AS club_name FROM staging.games
    UNION ALL
    SELECT away_club_id,            away_club_name            FROM staging.games
),
one_name_per_club AS (
    SELECT TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT) AS club_id,
           MAX(NULLIF(LTRIM(RTRIM(REPLACE(club_name, NCHAR(160), N' '))), N'')) AS club_name
    FROM game_clubs
    WHERE TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT) IS NOT NULL
    GROUP BY TRY_CAST(TRY_CAST(club_id AS FLOAT) AS INT)
)
INSERT INTO clean.clubs (club_id, club_name, club_type, in_clubs_table)
SELECT o.club_id, o.club_name, 'other (name from games)', 0
FROM one_name_per_club o
WHERE NOT EXISTS (SELECT 1 FROM clean.clubs c WHERE c.club_id = o.club_id);
GO

/* =====================================================================
   3) clean.players
   ===================================================================== */
DROP TABLE IF EXISTS clean.players;
CREATE TABLE clean.players (
    player_id                             INT           NOT NULL PRIMARY KEY,
    first_name                            NVARCHAR(200) NULL,
    last_name                             NVARCHAR(200) NULL,
    player_name                           NVARCHAR(300) NULL,
    last_season                           INT           NULL,
    current_club_id                       INT           NULL,
    country_of_birth                      NVARCHAR(100) NULL,
    city_of_birth                         NVARCHAR(200) NULL,
    country_of_citizenship                NVARCHAR(100) NULL,
    date_of_birth                         DATE          NULL,
    sub_position                          NVARCHAR(100) NULL,
    [position]                            NVARCHAR(50)  NULL,
    foot                                  NVARCHAR(20)  NULL,
    height_in_cm                          INT           NULL,
    contract_expiration_date              DATE          NULL,
    agent_name                            NVARCHAR(200) NULL,
    international_caps                    INT           NULL,
    international_goals                   INT           NULL,
    current_national_team_id              INT           NULL,
    current_club_domestic_competition_id  NVARCHAR(20)  NULL,
    current_club_name                     NVARCHAR(200) NULL,
    market_value_in_eur                   DECIMAL(18,2) NULL,
    highest_market_value_in_eur           DECIMAL(18,2) NULL
);

INSERT INTO clean.players
SELECT
    TRY_CAST(TRY_CAST(player_id AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(first_name, NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(last_name,  NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE([name],     NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(last_season AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(current_club_id AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(country_of_birth,       NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(city_of_birth,          NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(country_of_citizenship, NCHAR(160), N' '))), N''),
    TRY_CAST(date_of_birth AS DATE),
    NULLIF(NULLIF(LTRIM(RTRIM(REPLACE(sub_position, NCHAR(160), N' '))), N''), N'Missing'),
    NULLIF(NULLIF(LTRIM(RTRIM(REPLACE([position],   NCHAR(160), N' '))), N''), N'Missing'),
    NULLIF(LTRIM(RTRIM(REPLACE(foot,                NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(height_in_cm AS FLOAT) AS INT),
    TRY_CAST(contract_expiration_date AS DATE),
    NULLIF(LTRIM(RTRIM(REPLACE(agent_name,          NCHAR(160), N' '))), N''),
    TRY_CAST(TRY_CAST(international_caps AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(international_goals AS FLOAT) AS INT),
    TRY_CAST(TRY_CAST(current_national_team_id AS FLOAT) AS INT),
    NULLIF(LTRIM(RTRIM(REPLACE(current_club_domestic_competition_id, NCHAR(160), N' '))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(current_club_name,   NCHAR(160), N' '))), N''),
    TRY_CAST(market_value_in_eur AS DECIMAL(18,2)),
    TRY_CAST(highest_market_value_in_eur AS DECIMAL(18,2))
FROM staging.players
WHERE TRY_CAST(TRY_CAST(player_id AS FLOAT) AS INT) IS NOT NULL;
GO

/* =====================================================================
   4) Checks (run after the script; write the results down)
   ===================================================================== */

-- 4a) Row counts. Expected: competitions = 65 + 5 = 70, players = 50149
SELECT 'clean.competitions' AS table_name, COUNT(*) AS row_count FROM clean.competitions
UNION ALL SELECT 'clean.clubs',   COUNT(*) FROM clean.clubs
UNION ALL SELECT 'clean.players', COUNT(*) FROM clean.players;

-- 4b) Core leagues: expected 14
SELECT competition_id, competition_name FROM clean.competitions WHERE is_core_league = 1 ORDER BY competition_id;

-- 4c) Competition groups
SELECT competition_group, COUNT(*) AS n FROM clean.competitions GROUP BY competition_group ORDER BY n DESC;

-- 4d) Clubs by type
SELECT club_type, COUNT(*) AS n FROM clean.clubs GROUP BY club_type ORDER BY n DESC;

-- 4e) Silent cast failures in clubs: raw value present but NULL after conversion
--     (expected 0; if not, look at the raw format of that column)
SELECT
    SUM(CASE WHEN NULLIF(s.total_market_value, '') IS NOT NULL AND c.total_market_value IS NULL THEN 1 ELSE 0 END) AS failed_total_market_value,
    SUM(CASE WHEN NULLIF(s.squad_size, '')         IS NOT NULL AND c.squad_size         IS NULL THEN 1 ELSE 0 END) AS failed_squad_size,
    SUM(CASE WHEN NULLIF(s.average_age, '')        IS NOT NULL AND c.average_age        IS NULL THEN 1 ELSE 0 END) AS failed_average_age,
    SUM(CASE WHEN NULLIF(s.stadium_seats, '')      IS NOT NULL AND c.stadium_seats      IS NULL THEN 1 ELSE 0 END) AS failed_stadium_seats
FROM staging.clubs s
JOIN clean.clubs c ON c.club_id = TRY_CAST(TRY_CAST(s.club_id AS FLOAT) AS INT);

-- 4f) Players: the non-breaking-space problem is fixed (expected 0 rows)
SELECT COUNT(*) AS cities_with_code_160
FROM clean.players
WHERE city_of_birth LIKE N'%' + NCHAR(160) + N'%';

-- 4g) Players: positions ('Missing' is now NULL)
SELECT [position], COUNT(*) AS n FROM clean.players GROUP BY [position] ORDER BY n DESC;

-- 4h) Peek at the results
SELECT TOP 10 * FROM clean.players ORDER BY player_id;
SELECT TOP 10 * FROM clean.clubs ORDER BY club_id;
