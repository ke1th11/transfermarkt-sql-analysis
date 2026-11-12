/* Question: Market value by age and position: at what age does it peak?
			 - How does the market value of a player change with age, for each general position?
			 - At what age does a player reach the highest market value of his career, and does it change with the position?

   Approach: - CTE_Valuations_Top15: valuations of players at clubs of the top 15 leagues, season label built once (same rule as in the other queries).
             - CTE_Player_Age_At_Valuation_Date: exact age (in whole years) at the valuation date; only seasons between @first_season and @last_complete_season.
             - Position: lineup appearances are counted by specific position, mapped to 4 general positions (Goalkeeper, Defender, Midfield, Attack),
               and each player keeps the general position he played the most (ties: alphabetical order), so he is counted only once.
             - CTE_Max_Market_Value_By_Age: highest valuation of each player at each age.
             - CTE_Peak_Market_Value: highest valuation of each player's career (the first time it was reached), with the age and season it happened.
               Only players whose peak is at least @min_peak_value are kept, in every output.
             - Output A: players, average and median value by position and age. Output B: average and median peak age by position.
               Output C: how many players peaked at each age, by position. (Only one final SELECT runs at a time: comment out the others.)

   Insight: (to be written after running the query)

   Note: Only valuations at clubs of the top 15 leagues count; a player's value while at another league is not in the data.
   Note: Peak age is censored by the time window: players still young have not peaked yet and older players may have peaked before @first_season.
		 The peak age must be read with this in mind (check MIN(valuation_date) to see if earlier seasons can be used).
   Note: The position is the one played the most over the whole career (all competitions in game_lineups), not the position at each age.
   Note: Valuations are rounded and often stay flat for a long time, so the "peak" is the first valuation that reached the maximum.
   Note: Ignore ages or positions with few players (for example n_players < 30), as their averages are not reliable.
*/

USE TransfermarktDB;

DECLARE @min_peak_value DECIMAL(18,2) = 500000;
DECLARE @first_season INT = 2012;
DECLARE @last_complete_season INT = 2025;
DECLARE @min_minutes_per_age INT = 900;		
DECLARE @min_minutes_per_season INT = 900
DECLARE @min_ages_observed INT = 3;

WITH CTE_Valuations_Top15 AS
(
	SELECT
		v.player_id,
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
	WHERE c.is_top15_league = 1 AND v.market_value_in_eur IS NOT NULL
),

CTE_Player_Age_At_Valuation_Date AS
(
	SELECT
		t.player_id,
		t.market_value_in_eur,
		t.valuation_date,
		t.season_formatted,
		DATEDIFF(YEAR, p.date_of_birth, t.valuation_date) - CASE
																WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.date_of_birth, t.valuation_date), p.date_of_birth) > t.valuation_date 
																	THEN 1
																ELSE 0
															END AS age_at_valuation_date
	FROM CTE_Valuations_Top15 AS t
	INNER JOIN clean.players AS p
		ON t.player_id = p.player_id
	WHERE t.season_start_year BETWEEN @first_season AND @last_complete_season AND p.date_of_birth IS NOT NULL
),

CTE_Times_Played_At_Specific_Position AS
(
	SELECT 
		player_id,
		position AS specific_position,
		COUNT(*) AS times_played_at_specific_position
	FROM staging.game_lineups 
	WHERE position IS NOT NULL
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
	FROM CTE_Times_Played_At_Specific_Position AS sp 
),

CTE_Times_Played_At_General_Position AS
(
	SELECT
		gp.player_id,
		gp.general_position,
		SUM(gp.times_played_at_specific_position) AS times_played_at_general_position
	FROM CTE_General_Position_By_Player AS gp
	WHERE gp.general_position IS NOT NULL
	GROUP BY gp.player_id, gp.general_position
),

CTE_Main_Position_By_Player AS
(
	SELECT
		t.player_id,
		t.general_position
	FROM (
		SELECT
			gp.player_id,
			gp.general_position,
			ROW_NUMBER() OVER(PARTITION BY gp.player_id ORDER BY gp.times_played_at_general_position DESC, gp.general_position ASC) AS position_order
		FROM CTE_Times_Played_At_General_Position AS gp
	) AS t
	WHERE t.position_order = 1
),

CTE_Max_Market_Value_By_Age AS
(
	SELECT
		vd.player_id,
		vd.age_at_valuation_date,
		MAX(vd.market_value_in_eur) AS max_market_value_by_age
	FROM CTE_Player_Age_At_Valuation_Date AS vd
	GROUP BY vd.player_id, vd.age_at_valuation_date
),

CTE_Peak_Market_Value AS 
(
	SELECT 
		t.player_id,
		t.market_value_in_eur AS max_market_value,
		t.age_at_valuation_date AS peak_age,
		t.season_formatted AS peak_season
	FROM (
		SELECT 
			vd.player_id,
			vd.market_value_in_eur,
			vd.age_at_valuation_date,
			vd.season_formatted,
			ROW_NUMBER() OVER(PARTITION BY vd.player_id ORDER BY vd.market_value_in_eur DESC, vd.valuation_date ASC) AS peak_order
		FROM CTE_Player_Age_At_Valuation_Date AS vd
	) AS t
	WHERE t.peak_order = 1
		AND t.market_value_in_eur >= @min_peak_value
),

