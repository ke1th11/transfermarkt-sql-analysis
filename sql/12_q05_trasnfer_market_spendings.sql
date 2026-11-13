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

   Insight: (to be written after running the outputs)

   Note: Only completed transfers with a fee above 0 are used. Loans cannot be separated, because clean.transfers has no transfer type (a paid loan counts as a normal transfer).
   Note: The league of a club is the one in clean.clubs (its current league), not necessarily the league it played in at the date of the transfer, so older seasons can be distorted.
   Note: Clubs without a league in clean.clubs are not part of the top 15, so their own spending and revenue are not in the outputs (they only appear as the other side of a transfer).
   Note: The most recent season can be incomplete (data snapshot) and transfers after the snapshot (is_scheduled = 1) are excluded, so totals of that season tend to be lower.
   Note: In outputs C and D transfers between clubs of the same league are excluded; in outputs A and B (by club) they are included.
   Note: Spending and revenue by club are not net values: a club can appear in A and in B, and no spending is subtracted from revenue.
   Note: In output E very low market values can give extreme ratios (for example a 20,000 % ratio); raise @min_market_value to avoid it.
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
/*
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
*/