/* Question: Quais os melhores marcadores por época em cada liga principal? Maior sequência de jogos a marcar? A média de minutos para marcar? Qual foi a variação do seu valor de mercado durante essa época?
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
FROM clean.clubs */


USE TransfermarktDB;

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
		s.avg_mins_per_goal,
		s.player_id,
		RANK() OVER(PARTITION BY s.competition_id, s.season_formatted ORDER BY s.total_goals DESC) AS ranking
	FROM CTE_Players_Stats_By_Season AS s
),


CTE_Goal_Sequence_Games_By_Player AS 
(
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
),

CTE_Player_Market_Value_By_Season AS
(
SELECT
	*,
	final_market_value - LAG(final_market_value) OVER(ORDER BY season_formatted) AS market_value_diff
FROM (
		SELECT DISTINCT
			player_id,
			MAX(market_value_in_eur) OVER(PARTITION BY season_formatted) AS final_market_value,
			club_domestic_competition,
			season_formatted
		FROM (
				SELECT 
					*,
					CASE
						WHEN club_domestic_competition NOT IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1') AND MONTH(valuation_date) > '7'
							THEN CONVERT(VARCHAR(4), year) + ' / ' + CONVERT(VARCHAR(4), year + 1)
						WHEN club_domestic_competition NOT IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1') AND MONTH(valuation_date) < '7'
							THEN CONVERT(VARCHAR(4), year - 1) + ' / ' + CONVERT(VARCHAR(4), year )
						ELSE NULL
					END AS season_formatted
				FROM (
						SELECT 
							v.player_id,
							v.valuation_date,
							YEAR(v.valuation_date) AS year,
							v.market_value_in_eur,
							v.club_domestic_competition
						FROM clean.player_valuations AS v
				) AS t1
		) AS t2
		WHERE season_formatted IS NOT NULL
) AS t3
WHERE player_id = 10
)


SELECT 
	s.player_name,
	s.club_name,
	s.competition_id,
	s.season_formatted,
	s.total_goals,
	s.total_assists,
	s.total_games,
	s.avg_mins_per_goal,
	m.market_value_diff
FROM CTE_Ranking_League_Scorers_By_Season AS s
LEFT JOIN CTE_Player_Market_Value_By_Season AS m
	ON s.player_id = m.player_id AND s.season_formatted = m.season_formatted
WHERE s.ranking <= 3
ORDER BY s.competition_id, s.season_formatted, s.ranking;