CTE_Goal_Participations_By_Player AS
(
	SELECT
		t1.player_id,
		t1.age_at_appearance_date,
		SUM(t1.goals) AS total_goals_by_age,
		SUM(t1.assists) AS total_assists_by_age,
		SUM(t1.goals + t1.assists) AS total_goal_participations_by_age,
		SUM(t1.minutes_played) AS total_minutes_by_age
	FROM (
			SELECT 
				a.player_id,
				a.goals,
				a.assists,
				a.minutes_played,
				DATEDIFF(YEAR, p.date_of_birth, a.appearance_date) - CASE
																		WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.date_of_birth, a.appearance_date), p.date_of_birth) > a.appearance_date
																			THEN 1
																		ELSE 0
																	END AS age_at_appearance_date
			FROM clean.appearances AS a
			INNER JOIN clean.competitions AS c
				ON a.competition_id = c.competition_id
			INNER JOIN clean.players AS p
				ON a.player_id = p.player_id
			WHERE c.is_top15_league = 1
				AND p.date_of_birth IS NOT NULL
	) AS t1
	GROUP BY t1.player_id, t1.age_at_appearance_date
),
 
CTE_Goal_Participations_Per_90_By_Age AS
(
	SELECT
		gp.player_id,
		gp.age_at_appearance_date AS age,
		gp.total_goal_participations_by_age,
		gp.total_minutes_by_age,
		CAST(gp.total_goal_participations_by_age * 90.0 / gp.total_minutes_by_age AS DECIMAL(5,2)) AS goal_participations_per_90,
		COUNT(*) OVER(PARTITION BY gp.player_id) AS n_ages_observed
	FROM CTE_Goal_Participations_By_Player AS gp
	WHERE gp.total_minutes_by_age >= @min_minutes_per_age
),
 
CTE_Peak_Goal_Participations AS
(
	SELECT 
		t1.player_id,
		t1.age,
		t1.goal_participations_per_90
	FROM (
		SELECT 
			pa.player_id,
			pa.age,
			pa.goal_participations_per_90,
			ROW_NUMBER() OVER(PARTITION BY pa.player_id ORDER BY pa.goal_participations_per_90 DESC, pa.total_goal_participations_by_age DESC, pa.age ASC) AS ranking_goal_participations
		FROM CTE_Goal_Participations_Per_90_By_Age AS pa
		WHERE pa.goal_participations_per_90 > 0 AND pa.n_ages_observed >= @min_ages_observed
	) AS t1
	WHERE t1.ranking_goal_participations = 1
),

CTE_Minutes_Played_By_Player AS
(
	SELECT
		t1.player_id,
		t1.player_club_id,
		t1.competition_id,
		t1.season_formatted,
		SUM(t1.minutes_played) AS total_minutes_played_by_season
	FROM (
		SELECT 
			a.player_id,
			a.player_club_id,
			a.competition_id,
			a.minutes_played,
			CASE
				WHEN a.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
					THEN YEAR(a.appearance_date)
				WHEN MONTH(a.appearance_date) >= 7
					THEN YEAR(a.appearance_date)
				ELSE YEAR(a.appearance_date) - 1
			END AS season_start_year,
			CASE
				WHEN a.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
					THEN CONVERT(VARCHAR(4), YEAR(a.appearance_date))
				WHEN MONTH(a.appearance_date) >= 7				
					THEN CONVERT(VARCHAR(4), YEAR(a.appearance_date)) + ' / ' + CONVERT(VARCHAR(4), YEAR(a.appearance_date) + 1)
				ELSE CONVERT(VARCHAR(4), YEAR(a.appearance_date) - 1) + ' / ' + CONVERT(VARCHAR(4), YEAR(a.appearance_date))
			END AS season_formatted
		FROM clean.appearances AS a
		INNER JOIN clean.competitions AS c
			ON a.competition_id = c.competition_id
		WHERE c.is_top15_league = 1
	) AS t1
	GROUP BY t1.player_id, t1.player_club_id, t1.competition_id, t1.season_formatted
	HAVING SUM(t1.minutes_played) > @min_minutes_per_season
)

SELECT 
	p.player_id,
	p.date_of_birth,
	t.season_start_year,
	DATEDIFF(YEAR, p.date_of_birth, DATEFROMPARTS(t.season_start_year,1,1)) AS age_at_start_season
FROM clean.players AS p
INNER JOIN CTE_Valuations_Top15 AS t
	ON p.player_id = t.player_id


/*
SELECT 
	m.player_club_id,
	m.competition_id,
	m.season_formatted,
	CAST(AVG(CAST(m.total_minutes_played_by_season AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS avg_total_minutes_played
FROM CTE_Minutes_Played_By_Player AS m
GROUP BY m.player_club_id,
	m.competition_id,
	m.season_formatted
ORDER BY player_club_id
*/






