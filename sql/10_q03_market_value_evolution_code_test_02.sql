/* Question: How has the market value of players evolved over the seasons? 
			 Which players have seen the largest fluctuations? 
			 Which clubs have the highest total market value? 
			 Which clubs have experienced the greatest increase in their market value?
*/

/* =====================================================================
   RESUMO DAS CORREÇÕES (a lógica original foi mantida)
   ---------------------------------------------------------------------
   0. PRÉ-REQUISITO: corrigir club_id / club_domestic_competition em
      clean.player_valuations (problema vindo do staging). Este script
      assume que essa correção já foi feita.
   1. Rankings com ROW_NUMBER + desempate (em vez de RANK/DENSE_RANK),
      para o "top 3" devolver mesmo 3 linhas por grupo.
   2. NULLs (primeira época de cada clube / first_value = 0) são filtrados
      ANTES do ranking. Antes, com ORDER BY ASC, o NULL vinha primeiro e
      "roubava" o top 3 das descidas.
   3. LAG entre épocas só é válido se a época anterior for CONSECUTIVA
      (nova coluna numérica season_start_year).
   4. LAG calculado uma única vez (CTE intermédia) e divisões com NULLIF.
   5. Joins a clean.players / clean.clubs feitos uma vez, no fim, com
      player_id + club_id (sem DISTINCT e sem multiplicação de linhas).
   6. Subqueries redundantes removidas; SELECT * substituído por colunas.
   7. Nova coluna n_players_valued (cobertura: nº de jogadores com
      avaliação por clube-época) para validar o "valor total do clube".
   8. Parâmetro opcional @min_initial_value para evitar que valores
      iniciais muito pequenos dominem o ranking em percentagem.
   ===================================================================== */

USE TransfermarktDB;

-- 0 = sem filtro (comportamento original). Ex.: 500000 ignora jogadores
-- cujo primeiro valor da época seja inferior a 500k no ranking em %.
DECLARE @min_initial_value DECIMAL(18,2) = 0;

WITH CTE_Players_Market_Value AS
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

