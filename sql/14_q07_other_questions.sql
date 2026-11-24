/* Questions: A) Does the difference between the league positions of the two clubs of a game explain the result (home win, draw, away win)?
              B) Which players were the most loyal to a club (10 or more consecutive seasons at the same club)?
              C) What is the percentage of foreign players in each top 15 league, by season?
              D) Relative age effect: are the players born in some months over-represented, by country of citizenship?
              E) Which formations are the most used in each league and season (evolution along the seasons)?
              F) Which formations are the most used overall?

   Approach: - CTE_Games_Results (A): games of the top 15 leagues with both positions known. The position difference is home position - away position
               (negative = the home club is higher in the table). The round number is read from the text of the round ('1. Matchday' = 1); TRY_CAST makes
               the rounds that are not a matchday (playoffs, finals) NULL instead of an error.
             - CTE_N_Games_By_Position_Diff (A): home wins, draws and home losses by league and position difference (and for all leagues together, 'ALL').
               Only games from round @min_round onwards (the first rounds are too volatile) and only groups with at least @min_games games are kept.
               The seasons are pooled: by season each group would have only a few games and the percentages would mean nothing.
             - CTE_Month_Birth, CTE_N_Players_By_Month_Of_Birth, CTE_N_Players_By_Country_Of_Citizenship (D): players with a known birth date and country,
               counted by country and month of birth and by country. Both counts come from the same population (players with a birth date).
               Only countries with at least @min_players_country players are kept.
             - Output D: expected players of a month = players of the country * days of the month / 365.25 (February = 28.25 days, because of the leap years).
               relative_representation (%) = observed / expected * 100 (100 = as expected, above 100 = over-represented).
             - CTE_Club_By_Season, CTE_Last_Year_Playing, CTE_Transfer_Events, CTE_Distinct_Events (B, C): the moments when a player is known to be in a club:
               each completed transfer (to_club_id, season of the transfer) and the last season of the player in his current club (clean.players).
               The season label ('99/00' = 1999) is converted to the start year of the season, as in 12_q05.
             - CTE_Next_Transfer, CTE_Seasons_Recursive, CTE_Player_Club_By_Season (B, C): each event lasts until the next one (LEAD, by season and date),
               and the recursion fills the seasons in between, so there is one row per player, club and season (the club of the player in each season).
             - Output B: gaps and islands on CTE_Player_Club_By_Season. Seasons in a row at the same club have the same (season_start_year - ROW_NUMBER),
               so the size of each group is the number of consecutive seasons. Only the sequences with @min_years_loyalty seasons or more are kept.
             - CTE_Clubs_In_First_League_By_Season, CTE_Player_And_League_Country (C): clubs that played at home in a top 15 league in each season
               (the league of the club in that season, not the current one), joined with the clubs of each player and the citizenship of the player.
             - Output C: players of the league in the season, foreign players (citizenship different from the country of the league) and their percentage.
               A player is counted once by league and season (COUNT DISTINCT), even if he played for two clubs of the league.
             - CTE_Football_Formations, CTE_Formations_By_Game (E, F): list of valid formations (the 'Starting...' placeholders and NULL are removed) and the games of the top 15 leagues.
             - Output E: each game gives two formations (home and away, unpivoted with CROSS APPLY, so the same formation used by both clubs counts twice).
               The usage (%) is the share of the valid formations of the league and season; only the top @top_n formations of each league and season are shown.
             - Output F: the same count for all the games of clean.games (all competitions), with the share over all the valid formations.
             - The outputs that use the recursion (B, C) have OPTION (MAXRECURSION 200).
             (Only one final SELECT runs at a time: comment out the others.)

	Insight: Data window: seasons 2012/13 to 2025/26 (formations from 2013/14). The numbers below come from the outputs with @top_n = 3, @min_round = 5, @min_games = 30, @min_years_loyalty = 10 and @min_players_country = 500.

             A) League position vs result (34,941 games, rounds 5 onwards)
               - Only 9 leagues have rows (BE1, ES1, FR1, GB1, IT1, L1, NL1, PO1 and MLS1, the last one with only 303 games). BRA1, ARG1, COL1, MEX1 and NO1 do not appear,
                 because their round is not a numeric 'N. Matchday' (or their positions are missing), so the filter by round removed them.
               - Overall result of the home club in these games: 44.9% wins, 24.8% draws, 30.3% losses.
               - The relation is strong and goes in one direction. Home win % by position difference (home position - away position; negative = home club higher):
                 -19 to -13: 86.4% (loss 2.7%) | -12 to -8: 72.4% | -7 to -4: 62.2% | -3 to -1: 52.6% | +1 to +3: 34.7% (loss 34.0%) | +4 to +7: 25.6% (loss 44.6%) | +8 to +12: 17.1% (loss 58.7%) | +13 to +19: 8.1% (loss 73.9%).
               - The home advantage is visible: with a difference of only one place, the home club wins 50.5% of the games when it is above the visitor (-1), but the visitor wins
                 only 32.5% when it is above the home club (+1). The home win % only falls below the home loss % between +2 (36.1% vs 32.3%) and +3 (31.6% vs 37.6%):
                 the home club needs to be about 3 places below the visitor to be the underdog.
               - Draws are more frequent when the clubs are close (30.8% to 32.5% for +1 to +4, 28.9% at -1) and almost disappear at the extremes (18.0% for +13 to +19,
                 10.9% for -19 to -13 and 1.9% at -19 alone).
               - The leagues are very similar. When the home club is 8 or more places above, it wins 73.2% (FR1) to 77.5% (ES1) of the games; when it is 8 or more places below,
                 it wins only 13.2% (IT1) to 17.9% (ES1). The best placed club wins 54.5% (FR1) to 58.9% (PO1) of all the games and the worse placed club wins 16.2% (PO1)
                 to 19.7% (L1 and BE1). IT1 and FR1 have the most draws (26.3%) and GB1 the least (23.9%).
               - MLS1 (small sample, 303 games): the best placed club wins 47.2%, the worse placed 24.8% and 28.1% are draws, so the position explains less than in Europe, but the sample is small.
               - Caution: the position is itself built from past results, so part of this relation is expected, and it is only as clean as the assumption that the positions are the ones before the game.

             B) Loyalty (10 or more consecutive seasons at the same club)
               - 447 sequences of 10 or more seasons. The number falls fast with the length: 171 with exactly 10 seasons, 86 with 11, 62 with 12, 37 with 13, 24 with 14, 24 with 15; 67 have 15 or more and only 13 have 18 or more.
               - Longest: Igor Akinfeev (PFK CSKA Moskva, 24 seasons from 2002/03), Hisashi Jogo (Avispa Fukuoka, 22), Ali Khaseif (Al-Jazira), Benji Villalobos (CD Aguila)
                 and Zhenpeng Wang (Kitchee), 21 each. The top of the list is mostly in clubs outside the big European leagues (Output B is not limited to the top 15 leagues).
               - Top 15 leagues: Seamus Coleman (Everton) 18; Francesco Rossi (Atalanta) 17; Koke (Atletico de Madrid), Lewis Dunk (Brighton), Messi (Barcelona, 2005 to 2021),
                 Sergio Ramos (Real Madrid, 2005 to 2021), Oscar de Marcos (Athletic Bilbao) and Thomas Muller (Bayern, 2009 to 2025) 16 each; Neuer, Muniain, Maximilian Arnold,
                 Herrmann and Jantschke 15.
               - Clubs with more 10+ sequences: Real Madrid 10, Athletic Bilbao 6, and Atletico de Madrid, Bayern, Tottenham, Hoffenheim and Al-Hilal 5 each.
               - 236 of the 447 sequences (53%) are still open in 2025/26, so their length is a minimum. Several names are goalkeepers (for example Akinfeev, Neuer, Rossi),
                 which fits the idea that they stay longer at a club, but the position is not in the output, so it is only an observation.

             C) Foreign players by league (share of the players with a club in the season, citizenship different from the country of the league)
               - 2025/26 (2012/13 in brackets): PO1 66.5% (59.5%), IT1 63.7% (44.7%), GB1 63.1% (59.8%), BE1 60.1% (51.1%), FR1 59.6% (49.5%), L1 59.0% (52.3%),
                 NL1 44.4% (42.9%), ES1 37.7% (35.5%). Spain and the Netherlands are clearly below the other European leagues.
               - Italy has the biggest increase (+19.0 points: 44.7% in 2012/13, 56.1% in 2017/18, an isolated drop to 44.6% in 2018/19 that may be a data problem, and 57% to 64% since then).
                 France increased 10.1 points, Belgium 9.1, Portugal 7.0 and Germany 6.6.
               - England (peak 70.1% in 2018/19), Spain (47.5%) and Belgium (66.6%) had their peak in 2018/19 and decreased afterwards; the Netherlands peaked at 54.0% in 2019/20.
                 France peaked in 2024/25 (63.8%) and Germany in 2020/21 (61.0%).
               - England has more than 59% foreign players in every season, even counting the players from Scotland, Wales and Northern Ireland as foreign.
               - Leagues with only 1 or 2 seasons in the data: MLS1 59.2% to 59.5% (similar to the big European leagues), MEX1 33.5% to 31.3%, NO1 31.1% to 35.0%,
                 ARG1 15.1% to 17.1%, BRA1 16.1% to 24.6% and COL1 12.5% (1 season). The South American leagues have by far the lowest shares.
               - The last season (2025/26) is not complete, so changes in the last year (for example NL1 from 51.2% to 44.4%) should be read with care.

             D) Relative age effect (31 country labels with at least 500 players)
               - Pooling the countries, the players born in January are 145.7% of the expected number, February 133.7% and March 125.3%, while October is 74.3%, November 67.2%
                 and December 61.3%. The first quarter has 134.9% of the expected births and the last quarter 67.6%, so a player born in January to March is about twice as likely
                 to be in the data as one born in October to December.
               - The effect appears in 30 of the 31 country labels (January above December). Strong examples: Argentina (January 167.0%, December 47.8%), Italy (February 162.6%),
                 Germany (January 162.3%), Spain (January 143.7%, February 149.2%, December 55.1%), Brazil, the Netherlands and Portugal.
               - The exceptions are consistent with a different cut-off date: in England the peak is in September (154.1%) and the lowest months are June (51.8%) and August (63.5%),
                 which fits the school year starting in September; in Japan the peak is in April (146.5%), with January to March at 68% to 76%, which fits a school year starting in April.
               - No clear pattern in Nigeria (months between 70% and 147%, no ordered shape) and a weak one in the United States and Norway.
               - The strongest single month is January in Turkey (234.3%), which may be partly caused by default or rounded birth dates in the source. Turkey and 'Turkiye' appear as two
                 different countries (1,388 and 907 players), so they should be merged before using these two rows.

             E) Most used formations by league and season
               - In the 8 European leagues, 4-2-3-1 is the most used formation in 65 of the 104 league-seasons, followed by 4-3-3 Defending (17), 4-3-3 Attacking (12), 3-5-2 flat (6),
                 4-4-2 double 6 (3) and 3-4-2-1 (1).
                 Rank 1 by league: GB1 4-2-3-1 in 12 of 13 seasons (4-3-3 Attacking in 2021/22), L1 4-2-3-1 in 12 of 13 (3-4-2-1 in 2025/26), FR1 11 of 13, ES1 10 of 13 (4-4-2 double 6
                 from 2018/19 to 2020/21), PO1 10 of 13 and BE1 8 of 13.
               - The Netherlands is different: 4-3-3 Defending is the most used in all 13 seasons (36.1% to 75.3%; peak 75.3% in 2023/24).
               - Italy is the most varied: 3-5-2 flat (6 seasons), 4-3-3 Attacking (5) and 4-2-3-1 (2) share the first place; the leader never has more than 37.9% of the usage.
               - The dominance of the leader changes along the time: 4-2-3-1 in Spain fell from 69.5% (2013/14) to 21.5% in 2020/21 (4-4-2 double 6 on top) and went back to 43.0% and 42.5%
                 in the last two seasons. In England it went from 46.8% (2015/16) to 20.8% in 2018/19 and reached 52.9% in 2024/25 and 54.7% in 2025/26.
               - Back three: in the 8 European leagues, only 1 of the 24 top 3 positions of each season (Italy, in the seasons checked) had a three-man defence until 2019/20; from 2020/21 the number goes to 5,
                 6 and then 9 of 24 in each season from 2022/23 to 2025/26.

             F) Most used formations overall (161,552 formations of all the games in clean.games)
               - 4-2-3-1 is clearly the first (31.6%), then 4-3-3 Attacking (15.5%), 4-4-2 double 6 (8.5%), 4-1-4-1 (5.5%) and 4-3-3 Defending (5.0%). The first 3 have 55.6% of the usage
                 and the first 5 have 66.2%.
               - Grouping the variants by the first numbers: 4-2-3-1 31.6%, 4-3-3 21.0%, 4-4-2 14.2%, 3-5-2 6.6%, 4-1-4-1 5.5%, 3-4-2-1 4.6%, 3-4-3 4.0%.
                 By defence: four defenders 77.5%, three defenders 18.0% and five defenders 4.3%.
               - There are 60 different formations, but 22 of them have fewer than 20 uses (116 uses in total), and some are impossible or very unlikely (for example 7-3-0 or 1-8-1),
                 so they are probably data entry errors.

       Note: Output A assumes that home_club_position and away_club_position are the positions BEFORE the game. If they were the positions after the game, the result
             would be part of the position and the relation would be inflated. Check it with the first round of a league: before the game the positions should be
             equal or empty, after the game the winners would already be at the top.
       Note: The first rounds are excluded with @min_round because the table is very volatile at the start. The rounds that are not 'N. Matchday' have a NULL round and
             are excluded too, so playoff games are not used. Postponed games keep their real date and round; the effect of the postponements is not corrected.
       Note: The position difference is the raw difference of positions, not the difference of points: a gap of 3 positions at the top of the table does not mean the same
             as a gap of 3 positions in the middle. The groups are small at the extreme differences, so @min_games removes them.
       Note: Output B depends on the transfers of the players. A player that never transferred (for example a youth player that stayed in his club) has no start season
             and appears with only one season. A loan breaks the sequence of the club of origin.
       Note: In Output B the season of the arrival counts as a full season and the season of the departure belongs to the next club, so the number of seasons is an approximation.
             Clubs without a record in clean.clubs (for example 'Retired' or 'Without club') end the previous sequence but are not shown.
       Note: Output C counts the players that have the club in that season (reconstructed from the transfers), not the players that played minutes: players that did not play
             and players of the youth teams can be included. The citizenship is the first one of the player, so dual nationals are counted only by one country.
       Note: The names of the countries of clean.competitions and clean.players must be the same to compare them (for example 'England', 'Netherlands'); a different name makes
             all the players of that country foreign.
       Note: Output D uses all the players of clean.players (not only the ones of the top 15 leagues), with a known birth date and country. The expected distribution is the calendar one
             (days of each month); the countries have different cut-off dates in the youth categories, which is why the results are by country.
       Note: Formations (E, F) only exist for the games where the line-ups are in the data, so the first seasons can be empty or have fewer games.
       Note: The season label of the leagues played in a calendar year (BRA1, ARG1, NO1, MLS1, COL1) is the value of clean.games.season and can be one year behind the calendar year;
             check season vs game_date in clean.games before quoting these years. It also affects the join between the seasons of the players and of the games in Output C.
       Note: Output B is not limited to the top 15 leagues: it uses every club of the transfers and of clean.players.
       Note: The formations include the labels of the source ('4-3-3 Attacking', '4-3-3 Defending', '4-4-2 double 6', '3-5-2 flat'), which are counted as different formations; group
             them by the first numbers if only the shape is needed. Output F uses all the competitions of clean.games, not only the top 15 leagues.
       Note: 'Turkey' and 'Turkiye' are different values of country_of_citizenship, so they are two separate countries in Output D.
       Note: In Output A only the leagues with numeric rounds and known positions appear (BE1, ES1, FR1, GB1, IT1, L1, NL1, PO1 and a small part of MLS1).
*/