-- Output A: market value by position and age
/*
SELECT DISTINCT
	mp.general_position,
	ma.age_at_valuation_date AS age,
	COUNT(*) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS n_players,
	CAST(AVG(CAST(ma.max_market_value_by_age AS DECIMAL(18,2))) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS DECIMAL(18,2)) AS avg_market_value,
	CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ma.max_market_value_by_age) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS DECIMAL(18,2)) AS median_market_value
FROM CTE_Max_Market_Value_By_Age AS ma
INNER JOIN CTE_Peak_Market_Value AS pk
	ON ma.player_id = pk.player_id
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON ma.player_id = mp.player_id
ORDER BY general_position, age;
*/


-- Output B: peak age and peak value by position
/*
SELECT DISTINCT
	mp.general_position,
	COUNT(*) OVER(PARTITION BY mp.general_position) AS n_players,
	CAST(AVG(CAST(pk.peak_age AS DECIMAL(5,2))) OVER(PARTITION BY mp.general_position) AS DECIMAL(5,2)) AS avg_peak_age,
	CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pk.peak_age) OVER(PARTITION BY mp.general_position) AS DECIMAL(5,2)) AS median_peak_age,
	CAST(AVG(CAST(pk.max_market_value AS DECIMAL(18,2))) OVER(PARTITION BY mp.general_position) AS DECIMAL(18,2)) AS avg_peak_value
FROM CTE_Peak_Market_Value AS pk
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON pk.player_id = mp.player_id
ORDER BY general_position;
*/


-- Output C: number of players that peaked at each age, by position
/*
SELECT
	mp.general_position,
	pk.peak_age,
	COUNT(*) AS n_players
FROM CTE_Peak_Market_Value AS pk
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON pk.player_id = mp.player_id
GROUP BY mp.general_position, pk.peak_age
ORDER BY mp.general_position, pk.peak_age;
*/

-- Output D: at which age do players have their best goal participations per 90 minutes? (number of players by peak age and position)
/*
SELECT
	mp.general_position,
	pk.age,
	COUNT(*) AS n_players,
	CAST(AVG(pk.goal_participations_per_90) AS DECIMAL(5,2)) AS avg_goal_participations_per_90_at_peak
FROM CTE_Peak_Goal_Participations AS pk
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON pk.player_id = mp.player_id
WHERE mp.general_position != 'Goalkeeper'
GROUP BY mp.general_position, pk.age
ORDER BY mp.general_position, pk.age;
*/
 
-- Output E: age curve, goal participations per 90 minutes by age and position (all qualifying player-ages)
/*
SELECT DISTINCT
	mp.general_position,
	pa.age,
	COUNT(*) OVER(PARTITION BY mp.general_position, pa.age) AS n_players,
	CAST(AVG(pa.goal_participations_per_90) OVER(PARTITION BY mp.general_position, pa.age) AS DECIMAL(5,2)) AS avg_goal_participations_per_90,
	CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pa.goal_participations_per_90) OVER(PARTITION BY mp.general_position, pa.age) AS DECIMAL(5,2)) AS median_goal_participations_per_90
FROM CTE_Goal_Participations_Per_90_By_Age AS pa
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON pa.player_id = mp.player_id
WHERE mp.general_position != 'Goalkeeper'
ORDER BY general_position, age
*/

-- A partir de que idade a variação média passa a ser negativa?
/*
SELECT 
	*,
	t1.avg_market_value - LAG(t1.avg_market_value) OVER(PARTITION BY t1.general_position ORDER BY t1.age ASC) AS avg_market_diff,
	CAST((t1.avg_market_value - LAG(t1.avg_market_value) OVER(PARTITION BY t1.general_position ORDER BY t1.age ASC)) / LAG(t1.avg_market_value) OVER(PARTITION BY t1.general_position ORDER BY t1.age ASC) * 100 AS DECIMAL(5,2)) AS [avg_market_rate_diff (%)],
	t1.median_market_value - LAG(t1.median_market_value) OVER(PARTITION BY t1.general_position ORDER BY t1.age ASC) AS median_market_diff,
	CAST((t1.median_market_value - LAG(t1.median_market_value) OVER(PARTITION BY t1.general_position ORDER BY t1.age ASC)) / LAG(t1.median_market_value) OVER(PARTITION BY t1.general_position ORDER BY t1.age ASC) * 100 AS DECIMAL(5,2)) AS [median_market_rate_diff (%)]
FROM (
	SELECT DISTINCT
		mp.general_position,
		ma.age_at_valuation_date AS age,
		COUNT(*) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS n_players,
		CAST(AVG(CAST(ma.max_market_value_by_age AS DECIMAL(18,2))) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS DECIMAL(18,2)) AS avg_market_value,
		CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ma.max_market_value_by_age) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS DECIMAL(18,2)) AS median_market_value
	FROM CTE_Max_Market_Value_By_Age AS ma
	INNER JOIN CTE_Peak_Market_Value AS pk
		ON ma.player_id = pk.player_id
	INNER JOIN CTE_Main_Position_By_Player AS mp
		ON ma.player_id = mp.player_id
) AS t1
ORDER BY general_position, age
*/