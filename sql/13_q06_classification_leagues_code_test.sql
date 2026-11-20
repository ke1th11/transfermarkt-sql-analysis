/* Question: - Pontos acumulados ao longo da época por equipa (3 por vitória, 1 por empate)
			 - Campeões invictos?
			 - Maior sequência de vitórias?
			 - Maior pontuação da história de cada liga?
			 - Menor pontuação da história de cada liga?
*/

USE TransfermarktDB;

WITH CTE_Games_Of_Interest AS 
(
	SELECT 
		t2.season AS season_start_year,
		CASE
			WHEN t2.domestic_competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), t2.season)
			ELSE CONVERT(VARCHAR(4), t2.season) + ' / ' + CONVERT(VARCHAR(4), t2.season + 1)
		END AS season_formatted,
		t2.*
	FROM (
		SELECT 
			g.game_date,
			g.season,
			t1.*
		FROM (
			SELECT 
				cl.domestic_competition_id,
				cg.*
			FROM clean.club_games AS cg
			INNER JOIN clean.clubs AS cl
				ON cg.club_id = cl.club_id
			) AS t1
		INNER JOIN clean.games AS g
			ON t1.game_id = g.game_id
		INNER JOIN clean.competitions AS c
			ON t1.domestic_competition_id = c.competition_id
		WHERE c.is_top15_league = 1 AND g.competition_id = t1.domestic_competition_id
	) AS t2
),

CTE_Points_By_Club AS 
(
	SELECT 
		*,
		RANK() OVER(PARTITION BY t2.season_formatted, t2.domestic_competition_id ORDER BY t2.total_points DESC, t2.goal_diff DESC) AS classification
	FROM (
		SELECT 
			*,
			3*t1.wins + t1.draws AS total_points,
			t1.goals_scored - t1.goals_suffered AS goal_diff
		FROM (
			SELECT 
				gi.domestic_competition_id,
				gi.club_id,
				gi.season_formatted,
				ISNULL(SUM(CASE 
						WHEN gi.result = 'Win'
							THEN 1
					END 
				), 0) AS wins,
				ISNULL(SUM(CASE 
						WHEN gi.result = 'Draw'
							THEN 1
					END 
				), 0) AS draws,
				ISNULL(SUM(CASE 
						WHEN gi.result = 'Loss'
							THEN 1
					END 
				), 0) AS losses,
				COUNT(*) AS total_games,
				SUM(gi.own_goals) AS goals_scored,
				SUM(gi.opponent_goals) AS goals_suffered
			FROM CTE_Games_Of_Interest AS gi
			GROUP BY gi.domestic_competition_id, gi.club_id, gi.season_formatted
		) AS t1	
	) AS t2
),

CTE_Is_Win_Previous_Game AS
(
	SELECT 
		*,
		LAG(CASE
				WHEN t1.is_win = 1
					THEN 1
				ELSE 0
			END 
		) OVER(PARTITION BY t1.season_formatted, t1.club_id ORDER BY t1.game_date ASC) AS is_win_previous_game
	FROM (
		SELECT 
			*,
			RANK() OVER(PARTITION BY gi.season_formatted, gi.club_id ORDER BY gi.game_date ASC) AS game_order
		FROM CTE_Games_Of_Interest AS gi
	) AS t1
), 

CTE_Sequence_Id AS
(
	SELECT 
		*,
		SUM(
			CASE 
				WHEN pg.is_win = 1 AND (pg.is_win_previous_game = 0 OR pg.is_win_previous_game IS NULL)
					THEN 1
				ELSE 0
			END
		) OVER(PARTITION BY pg.season_formatted, pg.club_id ORDER BY pg.game_date ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_win_sequence_id
	FROM CTE_Is_Win_Previous_Game AS pg
),

CTE_Wins_In_Sequence AS
(
	SELECT 
		si.season_formatted,
		si.domestic_competition_id,
		si.club_id,
		si.total_win_sequence_id,
		COUNT(*) AS wins_in_sequence
	FROM CTE_Sequence_Id AS si
	WHERE si.is_win = 1
	GROUP BY si.season_formatted, si.domestic_competition_id, si.club_id, si.total_win_sequence_id
)

/*
-- Campeões Invictos
SELECT 
	pc.season_formatted,
	pc.domestic_competition_id,
	c.club_name,
	pc.wins,
	pc.draws,
	pc.losses,
	pc.total_points,
	pc.classification
FROM CTE_Points_By_Club AS pc
INNER JOIN clean.clubs AS c
	ON pc.club_id = c.club_id
WHERE pc.total_games > 20 AND pc.losses = 0
*/

/*
-- Maior pontuação da história de cada liga
SELECT 
	t1.season_formatted,
	t1.domestic_competition_id,
	c.club_name,
	t1.wins,
	t1.draws,
	t1.losses,
	t1.goals_scored,
	t1.goals_suffered,
	t1.goal_diff,
	t1.total_games,
	t1.total_points
FROM (
	SELECT 
		pc.*,
		RANK() OVER(PARTITION BY pc.domestic_competition_id ORDER BY pc.total_points DESC) AS top_points
	FROM CTE_Points_By_Club AS pc
	WHERE pc.classification = 1
) AS t1
INNER JOIN clean.clubs AS c
	ON t1.club_id = c.club_id
WHERE t1.top_points = 1
*/

/*
-- Menor pontuação da história de cada liga
SELECT 
	t1.season_formatted,
	t1.domestic_competition_id,
	c.club_name,
	t1.wins,
	t1.draws,
	t1.losses,
	t1.goals_scored,
	t1.goals_suffered,
	t1.goal_diff,
	t1.total_games,
	t1.total_points
FROM (
	SELECT 
		pc.*,
		RANK() OVER(PARTITION BY pc.domestic_competition_id ORDER BY pc.total_points ASC, pc.goal_diff ASC) AS top_points
	FROM CTE_Points_By_Club AS pc
) AS t1
INNER JOIN clean.clubs AS c
	ON t1.club_id = c.club_id
WHERE t1.top_points = 1
*/


-- Top3 maior sequência de vitórias por liga por temporada
SELECT 
	t1.season_formatted,
	t1.domestic_competition_id,
	c.club_name,
	t1.wins_in_sequence
FROM (
	SELECT 
		*,
		ROW_NUMBER() OVER(PARTITION BY ws.season_formatted, ws.domestic_competition_id ORDER BY ws.wins_in_sequence DESC) AS ranking
	FROM CTE_Wins_In_Sequence AS ws
) AS t1
INNER JOIN clean.clubs AS c
	ON t1.club_id = c.club_id
WHERE t1.ranking IN (1,2,3)
ORDER BY t1.season_formatted, t1.domestic_competition_id, t1.wins_in_sequence DESC