USE TransfermarktDB;

DECLARE @top_n INT = 3;
DECLARE @min_round INT = 5;
DECLARE @min_games INT = 30;
DECLARE @min_years_loyalty INT = 10;
DECLARE @min_players_country INT = 500;

WITH CTE_Month_Birth AS
(
	SELECT
		p.player_id,
		p.country_of_citizenship,
		MONTH(p.date_of_birth) AS month_of_birth
	FROM clean.players AS p
	WHERE p.date_of_birth IS NOT NULL AND p.country_of_citizenship IS NOT NULL
),

CTE_N_Players_By_Month_Of_Birth AS
(
	SELECT
		mb.country_of_citizenship,
		mb.month_of_birth,
		COUNT(*) AS n_players
	FROM CTE_Month_Birth AS mb
	GROUP BY mb.country_of_citizenship, mb.month_of_birth
),

CTE_N_Players_By_Country_Of_Citizenship AS
(
	SELECT
		mb.country_of_citizenship,
		COUNT(*) AS n_players_by_country
	FROM CTE_Month_Birth AS mb
	GROUP BY mb.country_of_citizenship
	HAVING COUNT(*) >= @min_players_country
),

CTE_Club_By_Season AS
(
	SELECT
		t.player_id,
		t.to_club_id AS club_id,
		t.transfer_date AS event_date,
		CASE
			WHEN TRY_CAST(LEFT(t.transfer_season, 2) AS INT) >= 50
				THEN 1900 + TRY_CAST(LEFT(t.transfer_season, 2) AS INT)
			ELSE 2000 + TRY_CAST(LEFT(t.transfer_season, 2) AS INT)
		END AS season_start_year
	FROM clean.transfers AS t
	WHERE t.is_scheduled = 0 AND TRY_CAST(LEFT(t.transfer_season, 2) AS INT) IS NOT NULL
),

