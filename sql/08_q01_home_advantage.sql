/* Question: How has home advantage evolved across top 15 football leagues, according to Global Football Rankings, and seasons, and to what extent did the COVID-19 pandemic affect this advantage?
   Approach: tables used and logic in one or two lines
   Insight: (written after seeing the result) 
   Note: The English second division, known as the Championship, will not be included in this analysis, as there is no data available for it. Consequently, only 14 of the 15 major men’s football leagues worldwide will be considered. */


/* Note: Due to a lack of data required for the analysis of the period corresponding to the COVID-19 pandemic (seasons 2019/2020 and 2020/2021), professional football leagues from the following countries will not be included in the analysis: Brazil, Argentina, Norway, Mexico, the USA, and Colombia.*/

USE TransfermarktDB

SELECT DISTINCT
	table2.competition_id,
	country_name,
	CAST((total_wins * 100.0 / total_games) AS DECIMAL(5,2)) AS 'home_win_rate (%)',
	CAST((total_defeats * 100.0 / total_games) AS DECIMAL(5,2)) AS 'home_defeat_rate (%)',
	CAST((total_draws * 100.0 / total_games) AS DECIMAL(5,2)) AS 'home_draw_rate (%)'
FROM (
	SELECT 
		*,
		COUNT(game_id) OVER(PARTITION BY competition_id) AS total_games,
		COUNT(CASE WHEN win_defeat_draw = 1 THEN 1 END) OVER(PARTITION BY competition_id) AS total_wins,
		COUNT(CASE WHEN win_defeat_draw = -1 THEN 1 END) OVER(PARTITION BY competition_id) AS total_defeats,
		COUNT(CASE WHEN win_defeat_draw = 0 THEN 1 END) OVER(PARTITION BY competition_id) AS total_draws
	FROM (
		SELECT 
			game_id,
			competition_id,
			game_date,
			CASE 
				WHEN home_result = 'Home win' THEN 1
				WHEN home_result = 'Away win' THEN -1
				ELSE 0
			END AS win_defeat_draw
		FROM clean.games
		WHERE competition_id IN (SELECT 
									competition_id
								 FROM clean.competitions
								 WHERE is_top15_league = 1 )
	) AS table1
) AS table2
INNER JOIN clean.competitions
ON table2.competition_id = clean.competitions.competition_id
ORDER BY [home_win_rate (%)] DESC
