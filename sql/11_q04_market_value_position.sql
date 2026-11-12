/* Question: Market value, performance and playing time by age and position: at what age does it peak?
			 A) How does the market value of a player change with age, for each general position?
			 B) At what age does a player reach the highest market value of his career, and how does it change with the position?
			 C) How many players peaked at each age, by position?
			 D) At what age do players have their best goal participations (goals + assists) per 90 minutes?
			 E) How do goal participations per 90 minutes change with age, by position?
			 F) From what age does the average change in market value turn negative?
			 G) What is the average age by club?
			 H) What is the average age by league?
			 I) What is the average number of minutes played per season?
			 J) What percentage of games are played as a starter, by age?
			 K) What percentage of games are played as a starter, by position?

   Approach: - CTE_Valuations_Top15: valuations of players at clubs of the top 15 leagues. The season label and a season reference date
               (1 January for calendar-year leagues, 1 July for the others) are built once.
             - CTE_Player_Age_At_Valuation_Date: exact age (in whole years) at the valuation date; only seasons between @first_season and @last_complete_season.
             - Position: lineup appearances are counted by specific position, mapped to 4 general positions (Goalkeeper, Defender, Midfield, Attack),
               and each player keeps the general position he played the most (ties: alphabetical order), so he is counted only once.
             - CTE_Max_Market_Value_By_Age: highest valuation of each player at each age.
             - CTE_Peak_Market_Value: highest valuation of each player's career (the first time it was reached), with the age and season it happened.
               Only players whose peak is at least @min_peak_value are kept in outputs A, B, C and F.
             - CTE_Market_Value_Change_By_Age: change (absolute and %) in the value of the same player between two consecutive ages.
             - CTE_Goal_Participations_By_Player and CTE_Goal_Participations_Per_90_By_Age: goals, assists and minutes of each player at each age (top 15 league games),
               turned into goal participations per 90 minutes; an age only counts if the player played at least @min_minutes_per_age minutes.
             - CTE_Peak_Goal_Participations: the age with the best rate of each player (ties: more participations, then the youngest age);
               players need at least @min_ages_observed qualifying ages and at least one goal participation.
             - CTE_Minutes_Played_By_Player: league minutes of each player by club, league and season (seasons between @first_season and @last_complete_season).
             - CTE_Age_By_Start_Season: age of each player on the season reference date, for every club where he had a valuation in that season (the squad).
             - CTE_Substitute_Or_Not_By_Game: games actually played in the top 15 leagues (a lineup row with an appearance), flagged as starter or substitute (came on),
               with the player's age at the game and the position he played in that game.
             - Output A: players, average and median market value by position and age.
             - Output B: players, average and median peak age and average peak value by position.
             - Output C: number of players by peak age and position.
             - Output D: number of players by age of best goal participations per 90 minutes and position, with the average rate at the peak.
             - Output E: average and median goal participations per 90 minutes by position and age (all qualifying player-ages).
             - Output F: for each player, the change in value from one age to the next; then average and median change (absolute and %) by position and age.
             - Output G: average age of the squad by club and season. Output H: the same by league and season.
             - Output I: average minutes played per player by club and season, for all players and for regular players (at least @min_minutes_per_season).
             - Output J: games as starter and as substitute, and their percentages, by age. Output K: the same by position.
             (Only one final SELECT runs at a time: comment out the others.)

   Insight: - Peak age (B, C): the career peak in market value comes at 24.1 for Attack (median 24), 24.3 for Midfield, 24.8 for Defender and 26.4 for Goalkeeper (16,571 players).
              58% of all players peak between 22 and 27; only 6% to 8% of outfield players peak at 30 or later, against 21% of goalkeepers.
            - Value by age (A): the average value is highest at 27 for Attack (7.37M EUR), at 26 for Midfield (7.09M) and Defender (5.34M) and at 28 for Goalkeeper (4.32M).
              The mean is about 3 times the median at the peak (Attack at 27: 7.37M vs 2.28M), so a few stars lift the average. Attack and Midfield are worth the most and goalkeepers the least.
              Attack keeps 74% of its peak value at 30, 37% at 33 and 23% at 35; goalkeepers decline more slowly (still 3.66M at 30).
            - Change by age (F): following the same player, the median change in value is 0 from about 22 to 27-28 and turns negative at 28 for Attack, 29 for Defender and Midfield and 30 for Goalkeeper.
              The average absolute change turns negative at 28 for Attack, 27 for Defender and Midfield and 29 for Goalkeeper. From 33 to 36 the median fall is about 33% a year for outfield players.
            - Performance (D, E): goal participations per 90 minutes peak at a median age of 25 for Attack and 26 for Midfield and Defender, about 1.3 years later than market value.
              The rate is flat from about 22 to 30 (Attack 0.45 to 0.50 per 90, Midfield 0.22 to 0.24, Defender 0.10) and does not fall for attackers, which is partly survivorship (only those still good remain at 33 to 36).
            - Playing time (J, K): the share of games as a starter rises from 46% at 17 and 64% at 20 to 78% to 81% from 25 to 35. By position, goalkeepers start 98.8% of their games, defenders 85.6%, midfielders 73.9% and attackers 62.0%.
            - Minutes (I): a club uses about 28 players, who average about 1,230 minutes (regular players, with 900 or more minutes, about 1,950). The Premier League has the most stable squads (1,362 minutes per player, 60% regular players),
              Belgium and Portugal the most rotation (about 1,060 minutes, 50% regular players).
            - Age of squads (G, H): Spain is the oldest league on average (26.1) and Norway (22.7) and the Netherlands (23.5) the youngest. Genk, Heerenveen, AZ, Ajax and Groningen are consistently young clubs,
              while Spanish clubs (Cádiz, Rayo Vallecano, Eibar, Osasuna) dominate the oldest list. The Premier League got younger, from 25.8 in 2018/19 to about 24.9-25.1 since 2023/24, while Mexico (23.4 to 25.8) and Brazil (22.3 to 26.2) got older.

   Note: Outputs D, E, I, J and K only contain the 8 European leagues (appearances table); outputs A, B, C, F, G and H cover 14 leagues.
   Note: In Output I, games of the 2019/20 season played in July and August 2020 are assigned to 2020/21 by the July cutoff. This understates 2019/20 and inflates 2020/21
		 (clubs relegated in 2020 appear with a few games and no regular players), so both seasons are unreliable.
   Note: Output G has 1,407 club-seasons with fewer than 15 valued players; use clubs with at least 15 for rankings. COL1, MLS1 and MEX1 have very few players in their first seasons (Output H).
   Note: In outputs D and E, the flat or rising rate of attackers at older ages is partly survivorship.

   Note: Only valuations at clubs of the top 15 leagues count; a player's value while at another league is not in the data.
   Note: Peak age is censored by the time window: players still young have not peaked yet and older players may have peaked before @first_season.
		 The peak age must be read with this in mind (check MIN(valuation_date) to see if earlier seasons can be used).
   Note: The position is the one played the most over the whole career (all competitions in game_lineups), not the position at each age.
   Note: Valuations are rounded and often stay flat for a long time, so the "peak" is the first valuation that reached the maximum.
   Note: Outputs A, B, C and F only include players whose peak is at least @min_peak_value, so young ages favour players who later succeeded.
   Note: Ignore ages or positions with few players (for example n_players < 30), as their averages are not reliable.
   Note: Output F follows the same player from one age to the next (it does not compare different players), which avoids the survivorship effect of comparing averages by age.
		 It uses the highest valuation of each age and a change is only computed when the player has valuations at two consecutive ages. % changes are very large at young ages, so prefer the median.
   Note: Outputs G and H take as squad the players with a valuation at the club in that season, not the players who played. Ages are measured on the season reference date.
   Note: Output I only counts league games, so players of clubs that also play in Europe have more minutes than shown for those competitions.
   Note: In outputs J and K, substitutes who stayed on the bench are not counted. Goalkeepers almost always start, which pushes up the starter % of their position.
*/