CTE_Last_Year_Playing AS
(
	SELECT
		p.player_id,
		p.current_club_id AS club_id,
		CAST('9999-12-31' AS DATE) AS event_date,
		TRY_CAST(p.last_season AS INT) AS season_start_year
	FROM clean.players AS p
	WHERE TRY_CAST(p.last_season AS INT) IS NOT NULL
),

CTE_Transfer_Events AS
(
	SELECT
		player_id,
		club_id,
		event_date,
		season_start_year
	FROM CTE_Club_By_Season

	UNION ALL

	SELECT
		player_id,
		club_id,
		event_date,
		season_start_year
	FROM CTE_Last_Year_Playing
),

CTE_Distinct_Events AS
(
	SELECT DISTINCT
		player_id,
		club_id,
		event_date,
		season_start_year
	FROM CTE_Transfer_Events
),

CTE_Next_Transfer AS
(
	SELECT
		de.*,
		LEAD(de.season_start_year) OVER(PARTITION BY de.player_id ORDER BY de.season_start_year, de.event_date) AS next_transfer_year
	FROM CTE_Distinct_Events AS de
),

CTE_Seasons_Recursive AS
(
	SELECT
		player_id,
		club_id,
		season_start_year,
		next_transfer_year
	FROM CTE_Next_Transfer

	UNION ALL

	SELECT
		player_id,
		club_id,
		season_start_year + 1,
		next_transfer_year
	FROM CTE_Seasons_Recursive
	WHERE season_start_year + 1 < next_transfer_year
),

