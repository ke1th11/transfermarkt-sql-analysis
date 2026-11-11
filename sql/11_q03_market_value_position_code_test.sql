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

CTE_Times_Played_At_General_Position AS
(
	SELECT
		gp.player_id,
		gp.general_position,
		SUM(gp.times_played_at_specific_position) AS times_played_at_generic_position
	FROM CTE_General_Position_By_Player AS gp
	GROUP BY gp.player_id, gp.general_position
),

CTE_Max_Market_Value_By_Age AS
(
	SELECT
		vd.player_id,
		vd.club_id,
		vd.club_domestic_competition,
		vd.season_formatted,
		vd.age_at_valuation_date,
		MAX(vd.market_value_in_eur) AS max_market_value_by_age
	FROM CTE_Player_Age_At_Valuation_Date AS vd
	GROUP BY vd.player_id,
		vd.club_id,
		vd.club_domestic_competition,
		vd.season_formatted,
		vd.age_at_valuation_date
),

CTE_Max_Market_Value_By_Player AS
(
	SELECT 
		t1.player_id, 
		t1.club_id, 
		t1.club_domestic_competition, 
		t1.season_formatted, 
		t1.age_at_valuation_date,
		t1.max_market_value_by_age
	FROM (
		SELECT 
			ba.player_id, 
			ba.club_id, 
			ba.club_domestic_competition, 
			ba.season_formatted, 
			ba.age_at_valuation_date,
			ba.max_market_value_by_age,
			RANK() OVER(PARTITION BY ba.player_id, ba.age_at_valuation_date ORDER BY ba.max_market_value_by_age DESC, ba.age_at_valuation_date ASC) AS ranking_max_market_value
		FROM CTE_Max_Market_Value_By_Age AS ba
	) AS t1
	WHERE t1.ranking_max_market_value = 1 AND t1.age_at_valuation_date IS NOT NULL
),

CTE_Max_Market_Value AS 
(
	SELECT 
			t1.player_id,
			t1.market_value_in_eur AS max_market_value,
			t1.season_formatted
	FROM (
		SELECT 
			t.player_id,
			t.market_value_in_eur,
			t.season_formatted,
			RANK() OVER(PARTITION BY t.player_id ORDER BY t.market_value_in_eur DESC, t.season_formatted ASC) AS ranking_max_market_value
		FROM CTE_Valuations_Top15 AS t
	) AS t1
	WHERE t1.ranking_max_market_value = 1
)

/*
SELECT
	*,
	CAST(t1.sum_max_market_value_by_age / t1.n_players_by_age AS DECIMAL(10,2)) AS avg_market_value_by_age
FROM (
	SELECT 
		mx.age_at_valuation_date,
		COUNT(mx.age_at_valuation_date) AS n_players_by_age,
		SUM(mx.max_market_value_by_age) AS sum_max_market_value_by_age
	FROM CTE_Max_Market_Value_By_Player AS mx
	GROUP BY mx.age_at_valuation_date
) AS t1*/

SELECT 
	*,
	CAST(t2.sum_max_market_value / t2.n_by_general_position AS DECIMAL(10,2)) AS avg_market_value_by_general_position
FROM (
	SELECT 
		t1.general_position,
		COUNT(t1.general_position) AS n_by_general_position,
		SUM(t1.max_market_value) AS sum_max_market_value
	FROM (
		SELECT DISTINCT
			gp.*,
			mx.max_market_value
		FROM CTE_Times_Played_At_General_Position AS gp
		LEFT JOIN CTE_Max_Market_Value AS mx
			ON gp.player_id = mx.player_id
		WHERE mx.max_market_value IS NOT NULL
	) AS t1
	GROUP BY t1.general_position
) AS t2