USE TransfermarktDB;

DECLARE @min_peak_value DECIMAL(18,2) = 500000;
DECLARE @first_season INT = 2012;
DECLARE @last_complete_season INT = 2025;
DECLARE @min_minutes_per_age INT = 900;
DECLARE @min_minutes_per_season INT = 900;
DECLARE @min_ages_observed INT = 3;

WITH CTE_Valuations_Top15 AS
(
	SELECT
		v.player_id,
		v.club_id,
		v.club_domestic_competition,
		v.market_value_in_eur,
		v.valuation_date,
		CASE
			WHEN v.club_domestic_competition IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN YEAR(v.valuation_date)
			WHEN MONTH(v.valuation_date) >= 7
				THEN YEAR(v.valuation_date)
			ELSE YEAR(v.valuation_date) - 1
		END AS season_start_year,
		CASE
			WHEN v.club_domestic_competition IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN CONVERT(VARCHAR(4), YEAR(v.valuation_date))
			WHEN MONTH(v.valuation_date) >= 7
				THEN CONVERT(VARCHAR(4), YEAR(v.valuation_date)) + ' / ' + CONVERT(VARCHAR(4), YEAR(v.valuation_date) + 1)
			ELSE CONVERT(VARCHAR(4), YEAR(v.valuation_date) - 1) + ' / ' + CONVERT(VARCHAR(4), YEAR(v.valuation_date))
		END AS season_formatted,
		CASE
			WHEN v.club_domestic_competition IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
				THEN DATEFROMPARTS(YEAR(v.valuation_date), 1, 1)
			WHEN MONTH(v.valuation_date) >= 7
				THEN DATEFROMPARTS(YEAR(v.valuation_date), 7, 1)
			ELSE DATEFROMPARTS(YEAR(v.valuation_date) - 1, 7, 1)
		END AS season_reference_date
	FROM clean.player_valuations AS v
	INNER JOIN clean.competitions AS c
		ON v.club_domestic_competition = c.competition_id
	WHERE c.is_top15_league = 1
		AND v.market_value_in_eur IS NOT NULL
),