CTE_Player_Club_By_Season AS
(
	SELECT DISTINCT
		player_id,
		club_id,
		season_start_year,
		CAST(season_start_year AS VARCHAR(4)) + '/' + CAST(season_start_year + 1 AS VARCHAR(4)) AS transfer_season
	FROM CTE_Seasons_Recursive
),

CTE_Clubs_In_First_League_By_Season AS
(
	SELECT
		g.competition_id,
		c.country_name,
		g.season,
		g.home_club_id
	FROM clean.games AS g
	INNER JOIN clean.competitions AS c
		ON g.competition_id = c.competition_id
	WHERE c.is_top15_league = 1
	GROUP BY g.competition_id, c.country_name, g.season, g.home_club_id
),

CTE_Player_And_League_Country AS
(
	SELECT
		cs.player_id,
		p.country_of_citizenship AS player_country,
		cs.season_start_year,
		cs.transfer_season,
		fl.competition_id,
		fl.country_name AS league_country,
		cs.club_id
	FROM CTE_Player_Club_By_Season AS cs
	INNER JOIN CTE_Clubs_In_First_League_By_Season AS fl
		ON cs.club_id = fl.home_club_id AND cs.season_start_year = fl.season
	INNER JOIN clean.players AS p
		ON cs.player_id = p.player_id
	WHERE p.country_of_citizenship IS NOT NULL
),

