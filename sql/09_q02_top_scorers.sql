/* Question: Who were the top scorers of each major league in each season? 
			 For each of them: 
				What was their longest streak of consecutive games with a goal (and how many goals did it include)
				How many minutes did they need on average to score a goal
				How did their market value change during that season?

   Approach: - CTE_Player_Games: one row per player per league game (appearances in the top 15 leagues), season label built once.
             - CTE_Players_Stats_By_Season: goals, assists, games, minutes and minutes per goal for each player, league and season
               (grouped at season level; the club shown is the one with most appearances that season).
             - CTE_Ranking_League_Scorers_By_Season: RANK() by goals inside each league and season; the top 3 are kept (ties are kept too).
             - Scoring streak (gaps and islands): LAG tells whether the player scored in his previous game. A streak begins when he
               scores after a game without a goal (or in his first game); the running sum of the beginnings gives each streak an id.
               Streaks are measured only for the top 3 scorers, and the longest one is kept (ties: the one with more goals).
             - Market value: last valuation of the season minus last valuation of the previous season.

   Insight: (to be written after running the query)

   Note: The English second division, known as the Championship, is not included, as there is no data available for it.
   Note: Only league games count (domestic leagues of the top 15 list). A streak counts consecutive games in which the player
         appeared: games he did not play do not break it.
   Note: With RANK(), players tied in 3rd place all appear, so a league-season can have more than 3 rows.
   Note: The latest season of calendar-year leagues (2026) was still in progress when the data was downloaded, so it is partial.
   Note: Market value season = July to June for leagues that start in one year and end in the next, and the calendar year for
         calendar-year leagues. The difference is NULL when the player has no valuation in the previous season.
*/

USE TransfermarktDB;

WITH CTE_Player_Games AS
(
	-- Grain: one row per player per league game. Everything else is built from this.
	SELECT
		a.player_id,
		a.game_id,
		a.appearance_date,
		a.player_club_id,
		a.competition_id,
		CASE
			WHEN a.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), g.season + 1)
			ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
		END AS season_formatted,
		a.goals,
		a.assists,
		a.minutes_played
	FROM clean.appearances AS a
	INNER JOIN clean.competitions AS c
		ON a.competition_id = c.competition_id
	INNER JOIN clean.games AS g
		ON a.game_id = g.game_id
	WHERE c.is_top15_league = 1
),

CTE_Player_Club_By_Season AS
(
	-- A player who changed club inside the same league and season would be split in two rows if the club
	-- was part of the GROUP BY, so we keep one club per player and season: the one with most appearances.
	SELECT
		player_id,
		competition_id,
		season_formatted,
		club_name
	FROM (
		SELECT
			pg.player_id,
			pg.competition_id,
			pg.season_formatted,
			cl.club_name,
			ROW_NUMBER() OVER(
				PARTITION BY pg.player_id, pg.competition_id, pg.season_formatted
				ORDER BY COUNT(*) DESC, cl.club_name
			) AS club_order
		FROM CTE_Player_Games AS pg
		INNER JOIN clean.clubs AS cl
			ON pg.player_club_id = cl.club_id
		GROUP BY pg.player_id, pg.competition_id, pg.season_formatted, cl.club_name
	) AS t
	WHERE club_order = 1
),

CTE_Players_Stats_By_Season AS
(
	-- Grain: one row per player, league and season (game_id is NOT in the GROUP BY)
	SELECT
		pg.player_id,
		p.player_name,
		pc.club_name,
		pg.competition_id,
		pg.season_formatted,
		SUM(pg.goals) AS total_goals,
		SUM(pg.assists) AS total_assists,
		COUNT(DISTINCT pg.game_id) AS total_games,
		SUM(pg.minutes_played) AS total_minutes,
		CASE
			WHEN SUM(pg.goals) = 0
				THEN NULL
			ELSE CAST(CAST(SUM(pg.minutes_played) AS DECIMAL(10,2)) / SUM(pg.goals) AS DECIMAL(10,2))
		END AS avg_mins_per_goal
	FROM CTE_Player_Games AS pg
	INNER JOIN clean.players AS p
		ON pg.player_id = p.player_id
	INNER JOIN CTE_Player_Club_By_Season AS pc
		ON pc.player_id = pg.player_id
		AND pc.competition_id = pg.competition_id
		AND pc.season_formatted = pg.season_formatted
	GROUP BY
		pg.player_id,
		p.player_name,
		pc.club_name,
		pg.competition_id,
		pg.season_formatted
),

CTE_Ranking_League_Scorers_By_Season AS
(
	SELECT
		s.player_id,
		s.player_name,
		s.club_name,
		s.competition_id,
		s.season_formatted,
		s.total_goals,
		s.total_assists,
		s.total_games,
		s.avg_mins_per_goal,
		RANK() OVER(PARTITION BY s.competition_id, s.season_formatted ORDER BY s.total_goals DESC) AS ranking
	FROM CTE_Players_Stats_By_Season AS s
),

