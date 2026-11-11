/* Question: How has the market value of players evolved over the seasons? 
			 Which players have seen the largest fluctuations? 
			 Which clubs have the highest total market value? 
			 Which clubs have experienced the greatest increase in their market value?
*/

USE TransfermarktDB;

DECLARE @min_initial_value DECIMAL(18,2) = 500000;
DECLARE @first_season INT = 2012;
DECLARE @last_complete_season INT = 2025;

WITH CTE_Valuations_Top15 AS
(
	SELECT
		v.player_id,
		p.player_name,
		v.club_id,
		cl.club_name,
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
		END AS season_formatted
	FROM clean.player_valuations AS v
	INNER JOIN clean.competitions AS c
		ON v.club_domestic_competition = c.competition_id
	INNER JOIN clean.clubs AS cl
		ON v.club_id = cl.club_id
	INNER JOIN clean.players AS p
		ON v.player_id = p.player_id
	WHERE c.is_top15_league = 1
),

CTE_Club_League_Seasons AS
(
	SELECT g.competition_id, g.season, g.home_club_id AS club_id FROM clean.games AS g
	UNION
	SELECT g.competition_id, g.season, g.away_club_id         FROM clean.games AS g
),

CTE_Players_Market_Value AS
(
	SELECT b.*
	FROM CTE_Valuations_Top15 AS b
	LEFT JOIN CTE_Club_League_Seasons AS ls
		ON  ls.competition_id = b.club_domestic_competition AND ls.season = b.season_start_year AND ls.club_id = b.club_id
	WHERE b.season_start_year BETWEEN @first_season AND @last_complete_season AND (b.club_domestic_competition NOT IN ('GB1','L1','IT1','ES1','FR1','NL1','PO1','BE1') OR ls.club_id IS NOT NULL)                                                      
),

CTE_Player_Season_Summary AS
(
	SELECT
		t1.player_id,
		t1.club_id,                          
		t1.club_domestic_competition,
		t1.season_formatted,
		t1.season_start_year,
		t1.market_value_in_eur AS last_market_value,
		t1.max_market_value,
		t1.min_market_value,
		t1.stdev_market_value,
		t1.n_valuations
	FROM (
		SELECT
			mv.*,
			MAX(mv.market_value_in_eur)   OVER(PARTITION BY mv.player_id, mv.season_formatted) AS max_market_value,
			MIN(mv.market_value_in_eur)   OVER(PARTITION BY mv.player_id, mv.season_formatted) AS min_market_value,
			STDEV(mv.market_value_in_eur) OVER(PARTITION BY mv.player_id, mv.season_formatted) AS stdev_market_value,
			COUNT(*)                      OVER(PARTITION BY mv.player_id, mv.season_formatted) AS n_valuations,
			ROW_NUMBER() OVER(PARTITION BY mv.player_id, mv.season_formatted ORDER BY mv.valuation_date DESC) AS rn_most_recent
		FROM CTE_Players_Market_Value AS mv
	) AS t1
	WHERE t1.rn_most_recent = 1
),

CTE_Player_Prev_Season AS
(
	SELECT
		ss.*,
		LAG(ss.last_market_value) OVER(PARTITION BY ss.player_id ORDER BY ss.season_start_year ASC) AS prev_last_market_value,
		LAG(ss.season_start_year) OVER(PARTITION BY ss.player_id ORDER BY ss.season_start_year ASC) AS prev_season_start_year
	FROM CTE_Player_Season_Summary AS ss
),

CTE_Market_Value_Rate_By_Season AS
(
	SELECT
		ps.player_id,
		ps.club_id,
		ps.club_domestic_competition,
		ps.season_formatted,
		ps.season_start_year,
		ps.prev_last_market_value,
		ps.last_market_value,
		ps.last_market_value - ps.prev_last_market_value AS market_value_abs_diff,
		CAST((ps.last_market_value - ps.prev_last_market_value) * 100.0 / NULLIF(ps.prev_last_market_value, 0) AS DECIMAL(10,2)) AS [market_value_rate_diff (%)]
	FROM CTE_Player_Prev_Season AS ps
	WHERE ps.prev_season_start_year = ps.season_start_year - 1 AND ps.prev_last_market_value >= @min_initial_value
),

