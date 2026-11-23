/* Question: Transfer market: which clubs and leagues spend and earn the most, and which transfers pay the biggest premium over the market value?
			 A) Which clubs spent the most on transfers in each season, by league?
			 B) Which clubs earned the most from transfers in each season, by league?
			 C) Which leagues spent the most on transfers in each season?
			 D) Which leagues earned the most from transfers in each season?
			 E) Which transfers had the highest fee relative to the market value of the player, by league and season?

   Approach: - CTE_Clubs_Competition_Top15_Leagues: clubs that play in a top 15 league, with the league they belong to (clean.clubs).
             - CTE_Transfers_Spending_Top15_Leagues: completed transfers (is_scheduled = 0) with a fee above 0 that were bought by a club of the top 15 leagues.
               The selling club is a LEFT JOIN, so purchases from clubs without a league are kept (from_club_competition_id = NULL).
               A season_start_year is built from the season label ('99/00' = 1999, '00/01' = 2000) so the seasons are sorted chronologically.
             - CTE_Transfers_Revenue_Top15_Leagues: the same, for transfers sold by a club of the top 15 leagues (the buying club is the LEFT JOIN).
             - Spending belongs to the buying club (to_club_id) and revenue to the selling club (from_club_id).
               Free transfers and transfers with an undisclosed fee (NULL) have no value, so they are excluded instead of counted as 0.
             - Ranking: ROW_NUMBER inside each league and season (clubs) or inside each season (leagues), by total fees
               (ties: fewer players, then the id); only the first @top_n are kept. n_transfers counts transfers and n_players distinct players.
             - Leagues (C, D): only transfers with a club from another league (or without a league) are counted,
               because a transfer between two clubs of the same league only moves money inside the league.
             - Ratio (E): fee / market value * 100 and the premium or discount (fee - market value) / market value * 100.
               Only transfers with a market value above @min_market_value; the transfers are ranked inside the league that paid the fee (the buying league).
             - Output A: total spent, transfers and players by club, season and league (top @top_n per league and season).
             - Output B: total received, transfers and players by club, season and league (top @top_n per league and season).
             - Output C: total spent, transfers and players by league and season (top @top_n per season).
             - Output D: total received, transfers and players by league and season (top @top_n per season).
             - Output E: the @top_n transfers with the highest fee to market value ratio by league and season, with the player, the clubs and the premium.
             (Only one final SELECT runs at a time: comment out the others.)

   Insight: - League spending (C): the Premier League is the biggest spending league in all 14 seasons from 12/13 to 25/26, from 189M EUR (35 transfers) in 12/13 to 2.48bn EUR (126 transfers) in 25/26.
              The peak is 22/23 with 2.34bn EUR, 4.7 times the second league (Italy and France, about 498M EUR each). It makes 45% to 70% of the spending of the top 3 leagues in every season (about 55% in a typical one).
              The places behind it rotate: Spain was second in 5 seasons between 14/15 and 19/20 and then left the top 3 for five seasons (21/22 to 25/26); Italy took over (second in 5 of the 6 seasons from 20/21 to 25/26);
              France (second in 12/13, 13/14 and 23/24) and Germany (3 times in the top 3) are occasional. Italy is in the top 3 in 11 of the 14 seasons, Spain and France in 7 each.
              The Premier League dipped only in 20/21 (1.03bn vs 1.26bn EUR), when Spain fell from 842M to 319M EUR.
            - League revenue (D): no league dominates. France is in the top 3 in 12 of the 14 seasons (first 4 times: 15/16, 19/20, 22/23, 25/26), Spain in 8 (first 5 times, all between 13/14 and 20/21), Italy in 7, Germany in 6 (first in 21/22 and 23/24)
              and Portugal in 4 (first in 12/13). The Premier League only appears in 3 seasons (17/18, 24/25 and 25/26) but with record values: 1.07bn EUR in 24/25 (first) and 1.10bn EUR in 25/26, just behind France (1.13bn EUR, 120 transfers).
            - Net balance (C vs D): the Premier League is a net buyer by a wide margin: 24/25 spent 1.80bn and received 1.07bn EUR (-0.73bn), 25/26 spent 2.48bn and received 1.10bn EUR (-1.38bn) and in 22/23 the deficit is at least 1.8bn EUR
              (its revenue was below the third place, 541M EUR). Adding the top 3 clubs of each league and season (12/13 to 25/26, an approximation), the selling leagues received about 1.8 to 2.5 times what they spent: Portugal 3.46bn vs 1.83bn EUR,
              Netherlands 2.31bn vs 1.09bn, Belgium 1.38bn vs 0.74bn, Argentina 0.98bn vs 0.46bn, Brazil 1.69bn vs 0.97bn and Norway 0.25bn vs 0.10bn. The big leagues buy more than they sell (revenue per EUR spent: Premier League 0.57, Spain 0.82, Italy 0.85, France 0.91), and Germany is balanced (1.03).
            - Club spending (A): the biggest seasons are Chelsea with 616M EUR in 22/23 (15 transfers), Liverpool 481M in 25/26 (only 6 transfers), Chelsea 464M in 23/24, PSG 454.5M in 23/24 and Barcelona 348M in 17/18 (6 transfers).
              11 of the 15 biggest spending seasons belong to Premier League clubs (Chelsea 5 times, Manchester City 3 times, plus Liverpool, Brighton and Tottenham); the other 4 are PSG and Barcelona, twice each.
              Concentration is very different by league (12/13 to 25/26): only 3 clubs led spending in Spain and Portugal, 4 in France, Italy, Netherlands and Argentina, against 6 in England and 7 in Brazil and Mexico.
              PSG led France in 9 of the 14 seasons; Benfica, Ajax and River Plate led 8 times, Barcelona, Juventus and Club Brugge 7. Porto and Benfica are in the top 3 of Portugal in all 14 seasons, Ajax and PSV in 13.
            - Club revenue (B): more spread than spending. The Premier League had 10 different top sellers (against 6 top spenders), and 6 of the 15 biggest sale seasons are Premier League clubs, all since 23/24 (Chelsea 3 times, Aston Villa, Bournemouth, Wolves).
              The biggest are Monaco 330M EUR in 18/19 (7 transfers), Chelsea 318M in 25/26 (13), Atlético de Madrid 311M in 19/20 (only 5), Bournemouth 307M in 25/26, Benfica 288M in 22/23 (17 transfers) and Dortmund 268M in 17/18.
              Chelsea is on both lists (5 of the biggest spending seasons and 3 of the biggest selling ones), which shows a high turnover model. Selling clubs lead their league repeatedly: River Plate and Atlético Nacional 9 times, Benfica and Ajax 7, Monaco and Bodø/Glimt 6.
            - Fee vs market value (E): in the 706 ranked transfers, 89% had a fee above the market value and 73% above twice the market value. The median ratio of the first-ranked transfer of each season is 160% to 200% until 08/09, 280% to 600% from 09/10 to 15/16 and 515% to 1,525% from 16/17 to 25/26.
              By league, the median ratio of the ranked transfers is highest in the Premier League and Italy (about 2,000%, all above 100%) and lowest in Colombia (91%, only 29% above 100%), Norway (217%) and Mexico (310%).
              The very high ratios come from very low market values, not from big fees: 414 of the 706 transfers have a market value under 1M EUR and 199 at most 300,000 EUR. The 15 highest ratios (4,000% to 24,000%) are all small values of players bought from lower
              divisions or youth teams, for example Emerson Royal (12M EUR vs 50,000 EUR, 24,000%), Kyle Walker (5.9M vs 50,000, 11,800%), Bart Verbruggen (9,200%) and Bebé (8,800%). It points to outdated valuations of young players more than to overpaying.
            - Biggest fees in E: the ten largest fees in the output were 1.2 to 27 times the market value: Anthony Gordon 80M EUR (65M, 123%), Loïs Openda 42.75M (171%), Alessandro Bastoni 40.7M (1.5M, 2,713%), Falcao 40M (160%), Darwin Núñez 34M (340%),
              Di María 33M (347%), Jefferson Lerma 30.5M (2M, 1,525%), Bellingham 30.15M (274%). The median ratio of all ranked transfers grows from 180% (until 10/11) to 293% (11/12-15/16) and 470% (16/17-20/21) and stays at 467% since 21/22.
              The only real discounts are small deals (fees up to 300,000 EUR), the lowest being Amahl Pellegrino at 12% (15,000 vs 125,000 EUR).

   Note: Only completed transfers with a fee above 0 are used. Loans cannot be separated, because clean.transfers has no transfer type (a paid loan counts as a normal transfer).
   Note: The league of a club is the one in clean.clubs (its current league), not necessarily the league it played in at the date of the transfer, so older seasons can be distorted.
   Note: Clubs without a league in clean.clubs are not part of the top 15, so their own spending and revenue are not in the outputs (they only appear as the other side of a transfer).
   Note: Seasons up to 09/10 have very few transfers recorded (for example only 1 transfer in 03/04), so only 12/13 to 25/26 are used in the insights; 26/27 is the current season and is incomplete
		 (for example 12 Premier League transfers and 286M EUR), so it should not be compared with full seasons.
   Note: Outputs A to D only keep the top 3 clubs per league and season (or the top 3 leagues per season), so league totals and net balances are approximations built from these values (a lower bound for the deficit of the Premier League).
   Note: In outputs C and D clubs without a league count as external, which includes clubs from lower divisions of the same country (for example part of the Premier League spending are purchases from English clubs outside the top flight).
   Note: In outputs C and D transfers between clubs of the same league are excluded; in outputs A and B (by club) they are included.
   Note: Spending and revenue by club are not net values: a club can appear in A and in B, and no spending is subtracted from revenue.
   Note: Output E ranks by ratio, so it mostly shows transfers with a very low (often outdated) market value, such as young players from lower divisions; it does not mean that the clubs overpaid.
		 To study relevant transfers raise @min_market_value (for example 5,000,000) and run it again.
   Note: The ratio and the premium carry the same information (ratio = premium + 100); both are shown because they are read differently.
   Note: Fees and market values are in EUR as they are in the source and are not adjusted for inflation, so the older seasons are not directly comparable with the recent ones.
*/