CTE_Market_Value_Over_Seasons AS
(
	SELECT 
		*,
		ROW_NUMBER() OVER(PARTITION BY mv.player_id, mv.season_formatted ORDER BY mv.valuation_date ASC) AS ranking_market_value_order_by_time,
		FIRST_VALUE(mv.market_value_in_eur) OVER(PARTITION BY mv.player_id, mv.season_formatted ORDER BY mv.valuation_date ASC) AS first_market_value,
		LAST_VALUE(mv.market_value_in_eur) OVER(PARTITION BY mv.player_id, mv.season_formatted ORDER BY mv.valuation_date ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_market_value
	FROM CTE_Players_Market_Value AS mv
),

CTE_First_Last_Market_Value AS
(
	SELECT 
		os.player_id,
		os.club_id,
		os.club_domestic_competition,
		os.season_formatted,
		os.season_start_year,
		os.first_market_value,
		os.last_market_value
	FROM CTE_Market_Value_Over_Seasons AS os
	WHERE os.ranking_market_value_order_by_time = 1
),

CTE_Market_Value_Rate_By_Season AS
(
	SELECT 
		fl.player_id,
		fl.club_id,
		fl.club_domestic_competition,
		fl.season_formatted,
		fl.season_start_year,
		fl.first_market_value,
		fl.last_market_value,
		fl.last_market_value - fl.first_market_value AS market_value_abs_diff,
		CAST((fl.last_market_value - fl.first_market_value) * 100.0 / NULLIF(fl.first_market_value, 0) AS DECIMAL(10,2)) AS [market_value_rate_diff (%)]
	FROM CTE_First_Last_Market_Value AS fl
	WHERE fl.first_market_value >= @min_initial_value
),

CTE_Market_Value_Prev_Throughout_Season AS
(
	SELECT 
		os.player_id,
		os.club_id,
		os.club_domestic_competition,
		os.valuation_date,
		os.season_formatted,
		os.ranking_market_value_order_by_time,
		os.market_value_in_eur,
		LAG(os.market_value_in_eur) OVER(PARTITION BY os.player_id, os.season_formatted ORDER BY os.ranking_market_value_order_by_time ASC) AS prev_market_value
	FROM CTE_Market_Value_Over_Seasons AS os
),

CTE_Market_Value_Rate_Throughout_Season AS
(
	SELECT 
		pv.player_id,
		pv.club_id,
		pv.club_domestic_competition,
		pv.valuation_date,
		pv.season_formatted,
		pv.ranking_market_value_order_by_time,
		pv.market_value_in_eur,
		pv.market_value_in_eur - pv.prev_market_value AS market_value_diff_throughout_season,
		CAST((pv.market_value_in_eur - pv.prev_market_value) * 100.0 / NULLIF(pv.prev_market_value, 0) AS DECIMAL(10,2)) AS [market_value_rate_diff_throughout_season (%)]
	FROM CTE_Market_Value_Prev_Throughout_Season AS pv
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

CTE_Total_Market_Value_By_Club AS
(
	SELECT 
		t1.club_id,
		t1.club_domestic_competition,
		t1.season_formatted,
		t1.season_start_year,
		SUM(t1.market_value_in_eur) AS total_market_value_by_club,
		COUNT(*) AS n_players_valued  
	FROM (
		SELECT 
			os.player_id,
			os.club_id,
			os.club_domestic_competition,
			os.market_value_in_eur,
			os.valuation_date,
			os.season_formatted,
			os.season_start_year,
			ROW_NUMBER() OVER(PARTITION BY os.player_id, os.season_formatted ORDER BY os.valuation_date DESC) AS ranking_valuation_date_most_recent_by_season
		FROM CTE_Market_Value_Over_Seasons AS os
	) AS t1
	WHERE t1.ranking_valuation_date_most_recent_by_season = 1
	GROUP BY t1.club_id, t1.club_domestic_competition, t1.season_formatted, t1.season_start_year
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
		CASE 
			WHEN pc.prev_season_start_year = pc.season_start_year - 1
				THEN pc.total_market_value_by_club - pc.prev_total_market_value
		END AS market_value_abs_diff_by_club,
		CASE 
			WHEN pc.prev_season_start_year = pc.season_start_year - 1
				THEN CAST((pc.total_market_value_by_club - pc.prev_total_market_value) * 100.0 / NULLIF(pc.prev_total_market_value, 0) AS DECIMAL(10,2))
		END AS [market_value_rate_diff_by_club (%)]
	FROM CTE_Market_Value_Prev_By_Club AS pc
)

/* ---------------------------------------------------------------------
   QUERIES FINAIS (executa uma de cada vez, descomentando a pretendida)
   --------------------------------------------------------------------- */

-- 1) Evolução do valor de cada jogador ao longo da época
SELECT 
	p.player_name,
	cl.club_name,
	ts.club_domestic_competition,
	ts.valuation_date,
	ts.season_formatted,
	ts.market_value_in_eur,
	ts.market_value_diff_throughout_season,
	ts.[market_value_rate_diff_throughout_season (%)]
FROM CTE_Market_Value_Rate_Throughout_Season AS ts
INNER JOIN clean.players AS p
	ON ts.player_id = p.player_id
INNER JOIN clean.clubs AS cl
	ON ts.club_id = cl.club_id
ORDER BY ts.player_id, ts.valuation_date; 

/* 2) Maiores subidas (%) por jogador, liga e época
SELECT
	p.player_name,
	cl.club_name,
	u.club_domestic_competition,
	u.season_formatted,
	u.first_market_value,
	u.last_market_value,
	u.market_value_abs_diff,
	u.[market_value_rate_diff (%)]
FROM CTE_Biggest_Rate_Diff_Upgrades AS u
INNER JOIN clean.players AS p
	ON u.player_id = p.player_id
INNER JOIN clean.clubs AS cl
	ON u.club_id = cl.club_id
ORDER BY u.season_formatted ASC, u.club_domestic_competition ASC, u.[market_value_rate_diff (%)] DESC; */

/* 3) Maiores descidas (%) por jogador, liga e época
SELECT
	p.player_name,
	cl.club_name,
	d.club_domestic_competition,
	d.season_formatted,
	d.first_market_value,
	d.last_market_value,
	d.market_value_abs_diff,
	d.[market_value_rate_diff (%)]
FROM CTE_Biggest_Rate_Diff_Downgrades AS d
INNER JOIN clean.players AS p
	ON d.player_id = p.player_id
INNER JOIN clean.clubs AS cl
	ON d.club_id = cl.club_id
ORDER BY d.season_formatted ASC, d.club_domestic_competition ASC, d.[market_value_rate_diff (%)] ASC; */

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
		ROW_NUMBER() OVER(
			PARTITION BY bc.season_formatted, bc.club_domestic_competition 
			ORDER BY bc.total_market_value_by_club DESC, bc.club_id ASC
		) AS ranking_most_valuable_clubs
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
		ROW_NUMBER() OVER(
			PARTITION BY d.season_formatted, d.club_domestic_competition 
			ORDER BY d.[market_value_rate_diff_by_club (%)] DESC, d.market_value_abs_diff_by_club DESC, d.club_id ASC
		) AS ranking_biggest_market_value_increases
	FROM CTE_Market_Value_Diff_By_Club AS d
	INNER JOIN clean.clubs AS c
		ON d.club_id = c.club_id
	WHERE d.[market_value_rate_diff_by_club (%)] IS NOT NULL
	  AND d.[market_value_rate_diff_by_club (%)] > 0
) AS t1
WHERE ranking_biggest_market_value_increases IN (1,2,3)
ORDER BY season_formatted, club_domestic_competition, ranking_biggest_market_value_increases; */

/*-- 6) Clubes com maiores descidas de valor (%)
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
		ROW_NUMBER() OVER(
			PARTITION BY d.season_formatted, d.club_domestic_competition 
			ORDER BY d.[market_value_rate_diff_by_club (%)] ASC, d.market_value_abs_diff_by_club ASC, d.club_id ASC
		) AS ranking_biggest_market_value_decreases
	FROM CTE_Market_Value_Diff_By_Club AS d
	INNER JOIN clean.clubs AS c
		ON d.club_id = c.club_id
	-- Filtro ANTES do ranking: exclui NULLs (1.ª época / épocas não consecutivas) e variações >= 0
	WHERE d.[market_value_rate_diff_by_club (%)] IS NOT NULL
	  AND d.[market_value_rate_diff_by_club (%)] < 0
) AS t1
WHERE ranking_biggest_market_value_decreases IN (1,2,3)
ORDER BY season_formatted, club_domestic_competition, ranking_biggest_market_value_decreases;*/