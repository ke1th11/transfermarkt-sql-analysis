/* Questions: -- 1. Posição na tabela vs. resultado (a mais forte).
			  -- 2. Lealdade de jogadores.
			  -- 3. % de estrangeiros por liga.
			  -- 4. Idade relativa.
			  -- 5. Formação mais usada (para ver a evolução ao longo das epocas)
			  -- 6. Formações mais usadas de sempre
*/

USE TransfermarktDB;

WITH CTE_Month_Birth AS
(
	SELECT 
		p.player_id,
		p.country_of_citizenship,
		MONTH(p.date_of_birth) AS month_of_birth
	FROM clean.players AS p
	WHERE MONTH(p.date_of_birth) IS NOT NULL
),

CTE_N_Players_By_Month_Of_Birth AS
(
	SELECT 
		country_of_citizenship, 
		mb.month_of_birth,
		COUNT(*) AS n_players
	FROM CTE_Month_Birth AS mb
	WHERE mb.country_of_citizenship IS NOT NULL
	GROUP BY mb.country_of_citizenship, mb.month_of_birth
),

CTE_N_Players_By_Country_Of_Citizenship AS
(
	SELECT 
		p.country_of_citizenship,
		COUNT(*) AS n_players_by_country
	FROM clean.players AS p
	WHERE p.country_of_citizenship IS NOT NULL
	GROUP BY p.country_of_citizenship
),

CTE_Last_Year_Playing AS
(
	SELECT 
		p.player_id,
		p.current_club_id,
		CAST((p.last_season) AS VARCHAR) + '/' + CAST(CAST(p.last_season AS INT) + 1 AS VARCHAR) AS last_season
	FROM clean.players AS p
),


CTE_Club_By_Season AS
(
	SELECT 
		t.player_id,
		t.to_club_id,
		CASE
			WHEN CAST(LEFT(t.transfer_season, 2) AS INT) >= 0 AND CAST(LEFT(t.transfer_season, 2) AS INT) < 50
				THEN CAST(2000 + CAST(LEFT(t.transfer_season, 2) AS INT) AS VARCHAR) + '/' + CAST(2000 + CAST(RIGHT(t.transfer_season, 2) AS INT) AS VARCHAR)
			WHEN CAST(LEFT(t.transfer_season, 2) AS INT) <= 98 AND CAST(LEFT(t.transfer_season, 2) AS INT) > 50
				THEN CAST(1900 + CAST(LEFT(t.transfer_season, 2) AS INT) AS VARCHAR) + '/' + CAST(1900 + CAST(RIGHT(t.transfer_season, 2) AS INT) AS VARCHAR)
			WHEN CAST(LEFT(t.transfer_season, 2) AS INT) = 99
				THEN CAST(1900 + CAST(LEFT(t.transfer_season, 2) AS INT) AS VARCHAR) + '/2000' 
		END AS transfer_season
	FROM clean.transfers AS t
	WHERE t.is_scheduled = 0
),

CTE_Transfer_Events AS
(
    SELECT
        player_id,
        to_club_id,
        transfer_season,
        CAST(LEFT(transfer_season, 4) AS INT) AS season_start_year
    FROM CTE_Club_By_Season

    UNION ALL

    SELECT
        player_id,
        current_club_id,
        last_season,
        CAST(LEFT(last_season, 4) AS INT)
    FROM CTE_Last_Year_Playing
),

CTE_Distinct_Events AS
(
    SELECT DISTINCT
        player_id,
        to_club_id,
        transfer_season,
        season_start_year
    FROM CTE_Transfer_Events
),

CTE_Next_Transfer AS
(
    SELECT
        *,
        LEAD(season_start_year) OVER(
            PARTITION BY player_id
            ORDER BY season_start_year
        ) AS next_transfer_year
    FROM CTE_Distinct_Events
),

CTE_Seasons_Recursive AS
(
    SELECT
        player_id,
        to_club_id,
        season_start_year,
        next_transfer_year
    FROM CTE_Next_Transfer

    UNION ALL

    SELECT
        player_id,
        to_club_id,
        season_start_year + 1,
        next_transfer_year
    FROM CTE_Seasons_Recursive
    WHERE season_start_year + 1 < next_transfer_year
),

