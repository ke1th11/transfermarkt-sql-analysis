/* Question: How has home advantage evolved across top 15 football leagues, according to Global Football Rankings, and seasons, and to what extent did the COVID-19 pandemic affect this advantage?
   Approach: tables used and logic in one or two lines
   Insight: (written after seeing the result) 
   Note: The English second division, known as the Championship, will not be included in this analysis, as there is no data available for it. Consequently, only 14 of the 15 major men’s football leagues worldwide will be considered. */


/* Note: Due to a lack of data required for the analysis of the period corresponding to the COVID-19 pandemic (seasons 2019/2020 and 2020/2021), professional football leagues from the following countries will not be included in the analysis: Brazil, Argentina, Norway, Mexico, the USA, and Colombia.*/

USE TransfermarktDB

WITH CTE_Home_Win_Rate_By_Competition AS
(
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
	ORDER BY competition_id ASC
),

CTE_Total_Sales AS
(
	SELECT DISTINCT
		competition_id,
		season_formatted,
		CAST((total_wins * 100.0 / total_games) AS DECIMAL(5,2)) AS 'home_win_rate (%)',
		CAST((total_defeats * 100.0 / total_games) AS DECIMAL(5,2)) AS 'home_defeat_rate (%)',
		CAST((total_draws * 100.0 / total_games) AS DECIMAL(5,2)) AS 'home_draw_rate (%)'
	FROM (
		SELECT
			*,
			COUNT(game_id) OVER(PARTITION BY competition_id, season_formatted) AS total_games,
			COUNT(CASE WHEN win_defeat_draw = 1 THEN 1 END) OVER(PARTITION BY competition_id, season_formatted) AS total_wins,
			COUNT(CASE WHEN win_defeat_draw = -1 THEN 1 END) OVER(PARTITION BY competition_id, season_formatted) AS total_defeats,
			COUNT(CASE WHEN win_defeat_draw = 0 THEN 1 END) OVER(PARTITION BY competition_id, season_formatted) AS total_draws
		FROM (
			SELECT *,
				CASE 
					WHEN home_result = 'Home win' THEN 1
					WHEN home_result = 'Away win' THEN -1
					ELSE 0
				END AS win_defeat_draw
			FROM (
				SELECT 
					game_id,
					competition_id,
					season,
					game_date,
					home_result,
					CASE
						WHEN competition_id = 'GB1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'L1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'ES1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'IT1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'FR1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'BRA1' THEN CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'BE1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'PO1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'ARG1' THEN CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'NO1' THEN CONVERT(VARCHAR, season)
						WHEN competition_id = 'NL1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'MEX1' THEN CONVERT(VARCHAR, season) + ' / ' + CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'MLS1' THEN CONVERT(VARCHAR,CONVERT(INT, season) + 1)
						WHEN competition_id = 'COL1' THEN CONVERT(VARCHAR,CONVERT(INT, season) + 1)
					END AS season_formatted
				FROM clean.games
				WHERE competition_id IN (SELECT 
											competition_id
										 FROM clean.competitions
										 WHERE is_top15_league = 1 )
			) AS table1
		) AS table2
	) AS table3
)

SELECT *
FROM clean.games














SELECT 
	game_id,
	competition_id,
	season,
	home_result
FROM clean.games
WHERE competition_id IN (SELECT 
							competition_id
						FROM clean.competitions
						WHERE is_top15_league = 1 )

SELECT *
FROM clean.competitions
WHERE country_name = 'Germany'

SELECT *
FROM clean.games
WHERE competition_id = 'PO1' AND season = '2019'
ORDER BY game_date ASC