CTE_Player_Age_At_Valuation_Date AS
(
	SELECT
		t.player_id,
		t.market_value_in_eur,
		t.valuation_date,
		t.season_formatted,
		DATEDIFF(YEAR, p.date_of_birth, t.valuation_date) - CASE
																WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.date_of_birth, t.valuation_date), p.date_of_birth) > t.valuation_date
																	THEN 1
																ELSE 0
															END AS age_at_valuation_date
	FROM CTE_Valuations_Top15 AS t
	INNER JOIN clean.players AS p
		ON t.player_id = p.player_id
	WHERE t.season_start_year BETWEEN @first_season AND @last_complete_season
		AND p.date_of_birth IS NOT NULL
),

CTE_Times_Played_At_Specific_Position AS
(
	SELECT 
		player_id,
		position AS specific_position,
		COUNT(*) AS times_played_at_specific_position
	FROM staging.game_lineups 
	WHERE position IS NOT NULL
	GROUP BY player_id, position
),

CTE_General_Position_By_Player AS
(
	SELECT 
		sp.player_id,
		sp.specific_position,
		sp.times_played_at_specific_position,
		CASE
			WHEN sp.specific_position IN ('Second Striker', 'Attack', 'Right Winger', 'Left Winger', 'Centre-Forward')
				THEN 'Attack'
			WHEN sp.specific_position IN ('Sweeper', 'Right-Back', 'Defender', 'Centre-Back', 'Left-Back')
				THEN 'Defender'
			WHEN sp.specific_position IN ('Attacking Midfield', 'Left Midfield', 'Right Midfield', 'Central Midfield', 'Defensive Midfield', 'midfield')
				THEN 'Midfield'
			WHEN sp.specific_position = 'Goalkeeper'
				THEN 'Goalkeeper'
			ELSE NULL
		END AS general_position
	FROM CTE_Times_Played_At_Specific_Position AS sp 
),

CTE_Times_Played_At_General_Position AS
(
	SELECT
		gp.player_id,
		gp.general_position,
		SUM(gp.times_played_at_specific_position) AS times_played_at_general_position
	FROM CTE_General_Position_By_Player AS gp
	WHERE gp.general_position IS NOT NULL
	GROUP BY gp.player_id, gp.general_position
),

CTE_Main_Position_By_Player AS
(
	SELECT
		t.player_id,
		t.general_position
	FROM (
		SELECT
			gp.player_id,
			gp.general_position,
			ROW_NUMBER() OVER(PARTITION BY gp.player_id ORDER BY gp.times_played_at_general_position DESC, gp.general_position ASC) AS position_order
		FROM CTE_Times_Played_At_General_Position AS gp
	) AS t
	WHERE t.position_order = 1
),

CTE_Max_Market_Value_By_Age AS
(
	SELECT
		vd.player_id,
		vd.age_at_valuation_date,
		MAX(vd.market_value_in_eur) AS max_market_value_by_age
	FROM CTE_Player_Age_At_Valuation_Date AS vd
	GROUP BY vd.player_id, vd.age_at_valuation_date
),