CTE_Biggest_Rate_Diff_Upgrades AS
(
	SELECT *
	FROM (
		SELECT 
			bs.*,
			ROW_NUMBER() OVER(PARTITION BY bs.club_domestic_competition, bs.season_formatted ORDER BY bs.[market_value_rate_diff (%)] DESC, bs.market_value_abs_diff DESC, bs.player_id ASC) AS ranking_rate_diff
		FROM CTE_Market_Value_Rate_By_Season AS bs
		WHERE bs.[market_value_rate_diff (%)] IS NOT NULL AND bs.[market_value_rate_diff (%)] > 0
	) AS t1
	WHERE ranking_rate_diff IN (1,2,3)
),

CTE_Biggest_Rate_Diff_Downgrades AS
(
	SELECT *
	FROM (
		SELECT 
			bs.*,
			ROW_NUMBER() OVER(PARTITION BY bs.club_domestic_competition, bs.season_formatted ORDER BY bs.[market_value_rate_diff (%)] ASC, bs.market_value_abs_diff ASC, bs.player_id ASC) AS ranking_rate_diff
		FROM CTE_Market_Value_Rate_By_Season AS bs
		WHERE bs.[market_value_rate_diff (%)] IS NOT NULL AND bs.[market_value_rate_diff (%)] < 0
	) AS t1
	WHERE ranking_rate_diff IN (1,2,3)
),

CTE_Player_Volatility AS
(
	SELECT
		ss.player_id,
		ss.club_id,
		ss.club_domestic_competition,
		ss.season_formatted,
		ss.n_valuations,
		ss.min_market_value,
		ss.max_market_value,
		ss.max_market_value - ss.min_market_value AS amplitude_abs,
		CAST((ss.max_market_value - ss.min_market_value) * 100.0 / NULLIF(ss.min_market_value, 0) AS DECIMAL(10,2)) AS [amplitude_rate (%)],
		CAST(ss.stdev_market_value AS DECIMAL(18,2)) AS stdev_market_value
	FROM CTE_Player_Season_Summary AS ss
	WHERE ss.n_valuations >= 2 AND ss.min_market_value >= @min_initial_value
),

CTE_Most_Volatile_Players AS
(
	SELECT *
	FROM (
		SELECT
			vo.*,
			ROW_NUMBER() OVER(PARTITION BY vo.club_domestic_competition, vo.season_formatted ORDER BY vo.amplitude_abs DESC, vo.[amplitude_rate (%)] DESC, vo.player_id ASC) AS ranking_volatility
		FROM CTE_Player_Volatility AS vo
		WHERE vo.amplitude_abs > 0
	) AS t1
	WHERE ranking_volatility IN (1,2,3)
),

CTE_Total_Market_Value_By_Club AS
(
	SELECT 
		ss.club_id,
		ss.club_domestic_competition,
		ss.season_formatted,
		ss.season_start_year,
		SUM(ss.last_market_value) AS total_market_value_by_club,
		COUNT(*) AS n_players_valued
	FROM CTE_Player_Season_Summary AS ss
	GROUP BY ss.club_id, ss.club_domestic_competition, ss.season_formatted, ss.season_start_year
),

CTE_Market_Value_Prev_By_Club AS
(
	SELECT 
		bc.*,
		LAG(bc.total_market_value_by_club) OVER(PARTITION BY bc.club_id ORDER BY bc.season_start_year ASC) AS prev_total_market_value,
		LAG(bc.season_start_year) OVER(PARTITION BY bc.club_id ORDER BY bc.season_start_year ASC) AS prev_season_start_year
	FROM CTE_Total_Market_Value_By_Club AS bc
),

CTE_Market_Value_Diff_By_Club AS
(
	SELECT 
		pc.club_id,
		pc.club_domestic_competition,
		pc.season_formatted,
		pc.season_start_year,
		pc.total_market_value_by_club,
		pc.n_players_valued,
		CASE WHEN pc.prev_season_start_year = pc.season_start_year - 1
			THEN pc.total_market_value_by_club - pc.prev_total_market_value
		END AS market_value_abs_diff_by_club,
		CASE WHEN pc.prev_season_start_year = pc.season_start_year - 1
			THEN CAST((pc.total_market_value_by_club - pc.prev_total_market_value) * 100.0 / NULLIF(pc.prev_total_market_value, 0) AS DECIMAL(10,2))
		END AS [market_value_rate_diff_by_club (%)]
	FROM CTE_Market_Value_Prev_By_Club AS pc
)

