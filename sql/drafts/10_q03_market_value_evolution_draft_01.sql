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
		p.player_name,
		v.club_id,
		cl.club_name,
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
	INNER JOIN clean.clubs AS cl
		ON v.club_id = cl.club_id
	INNER JOIN clean.players AS p
		ON v.player_id = p.player_id
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

	
SELECT 
	mv.player_name,
	mv.club_name,
	ts.club_domestic_competition,
	ts.valuation_date,
	ts.season_formatted,
	ts.market_value_in_eur,
	ts.market_value_diff_throughout_season,
	ts.[market_value_rate_diff_throughout_season (%)]
FROM CTE_Market_Value_Rate_Throughout_Season AS ts
LEFT JOIN CTE_Players_Market_Value AS mv
	ON ts.player_id = mv.player_id; 
/*
SELECT DISTINCT
	mv.player_name,
	mv.club_name,
	u.club_domestic_competition,
	u.season_formatted,
	u.first_market_value,
	u.last_market_value,
	u.market_value_abs_diff,
	u.[market_value_rate_diff (%)]
FROM CTE_Biggest_Rate_Diff_Upgrades AS u
LEFT JOIN CTE_Players_Market_Value AS mv
	ON u.player_id = mv.player_id AND u.season_formatted = mv.season_formatted 
ORDER BY u.season_formatted ASC, u.club_domestic_competition ASC, u.[market_value_rate_diff (%)] DESC*/
/*
SELECT DISTINCT
	mv.player_name,
	mv.club_name,
	d.club_domestic_competition,
	d.season_formatted,
	d.first_market_value,
	d.last_market_value,
	d.market_value_abs_diff,
	d.[market_value_rate_diff (%)]
FROM CTE_Biggest_Rate_Diff_Downgrades AS d
LEFT JOIN CTE_Players_Market_Value AS mv
	ON d.player_id = mv.player_id AND d.season_formatted = mv.season_formatted 
ORDER BY d.season_formatted ASC, d.club_domestic_competition ASC, d.[market_value_rate_diff (%)]*/
/*
SELECT 
	club_name,
	club_domestic_competition,
	season_formatted,
	total_market_value_by_club
FROM (
	SELECT 
		c.club_name,
		bc.club_domestic_competition,
		bc.season_formatted,
		bc.total_market_value_by_club,
		RANK() OVER(PARTITION BY bc.season_formatted, bc.club_domestic_competition ORDER BY bc.total_market_value_by_club DESC) AS ranking_most_valuable_clubs
	FROM CTE_Total_Market_Value_By_Club AS bc
	LEFT JOIN clean.clubs AS c
		ON bc.club_id = c.club_id
) AS t1
WHERE ranking_most_valuable_clubs IN (1,2,3)*/
/*
SELECT 
		club_name,
		club_domestic_competition,
		season_formatted,
		total_market_value_by_club,
		market_value_abs_diff_by_club,
		[market_value_rate_diff_by_club (%)]
FROM (
	SELECT 
		c.club_name,
		d.club_domestic_competition,
		d.season_formatted,
		d.total_market_value_by_club,
		d.market_value_abs_diff_by_club,
		d.[market_value_rate_diff_by_club (%)],
		RANK() OVER(PARTITION BY d.season_formatted, d.club_domestic_competition ORDER BY d.[market_value_rate_diff_by_club (%)] DESC) AS ranking_biggest_market_value_increases
	FROM CTE_Market_Value_Diff_By_Club as d
	LEFT JOIN clean.clubs AS c
		ON d.club_id = c.club_id
) AS t1
WHERE ranking_biggest_market_value_increases IN (1,2,3)*/
/*
SELECT 
		club_name,
		club_domestic_competition,
		season_formatted,
		total_market_value_by_club,
		market_value_abs_diff_by_club,
		[market_value_rate_diff_by_club (%)]
FROM (
	SELECT 
		c.club_name,
		d.club_domestic_competition,
		d.season_formatted,
		d.total_market_value_by_club,
		d.market_value_abs_diff_by_club,
		d.[market_value_rate_diff_by_club (%)],
		RANK() OVER(PARTITION BY d.season_formatted, d.club_domestic_competition ORDER BY d.[market_value_rate_diff_by_club (%)] ASC) AS ranking_biggest_market_value_decreases
	FROM CTE_Market_Value_Diff_By_Club as d
	LEFT JOIN clean.clubs AS c
		ON d.club_id = c.club_id
) AS t1
WHERE ranking_biggest_market_value_decreases IN (1,2,3)*/