USE TransfermarktDB;

DECLARE @top_n INT = 3;
DECLARE @min_market_value DECIMAL(18,2) = 0;

WITH CTE_Clubs_Competition_Top15_Leagues AS
(
	SELECT
		cl.club_id,
		cl.domestic_competition_id
	FROM clean.clubs AS cl
	INNER JOIN clean.competitions AS c
		ON cl.domestic_competition_id = c.competition_id
	WHERE c.is_top15_league = 1
),

CTE_Transfers_Spending_Top15_Leagues AS
(
	SELECT
		t.transfer_id,
		t.player_id,
		t.transfer_date,
		t.transfer_season,
		CASE
			WHEN TRY_CAST(LEFT(t.transfer_season, 2) AS INT) >= 50
				THEN 1900 + TRY_CAST(LEFT(t.transfer_season, 2) AS INT)
			ELSE 2000 + TRY_CAST(LEFT(t.transfer_season, 2) AS INT)
		END AS season_start_year,
		cf.domestic_competition_id AS from_club_competition_id,
		t.from_club_id,
		ct.domestic_competition_id AS to_club_competition_id,
		t.to_club_id,
		t.transfer_fee,
		t.market_value_in_eur
	FROM clean.transfers AS t
	INNER JOIN CTE_Clubs_Competition_Top15_Leagues AS ct
		ON t.to_club_id = ct.club_id
	LEFT JOIN clean.clubs AS cf
		ON t.from_club_id = cf.club_id
	WHERE t.is_scheduled = 0 AND t.transfer_fee > 0
),