/* Question: Which players had the biggest percentage rise in market value from the end of one season to the end of the next, in each league?

   Approach: - Last valuation of the season compared with the last valuation of the previous season (absolute and % difference).
             - Only players with a previous value of at least 500K EUR; the top 3 per league and season by % rise are kept.

   Insight: - Typical case: median rise of +500% (from 0.95M to 7.0M EUR); 67% started at 1M or less, so these are mostly young breakouts. 118 of the 529 rows are above +1,000%.
            - Largest %: Mainoo +6,150% (0.8M to 50M, 2023/24) and Diomande +5,900% (1.5M to 90M, 2025/26, also the largest absolute rise at +88.5M).
              Largest absolute rises from higher bases: De Jong +78M (2018/19), Haaland +67M (2019/20), Huijsen +50M (2024/25).
            - Median rise is highest in the Premier League (971%), Bundesliga, Ligue 1 and Serie A (900%) and lowest in Colombia (94%) and Norway (86%).

   Note: Ranking by % favours players with a low starting value; the absolute difference shows the real market movers.
   Note: Colombia starts in 2014 and MLS in 2016, so they have fewer rows.
*/

/*SELECT
	p.player_name,
	cl.club_name,
	u.club_domestic_competition,
	u.season_formatted,
	u.prev_last_market_value,
	u.last_market_value,
	u.market_value_abs_diff,
	u.[market_value_rate_diff (%)]
FROM CTE_Biggest_Rate_Diff_Upgrades AS u
INNER JOIN clean.players AS p
	ON u.player_id = p.player_id
INNER JOIN clean.clubs AS cl
	ON u.club_id = cl.club_id
ORDER BY u.season_formatted ASC, u.club_domestic_competition ASC, u.[market_value_rate_diff (%)] DESC;*/


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


/* Question: Which players had the biggest percentage fall in market value from the end of one season to the end of the next, in each league?

   Approach: - Same logic as the previous query, keeping the biggest % falls (previous value of at least 500K EUR; top 3 per league and season).

   Insight: - Typical case: median fall of -70% (from 2.5M to 0.85M EUR); 113 of the 533 rows are at -80% or worse and 36% end the season at 500K or less.
            - Steepest: Mandžukić -92% (10M to 0.8M, 2020/21) and Kirian Rodríguez -91.7% (12M to 1M, 2024/25).
              Largest absolute falls: Boniface -35M (40M to 5M, 2025/26), Antony -35M (60M to 25M, 2023/24), Højbjerg -27M, Umtiti -24M, Ward-Prowse -22M.
            - Falls are deepest in Serie A (-80%), Bundesliga (-79%) and La Liga (-78%), and mildest in Colombia and Norway (-50%).
            - The median fall deepens over time, from about -67% (2013) to about -77% (2025).

   Note: Falls are capped at -100% while rises are unbounded, so the % of this query and the previous one are not comparable. Compare absolute differences instead (median +6.0M vs -1.75M).
*/

/*SELECT
	p.player_name,
	cl.club_name,
	d.club_domestic_competition,
	d.season_formatted,
	d.prev_last_market_value,
	d.last_market_value,
	d.market_value_abs_diff,
	d.[market_value_rate_diff (%)]
FROM CTE_Biggest_Rate_Diff_Downgrades AS d
INNER JOIN clean.players AS p
	ON d.player_id = p.player_id
INNER JOIN clean.clubs AS cl
	ON d.club_id = cl.club_id
ORDER BY d.season_formatted ASC, d.club_domestic_competition ASC, d.[market_value_rate_diff (%)] ASC;*/


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