CTE_Football_Formations AS
(
	SELECT
		t1.formation
	FROM (
		SELECT g1.home_club_formation AS formation
		FROM clean.games AS g1

		UNION

		SELECT g2.away_club_formation
		FROM clean.games AS g2
	) AS t1
	WHERE t1.formation IS NOT NULL AND t1.formation NOT LIKE 'Starting%'
),

CTE_Formations_By_Game AS
(
	SELECT
		g.game_id,
		g.competition_id,
		CASE
			WHEN g.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), g.season)
			ELSE CONVERT(VARCHAR(4), g.season) + ' / ' + CONVERT(VARCHAR(4), g.season + 1)
		END AS season_formatted,
		g.home_club_formation,
		g.away_club_formation
	FROM clean.games AS g
	INNER JOIN clean.competitions AS c
		ON g.competition_id = c.competition_id
	WHERE c.is_top15_league = 1
),

CTE_Games_Results AS
(
	SELECT
		g.game_id,
		g.competition_id,
		TRY_CAST(LEFT(g.round, NULLIF(CHARINDEX('.', g.round), 0) - 1) AS INT) AS round,
		g.home_result,
		g.home_club_position - g.away_club_position AS position_diff
	FROM clean.games AS g
	INNER JOIN clean.competitions AS c
		ON g.competition_id = c.competition_id
	WHERE c.is_top15_league = 1 AND g.home_club_position IS NOT NULL AND g.away_club_position IS NOT NULL
),