CTE_Transfers_Revenue_Top15_Leagues AS
(
	SELECT
		t.transfer_id,
		t.player_id,
		t.transfer_date,
		t.transfer_season,
		CASE
			WHEN TRY_CAST(LEFT(t.transfer_season, 2) AS INT) >= 50
				THEN 1900 + TRY_CAST(LEFT(t.transfer_season, 2) AS INT)
			ELSE 2000 + TRY_CAST(LEFT(t.transfer_season, 2) AS INT)
		END AS season_start_year,
		cf.domestic_competition_id AS from_club_competition_id,
		t.from_club_id,
		ct.domestic_competition_id AS to_club_competition_id,
		t.to_club_id,
		t.transfer_fee,
		t.market_value_in_eur
	FROM clean.transfers AS t
	INNER JOIN CTE_Clubs_Competition_Top15_Leagues AS cf
		ON t.from_club_id = cf.club_id
	LEFT JOIN clean.clubs AS ct
		ON t.to_club_id = ct.club_id
	WHERE t.is_scheduled = 0 AND t.transfer_fee > 0
)


-- Output A: which clubs spent the most on transfers in each season, by league?
/*
SELECT
	t2.to_club_competition_id AS competition_id,
	c.club_name,
	t2.transfer_season,
	t2.total_spent,
	t2.n_transfers,
	t2.n_players,
	t2.ranking_spending
FROM (
	SELECT
		t1.to_club_competition_id,
		t1.to_club_id,
		t1.transfer_season,
		t1.season_start_year,
		t1.total_spent,
		t1.n_transfers,
		t1.n_players,
		ROW_NUMBER() OVER(PARTITION BY t1.to_club_competition_id, t1.transfer_season ORDER BY t1.total_spent DESC, t1.n_players ASC, t1.to_club_id ASC) AS ranking_spending
	FROM (
		SELECT
			s.to_club_competition_id,
			s.to_club_id,
			s.transfer_season,
			s.season_start_year,
			SUM(s.transfer_fee) AS total_spent,
			COUNT(*) AS n_transfers,
			COUNT(DISTINCT s.player_id) AS n_players
		FROM CTE_Transfers_Spending_Top15_Leagues AS s
		GROUP BY s.to_club_competition_id, s.to_club_id, s.transfer_season, s.season_start_year
	) AS t1
) AS t2
INNER JOIN clean.clubs AS c
	ON t2.to_club_id = c.club_id
WHERE t2.ranking_spending <= @top_n
ORDER BY t2.to_club_competition_id, t2.season_start_year, t2.ranking_spending;
*/