CTE_Peak_Market_Value AS 
(
	SELECT 
		t.player_id,
		t.market_value_in_eur AS max_market_value,
		t.age_at_valuation_date AS peak_age,
		t.season_formatted AS peak_season
	FROM (
		SELECT 
			vd.player_id,
			vd.market_value_in_eur,
			vd.age_at_valuation_date,
			vd.season_formatted,
			ROW_NUMBER() OVER(PARTITION BY vd.player_id ORDER BY vd.market_value_in_eur DESC, vd.valuation_date ASC) AS peak_order
		FROM CTE_Player_Age_At_Valuation_Date AS vd
	) AS t
	WHERE t.peak_order = 1
		AND t.market_value_in_eur >= @min_peak_value
),

CTE_Market_Value_Change_By_Age AS
(
	SELECT
		t.player_id,
		t.age_at_valuation_date AS age,
		CAST(t.max_market_value_by_age - t.previous_market_value AS DECIMAL(18,2)) AS market_value_diff,
		CAST((t.max_market_value_by_age - t.previous_market_value) * 100.0 / t.previous_market_value AS DECIMAL(18,2)) AS market_value_diff_pct
	FROM (
		SELECT
			ma.player_id,
			ma.age_at_valuation_date,
			ma.max_market_value_by_age,
			CASE
				WHEN ma.age_at_valuation_date - LAG(ma.age_at_valuation_date) OVER(PARTITION BY ma.player_id ORDER BY ma.age_at_valuation_date) = 1
					THEN LAG(ma.max_market_value_by_age) OVER(PARTITION BY ma.player_id ORDER BY ma.age_at_valuation_date)
			END AS previous_market_value
		FROM CTE_Max_Market_Value_By_Age AS ma
		INNER JOIN CTE_Peak_Market_Value AS pk
			ON ma.player_id = pk.player_id
	) AS t
	WHERE t.previous_market_value > 0
),

CTE_Goal_Participations_By_Player AS
(
	SELECT
		t1.player_id,
		t1.age_at_appearance_date,
		SUM(t1.goals) AS total_goals_by_age,
		SUM(t1.assists) AS total_assists_by_age,
		SUM(t1.goals + t1.assists) AS total_goal_participations_by_age,
		SUM(t1.minutes_played) AS total_minutes_by_age
	FROM (
			SELECT 
				a.player_id,
				a.goals,
				a.assists,
				a.minutes_played,
				DATEDIFF(YEAR, p.date_of_birth, a.appearance_date) - CASE
																		WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.date_of_birth, a.appearance_date), p.date_of_birth) > a.appearance_date
																			THEN 1
																		ELSE 0
																	END AS age_at_appearance_date
			FROM clean.appearances AS a
			INNER JOIN clean.competitions AS c
				ON a.competition_id = c.competition_id
			INNER JOIN clean.players AS p
				ON a.player_id = p.player_id
			WHERE c.is_top15_league = 1
				AND p.date_of_birth IS NOT NULL
	) AS t1
	GROUP BY t1.player_id, t1.age_at_appearance_date
),
 
CTE_Goal_Participations_Per_90_By_Age AS
(
	SELECT
		gp.player_id,
		gp.age_at_appearance_date AS age,
		gp.total_goal_participations_by_age,
		gp.total_minutes_by_age,
		CAST(gp.total_goal_participations_by_age * 90.0 / gp.total_minutes_by_age AS DECIMAL(5,2)) AS goal_participations_per_90,
		COUNT(*) OVER(PARTITION BY gp.player_id) AS n_ages_observed
	FROM CTE_Goal_Participations_By_Player AS gp
	WHERE gp.total_minutes_by_age >= @min_minutes_per_age
),
 
CTE_Peak_Goal_Participations AS
(
	SELECT 
		t1.player_id,
		t1.age,
		t1.goal_participations_per_90
	FROM (
		SELECT 
			pa.player_id,
			pa.age,
			pa.goal_participations_per_90,
			ROW_NUMBER() OVER(PARTITION BY pa.player_id ORDER BY pa.goal_participations_per_90 DESC, pa.total_goal_participations_by_age DESC, pa.age ASC) AS ranking_goal_participations
		FROM CTE_Goal_Participations_Per_90_By_Age AS pa
		WHERE pa.goal_participations_per_90 > 0
			AND pa.n_ages_observed >= @min_ages_observed
	) AS t1
	WHERE t1.ranking_goal_participations = 1
),