CTE_Player_Club_By_Season AS
(
    SELECT DISTINCT
        player_id,
        to_club_id,
        season_start_year,
        CAST(season_start_year AS VARCHAR(4))
            + '/'
            + CAST(season_start_year + 1 AS VARCHAR(4)) AS transfer_season
    FROM CTE_Seasons_Recursive
),

CTE_Clubs_In_First_League_By_Season AS
(
	SELECT 
		g.competition_id,
		c.country_name,
		g.season,
		CASE
			WHEN g.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), g.season)
			ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
		END AS season_formatted,
		g.home_club_id
	FROM clean.games AS g
	INNER JOIN clean.competitions AS c
		ON g.competition_id = c.competition_id
	WHERE c.is_top15_league = 1
	GROUP BY g.competition_id, c.country_name, g.season, g.home_club_id
),

CTE_Player_And_League_Country AS
(
	SELECT 
		cs.player_id,
		mb.country_of_citizenship AS player_country,
		cs.transfer_season,
		fl.country_name AS league_country,
		cs.to_club_id AS club_id
	FROM CTE_Player_Club_By_Season AS cs
	INNER JOIN CTE_Clubs_In_First_League_By_Season AS fl
		ON cs.to_club_id = fl.home_club_id AND cs.season_start_year = fl.season
	INNER JOIN CTE_Month_Birth AS mb
		ON cs.player_id = mb.player_id
),

CTE_Football_Formations AS
(
	SELECT DISTINCT *
	FROM (
		SELECT 
			DISTINCT(g1.home_club_formation) AS formation
		FROM clean.games AS g1

		UNION ALL

		SELECT 
			DISTINCT(g2.away_club_formation)
		FROM clean.games AS g2
	) AS t1
	WHERE LEFT(t1.formation, 8) != 'Starting' 
),

CTE_Formations_By_Game AS
(
	SELECT 
		g.game_id,
		g.competition_id,
		CASE
			WHEN g.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), g.season)
			ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
		END AS season_formatted,
		g.home_club_formation,
		g.away_club_formation
	FROM clean.games AS g
	INNER JOIN clean.competitions AS c
		ON g.competition_id = c.competition_id
	WHERE c.is_top15_league = 1
),

CTE_Games_By_Season AS
(
	SELECT 
		fg.season_formatted,
		fg.competition_id,
		COUNT(*) AS games_by_season
	FROM CTE_Formations_By_Game AS fg
	GROUP BY fg.season_formatted, fg.competition_id
),

CTE_Formations_Every_Game AS
(
	SELECT 
		g.game_id,
		g.home_club_formation,
		g.away_club_formation
	FROM clean.games AS g
),

CTE_Games_Results AS
(
    SELECT 
        g.game_id,
        g.game_date,
        CASE
            WHEN LEN(g.round) = 11
                THEN CAST(LEFT(g.round, 1) AS INT)
            ELSE CAST(LEFT(g.round, 2) AS INT)
        END AS round,
        g.competition_id,
        CASE
            WHEN g.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
                THEN CONVERT(VARCHAR(4), g.season)
            ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
        END AS season_formatted,
        g.home_club_position,
        g.away_club_position,
        g.home_result,
        g.home_club_position - g.away_club_position AS position_diff
    FROM clean.games AS g
    INNER JOIN clean.competitions AS c
        ON g.competition_id = c.competition_id
    WHERE c.is_top15_league = 1
),

CTE_N_Games_By_Position_Diff AS
(
	SELECT 
		gr.season_formatted,
        gr.competition_id,
        gr.position_diff,
        COUNT(*) AS n_games_by_position_diff,
        COUNT(CASE
				WHEN gr.home_result = 'Home win' 
					THEN 1
			  END) AS n_wins_by_position_diff,
        COUNT(CASE
				WHEN gr.home_result = 'Draw' 
					THEN 1
			  END) AS n_draws_by_position_diff,
        COUNT(CASE
				WHEN gr.home_result = 'Away win' 
					THEN 1
			  END) AS n_losses_by_position_diff
    FROM CTE_Games_Results AS gr
    GROUP BY gr.competition_id, gr.season_formatted, gr.position_diff
)

