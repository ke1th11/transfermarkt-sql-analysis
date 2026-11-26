/* Question: League classifications: how do the clubs of the top 15 leagues perform across the seasons, and what are the records of each league?
             A) How many points does each club accumulate along a season (3 per win, 1 per draw)?
             B) Which champions were unbeaten (no losses in a full season)?
             C) What are the longest winning streaks in each league and season?
             D) What is the longest winning streak in the history of each league?
             E) What is the highest number of points in the history of each league?
             F) What is the lowest number of points in the history of each league?

   Approach: - CTE_Games_Of_Interest: one row per club and game played in a top 15 league (clean.club_games + clean.games + clean.competitions).
               The league of a game is the competition of the game itself (g.competition_id), not the current league of the club,
               so clubs that were relegated or promoted keep their games in the league where they were played.
               season_formatted is the label of the season ('2023 / 2024', or just '2023' for the leagues played in a calendar year).
               Each game has its points (3 win, 1 draw, 0 loss) and an is_win flag.
             - CTE_Club_Season_Stats: wins, draws, losses, goals and points by club, league and season.
             - CTE_Points_By_Club: adds the classification (RANK by points, goal difference and goals scored) inside each league and season,
               and is_full_season = 1 when the club played as many games as the longest season of its league (see notes).
             - CTE_Cumulative_Points_By_Game: running total of points by club along a season (games ordered by date), with the matchday number.
             - CTE_Sequence_Id: running count of games that were not a win, by club and season. All the wins between two non-wins
               have the same value, so each value identifies one winning streak (gaps and islands).
             - CTE_Wins_In_Sequence: size, start date and end date of each winning streak.
             - CTE_Best_Streak_By_Club: only the longest streak of each club in each season (ties: the earliest), so a club appears once in the rankings.
             - Output A: points of a club game by game for one league and season (@competition_id and @season_start_year).
             - Output B: champions (classification = 1) with 0 losses in a full season.
             - Output C: top @top_n longest winning streaks by league and season (one streak per club).
             - Output D: longest winning streak of each league in the whole data (ties are kept).
             - Output E: highest number of points of each league in a full season (ties are kept).
             - Output F: lowest number of points of each league in a full season (ties are kept), with the final position of the club.
             (Only one final SELECT runs at a time: comment out the others.)

   Insight: Data window: seasons 2012/13 to 2025/26, so "history" below means this window only (Output A is the 2023/24 Premier League, GB1).

            A) Points along the season (GB1 2023/24)
              - Final table: Manchester City 91, Arsenal 89, Liverpool 82, then a gap of 14 points to Aston Villa (68). At the bottom: Luton 26, Burnley 24
                and Sheffield United 16. Nottingham Forest (36) stayed up, 10 points above Luton.
              - A three-way race: the lead changed hands several times (Man City early, Liverpool roughly between matchdays 16 and 27, Arsenal at the top at matchday 15
                with +6 over City and level at the top at matchday 28).
              - The title was decided in the last 10 games: after 28 games Arsenal and Liverpool had 64 points and City 63, and in the last 10 games City took 28 points,
                Arsenal 25 and Liverpool only 18. A strong finish mattered more than the start.
              - Caution: the matchday is the order of each club's games, not the official round, so the gaps between clubs at a given matchday can be affected by games in hand.

            B) Unbeaten champions
              - Only one in the whole data: Bayer 04 Leverkusen 2023/24 (L1): 34 games, 28 wins, 6 draws, 0 losses, 89 goals for and 24 against, 90 points.
              - No other champion went unbeaten in 14 seasons, even the dominant ones: the record champions in Output E lost between 1 and 2 games
                (Bayern 12/13, PSV 23/24 and Porto 21/22 lost 1; Barcelona 12/13, Juventus 13/14 and Man City 17/18 lost 2).
              - Leverkusen's 90 points are not a points record (Bayern and PSV have 91 in the same 34-game league), so being unbeaten came from the draws, not from more wins.

            C) Longest winning streaks by league and season (top 3 per season, in the output)
              - The typical best streak of a season (median) is highest in GB1 (11.5), then IT1 (10.5), NL1 (10), PO1 (9.5), ES1 (9), FR1 and L1 (8.5) and BE1 (7).
              - Streaks of 13 or more games happened 16 times: GB1 5, NL1 4, L1 3, PO1 2, IT1 1 and FR1 1. None in ES1 or BE1 (the best are 12 and 11).
              - The same clubs own the top spot: Bayern was the best streak of the season in 9 of 14 seasons, PSG and PSV in 8, Barcelona and Benfica in 7, Man City in 6.
                The streaks follow the dominance of a club in the league, more than the strength of the league.
              - ARG1, BRA1, COL1, MEX1, MLS1 and NO1 have only 1 or 2 seasons in the data (best streaks of 4 to 9), so they are not comparable with the European leagues.

            D) Longest winning streak in the history of each league (inside one season)
              - L1: Bayern 19 (2013/14). GB1: Man City 18 (2017/18) and Liverpool 18 (2019/20). NL1: PSV 17 (2023/24). PO1: Benfica 16 (2019/20) and Porto 16 (2021/22).
                IT1: Juventus 15 (2015/16). FR1: PSG 14 (2018/19). ES1: Barcelona and Real Madrid 12 (four seasons tied). BE1: Anderlecht 11 (2012/13).
              - The Spanish record is the lowest of the big five leagues: it is the most balanced at the top, with no streak above 12 in 14 seasons.
              - Records outside Europe: MLS1 Charlotte 9, NO1 Tromsø and Viking 9, ARG1 Huracán 6, COL1 Independiente Medellín 6, MEX1 Guadalajara 6, BRA1 5 (three clubs tied).

            E) Highest number of points in the history of each league (full seasons)
              - 38-game leagues: Juventus 102 (IT1 13/14, 33W 3D 2L), Barcelona 100 (ES1 12/13), Man City 100 (GB1 17/18, 106 goals) and PSG 96 (FR1 15/16, only 19 goals against).
              - 34-game leagues: Bayern 91 (L1 12/13), PSV 91 (NL1 23/24) and Porto 91 (PO1 21/22), all with 29 wins. PSV scored 111 goals (+90 goal difference), the highest goal tally in the output.
              - In points per game, Juventus (2.68), Bayern, PSV and Porto (2.68) are in practice tied at the top; Barcelona and Man City have 2.63 and PSG 2.53.
              - Belgium (Union Saint-Gilloise 77 points, 2.26 per game), Brazil (Flamengo 79, 2.08) and MLS (Philadelphia 66, 1.94) have much lower records:
                the champions are less dominant than in the big European leagues.
              - All the records belong to the champion of that season (classification 1).

            F) Lowest number of points in the history of each league (full seasons)
              - 38-game leagues: Southampton 12 (GB1 24/25, 2W 6D 30L, -60 goal difference), Valladolid 16 (ES1 24/25), Salernitana 17 (IT1 23/24), Sport Recife 17 (BRA1) and Troyes 18 (FR1 15/16).
                34-game leagues: Schalke 16 (L1 20/21), Beerschot 16 (BE1 21/22), Aves 17 (PO1 19/20) and Cambuur 18 (NL1 15/16). The lowest of all is Haugesund with 9 points in 30 games (NO1, 2 wins).
              - Southampton, Salernitana, Sport Recife and Haugesund won only 2 games in the season. In points per game Haugesund (0.30) and Southampton (0.32) are the worst.
              - Every record-low club finished in the last position of its league. The exception to the pattern is MLS (D.C. United, 26 points, 11 draws), where there is no relegation.
              - The lowest points are far from the highest ones in every league, but in absolute terms the bottom is closer to zero than the top is to the maximum:
                Southampton had 12 points against 102 of Juventus (the maximum for 38 games is 114).

   Note: The league of a game is the competition of the game (g.competition_id) and only competitions with is_top15_league = 1 are used. It is assumed that
         this flag is only set for domestic leagues (not cups); this should be confirmed in clean.competitions.
   Note: The points are 3 per win and 1 per draw as results of the games. Points deductions, head-to-head tie-breakers and other league rules are not applied,
         so a final classification can differ from the official one.
   Note: The classification uses points, goal difference and goals scored. If two clubs are equal in the three, they share the position (RANK).
   Note: A full season (is_full_season = 1) means that the club played as many games as the maximum of its league in the data.
         It removes the seasons in progress (a club with 10 games would otherwise have the lowest points of the history), but it is a heuristic:
         seasons shortened by external reasons or with a different format are excluded, and leagues with playoffs or split formats (e.g. MLS1, ARG1) should be checked.
   Note: Records of points (E, F) and unbeaten champions (B) only use full seasons, so they are comparable inside the same league.
   Note: The winning streaks restart in each season (a streak between two seasons is not counted) and only league games are used.
   Note: The matchday in output A is the order of the games of each club (1, 2, 3...), not an official round number, so it can differ a little between clubs.
   Note: The most recent season can be incomplete (data snapshot), so it only appears in outputs A and C and in the streaks.
   Note: The "history" of each league is the data window (2012/13 onwards). Older records are not covered (for example the 11 points of Derby County in 2007/08 in the Premier League).
   Note: For BRA1, ARG1, NO1, MLS1 and COL1 the season label is the value of clean.games.season. In the output, games played in 2025 (for example in BRA1 and NO1) appear under 2024,
         so the label of these leagues can be one year behind the calendar year; check season vs game_date in clean.games before quoting these years.
   Note: ARG1, COL1 and MEX1 have a single short tournament per season in the data (16 to 20 games), so their points records are not comparable with leagues of 30 to 38 games.
   Note: The club name of Aves in PO1 comes from the source with a suffix ("Desportivo Aves (- 2020)").
*/