CTE_Minutes_Played_By_Player AS
(
	SELECT
		t1.player_id,
		t1.player_club_id,
		t1.competition_id,
		t1.season_formatted,
		SUM(t1.minutes_played) AS total_minutes_played_by_season
	FROM (
		SELECT 
			a.player_id,
			a.player_club_id,
			a.competition_id,
			a.minutes_played,
			CASE
				WHEN a.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
					THEN YEAR(a.appearance_date)
				WHEN MONTH(a.appearance_date) >= 7
					THEN YEAR(a.appearance_date)
				ELSE YEAR(a.appearance_date) - 1
			END AS season_start_year,
			CASE
				WHEN a.competition_id IN ('BRA1', 'ARG1', 'NO1', 'MLS1', 'COL1')
					THEN CONVERT(VARCHAR(4), YEAR(a.appearance_date))
				WHEN MONTH(a.appearance_date) >= 7
					THEN CONVERT(VARCHAR(4), YEAR(a.appearance_date)) + ' / ' + CONVERT(VARCHAR(4), YEAR(a.appearance_date) + 1)
				ELSE CONVERT(VARCHAR(4), YEAR(a.appearance_date) - 1) + ' / ' + CONVERT(VARCHAR(4), YEAR(a.appearance_date))
			END AS season_formatted
		FROM clean.appearances AS a
		INNER JOIN clean.competitions AS c
			ON a.competition_id = c.competition_id
		WHERE c.is_top15_league = 1
	) AS t1
	WHERE t1.season_start_year BETWEEN @first_season AND @last_complete_season
	GROUP BY t1.player_id, t1.player_club_id, t1.competition_id, t1.season_formatted
),

CTE_Age_By_Start_Season AS
(
	SELECT DISTINCT
		t.player_id,
		t.club_id,
		t.club_domestic_competition,
		t.season_start_year,
		t.season_formatted,
		DATEDIFF(YEAR, p.date_of_birth, t.season_reference_date) - CASE
																		WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.date_of_birth, t.season_reference_date), p.date_of_birth) > t.season_reference_date
																			THEN 1
																		ELSE 0
																	END AS age_at_start_season
	FROM CTE_Valuations_Top15 AS t
	INNER JOIN clean.players AS p
		ON t.player_id = p.player_id
	WHERE t.season_start_year BETWEEN @first_season AND @last_complete_season
		AND p.date_of_birth IS NOT NULL
),

CTE_Substitute_Or_Not_By_Game AS
(
	SELECT 
		a.player_id,
		l.type,
		CASE
			WHEN l.position IN ('Second Striker', 'Attack', 'Right Winger', 'Left Winger', 'Centre-Forward')
				THEN 'Attack'
			WHEN l.position IN ('Sweeper', 'Right-Back', 'Defender', 'Centre-Back', 'Left-Back')
				THEN 'Defender'
			WHEN l.position IN ('Attacking Midfield', 'Left Midfield', 'Right Midfield', 'Central Midfield', 'Defensive Midfield', 'midfield')
				THEN 'Midfield'
			WHEN l.position = 'Goalkeeper'
				THEN 'Goalkeeper'
			ELSE NULL
		END AS general_position,
		DATEDIFF(YEAR, p.date_of_birth, a.appearance_date) - CASE
																WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.date_of_birth, a.appearance_date), p.date_of_birth) > a.appearance_date
																	THEN 1
																ELSE 0
															END AS age_at_game_date
	FROM clean.appearances AS a
	INNER JOIN staging.game_lineups AS l
		ON a.game_id = l.game_id AND a.player_id = l.player_id
	INNER JOIN clean.competitions AS c
		ON a.competition_id = c.competition_id
	INNER JOIN clean.players AS p
		ON a.player_id = p.player_id
	WHERE c.is_top15_league = 1
		AND p.date_of_birth IS NOT NULL
),

CTE_Times_Substitute_By_Age_By_Position AS
(
	SELECT 
		t1.player_id,
		t1.general_position,
		t1.age_at_game_date,
		t1.n_first_11,
		t1.n_subs,
		t1.n_first_11 + t1.n_subs AS games
	FROM (
		SELECT 
			sn.player_id,
			sn.general_position,
			sn.age_at_game_date,
			COUNT(CASE WHEN sn.type = 'starting_lineup' THEN 1 END) AS n_first_11,
			COUNT(CASE WHEN sn.type = 'substitutes' THEN 1 END) AS n_subs
		FROM CTE_Substitute_Or_Not_By_Game AS sn
		GROUP BY sn.player_id,
			sn.general_position,
			sn.age_at_game_date
	) AS t1
)