-- Output B: which clubs earned the most from transfers in each season, by league?
/*
SELECT
	t2.from_club_competition_id AS competition_id,
	c.club_name,
	t2.transfer_season,
	t2.total_revenue,
	t2.n_transfers,
	t2.n_players,
	t2.ranking_revenue
FROM (
	SELECT
		t1.from_club_competition_id,
		t1.from_club_id,
		t1.transfer_season,
		t1.season_start_year,
		t1.total_revenue,
		t1.n_transfers,
		t1.n_players,
		ROW_NUMBER() OVER(PARTITION BY t1.from_club_competition_id, t1.transfer_season ORDER BY t1.total_revenue DESC, t1.n_players ASC, t1.from_club_id ASC) AS ranking_revenue
	FROM (
		SELECT
			r.from_club_competition_id,
			r.from_club_id,
			r.transfer_season,
			r.season_start_year,
			SUM(r.transfer_fee) AS total_revenue,
			COUNT(*) AS n_transfers,
			COUNT(DISTINCT r.player_id) AS n_players
		FROM CTE_Transfers_Revenue_Top15_Leagues AS r
		GROUP BY r.from_club_competition_id, r.from_club_id, r.transfer_season, r.season_start_year
	) AS t1
) AS t2
INNER JOIN clean.clubs AS c
	ON t2.from_club_id = c.club_id
WHERE t2.ranking_revenue <= @top_n
ORDER BY t2.from_club_competition_id, t2.season_start_year, t2.ranking_revenue;
*/


-- Output C: which leagues spent the most on transfers in each season?
/*
SELECT
	t2.to_club_competition_id AS competition_id,
	t2.transfer_season,
	t2.total_spent,
	t2.n_transfers,
	t2.n_players,
	t2.ranking_spending
FROM (
	SELECT
		t1.to_club_competition_id,
		t1.transfer_season,
		t1.season_start_year,
		t1.total_spent,
		t1.n_transfers,
		t1.n_players,
		ROW_NUMBER() OVER(PARTITION BY t1.transfer_season ORDER BY t1.total_spent DESC, t1.n_players ASC, t1.to_club_competition_id ASC) AS ranking_spending
	FROM (
		SELECT
			s.to_club_competition_id,
			s.transfer_season,
			s.season_start_year,
			SUM(s.transfer_fee) AS total_spent,
			COUNT(*) AS n_transfers,
			COUNT(DISTINCT s.player_id) AS n_players
		FROM CTE_Transfers_Spending_Top15_Leagues AS s
		WHERE s.from_club_competition_id IS NULL OR s.from_club_competition_id <> s.to_club_competition_id
		GROUP BY s.to_club_competition_id, s.transfer_season, s.season_start_year
	) AS t1
) AS t2
WHERE t2.ranking_spending <= @top_n
ORDER BY t2.season_start_year, t2.ranking_spending;
*/