USE TransfermarktDB;

DECLARE @top_n INT = 3;
DECLARE @competition_id VARCHAR(10) = 'GB1';
DECLARE @season_start_year INT = 2023;

WITH CTE_Games_Of_Interest AS
(
	SELECT
		g.competition_id,
		g.season AS season_start_year,
		CASE
			WHEN g.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), g.season)
			ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
		END AS season_formatted,
		g.game_id,
		g.game_date,
		cg.club_id,
		cg.own_goals,
		cg.opponent_goals,
		cg.result,
		CASE WHEN cg.result = 'Win' THEN 1 ELSE 0 END AS is_win,
		CASE cg.result
			WHEN 'Win' THEN 3
			WHEN 'Draw' THEN 1
			ELSE 0
		END AS points
	FROM clean.club_games AS cg
	INNER JOIN clean.games AS g
		ON cg.game_id = g.game_id
	INNER JOIN clean.competitions AS c
		ON g.competition_id = c.competition_id
	WHERE c.is_top15_league = 1
),

CTE_Club_Season_Stats AS
(
	SELECT
		gi.competition_id,
		gi.club_id,
		gi.season_formatted,
		gi.season_start_year,
		COUNT(*) AS total_games,
		SUM(gi.is_win) AS wins,
		SUM(CASE WHEN gi.result = 'Draw' THEN 1 ELSE 0 END) AS draws,
		SUM(CASE WHEN gi.result = 'Loss' THEN 1 ELSE 0 END) AS losses,
		SUM(gi.own_goals) AS goals_scored,
		SUM(gi.opponent_goals) AS goals_suffered,
		SUM(gi.own_goals) - SUM(gi.opponent_goals) AS goal_diff,
		SUM(gi.points) AS total_points
	FROM CTE_Games_Of_Interest AS gi
	GROUP BY gi.competition_id, gi.club_id, gi.season_formatted, gi.season_start_year
),

