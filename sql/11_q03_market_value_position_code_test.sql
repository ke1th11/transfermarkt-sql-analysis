/*
Question: Market value by age and position: at what age does it peak?
*/

USE TransfermarktDB;

DECLARE @min_initial_value DECIMAL(18,2) = 500000;
DECLARE @first_season INT = 2012;
DECLARE @last_complete_season INT = 2025;

WITH CTE_Valuations_Top15 AS
(
	SELECT
		v.player_id,
		p.player_name,
		v.club_id,
		cl.club_name,
		v.club_domestic_competition,
		v.market_value_in_eur,
		v.valuation_date,
		CASE
			WHEN v.club_domestic_competition IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN YEAR(v.valuation_date)
			WHEN MONTH(v.valuation_date) >= 7
				THEN YEAR(v.valuation_date)
			ELSE YEAR(v.valuation_date) - 1
		END AS season_start_year,
		CASE
			WHEN v.club_domestic_competition IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), YEAR(v.valuation_date))
			WHEN MONTH(v.valuation_date) >= 7
				THEN CONVERT(VARCHAR(4), YEAR(v.valuation_date)) + ' / ' + CONVERT(VARCHAR(4), YEAR(v.valuation_date) + 1)
			ELSE CONVERT(VARCHAR(4), YEAR(v.valuation_date) - 1) + ' / ' + CONVERT(VARCHAR(4), YEAR(v.valuation_date))
		END AS season_formatted
	FROM clean.player_valuations AS v
	INNER JOIN clean.competitions AS c
		ON v.club_domestic_competition = c.competition_id
	INNER JOIN clean.clubs AS cl
		ON v.club_id = cl.club_id
	INNER JOIN clean.players AS p
		ON v.player_id = p.player_id
	WHERE c.is_top15_league = 1
),

CTE_Player_Age_At_Valuation_Date AS
(
	SELECT
		t.player_id,
		t.club_id,
		t.club_domestic_competition,
		t.market_value_in_eur,
		t.season_start_year,
		t.season_formatted,
		p.date_of_birth,
		t.valuation_date,
		DATEDIFF(YEAR, p.date_of_birth, t.valuation_date) - CASE
																WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.date_of_birth, t.valuation_date), p.date_of_birth) > t.valuation_date 
																	THEN 1
																ELSE 0
															END AS age_at_valuation_date
	FROM CTE_Valuations_Top15 AS t
	INNER JOIN clean.players AS p
		ON t.player_id = p.player_id
),

CTE_Times_Played_At_Specific_Position AS
(
	SELECT 
		player_id,
		position AS specific_position,
		COUNT(*) AS times_played_at_specific_position
	FROM staging.game_lineups 
	GROUP BY player_id, position
),

CTE_General_Position_By_Player AS
(
	SELECT 
		sp.player_id,
		sp.specific_position,
		sp.times_played_at_specific_position,
		CASE
			WHEN sp.specific_position IN ('Second Striker', 'Attack', 'Right Winger', 'Left Winger', 'Centre-Forward')
				THEN 'Attack'
			WHEN sp.specific_position IN ('Sweeper', 'Right-Back', 'Defender', 'Centre-Back', 'Left-Back')
				THEN 'Defender'
			WHEN sp.specific_position IN ('Attacking Midfield', 'Left Midfield', 'Right Midfield', 'Central Midfield', 'Defensive Midfield', 'midfield')
				THEN 'Midfield'
			WHEN sp.specific_position = 'Goalkeeper'
				THEN 'Goalkeeper'
			ELSE NULL
		END AS general_position
	FROM CTE_Times_Played_At_Specific_Position	AS sp 
),

CTE_Times_Played_At_General_Position
(
	SELECT
		gp.player_id,
		gp.general_position,
		SUM(gp.times_played_at_specific_position) AS times_played_at_generic_position
	FROM CTE_General_Position_By_Player AS gp
	GROUP BY gp.player_id, gp.general_position
),

CTE_Player

CTE_Market_Value_By_Age_By_Player AS
(
	SELECT
		t.player_id,
		t.club_id,
		t.club_domestic_competition,
		t.market_value_in_eur,
		t.season_start_year,
		t.season_formatted,
		SUM(t.market_value_in_eur) OVER(PARTITION BY )
	FROM CTE_Valuations_Top15 AS t
)


/*
SELECT 
	player_id,
	sub_position,
	COUNT(*) AS n
FROM clean.players
GROUP BY player_id,sub_position
ORDER BY player_id

SELECT 
	player_id,
	position,
	COUNT(*) AS n
FROM staging.game_lineups
GROUP BY player_id, position
ORDER BY player_id

SELECT*
FROM staging.game_lineups

SELECT *
FROM staging.game_lineups
*/
