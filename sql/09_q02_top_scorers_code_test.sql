/* Question: Quais os melhores marcadores por época em cada liga principal? Maior sequência de jogos a marcar? A média de minutos para marcar? Qual foi o aumento do seu valor de mercado durante essa época?
*/

/*
SELECT *
FROM clean.players

SELECT *
FROM clean.games

SELECT *
FROM clean.club_games

SELECT *
FROM clean.player_valuations

SELECT *
FROM clean.competitions

SELECT *
FROM clean.appearances

SELECT *
FROM clean.clubs*/


USE TransfermarktDB;

WITH CTE_Players_Stats_By_Season AS 
(
	SELECT
		p.player_name,
		cl.club_name,
		a.competition_id,
		CASE
			WHEN g.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), g.season + 1)
			ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
		END AS season_formatted,
		SUM(a.goals) AS total_goals,
		SUM(a.assists) AS total_assists,
		COUNT(DISTINCT a.game_id) AS total_games,
		SUM(a.minutes_played) AS total_minutes,
		SUM(a.minutes_played) / SUM(a.goals) AS avg_goals_per_min
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
        g.season
),

CTE_Ranking_League_Scorers_By_Season AS 
(
	SELECT 
		s.player_name,
		s.club_name,
		s.competition_id,
		s.season_formatted,
		s.total_goals,
		s.total_assists,
		s.total_games,
		RANK() OVER(PARTITION BY s.competition_id, s.season_formatted ORDER BY s.total_goals DESC) AS Ranking
	FROM CTE_Players_Stats_By_Season AS s
),

/*
CTE_Goal_Sequence_Games_By_Player AS 
(
	SELECT
)*/

SELECT *
FROM CTE_Ranking_League_Scorers_By_Season
WHERE Ranking <= 3
ORDER BY competition_id, season_formatted, Ranking;