CTE_Points_By_Club AS
(
	SELECT
		cs.*,
		RANK() OVER(PARTITION BY cs.competition_id, cs.season_start_year ORDER BY cs.total_points DESC, cs.goal_diff DESC, cs.goals_scored DESC) AS classification,
		CASE
			WHEN cs.total_games = MAX(cs.total_games) OVER(PARTITION BY cs.competition_id)
				THEN 1
			ELSE 0
		END AS is_full_season
	FROM CTE_Club_Season_Stats AS cs
),

CTE_Cumulative_Points_By_Game AS
(
	SELECT
		gi.competition_id,
		gi.club_id,
		gi.season_formatted,
		gi.season_start_year,
		gi.game_date,
		gi.points,
		ROW_NUMBER() OVER(PARTITION BY gi.competition_id, gi.club_id, gi.season_start_year ORDER BY gi.game_date ASC, gi.game_id ASC) AS matchday,
		SUM(gi.points) OVER(PARTITION BY gi.competition_id, gi.club_id, gi.season_start_year ORDER BY gi.game_date ASC, gi.game_id ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_points
	FROM CTE_Games_Of_Interest AS gi
),

CTE_Sequence_Id AS
(
	SELECT
		gi.competition_id,
		gi.club_id,
		gi.season_formatted,
		gi.season_start_year,
		gi.game_date,
		gi.is_win,
		SUM(1 - gi.is_win) OVER(PARTITION BY gi.competition_id, gi.club_id, gi.season_start_year ORDER BY gi.game_date ASC, gi.game_id ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS non_win_sequence_id
	FROM CTE_Games_Of_Interest AS gi
),

CTE_Wins_In_Sequence AS
(
	SELECT
		si.competition_id,
		si.club_id,
		si.season_formatted,
		si.season_start_year,
		si.non_win_sequence_id,
		COUNT(*) AS wins_in_sequence,
		MIN(si.game_date) AS sequence_start,
		MAX(si.game_date) AS sequence_end
	FROM CTE_Sequence_Id AS si
	WHERE si.is_win = 1
	GROUP BY si.competition_id, si.club_id, si.season_formatted, si.season_start_year, si.non_win_sequence_id
),

CTE_Best_Streak_By_Club AS
(
	SELECT
		t1.competition_id,
		t1.club_id,
		t1.season_formatted,
		t1.season_start_year,
		t1.wins_in_sequence,
		t1.sequence_start,
		t1.sequence_end
	FROM (
		SELECT
			ws.*,
			ROW_NUMBER() OVER(PARTITION BY ws.competition_id, ws.club_id, ws.season_start_year ORDER BY ws.wins_in_sequence DESC, ws.sequence_start ASC) AS best_streak_order
		FROM CTE_Wins_In_Sequence AS ws
	) AS t1
	WHERE t1.best_streak_order = 1
)


-- Output A: points accumulated along the season by club (one league and one season)
/*
SELECT
	cp.season_formatted,
	cp.competition_id,
	c.club_name,
	cp.matchday,
	cp.game_date,
	cp.points,
	cp.cumulative_points
FROM CTE_Cumulative_Points_By_Game AS cp
INNER JOIN clean.clubs AS c
	ON cp.club_id = c.club_id
WHERE cp.competition_id = @competition_id AND cp.season_start_year = @season_start_year
ORDER BY cp.matchday, cp.cumulative_points DESC;
*/


-- Output B: unbeaten champions
/*
SELECT
	pc.season_formatted,
	pc.competition_id,
	c.club_name,
	pc.total_games,
	pc.wins,
	pc.draws,
	pc.losses,
	pc.goals_scored,
	pc.goals_suffered,
	pc.goal_diff,
	pc.total_points
FROM CTE_Points_By_Club AS pc
INNER JOIN clean.clubs AS c
	ON pc.club_id = c.club_id
WHERE pc.is_full_season = 1 AND pc.classification = 1 AND pc.losses = 0
ORDER BY pc.competition_id, pc.season_start_year;
*/


-- Output C: top @top_n longest winning streaks by league and season
/*
SELECT
	t1.season_formatted,
	t1.competition_id,
	c.club_name,
	t1.wins_in_sequence,
	t1.sequence_start,
	t1.sequence_end,
	t1.ranking_streak
FROM (
	SELECT
		bs.*,
		ROW_NUMBER() OVER(PARTITION BY bs.competition_id, bs.season_start_year ORDER BY bs.wins_in_sequence DESC, bs.sequence_start ASC, bs.club_id ASC) AS ranking_streak
	FROM CTE_Best_Streak_By_Club AS bs
) AS t1
INNER JOIN clean.clubs AS c
	ON t1.club_id = c.club_id
WHERE t1.ranking_streak <= @top_n
ORDER BY t1.competition_id, t1.season_start_year, t1.ranking_streak;
*/


-- Output D: longest winning streak in the history of each league
/*
SELECT
	t1.competition_id,
	t1.season_formatted,
	c.club_name,
	t1.wins_in_sequence,
	t1.sequence_start,
	t1.sequence_end
FROM (
	SELECT
		bs.*,
		RANK() OVER(PARTITION BY bs.competition_id ORDER BY bs.wins_in_sequence DESC) AS top_streak
	FROM CTE_Best_Streak_By_Club AS bs
) AS t1
INNER JOIN clean.clubs AS c
	ON t1.club_id = c.club_id
WHERE t1.top_streak = 1
ORDER BY t1.competition_id, t1.season_start_year;
*/


-- Output E: highest number of points in the history of each league
/*
SELECT
	t1.competition_id,
	t1.season_formatted,
	c.club_name,
	t1.wins,
	t1.draws,
	t1.losses,
	t1.goals_scored,
	t1.goals_suffered,
	t1.goal_diff,
	t1.total_games,
	t1.total_points,
	t1.classification
FROM (
	SELECT
		pc.*,
		RANK() OVER(PARTITION BY pc.competition_id ORDER BY pc.total_points DESC, pc.goal_diff DESC, pc.goals_scored DESC) AS top_points
	FROM CTE_Points_By_Club AS pc
	WHERE pc.is_full_season = 1
) AS t1
INNER JOIN clean.clubs AS c
	ON t1.club_id = c.club_id
WHERE t1.top_points = 1
ORDER BY t1.competition_id, t1.season_start_year;
*/


-- Output F: lowest number of points in the history of each league

SELECT
	t1.competition_id,
	t1.season_formatted,
	c.club_name,
	t1.wins,
	t1.draws,
	t1.losses,
	t1.goals_scored,
	t1.goals_suffered,
	t1.goal_diff,
	t1.total_games,
	t1.total_points,
	t1.classification
FROM (
	SELECT
		pc.*,
		RANK() OVER(PARTITION BY pc.competition_id ORDER BY pc.total_points ASC, pc.goal_diff ASC, pc.goals_scored ASC) AS low_points
	FROM CTE_Points_By_Club AS pc
	WHERE pc.is_full_season = 1
) AS t1
INNER JOIN clean.clubs AS c
	ON t1.club_id = c.club_id
WHERE t1.low_points = 1
ORDER BY t1.competition_id, t1.season_start_year;