/* Question: How has home advantage evolved across top 15 football leagues, according to Global Football Rankings, and seasons, and to what extent did the COVID-19 pandemic affect this advantage?

   Approach: clean.games joined to clean.competitions (is_top15_league = 1). 
			 For each league and season, home win rate = home wins / games played (GROUP BY).
             The COVID periods (empty or limited stadiums) are defined per league in CTE_Covid_Periods:
             - low attendance = all games played inside the league's period (empty or limited stadiums)
             - no attendance  = games inside the period with attendance NULL or 0 (empty stadiums)

   Insight: In the 8 leagues with full history (2012/13 to 2025/26), the home win rate was stable before the pandemic: between 44.7% and 47.9% per season, 45.8% on average. 
			In 2020/21, when almost every game was played without fans, it fell to about 40% (-5.5 pp), below the lowest pre-pandemic season, and the drop appears in all 8 leagues (from -3.7 pp in the Bundesliga to -7.8 pp in the Premier League and Ligue 1). 
			In about 3,100 games played in empty stadiums (2019/20 restart, 2020/21 and the 2021/22 waves) the home win rate was about 39.7%, against about 48% in roughly 300 games played with limited crowds, which suggests that even a small crowd restores most of the home advantage. 
			After the pandemic the rate went back to 45.9% in 2022/23, but it has stayed slightly lower since (about 43% in the last three seasons). That difference is small and not enough to claim a lasting change. 
			Limitation: this is an observational comparison and it cannot separate fans' absence from other pandemic-related changes.

   Note: The English second division, known as the Championship, will not be included in this analysis, as there is no data available for it. Consequently, only 14 of the 15 major men's football leagues worldwide will be considered. 
   Note: Due to a lack of data required for the analysis of the period corresponding to the COVID-19 pandemic (seasons 2019/2020 and 2020/2021), professional football leagues from the following countries will not be included in the analysis: Brazil, Argentina, Norway, Mexico, the USA, and Colombia.
   Note: Seasons with few games (e.g. the latest season of calendar-year leagues, still in progress when the data was downloaded) are partial. Check the total_games columns. */

USE TransfermarktDB;

WITH CTE_Covid_Periods AS
(
	SELECT
		competition_id,
		CAST(period_start AS DATE) AS period_start,
		CAST(period_end AS DATE) AS period_end
	FROM (VALUES
		('BE1', '2020-03-07', '2021-05-23'),
		('BE1', '2021-12-26', '2022-01-27'),
		('ES1', '2020-03-10', '2021-05-23'),
		('FR1', '2020-08-21', '2021-05-23'),
		('GB1', '2020-06-17', '2021-05-23'),
		('IT1', '2020-03-08', '2021-05-23'),
		('L1',  '2020-03-11', '2021-05-22'),
		('L1',  '2021-11-28', '2022-03-03'),
		('NL1', '2020-10-02', '2021-05-16'),
		('NL1', '2021-11-20', '2022-01-23'),
		('PO1', '2020-06-03', '2021-05-19')
	) AS p (competition_id, period_start, period_end)
),

CTE_Games_Base AS
(
	SELECT
		g.game_id,
		g.competition_id,
		g.game_date,
		g.home_result,
		g.attendance,
		CASE
			WHEN g.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), g.season + 1)
			ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
		END AS season_formatted
	FROM clean.games AS g
	INNER JOIN clean.competitions AS c
		ON c.competition_id = g.competition_id
	WHERE c.is_top15_league = 1
),

CTE_Home_Win_Rate_By_Season AS
(
	SELECT
		competition_id,
		season_formatted,
		COUNT(*) AS total_games,
		CAST(SUM(CASE WHEN home_result = 'Home win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_win_rate (%)],
		CAST(SUM(CASE WHEN home_result = 'Away win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_defeat_rate (%)],
		CAST(SUM(CASE WHEN home_result = 'Draw'     THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_draw_rate (%)]
	FROM CTE_Games_Base
	GROUP BY competition_id, season_formatted
),

CTE_Home_Win_Rate_By_Season_Low_Attendance AS
(
	SELECT
		b.competition_id,
		b.season_formatted,
		COUNT(*) AS total_games,
		CAST(SUM(CASE WHEN b.home_result = 'Home win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_win_rate (%)],
		CAST(SUM(CASE WHEN b.home_result = 'Away win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_defeat_rate (%)],
		CAST(SUM(CASE WHEN b.home_result = 'Draw'     THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_draw_rate (%)]
	FROM CTE_Games_Base AS b
	INNER JOIN CTE_Covid_Periods AS p
		ON b.competition_id = p.competition_id AND b.game_date BETWEEN p.period_start AND p.period_end
	GROUP BY b.competition_id, b.season_formatted
),

CTE_Home_Win_Rate_By_Season_No_Attendance AS
(
	SELECT
		b.competition_id,
		b.season_formatted,
		COUNT(*) AS total_games,
		CAST(SUM(CASE WHEN b.home_result = 'Home win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_win_rate (%)],
		CAST(SUM(CASE WHEN b.home_result = 'Away win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_defeat_rate (%)],
		CAST(SUM(CASE WHEN b.home_result = 'Draw'     THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [home_draw_rate (%)]
	FROM CTE_Games_Base AS b
	INNER JOIN CTE_Covid_Periods AS p
		ON b.competition_id = p.competition_id AND b.game_date BETWEEN p.period_start AND p.period_end
	WHERE b.attendance IS NULL OR b.attendance = 0
	GROUP BY b.competition_id, b.season_formatted
)

SELECT
	S.competition_id,
	S.season_formatted,
	S.total_games,
	S.[home_win_rate (%)],
	L.total_games AS total_games_low_att,
	L.[home_win_rate (%)] AS [home_win_rate_low_att (%)],
	N.total_games AS total_games_no_att,
	N.[home_win_rate (%)] AS [home_win_rate_no_att (%)]
FROM CTE_Home_Win_Rate_By_Season AS S
LEFT JOIN CTE_Home_Win_Rate_By_Season_Low_Attendance AS L
	ON S.competition_id = L.competition_id AND S.season_formatted = L.season_formatted
LEFT JOIN CTE_Home_Win_Rate_By_Season_No_Attendance AS N
	ON S.competition_id = N.competition_id AND S.season_formatted = N.season_formatted
ORDER BY S.competition_id, S.season_formatted;