/* Question: Which players had the largest fluctuation in market value within a single season?

   Approach: - For each player and season with at least 2 valuations: minimum, maximum, amplitude (max - min, absolute and %), standard deviation and number of valuations.
             - The top 3 per league and season are kept, ranked by absolute amplitude.

   Insight: - Median amplitude of 10M EUR (+114%). The largest were Salah +110M (40M to 150M, 2017/18), Sancho +80M (2018/19) and Yamal +80M (120M to 200M, 2024/25).
              28 player-seasons have an amplitude of 50M or more.
            - Largest % amplitudes: Aouar +4,275% (0.8M to 35M, 2017/18), Musiala +3,700% (2020/21), Mbappé +2,233% (2016/17).
            - More valuations in the season mean larger amplitudes: median 3.3M with 2 valuations, 9M with 3, 19M with 4 and 31.5M with 5.
            - Median amplitude is highest in the Premier League (39M) and La Liga (30M) and lowest in Colombia (0.9M) and Norway (0.7M); in % terms, Argentina (220%) and Belgium (180%) lead.

   Note: The query only measures max - min, not direction or order: a large amplitude does not show whether the value rose or fell.
*/

/*SELECT
	p.player_name,
	cl.club_name,
	mv.club_domestic_competition,
	mv.season_formatted,
	mv.n_valuations,
	mv.min_market_value,
	mv.max_market_value,
	mv.amplitude_abs,
	mv.[amplitude_rate (%)],
	mv.stdev_market_value
FROM CTE_Most_Volatile_Players AS mv
INNER JOIN clean.players AS p
	ON mv.player_id = p.player_id
INNER JOIN clean.clubs AS cl
	ON mv.club_id = cl.club_id
ORDER BY mv.season_formatted ASC, mv.club_domestic_competition ASC, mv.ranking_volatility ASC;*/


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


/* Question: Which clubs had the highest total market value in each league and season?

   Approach: - Sum of the market value of each club's valued players at the end of the season, together with the number of valued players.
             - The top 3 clubs per league and season are kept (2012 to 2025/26).

   Insight: - Highest totals: PSG 2025/26 (1.37B EUR), Man City 2025/26 (1.33B) and 2023/24 (1.30B), Arsenal 2025/26 (1.25B), Real Madrid 2024/25 (1.21B).
            - Dominance: PSG and Bayern lead their league in all 14 seasons, Man City in 11 (Chelsea the other 3), Ajax in 10 of 14, Real Madrid in 9 of 14 (Barcelona 5) and Juventus in 8 (Inter 4). In Portugal, Porto and Benfica led 6 seasons each and Sporting 2 (2024/25 and 2025/26).
            - Ligue 1 is the most concentrated league (the 1st club is worth 2.7 times the 3rd, median); the Premier League is the most balanced (1.2 times).
            - Growth: the top-3 total of the Premier League grew from 1.25B to 3.69B, La Liga from 1.32B to 2.92B and Ligue 1 from 0.55B to 2.18B. Serie A peaked in 2018/19 (1.89B) and is at 1.62B.

   Note: Totals only include valued players, so clubs are not strictly comparable. In 28 club-seasons (mainly early MLS, Colombia and Mexico) only 1 to 5 players are valued.
*/

/*SELECT 
	club_name,
	club_domestic_competition,
	season_formatted,
	total_market_value_by_club,
	n_players_valued
FROM (
	SELECT 
		c.club_name,
		bc.club_domestic_competition,
		bc.season_formatted,
		bc.total_market_value_by_club,
		bc.n_players_valued,
		ROW_NUMBER() OVER(PARTITION BY bc.season_formatted, bc.club_domestic_competition ORDER BY bc.total_market_value_by_club DESC, bc.club_id ASC) AS ranking_most_valuable_clubs
	FROM CTE_Total_Market_Value_By_Club AS bc
	INNER JOIN clean.clubs AS c
		ON bc.club_id = c.club_id
) AS t1
WHERE ranking_most_valuable_clubs IN (1,2,3)
ORDER BY season_formatted, club_domestic_competition, ranking_most_valuable_clubs;*/


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


/* Question: Which clubs had the biggest percentage rise in total market value from one season to the next, in each league?

   Approach: - Club total (sum of valued players) compared with the previous season's total (absolute and % difference).
             - The top 3 per league and season by % rise are kept (from 2013).

   Insight: - Typical case: median rise of +69% and +17.2M EUR. The largest % come from very small bases or new clubs: Belgrano +10,000% (2015) and St. Louis City +6,309% (2023).
            - Largest absolute rises: Arsenal 2022/23 (+442M, +82%), Man City 2017/18 (+427M, +78%), Liverpool 2018/19 (+390M, +54%) and Ajax 2018/19 (+272M, +132%).
              Most recent: Como 2025/26 (+187M, +94%).
            - Median rise is about 38% to 45% in the five biggest leagues, against 215% in Argentina, 192% in MLS and 169% in Brazil.

   Note: 91 rows have 10 or fewer valued players and 130 start below 5M EUR, so % is very volatile. The set of valued players also changes between seasons (e.g. Inter 2014/15, +328%).
*/

