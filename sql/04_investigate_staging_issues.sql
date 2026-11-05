/* =====================================================================
   04_investigate_staging_issues.sql
   Read-only queries to understand the issues found in 03_validate_staging.sql
   before deciding how to clean them. Run one block at a time.
   Write down what you find: it becomes your data-quality notes.
   ===================================================================== */

USE TransfermarktDB;
GO

/* ---------------------------------------------------------------------
   1) The 2 appearances whose player does not exist in players
   --------------------------------------------------------------------- */
SELECT a.appearance_id, a.player_id, a.player_name, a.game_id, a.[date], a.competition_id
FROM staging.appearances a
WHERE NULLIF(a.player_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.players p WHERE p.player_id = a.player_id);


/* ---------------------------------------------------------------------
   2) The 1,214 games whose competition_id is not in competitions
   --------------------------------------------------------------------- */
SELECT g.competition_id, g.competition_type, COUNT(*) AS n_games,
       MIN(g.season) AS first_season, MAX(g.season) AS last_season
FROM staging.games g
WHERE NULLIF(g.competition_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.competitions c WHERE c.competition_id = g.competition_id)
GROUP BY g.competition_id, g.competition_type
ORDER BY n_games DESC;


/* ---------------------------------------------------------------------
   3) The 12,818 games whose home club is not in clubs.
      Hypothesis: national-team games use ids from national_teams.
   --------------------------------------------------------------------- */
SELECT competition_type, home_id_status, COUNT(*) AS n_games
FROM (
    SELECT g.competition_type,
           CASE WHEN EXISTS (SELECT 1 FROM staging.national_teams n
                             WHERE n.national_team_id = g.home_club_id)
                THEN 'id is a national team'
                ELSE 'id not found anywhere'
           END AS home_id_status
    FROM staging.games g
    WHERE NULLIF(g.home_club_id, '') IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM staging.clubs c WHERE c.club_id = g.home_club_id)
) x
GROUP BY competition_type, home_id_status
ORDER BY n_games DESC;

-- Which clubs are missing from the clubs table? (top 20 by number of games)
SELECT TOP 20 g.home_club_id, g.home_club_name, COUNT(*) AS n_games
FROM staging.games g
WHERE NULLIF(g.home_club_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.clubs c WHERE c.club_id = g.home_club_id)
  AND NOT EXISTS (SELECT 1 FROM staging.national_teams n WHERE n.national_team_id = g.home_club_id)
GROUP BY g.home_club_id, g.home_club_name
ORDER BY n_games DESC;


/* ---------------------------------------------------------------------
   4) Dates: what is the latest real data, and are there future dates?
   --------------------------------------------------------------------- */
SELECT 'games' AS table_name,
       MIN(TRY_CAST([date] AS DATE)) AS first_date, MAX(TRY_CAST([date] AS DATE)) AS last_date
FROM staging.games
UNION ALL
SELECT 'appearances', MIN(TRY_CAST([date] AS DATE)), MAX(TRY_CAST([date] AS DATE))
FROM staging.appearances
UNION ALL
SELECT 'player_valuations', MIN(TRY_CAST([date] AS DATE)), MAX(TRY_CAST([date] AS DATE))
FROM staging.player_valuations
UNION ALL
SELECT 'transfers', MIN(TRY_CAST(transfer_date AS DATE)), MAX(TRY_CAST(transfer_date AS DATE))
FROM staging.transfers;

-- Games without a score (scheduled / not played yet?)
SELECT COUNT(*) AS games_without_score,
       MIN(TRY_CAST([date] AS DATE)) AS first_date,
       MAX(TRY_CAST([date] AS DATE)) AS last_date
FROM staging.games
WHERE NULLIF(home_club_goals, '') IS NULL;

-- Transfers per year (look at the most recent years)
SELECT YEAR(TRY_CAST(transfer_date AS DATE)) AS transfer_year, COUNT(*) AS n_transfers
FROM staging.transfers
GROUP BY YEAR(TRY_CAST(transfer_date AS DATE))
ORDER BY transfer_year DESC;

-- Transfers dated after today
SELECT COUNT(*) AS transfers_after_today,
       MIN(TRY_CAST(transfer_date AS DATE)) AS first_date,
       MAX(TRY_CAST(transfer_date AS DATE)) AS last_date
FROM staging.transfers
WHERE TRY_CAST(transfer_date AS DATE) > CAST(GETDATE() AS DATE);


/* ---------------------------------------------------------------------
   5) Coverage by competition: why do 2024 and 2025 have ~10k games
      when previous seasons have ~6k?
   --------------------------------------------------------------------- */
SELECT g.competition_id, c.[name],
       SUM(CASE WHEN g.season = '2023' THEN 1 ELSE 0 END) AS games_2023,
       SUM(CASE WHEN g.season = '2024' THEN 1 ELSE 0 END) AS games_2024,
       SUM(CASE WHEN g.season = '2025' THEN 1 ELSE 0 END) AS games_2025,
       MIN(g.season) AS first_season
FROM staging.games g
LEFT JOIN staging.competitions c ON c.competition_id = g.competition_id
GROUP BY g.competition_id, c.[name]
ORDER BY games_2024 DESC;


/* ---------------------------------------------------------------------
   6) Placeholder text that is not NULL (e.g. 'Missing')
   --------------------------------------------------------------------- */
SELECT 'players.position' AS column_name, COUNT(*) AS missing_text
FROM staging.players WHERE [position] = 'Missing'
UNION ALL SELECT 'players.sub_position', COUNT(*)
FROM staging.players WHERE sub_position = 'Missing'
UNION ALL SELECT 'players.country_of_birth', COUNT(*)
FROM staging.players WHERE country_of_birth = 'Missing'
UNION ALL SELECT 'players.country_of_citizenship', COUNT(*)
FROM staging.players WHERE country_of_citizenship = 'Missing'
UNION ALL SELECT 'players.city_of_birth', COUNT(*)
FROM staging.players WHERE city_of_birth = 'Missing';


/* ---------------------------------------------------------------------
   7) Extra spaces at the start/end of text.
      Note: in SQL Server, 'abc ' = 'abc' is TRUE (trailing spaces are
      ignored in comparisons), so <> would not find them. DATALENGTH counts
      the real size, so it does.
   --------------------------------------------------------------------- */
SELECT 'players.city_of_birth' AS column_name, COUNT(*) AS rows_with_extra_spaces
FROM staging.players
WHERE DATALENGTH(city_of_birth) <> DATALENGTH(LTRIM(RTRIM(city_of_birth)))
UNION ALL SELECT 'players.name', COUNT(*)
FROM staging.players
WHERE DATALENGTH([name]) <> DATALENGTH(LTRIM(RTRIM([name])))
UNION ALL SELECT 'clubs.name', COUNT(*)
FROM staging.clubs
WHERE DATALENGTH([name]) <> DATALENGTH(LTRIM(RTRIM([name])))
UNION ALL SELECT 'games.referee', COUNT(*)
FROM staging.games
WHERE DATALENGTH(referee) <> DATALENGTH(LTRIM(RTRIM(referee)))
UNION ALL SELECT 'games.stadium', COUNT(*)
FROM staging.games
WHERE DATALENGTH(stadium) <> DATALENGTH(LTRIM(RTRIM(stadium)))
UNION ALL SELECT 'games.home_club_name', COUNT(*)
FROM staging.games
WHERE DATALENGTH(home_club_name) <> DATALENGTH(LTRIM(RTRIM(home_club_name)));