CTE_Goal_Sequence_Flags AS
(
	-- All games of the top 3 scorers, with a flag for "scored in this game" and "scored in the previous game"
	SELECT
		pg.player_id,
		pg.competition_id,
		pg.season_formatted,
		pg.appearance_date,
		pg.goals,
		CASE WHEN pg.goals > 0 THEN 1 ELSE 0 END AS did_he_score_this_game,
		LAG(CASE WHEN pg.goals > 0 THEN 1 ELSE 0 END) OVER(
			PARTITION BY pg.player_id, pg.competition_id, pg.season_formatted
			ORDER BY pg.appearance_date
		) AS did_he_score_previous_game
	FROM CTE_Player_Games AS pg
	INNER JOIN CTE_Ranking_League_Scorers_By_Season AS r
		ON r.player_id = pg.player_id
		AND r.competition_id = pg.competition_id
		AND r.season_formatted = pg.season_formatted
	WHERE r.ranking <= 3
),

CTE_Goal_Sequence_Id AS
(
	-- A streak begins when he scores after a game without a goal (or in his first game).
	-- The running sum of the beginnings is the same number for every game of the same streak.
	SELECT
		*,
		SUM(CASE
				WHEN did_he_score_this_game = 1
					AND (did_he_score_previous_game = 0 OR did_he_score_previous_game IS NULL)
					THEN 1
				ELSE 0
			END) OVER(
				PARTITION BY player_id, competition_id, season_formatted
				ORDER BY appearance_date
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			) AS sequence_id
	FROM CTE_Goal_Sequence_Flags
),

CTE_Goal_Sequences AS
(
	-- One row per streak: how many games and how many goals
	SELECT
		player_id,
		competition_id,
		season_formatted,
		sequence_id,
		COUNT(*) AS sequence_len,
		SUM(goals) AS goals_in_sequence
	FROM CTE_Goal_Sequence_Id
	WHERE did_he_score_this_game = 1
	GROUP BY player_id, competition_id, season_formatted, sequence_id
),

CTE_Longest_Goal_Sequence AS
(
	-- The longest streak of each player and season (ties: the one with more goals)
	SELECT
		player_id,
		competition_id,
		season_formatted,
		sequence_len AS maximum_sequence_len,
		goals_in_sequence AS goals_in_longest_sequence
	FROM (
		SELECT
			*,
			ROW_NUMBER() OVER(
				PARTITION BY player_id, competition_id, season_formatted
				ORDER BY sequence_len DESC, goals_in_sequence DESC
			) AS sequence_order
		FROM CTE_Goal_Sequences
	) AS t
	WHERE sequence_order = 1
),

CTE_Player_Market_Value_By_Season AS
(
	-- Last valuation of each player in each season, and its difference to the last valuation of the previous season
	SELECT
		player_id,
		season_formatted,
		final_market_value,
		CASE
			WHEN season_start - LAG(season_start) OVER(PARTITION BY player_id ORDER BY season_start) = 1
				THEN final_market_value - LAG(final_market_value) OVER(PARTITION BY player_id ORDER BY season_start)
		END AS market_value_diff
	FROM (
		SELECT
			player_id,
			season_start,
			season_formatted,
			market_value_in_eur AS final_market_value,
			ROW_NUMBER() OVER(PARTITION BY player_id, season_formatted ORDER BY valuation_date DESC) AS valuation_order
		FROM (
			SELECT
				v.player_id,
				v.valuation_date,
				v.market_value_in_eur,
				CASE
					WHEN v.club_domestic_competition IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
						THEN YEAR(v.valuation_date)
					WHEN MONTH(v.valuation_date) >= 7
						THEN YEAR(v.valuation_date)
					ELSE YEAR(v.valuation_date) - 1
				END AS season_start,
				CASE
					WHEN v.club_domestic_competition IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
						THEN CONVERT(VARCHAR(4), YEAR(v.valuation_date))
					WHEN MONTH(v.valuation_date) >= 7
						THEN CONVERT(VARCHAR(4), YEAR(v.valuation_date)) + ' / ' + CONVERT(VARCHAR(4), YEAR(v.valuation_date) + 1)
					ELSE CONVERT(VARCHAR(4), YEAR(v.valuation_date) - 1) + ' / ' + CONVERT(VARCHAR(4), YEAR(v.valuation_date))
				END AS season_formatted
			FROM clean.player_valuations AS v
			WHERE v.market_value_in_eur IS NOT NULL
		) AS t1
	) AS t2
	WHERE valuation_order = 1
)


SELECT
	s.player_name,
	s.club_name,
	s.competition_id,
	s.season_formatted,
	s.ranking,
	s.total_goals,
	s.total_assists,
	s.total_games,
	s.avg_mins_per_goal,
	q.maximum_sequence_len AS longest_scoring_streak_games,
	q.goals_in_longest_sequence AS goals_in_longest_streak,
	m.market_value_diff
FROM CTE_Ranking_League_Scorers_By_Season AS s
LEFT JOIN CTE_Longest_Goal_Sequence AS q
	ON s.player_id = q.player_id
	AND s.competition_id = q.competition_id
	AND s.season_formatted = q.season_formatted
LEFT JOIN CTE_Player_Market_Value_By_Season AS m
	ON s.player_id = m.player_id
	AND s.season_formatted = m.season_formatted
WHERE s.ranking <= 3
ORDER BY s.competition_id, s.season_formatted, s.ranking;