-- Output A: market value by position and age
/*
SELECT DISTINCT
	mp.general_position,
	ma.age_at_valuation_date AS age,
	COUNT(*) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS n_players,
	CAST(AVG(CAST(ma.max_market_value_by_age AS DECIMAL(18,2))) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS DECIMAL(18,2)) AS avg_market_value,
	CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ma.max_market_value_by_age) OVER(PARTITION BY mp.general_position, ma.age_at_valuation_date) AS DECIMAL(18,2)) AS median_market_value
FROM CTE_Max_Market_Value_By_Age AS ma
INNER JOIN CTE_Peak_Market_Value AS pk
	ON ma.player_id = pk.player_id
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON ma.player_id = mp.player_id
ORDER BY general_position, age;
*/


-- Output B: peak age and peak value by position
/*
SELECT DISTINCT
	mp.general_position,
	COUNT(*) OVER(PARTITION BY mp.general_position) AS n_players,
	CAST(AVG(CAST(pk.peak_age AS DECIMAL(5,2))) OVER(PARTITION BY mp.general_position) AS DECIMAL(5,2)) AS avg_peak_age,
	CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pk.peak_age) OVER(PARTITION BY mp.general_position) AS DECIMAL(5,2)) AS median_peak_age,
	CAST(AVG(CAST(pk.max_market_value AS DECIMAL(18,2))) OVER(PARTITION BY mp.general_position) AS DECIMAL(18,2)) AS avg_peak_value
FROM CTE_Peak_Market_Value AS pk
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON pk.player_id = mp.player_id
ORDER BY general_position;
*/


-- Output C: number of players that peaked at each age, by position
/*
SELECT
	mp.general_position,
	pk.peak_age,
	COUNT(*) AS n_players
FROM CTE_Peak_Market_Value AS pk
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON pk.player_id = mp.player_id
GROUP BY mp.general_position, pk.peak_age
ORDER BY mp.general_position, pk.peak_age;
*/


-- Output D: at which age do players have their best goal participations per 90 minutes? (number of players by peak age and position)
/*
SELECT
	mp.general_position,
	pk.age,
	COUNT(*) AS n_players,
	CAST(AVG(pk.goal_participations_per_90) AS DECIMAL(5,2)) AS avg_goal_participations_per_90_at_peak
FROM CTE_Peak_Goal_Participations AS pk
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON pk.player_id = mp.player_id
WHERE mp.general_position != 'Goalkeeper'
GROUP BY mp.general_position, pk.age
ORDER BY mp.general_position, pk.age;
*/


-- Output E: age curve, goal participations per 90 minutes by age and position (all qualifying player-ages)
/*
SELECT DISTINCT
	mp.general_position,
	pa.age,
	COUNT(*) OVER(PARTITION BY mp.general_position, pa.age) AS n_players,
	CAST(AVG(pa.goal_participations_per_90) OVER(PARTITION BY mp.general_position, pa.age) AS DECIMAL(5,2)) AS avg_goal_participations_per_90,
	CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pa.goal_participations_per_90) OVER(PARTITION BY mp.general_position, pa.age) AS DECIMAL(5,2)) AS median_goal_participations_per_90
FROM CTE_Goal_Participations_Per_90_By_Age AS pa
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON pa.player_id = mp.player_id
WHERE mp.general_position != 'Goalkeeper'
ORDER BY general_position, age;
*/


-- Output F: from what age does the average change in market value turn negative?
/*
SELECT DISTINCT
	mp.general_position,
	ch.age,
	COUNT(*) OVER(PARTITION BY mp.general_position, ch.age) AS n_players,
	CAST(AVG(ch.market_value_diff) OVER(PARTITION BY mp.general_position, ch.age) AS DECIMAL(18,2)) AS avg_market_diff,
	CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ch.market_value_diff) OVER(PARTITION BY mp.general_position, ch.age) AS DECIMAL(18,2)) AS median_market_diff,
	CAST(AVG(ch.market_value_diff_pct) OVER(PARTITION BY mp.general_position, ch.age) AS DECIMAL(18,2)) AS [avg_market_rate_diff (%)],
	CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ch.market_value_diff_pct) OVER(PARTITION BY mp.general_position, ch.age) AS DECIMAL(18,2)) AS [median_market_rate_diff (%)]
FROM CTE_Market_Value_Change_By_Age AS ch
INNER JOIN CTE_Main_Position_By_Player AS mp
	ON ch.player_id = mp.player_id
ORDER BY general_position, age;
*/


