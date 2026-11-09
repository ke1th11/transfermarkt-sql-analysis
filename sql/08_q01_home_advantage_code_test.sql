/* Question: How has home advantage evolved across top 15 football leagues, according to Global Football Rankings, and seasons, and to what extent did the COVID-19 pandemic affect this advantage?
   Approach: tables used and logic in one or two lines
   Insight: (written after seeing the result) 
   Note: The English second division, known as the Championship, will not be included in this analysis, as there is no data available for it. Consequently, only 14 of the 15 major men’s football leagues worldwide will be considered. */


/* Note: Due to a lack of data required for the analysis of the period corresponding to the COVID-19 pandemic (seasons 2019/2020 and 2020/2021), professional football leagues from the following countries will not be included in the analysis: Brazil, Argentina, Norway, Mexico, the USA, and Colombia.*/

USE TransfermarktDB; 

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
),

CTE_Home_Win_Rate_By_Season AS
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
),

CTE_Home_Win_Rate_By_Season_No_Attendance AS
(
	SELECT DISTINCT
		table3.competition_id,
		season_formatted,
		total_games,
		total_wins,
		total_defeats,
		total_draws,
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
					attendance,
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
										 WHERE is_top15_league = 1 ) AND (season = '2019' OR season = '2020' OR season = '2021') AND (CONVERT(DATE, game_date) > '2020-03-01' AND CONVERT(DATE, game_date) < '2021-05-23') AND attendance IS NULL
			) AS table1
		) AS table2
	) AS table3
),

CTE_Home_Win_Rate_By_Season_Low_Attendance AS
(
	SELECT DISTINCT
		table3.competition_id,
		season_formatted,
		total_games,
		total_wins,
		total_defeats,
		total_draws,
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
					attendance,
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
										 WHERE is_top15_league = 1 ) AND (season = '2019' OR season = '2020' OR season = '2021') AND (CONVERT(DATE, game_date) > '2020-03-01' AND CONVERT(DATE, game_date) < '2021-05-23') 
			) AS table1
		) AS table2
	) AS table3
)

SELECT
    S.competition_id,
    S.season_formatted,
    S.[home_win_rate (%)],
	L.[home_win_rate (%)] AS 'home_win_rate_low_att (%)', 
	N.[home_win_rate (%)] AS 'home_win_rate_no_att (%)'
FROM CTE_Home_Win_Rate_By_Season AS S
LEFT JOIN CTE_Home_Win_Rate_By_Season_Low_Attendance AS L
ON S.competition_id = L.competition_id AND S.season_formatted = L.season_formatted
LEFT JOIN CTE_Home_Win_Rate_By_Season_No_Attendance AS N
ON S.competition_id = N.competition_id AND S.season_formatted = N.season_formatted
ORDER BY competition_id, season_formatted;


/*

BE1: 2020-03-07 a 2021-04-18 e 2021-12-26 a 2022-01-27
ES1: 2020-03-10 a 2021-05-23
FR1: 2020-08-21 a 2021-05-23
GB1: 2020-06-17 a 2021-05-23
IT1: 2020-03-08 a 2021-05-23
L1: 2020-03-11 a 2021-05-22 e 2021-11-28 a 2022-02-27
NL1: 2020-10-02 a 2021-05-16 e 2021-11-20 a 2022-01-23
PO1: 2020-06-03 a 2021-05-19

*/