-- Output D: which leagues earned the most from transfers in each season?
/*
SELECT
	t2.from_club_competition_id AS competition_id,
	t2.transfer_season,
	t2.total_revenue,
	t2.n_transfers,
	t2.n_players,
	t2.ranking_revenue
FROM (
	SELECT
		t1.from_club_competition_id,
		t1.transfer_season,
		t1.season_start_year,
		t1.total_revenue,
		t1.n_transfers,
		t1.n_players,
		ROW_NUMBER() OVER(PARTITION BY t1.transfer_season ORDER BY t1.total_revenue DESC, t1.n_players ASC, t1.from_club_competition_id ASC) AS ranking_revenue
	FROM (
		SELECT
			r.from_club_competition_id,
			r.transfer_season,
			r.season_start_year,
			SUM(r.transfer_fee) AS total_revenue,
			COUNT(*) AS n_transfers,
			COUNT(DISTINCT r.player_id) AS n_players
		FROM CTE_Transfers_Revenue_Top15_Leagues AS r
		WHERE r.to_club_competition_id IS NULL OR r.to_club_competition_id <> r.from_club_competition_id
		GROUP BY r.from_club_competition_id, r.transfer_season, r.season_start_year
	) AS t1
) AS t2
WHERE t2.ranking_revenue <= @top_n
ORDER BY t2.season_start_year, t2.ranking_revenue;
*/


-- Output E: which transfers had the highest fee relative to the market value of the player, by league and season?

SELECT
	p.player_name,
	t2.transfer_season,
	t2.from_club_competition_id,
	c1.club_name AS from_club_name,
	t2.to_club_competition_id,
	c2.club_name AS to_club_name,
	t2.transfer_fee,
	t2.market_value_in_eur,
	t2.[transfer_fee_ratio (%)],
	t2.[premium/discount (%)],
	t2.ranking_transfer_fee_ratio
FROM (
	SELECT
		t1.*,
		ROW_NUMBER() OVER(PARTITION BY t1.to_club_competition_id, t1.transfer_season ORDER BY t1.[transfer_fee_ratio (%)] DESC, t1.transfer_fee DESC, t1.transfer_id ASC) AS ranking_transfer_fee_ratio
	FROM (
		SELECT
			s.transfer_id,
			s.player_id,
			s.transfer_season,
			s.season_start_year,
			s.from_club_competition_id,
			s.from_club_id,
			s.to_club_competition_id,
			s.to_club_id,
			s.transfer_fee,
			s.market_value_in_eur,
			CAST(s.transfer_fee * 100.0 / s.market_value_in_eur AS DECIMAL(20,2)) AS [transfer_fee_ratio (%)],
			CAST((s.transfer_fee - s.market_value_in_eur) * 100.0 / s.market_value_in_eur AS DECIMAL(20,2)) AS [premium/discount (%)]
		FROM CTE_Transfers_Spending_Top15_Leagues AS s
		WHERE s.market_value_in_eur > @min_market_value AND s.market_value_in_eur > 0
	) AS t1
) AS t2
INNER JOIN clean.clubs AS c2
	ON t2.to_club_id = c2.club_id
LEFT JOIN clean.clubs AS c1
	ON t2.from_club_id = c1.club_id
LEFT JOIN clean.players AS p
	ON t2.player_id = p.player_id
WHERE t2.ranking_transfer_fee_ratio <= @top_n
ORDER BY t2.to_club_competition_id, t2.season_start_year, t2.ranking_transfer_fee_ratio;