-- Output G: what is the average age by club?
/*
SELECT 
	c.club_name,
	ss.club_domestic_competition,
	ss.season_formatted,
	COUNT(*) AS n_players,
	CAST(AVG(CAST(ss.age_at_start_season AS DECIMAL(5,2))) AS DECIMAL(5,2)) AS avg_age
FROM CTE_Age_By_Start_Season AS ss
INNER JOIN clean.clubs AS c
	ON ss.club_id = c.club_id
GROUP BY ss.club_id,
	c.club_name,
	ss.club_domestic_competition,
	ss.season_formatted
ORDER BY ss.club_domestic_competition, ss.season_formatted, c.club_name;
*/


-- Output H: what is the average age by league?
/*
SELECT 
	ss.club_domestic_competition,
	ss.season_formatted,
	COUNT(*) AS n_players,
	CAST(AVG(CAST(ss.age_at_start_season AS DECIMAL(5,2))) AS DECIMAL(5,2)) AS avg_age
FROM CTE_Age_By_Start_Season AS ss
GROUP BY 
	ss.club_domestic_competition,
	ss.season_formatted
ORDER BY ss.club_domestic_competition, ss.season_formatted;
*/


-- Output I: what is the average number of minutes played per season?
/*
SELECT 
	cl.club_name,
	m.competition_id,
	m.season_formatted,
	COUNT(*) AS n_players,
	CAST(AVG(CAST(m.total_minutes_played_by_season AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS avg_minutes_per_player,
	COUNT(CASE WHEN m.total_minutes_played_by_season >= @min_minutes_per_season THEN 1 END) AS n_regular_players,
	CAST(AVG(CASE WHEN m.total_minutes_played_by_season >= @min_minutes_per_season THEN CAST(m.total_minutes_played_by_season AS DECIMAL(10,2)) END) AS DECIMAL(10,2)) AS avg_minutes_per_regular_player
FROM CTE_Minutes_Played_By_Player AS m
INNER JOIN clean.clubs AS cl
	ON m.player_club_id = cl.club_id
GROUP BY m.player_club_id,
	cl.club_name,
	m.competition_id,
	m.season_formatted
ORDER BY m.competition_id, m.season_formatted, cl.club_name;
*/


-- Output J: what percentage of games are played as a starter, by age?
/*
SELECT
	*,
	CAST(CAST(t1.total_n_first_11 AS DECIMAL(18,2)) / t1.total_games * 100 AS DECIMAL(18,2)) AS [n_first_11 (%)],
	CAST(CAST(t1.total_n_subs AS DECIMAL(18,2)) / t1.total_games * 100 AS DECIMAL(18,2)) AS [n_subs (%)]
FROM (
	SELECT
		s.age_at_game_date,
		SUM(s.n_first_11) AS total_n_first_11,
		SUM(s.n_subs) AS total_n_subs,
		SUM(s.games) AS total_games
	FROM CTE_Times_Substitute_By_Age_By_Position AS s
	GROUP BY s.age_at_game_date
) AS t1
ORDER BY t1.age_at_game_date;
*/


-- Output K: what percentage of games are played as a starter, by position?

SELECT
	*,
	CAST(CAST(t1.total_n_first_11 AS DECIMAL(18,2)) / t1.total_games * 100 AS DECIMAL(18,2)) AS [n_first_11 (%)],
	CAST(CAST(t1.total_n_subs AS DECIMAL(18,2)) / t1.total_games * 100 AS DECIMAL(18,2)) AS [n_subs (%)]
FROM (
	SELECT
		s.general_position,
		SUM(s.n_first_11) AS total_n_first_11,
		SUM(s.n_subs) AS total_n_subs,
		SUM(s.games) AS total_games
	FROM CTE_Times_Substitute_By_Age_By_Position AS s
	WHERE s.general_position IS NOT NULL
	GROUP BY s.general_position
) AS t1
ORDER BY t1.general_position;
