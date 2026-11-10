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
)


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

