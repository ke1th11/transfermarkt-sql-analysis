
/*
WITH CTE_Players_Stats_By_Season AS 
(
	SELECT
		a.player_id,
		p.player_name,
		cl.club_name,
		a.competition_id,
		a.game_id,
		g.season,
		CASE
			WHEN g.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), g.season + 1)
			ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
		END AS season_formatted,
		SUM(a.goals) AS total_goals,
		SUM(a.assists) AS total_assists,
		COUNT(DISTINCT a.game_id) AS total_games,
		SUM(a.minutes_played) AS total_minutes,
		CASE
			WHEN SUM(a.goals) = 0
				THEN NULL
			ELSE CAST(CAST(SUM(a.minutes_played) AS DECIMAL(10,2)) / SUM(a.goals) AS DECIMAL(10,2)) 
		END AS avg_mins_per_goal
	FROM clean.appearances AS a
	INNER JOIN clean.competitions AS c
		ON a.competition_id = c.competition_id
	INNER JOIN clean.players AS p
		ON a.player_id = p.player_id
	INNER JOIN clean.clubs AS cl
		ON a.player_club_id = cl.club_id
	INNER JOIN clean.games AS g
		ON a.game_id = g.game_id
	WHERE c.is_top15_league = 1 
	GROUP BY
        p.player_id,
        p.player_name,
        cl.club_name,
        a.competition_id,
        g.competition_id,
		a.game_id,
        g.season,
		a.player_id
)
SELECT 
	player_id,
	season_formatted,
	maximum_sequence_len,
	MAX(goals_in_sequence) OVER(PARTITION BY maximum_sequence_len) AS goals_in_sequence_max
FROM (
		SELECT DISTINCT
			player_id,
			season_formatted,
			goals_in_sequence,
			MAX(sequence_len) OVER(PARTITION BY player_id, season) AS maximum_sequence_len
		FROM (
				SELECT
					*,
					SUM(goals) OVER(PARTITION BY player_id, season, sequence_id) AS goals_in_sequence,
					COUNT(sequence_id) OVER(PARTITION BY player_id, season, sequence_id) AS sequence_len
				FROM (
						SELECT 
							*,
							SUM(sequence_beginning) OVER(PARTITION BY player_id, season ORDER BY appearance_date) AS sequence_id
						FROM (
								SELECT
									*,
									CASE 
										WHEN did_he_score_this_game = 1 AND (did_he_score_previous_game = 0 OR did_he_score_previous_game IS NULL)
											THEN 1
										ELSE 0
									END AS sequence_beginning
								FROM (
										SELECT 
											*,
											LAG(did_he_score_this_game) OVER(PARTITION BY player_id, season ORDER BY appearance_date) AS did_he_score_previous_game
										FROM (
											SELECT 
												a.player_id,
												a.appearance_date,
												a.goals,
												s.season,
												s.season_formatted,
												RANK() OVER(PARTITION BY a.player_id, s.season ORDER BY a.appearance_date ASC) AS date_order,
												CASE
													WHEN goals > 0
														THEN 1
													ELSE 0
												END AS did_he_score_this_game
											FROM clean.appearances AS a
											INNER JOIN CTE_Players_Stats_By_Season AS s
												ON s.game_id = a.game_id AND s.player_id = a.player_id
										) AS t1
								) AS t2
						) AS t3
						WHERE did_he_score_this_game = 1
				) AS t4
		) AS t5
) AS t6
WHERE player_id = 10 */


/*================================================================================================================================================================

================================================================================================================================================================*/

/* Question: How has the market value of players evolved over the seasons? 
			 Which players have seen the largest fluctuations? 
			 Which clubs have the highest total market value? 
			 Which clubs have experienced the greatest increase in their market value?
*/

USE TransfermarktDB;

/*SELECT *
FROM clean.player_valuations

SELECT *
FROM clean.competitions;*/

WITH CTE_Players_Market_Value AS
(
	SELECT
		v.player_id,
		v.club_id,
		v.club_domestic_competition,
		v.market_value_in_eur,
		V.valuation_date,
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
	WHERE c.is_top15_league = 1
),