/*SELECT 
	club_name,
	club_domestic_competition,
	season_formatted,
	total_market_value_by_club,
	n_players_valued,
	market_value_abs_diff_by_club,
	[market_value_rate_diff_by_club (%)]
FROM (
	SELECT 
		c.club_name,
		d.club_domestic_competition,
		d.season_formatted,
		d.total_market_value_by_club,
		d.n_players_valued,
		d.market_value_abs_diff_by_club,
		d.[market_value_rate_diff_by_club (%)],
		ROW_NUMBER() OVER(PARTITION BY d.season_formatted, d.club_domestic_competition ORDER BY d.[market_value_rate_diff_by_club (%)] DESC, d.market_value_abs_diff_by_club DESC, d.club_id ASC) AS ranking_biggest_market_value_increases
	FROM CTE_Market_Value_Diff_By_Club AS d
	INNER JOIN clean.clubs AS c
		ON d.club_id = c.club_id
	WHERE d.[market_value_rate_diff_by_club (%)] IS NOT NULL AND d.[market_value_rate_diff_by_club (%)] > 0
) AS t1
WHERE ranking_biggest_market_value_increases IN (1,2,3)
ORDER BY season_formatted, club_domestic_competition, ranking_biggest_market_value_increases;*/


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

/* Question: Which clubs had the biggest percentage fall in total market value from one season to the next, in each league?

   Approach: - Same logic as the previous query, keeping the biggest % falls (only clubs whose value fell are returned).

   Insight: - Typical case: median fall of -26% and -9.9M EUR. Largest absolute falls: Chelsea 2019/20 (-260M, -28%), Barcelona 2019/20 (-260M, -24%), Real Madrid 2020/21 (-197M) and Napoli 2023/24 (-176M).
              The biggest % falls come from very small clubs (Guadalajara -96%, Chapecoense -94%) and mostly reflect few valued players.
            - 2019/20 has the deepest median fall (-34%) and the largest absolute losses, followed by a heavy 2020/21, which fits the COVID-era correction.
            - Median fall is deepest in Brazil (-49%) and Argentina (-45%) and mildest in the Premier League (-11%), but the Premier League has the largest absolute falls (median -47M).

   Note: Fewer than 3 rows appear in 20 league-seasons (e.g. no Premier League club in 2015/16 and 2016/17), as only declines are returned.
   Note: 54 rows have 5 or fewer valued players, so some falls come from changes in which players are valued.
   Note: Chelsea and Barcelona 2019/20 have exactly the same absolute fall (-259.85M EUR); worth checking in the source data.
*/

SELECT 
	club_name,
	club_domestic_competition,
	season_formatted,
	total_market_value_by_club,
	n_players_valued,
	market_value_abs_diff_by_club,
	[market_value_rate_diff_by_club (%)]
FROM (
	SELECT 
		c.club_name,
		d.club_domestic_competition,
		d.season_formatted,
		d.total_market_value_by_club,
		d.n_players_valued,
		d.market_value_abs_diff_by_club,
		d.[market_value_rate_diff_by_club (%)],
		ROW_NUMBER() OVER(PARTITION BY d.season_formatted, d.club_domestic_competition ORDER BY d.[market_value_rate_diff_by_club (%)] ASC, d.market_value_abs_diff_by_club ASC, d.club_id ASC) AS ranking_biggest_market_value_decreases
	FROM CTE_Market_Value_Diff_By_Club AS d
	INNER JOIN clean.clubs AS c
		ON d.club_id = c.club_id
	WHERE d.[market_value_rate_diff_by_club (%)] IS NOT NULL AND d.[market_value_rate_diff_by_club (%)] < 0
) AS t1
WHERE ranking_biggest_market_value_decreases IN (1,2,3)
ORDER BY season_formatted, club_domestic_competition, ranking_biggest_market_value_decreases; 