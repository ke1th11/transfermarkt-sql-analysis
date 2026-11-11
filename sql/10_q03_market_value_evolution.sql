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

/* 0) Verificação do âmbito: efeito do filtro por competição (executa antes de interpretar)
SELECT
	b.club_domestic_competition,
	COUNT(*) AS n_top15_total,
	SUM(CASE WHEN s.player_id IS NOT NULL THEN 1 ELSE 0 END) AS n_in_scope,
	CAST(SUM(CASE WHEN s.player_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS pct_kept,
	CASE WHEN b.club_domestic_competition IN ('GB1','L1','IT1','ES1','FR1','NL1','PO1','BE1')
		THEN 'verificada' ELSE 'NAO verificavel' END AS league_check
FROM CTE_Valuations_Top15 AS b
LEFT JOIN CTE_Players_Market_Value AS s
	ON s.player_id = b.player_id AND s.valuation_date = b.valuation_date
GROUP BY b.club_domestic_competition
ORDER BY league_check, b.club_domestic_competition; */

-- 1) Maiores subidas (%) de jogadores: fim de época vs fim da época anterior
SELECT
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
ORDER BY u.season_formatted ASC, u.club_domestic_competition ASC, u.[market_value_rate_diff (%)] DESC;

/* 2) Maiores descidas (%) de jogadores
SELECT
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
ORDER BY d.season_formatted ASC, d.club_domestic_competition ASC, d.[market_value_rate_diff (%)] ASC; */

/* 3) Jogadores com maior flutuação dentro da época (amplitude máx - mín)
SELECT
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
ORDER BY mv.season_formatted ASC, mv.club_domestic_competition ASC, mv.ranking_volatility ASC; */

/* 4) Clubes com maior valor de mercado total, por liga e época
SELECT 
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
ORDER BY season_formatted, club_domestic_competition, ranking_most_valuable_clubs; */

/* 5) Clubes com maiores subidas de valor (%)
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
		ROW_NUMBER() OVER(PARTITION BY d.season_formatted, d.club_domestic_competition ORDER BY d.[market_value_rate_diff_by_club (%)] DESC, d.market_value_abs_diff_by_club DESC, d.club_id ASC) AS ranking_biggest_market_value_increases
	FROM CTE_Market_Value_Diff_By_Club AS d
	INNER JOIN clean.clubs AS c
		ON d.club_id = c.club_id
	WHERE d.[market_value_rate_diff_by_club (%)] IS NOT NULL AND d.[market_value_rate_diff_by_club (%)] > 0
) AS t1
WHERE ranking_biggest_market_value_increases IN (1,2,3)
ORDER BY season_formatted, club_domestic_competition, ranking_biggest_market_value_increases; */

/* 6) Clubes com maiores descidas de valor (%)
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
ORDER BY season_formatted, club_domestic_competition, ranking_biggest_market_value_decreases; */