CTE_Market_Value_Over_Seasons AS
(
	SELECT 
		*,
		RANK() OVER(PARTITION BY mv.player_id, mv.season_formatted ORDER BY mv.valuation_date ASC) AS ranking_market_value_order_by_time,
		FIRST_VALUE(mv.market_value_in_eur) OVER(PARTITION BY mv.player_id, mv.season_formatted ORDER BY mv.valuation_date ASC) AS first_market_value,
		LAST_VALUE(mv.market_value_in_eur) OVER(PARTITION BY mv.player_id, mv.season_formatted ORDER BY mv.valuation_date ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_market_value
	FROM CTE_Players_Market_Value AS mv
),

CTE_First_Last_Market_Value AS
(
	SELECT 
		os.player_id,
		os.club_id,
		os.club_domestic_competition,
		os.season_formatted,
		os.first_market_value,
		os.last_market_value
	FROM CTE_Market_Value_Over_Seasons AS os
	WHERE os.ranking_market_value_order_by_time = 1
),

CTE_Market_Value_Rate_By_Season AS
(
	SELECT 
		*,
		fl.last_market_value - fl.first_market_value AS market_value_abs_diff,
		CAST((fl.last_market_value - fl.first_market_value) / NULLIF(fl.first_market_value, 0) * 100 AS DECIMAL(10,2)) AS [market_value_rate_diff (%)]
	FROM CTE_First_Last_Market_Value AS fl
),

CTE_Market_Value_Rate_Throughout_Season AS
(
	SELECT 
		os.player_id,
		os.club_id,
		os.club_domestic_competition,
		os.valuation_date,
		os.season_formatted,
		os.ranking_market_value_order_by_time,
		os.market_value_in_eur,
		os.market_value_in_eur - LAG(os.market_value_in_eur) OVER(PARTITION BY os.player_id, os.season_formatted ORDER BY os.ranking_market_value_order_by_time ASC) AS market_value_diff_throughout_season,
		CAST((os.market_value_in_eur - LAG(os.market_value_in_eur) OVER(PARTITION BY os.player_id, os.season_formatted ORDER BY os.ranking_market_value_order_by_time ASC))  / LAG(os.market_value_in_eur) OVER(PARTITION BY os.player_id, os.season_formatted ORDER BY os.ranking_market_value_order_by_time ASC) * 100 AS DECIMAL(10,2)) AS [market_value_rate_diff_throughout_season (%)]
	FROM CTE_Market_Value_Over_Seasons AS os
),

CTE_Biggest_Rate_Diff_Upgrades AS
(
	SELECT *
	FROM (
		SELECT 
			*,
			DENSE_RANK() OVER(PARTITION BY bs.club_domestic_competition, bs.season_formatted ORDER BY bs.[market_value_rate_diff (%)] DESC) AS ranking_rate_diff
		FROM CTE_Market_Value_Rate_By_Season AS bs
	) AS t1
	WHERE ranking_rate_diff IN (1,2,3) AND [market_value_rate_diff (%)] > 0
),

CTE_Biggest_Rate_Diff_Downgrades AS
(
	SELECT *
	FROM (
		SELECT 
			*,
			DENSE_RANK() OVER(PARTITION BY bs.club_domestic_competition, bs.season_formatted ORDER BY bs.[market_value_rate_diff (%)] ASC) AS ranking_rate_diff
		FROM CTE_Market_Value_Rate_By_Season AS bs
	) AS t1
	WHERE ranking_rate_diff IN (1,2,3) AND [market_value_rate_diff (%)] < 0
),

CTE_Total_Market_Value_By_Club AS
(
	SELECT 
		club_id,
		club_domestic_competition,
		season_formatted,
		SUM(market_value_in_eur) AS total_market_value_by_club
	FROM (
		SELECT *
		FROM (
			SELECT 
				os.player_id,
				os.club_id,
				os.club_domestic_competition,
				os.market_value_in_eur,
				os.valuation_date,
				os.season_formatted,
				RANK() OVER(PARTITION BY os.player_id, os.season_formatted ORDER BY os.valuation_date DESC) AS ranking_valuation_date_most_recent_by_season
			FROM CTE_Market_Value_Over_Seasons AS os
		) AS t1
		WHERE ranking_valuation_date_most_recent_by_season = 1
	) AS t2
	GROUP BY club_id, club_domestic_competition, season_formatted
),

CTE_Market_Value_Diff_By_Club AS
(
SELECT *,
	bc.total_market_value_by_club - LAG(bc.total_market_value_by_club) OVER(PARTITION BY bc.club_id ORDER BY bc.season_formatted ASC) AS market_value_abs_diff_by_club,
	CAST((bc.total_market_value_by_club - LAG(bc.total_market_value_by_club) OVER(PARTITION BY bc.club_id ORDER BY bc.season_formatted ASC)) / LAG(bc.total_market_value_by_club) OVER(PARTITION BY bc.club_id ORDER BY bc.season_formatted ASC) * 100 AS DECIMAL(10,2)) AS [market_value_rate_diff_by_club (%)]
FROM CTE_Total_Market_Value_By_Club AS bc
)