CTE_N_Games_By_Position_Diff AS
(
	SELECT
		ISNULL(gr.competition_id, 'ALL') AS competition_id,
		gr.position_diff,
		COUNT(*) AS n_games,
		SUM(CASE WHEN gr.home_result = 'Home win' THEN 1 ELSE 0 END) AS n_home_wins,
		SUM(CASE WHEN gr.home_result = 'Draw' THEN 1 ELSE 0 END) AS n_draws,
		SUM(CASE WHEN gr.home_result = 'Away win' THEN 1 ELSE 0 END) AS n_home_losses
	FROM CTE_Games_Results AS gr
	WHERE gr.round >= @min_round
	GROUP BY GROUPING SETS ((gr.competition_id, gr.position_diff), (gr.position_diff))
	HAVING COUNT(*) >= @min_games
)


-- Output A: does the difference between the league positions of the two clubs explain the result?
/*
SELECT
	ng.competition_id,
	ng.position_diff,
	ng.n_games,
	ng.n_home_wins,
	ng.n_draws,
	ng.n_home_losses,
	CAST(ng.n_home_wins * 100.0 / ng.n_games AS DECIMAL(5,2)) AS [home win (%)],
	CAST(ng.n_draws * 100.0 / ng.n_games AS DECIMAL(5,2)) AS [draw (%)],
	CAST(ng.n_home_losses * 100.0 / ng.n_games AS DECIMAL(5,2)) AS [home loss (%)]
FROM CTE_N_Games_By_Position_Diff AS ng
ORDER BY CASE WHEN ng.competition_id = 'ALL' THEN 0 ELSE 1 END, ng.competition_id, ng.position_diff;
*/


-- Output B: which players were the most loyal to a club (@min_years_loyalty or more consecutive seasons)?
/*
SELECT
	p.player_name,
	c.club_name,
	CAST(t2.first_season AS VARCHAR(4)) + '/' + CAST(t2.last_season + 1 AS VARCHAR(4)) AS first_season,
	CAST(t2.last_season AS VARCHAR(4)) + '/' + CAST(t2.last_season + 1 AS VARCHAR(4)) AS last_season,
	t2.years_in_sequence
FROM (
	SELECT
		t1.player_id,
		t1.club_id,
		MIN(t1.season_start_year) AS first_season,
		MAX(t1.season_start_year) AS last_season,
		COUNT(*) AS years_in_sequence
	FROM (
		SELECT
			pc.player_id,
			pc.club_id,
			pc.season_start_year,
			pc.season_start_year - ROW_NUMBER() OVER(PARTITION BY pc.player_id, pc.club_id ORDER BY pc.season_start_year ASC) AS sequence_id
		FROM CTE_Player_Club_By_Season AS pc
	) AS t1
	GROUP BY t1.player_id, t1.club_id, t1.sequence_id
) AS t2
INNER JOIN clean.players AS p
	ON t2.player_id = p.player_id
INNER JOIN clean.clubs AS c
	ON t2.club_id = c.club_id
WHERE t2.years_in_sequence >= @min_years_loyalty
ORDER BY t2.years_in_sequence DESC, p.player_name
OPTION (MAXRECURSION 200);
*/