--4. Idade relativa.
/*
SELECT
	t2.country_of_citizenship,
	CASE 
		WHEN t2.month_of_birth = 1
			THEN 'January'
		WHEN t2.month_of_birth = 2
			THEN 'February'
		WHEN t2.month_of_birth = 3
			THEN 'March'
		WHEN t2.month_of_birth = 4
			THEN 'April'
		WHEN t2.month_of_birth = 5
			THEN 'May'
		WHEN t2.month_of_birth = 6
			THEN 'June'
		WHEN t2.month_of_birth = 7
			THEN 'July'
		WHEN t2.month_of_birth = 8
			THEN 'August'
		WHEN t2.month_of_birth = 9
			THEN 'September'
		WHEN t2.month_of_birth = 10
			THEN 'October'
		WHEN t2.month_of_birth = 11
			THEN 'November'
		WHEN t2.month_of_birth = 12
			THEN 'December'
	END AS month_name,
	t2.n_players_expected,
	t2.n_players,
	CAST((CAST(t2.n_players AS DECIMAL(20,2)) / t2.n_players_expected) * 100 AS DECIMAL(20,2)) AS [relative_representation (%)]
FROM (
	SELECT 
		t1.*,
		CAST((CAST(cc.n_players_by_country AS DECIMAL(20,2)) * t1.n_days_by_month) / 365 AS DECIMAL(20,2)) AS n_players_expected
	FROM (
		SELECT 
			np.country_of_citizenship,
			np.month_of_birth,
			np.n_players,
			CASE
				WHEN np.month_of_birth = 1
					THEN 31
				WHEN np.month_of_birth = 2
					THEN 29
				WHEN np.month_of_birth = 3
					THEN 31
				WHEN np.month_of_birth = 4
					THEN 30
				WHEN np.month_of_birth = 5
					THEN 31
				WHEN np.month_of_birth = 6
					THEN 30
				WHEN np.month_of_birth = 7
					THEN 31
				WHEN np.month_of_birth = 8
					THEN 31
				WHEN np.month_of_birth = 9
					THEN 30
				WHEN np.month_of_birth = 10
					THEN 31
				WHEN np.month_of_birth = 11
					THEN 30
				WHEN np.month_of_birth = 12
					THEN 31
			END AS n_days_by_month
		FROM CTE_N_Players_By_Month_Of_Birth AS np
	) AS t1
	INNER JOIN CTE_N_Players_By_Country_Of_Citizenship AS cc
		ON t1.country_of_citizenship = cc.country_of_citizenship
) AS t2
ORDER BY t2.country_of_citizenship, t2.month_of_birth
*/

-- 2. Lealdade de jogadores (10 ou mais anos seguidos no mesmo clube).
/*
SELECT *
FROM (
	SELECT 
		p.player_name,
		c.club_name,
		t2.transfer_season,
		SUM(t2.years_same_club_in_sequence) AS years_in_sequence
	FROM (
		SELECT
			t1.*,
			CASE
				WHEN ISNULL(CAST(LEFT(LEAD(t1.transfer_season) OVER(PARTITION BY t1.player_id ORDER BY t1.transfer_season), 4) AS INT) - CAST(LEFT(t1.transfer_season, 4) AS INT), 1) = 0
					THEN 1
				ELSE ISNULL(CAST(LEFT(LEAD(t1.transfer_season) OVER(PARTITION BY t1.player_id ORDER BY t1.transfer_season), 4) AS INT) - CAST(LEFT(t1.transfer_season, 4) AS INT), 1)
			END AS years_same_club_in_sequence	
		FROM (
			SELECT *
			FROM CTE_Club_By_Season

			UNION ALL

			SELECT *
			FROM CTE_Last_Year_Playing
		) AS t1
	) AS t2
	INNER JOIN clean.players AS p
		ON t2.player_id = p.player_id
	INNER JOIN clean.clubs AS c
		ON t2.to_club_id = c.club_id
	GROUP BY p.player_name, c.club_name, t2.transfer_season
) AS t3
WHERE t3.years_in_sequence >= 10
ORDER BY t3.years_in_sequence DESC
*/

-- 3. % de estrangeiros por liga.
/*
SELECT 
	t1.transfer_season AS season,
	c.competition_id,
	t1.league_country,
	t1.total_foreign_players,
	t1.total_players,
	CAST(CAST(t1.total_foreign_players AS DECIMAL(5,2)) / t1.total_players * 100 AS DECIMAL(5,2)) AS [foreign_players (%)]
FROM (
	SELECT 
		pl.transfer_season,
		pl.league_country,
		COUNT(pl.player_id) AS total_players,
		COUNT(CASE 
			WHEN pl.player_country != pl.league_country
				THEN 1
		END) AS total_foreign_players
	FROM CTE_Player_And_League_Country AS pl
	GROUP BY pl.transfer_season, pl.league_country
) AS t1
INNER JOIN clean.competitions AS c
	ON t1.league_country = c.country_name
WHERE c.is_top15_league = 1
ORDER BY c.competition_id, t1.transfer_season
*/

-- 5. Formação mais usada (para ver a evolução ao longo das epocas)
/*
SELECT 
	t1.season_formatted,
	t1.competition_id,
	t1.formation,
	t1.times_used,
	CAST(CAST(t1.times_used AS DECIMAL(20,2)) / (gs.games_by_season * 2) * 100 AS DECIMAL(20,2)) AS [formation_usage (%)]
FROM (
	SELECT 
		fg.season_formatted,
		fg.competition_id,
		ff.formation,
		COUNT(*) AS times_used
	FROM CTE_Formations_By_Game AS fg
	INNER JOIN CTE_Football_Formations AS ff
		ON fg.home_club_formation = ff.formation OR fg.away_club_formation = ff.formation
	GROUP BY fg.season_formatted, fg.competition_id, ff.formation
) AS t1
INNER JOIN CTE_Games_By_Season AS gs
	ON t1.season_formatted = gs.season_formatted AND t1.competition_id = gs.competition_id
ORDER BY t1.competition_id, t1.season_formatted, [formation_usage (%)] DESC
*/

-- 6. Formações mais usadas de sempre
/*
SELECT
	t1.formation,
	t1.times_used,
	CAST(CAST(t1.times_used AS DECIMAL(20,3)) / (SUM(t1.times_used) OVER()) * 100 AS DECIMAL(20,3)) AS [formation_usage (%)]
FROM (
	SELECT 
		ff.formation,
		COUNT(*) AS times_used
	FROM CTE_Formations_Every_Game AS eg
	INNER JOIN CTE_Football_Formations AS ff
			ON eg.home_club_formation = ff.formation OR eg.away_club_formation = ff.formation
	GROUP BY ff.formation
) AS t1
ORDER BY t1.times_used DESC ,[formation_usage (%)] DESC
*/

-- 1. Posição na tabela vs. resultado (a mais forte).
SELECT 
    ng.season_formatted,
    ng.competition_id,
    ng.position_diff,
    ng.n_games_by_position_diff,
    ng.n_wins_by_position_diff,
    ng.n_draws_by_position_diff,
    ng.n_losses_by_position_diff,
    CAST(CAST(ng.n_wins_by_position_diff AS DECIMAL(20,2)) / ng.n_games_by_position_diff * 100 AS DECIMAL(20,2)) AS [win (%)],
    CAST(CAST(ng.n_draws_by_position_diff AS DECIMAL(20,2)) / ng.n_games_by_position_diff * 100 AS DECIMAL(20,2)) AS [draw (%)],
	CAST(CAST(ng.n_losses_by_position_diff AS DECIMAL(20,2)) / ng.n_games_by_position_diff * 100 AS DECIMAL(20,2)) AS [loss (%)]
FROM CTE_N_Games_By_Position_Diff AS ng
ORDER BY ng.competition_id, ng.season_formatted, ng.position_diff;