-- Output C: what is the percentage of foreign players in each top 15 league, by season?
/*
SELECT
	t1.transfer_season AS season,
	t1.competition_id,
	t1.league_country,
	t1.total_foreign_players,
	t1.total_players,
	CAST(t1.total_foreign_players * 100.0 / t1.total_players AS DECIMAL(5,2)) AS [foreign_players (%)]
FROM (
	SELECT
		pl.competition_id,
		pl.league_country,
		pl.season_start_year,
		pl.transfer_season,
		COUNT(DISTINCT pl.player_id) AS total_players,
		COUNT(DISTINCT CASE
							WHEN pl.player_country != pl.league_country
								THEN pl.player_id
					   END) AS total_foreign_players
	FROM CTE_Player_And_League_Country AS pl
	GROUP BY pl.competition_id, pl.league_country, pl.season_start_year, pl.transfer_season
) AS t1
ORDER BY t1.competition_id, t1.season_start_year
OPTION (MAXRECURSION 200);
*/


-- Output D: relative age effect (observed vs expected players by month of birth and country)
/*
SELECT
	t2.country_of_citizenship,
	CHOOSE(t2.month_of_birth, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December') AS month_name,
	t2.n_players_expected,
	t2.n_players,
	CAST(t2.n_players * 100.0 / t2.n_players_expected AS DECIMAL(20,2)) AS [relative_representation (%)]
FROM (
	SELECT
		t1.country_of_citizenship,
		t1.month_of_birth,
		t1.n_players,
		CAST(cc.n_players_by_country * t1.n_days_by_month / 365.25 AS DECIMAL(20,2)) AS n_players_expected
	FROM (
		SELECT
			np.country_of_citizenship,
			np.month_of_birth,
			np.n_players,
			CHOOSE(np.month_of_birth, 31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31) AS n_days_by_month
		FROM CTE_N_Players_By_Month_Of_Birth AS np
	) AS t1
	INNER JOIN CTE_N_Players_By_Country_Of_Citizenship AS cc
		ON t1.country_of_citizenship = cc.country_of_citizenship
) AS t2
ORDER BY t2.country_of_citizenship, t2.month_of_birth;
*/


-- Output E: which formations are the most used in each league and season?
/*
SELECT
	t2.season_formatted,
	t2.competition_id,
	t2.formation,
	t2.times_used,
	t2.[formation_usage (%)],
	t2.ranking_formation
FROM (
	SELECT
		t1.*,
		CAST(t1.times_used * 100.0 / SUM(t1.times_used) OVER(PARTITION BY t1.season_formatted, t1.competition_id) AS DECIMAL(20,2)) AS [formation_usage (%)],
		ROW_NUMBER() OVER(PARTITION BY t1.season_formatted, t1.competition_id ORDER BY t1.times_used DESC, t1.formation ASC) AS ranking_formation
	FROM (
		SELECT
			fg.season_formatted,
			fg.competition_id,
			f.formation,
			COUNT(*) AS times_used
		FROM CTE_Formations_By_Game AS fg
		CROSS APPLY (VALUES (fg.home_club_formation), (fg.away_club_formation)) AS f(formation)
		INNER JOIN CTE_Football_Formations AS ff
			ON f.formation = ff.formation
		GROUP BY fg.season_formatted, fg.competition_id, f.formation
	) AS t1
) AS t2
WHERE t2.ranking_formation <= @top_n
ORDER BY t2.competition_id, t2.season_formatted, t2.ranking_formation;
*/


-- Output F: which formations are the most used overall?

SELECT
	t1.formation,
	t1.times_used,
	CAST(t1.times_used * 100.0 / SUM(t1.times_used) OVER() AS DECIMAL(20,3)) AS [formation_usage (%)]
FROM (
	SELECT
		f.formation,
		COUNT(*) AS times_used
	FROM clean.games AS g
	CROSS APPLY (VALUES (g.home_club_formation), (g.away_club_formation)) AS f(formation)
	INNER JOIN CTE_Football_Formations AS ff
		ON f.formation = ff.formation
	GROUP BY f.formation
) AS t1
ORDER BY t1.times_used DESC;
