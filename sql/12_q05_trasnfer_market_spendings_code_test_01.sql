-- Gasto líquido dos clubes em transferências por época, ignorando as agendadas e as taxas desconhecidas.
-- Quais clubes mais arrecadaram dinheiro com vendas.
-- Maiores transferências por clube e liga e relação entre a taxa paga e o valor de mercado.

USE TransfermarktDB;

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

CTE_Transfers_Already_Happened_From_Top15_leagues AS
(
	SELECT 
		t1.transfer_id,
		t1.player_id,
		t1.transfer_date,
		t1.transfer_season,
		t1.domestic_competition_id AS from_club_competition_id,
		t1.from_club_id,
		c.domestic_competition_id AS to_club_competition_id,
		t1.to_club_id,
		t1.transfer_fee,
		t1.market_value_in_eur
	FROM (
		SELECT 
			t.transfer_id,
			t.player_id,
			t.transfer_date,
			t.transfer_season,
			cc.domestic_competition_id,
			t.from_club_id,
			t.to_club_id,
			ISNULL(t.transfer_fee, 0) AS transfer_fee,
			t.market_value_in_eur
		FROM clean.transfers AS t
		INNER JOIN CTE_Clubs_Competition_Top15_Leagues AS cc
			ON t.from_club_id = cc.club_id
		WHERE t.is_scheduled = 0
	) AS t1
	INNER JOIN clean.clubs AS c
		ON t1.to_club_id = c.club_id
),

CTE_Transfers_Already_Happened_To_Top15_leagues AS
(
	SELECT 
		t1.transfer_id,
		t1.player_id,
		t1.transfer_date,
		t1.transfer_season,
		c.domestic_competition_id AS from_club_competition_id,
		t1.from_club_id,
		t1.domestic_competition_id AS to_club_competition_id,
		t1.to_club_id,
		t1.transfer_fee,
		t1.market_value_in_eur
	FROM (
		SELECT 
			t.transfer_id,
			t.player_id,
			t.transfer_date,
			t.transfer_season,
			cc.domestic_competition_id,
			t.from_club_id,
			t.to_club_id,
			ISNULL(t.transfer_fee, 0) AS transfer_fee,
			t.market_value_in_eur
		FROM clean.transfers AS t
		INNER JOIN CTE_Clubs_Competition_Top15_Leagues AS cc
			ON t.to_club_id = cc.club_id
		WHERE t.is_scheduled = 0
	) AS t1
	INNER JOIN clean.clubs AS c
		ON t1.from_club_id = c.club_id
)

-- Top clubes que mais gastaram em transferências por season
/*
SELECT 
		t2.domestic_competition_id,
		t2.from_club_id,
		t2.transfer_season,
		t2.total_transfers_value,
		t2.n_players
FROM (
	SELECT 
		t1.domestic_competition_id,
		t1.from_club_id,
		t1.transfer_season,
		t1.total_transfers_value,
		t1.n_players,
		ROW_NUMBER() OVER(PARTITION BY t1.domestic_competition_id, t1.transfer_season ORDER BY t1.total_transfers_value DESC, t1.n_players ASC) AS ranking_spending
	FROM (
		SELECT 
			hf.domestic_competition_id,
			hf.from_club_id,
			hf.transfer_season,
			SUM(hf.transfer_fee) AS total_transfers_value,
			COUNT(hf.transfer_fee) AS n_players
		FROM CTE_Transfers_Already_Happened_From_Top15_leagues AS hf
		GROUP BY 	hf.domestic_competition_id, hf.from_club_id, hf.transfer_season
	) AS t1
) AS t2
WHERE t2.ranking_spending IN (1,2,3)
*/

-- Top clubes que mais arrecadaram em transferências por season
/*
SELECT 
	*
FROM (
	SELECT 
		t1.domestic_competition_id,
		t1.from_club_id,
		t1.transfer_season,
		t1.total_transfers_value,
		t1.n_players,
		ROW_NUMBER() OVER(PARTITION BY t1.domestic_competition_id, t1.transfer_season ORDER BY t1.total_transfers_value DESC, t1.n_players ASC) AS ranking_spending
	FROM (
		SELECT 
			ht.domestic_competition_id,
			ht.from_club_id,
			ht.transfer_season,
			SUM(ht.transfer_fee) AS total_transfers_value,
			COUNT(ht.transfer_fee) AS n_players
		FROM CTE_Transfers_Already_Happened_To_Top15_leagues AS ht
		GROUP BY ht.domestic_competition_id, ht.from_club_id, ht.transfer_season
	) AS t1
) AS t2
WHERE t2.ranking_spending IN (1,2,3) AND t2.total_transfers_value > 0
*/

-- Top ligas que mais gastaram em transferências por season
/*
SELECT 
	*
FROM (
	SELECT 
		*,
		ROW_NUMBER() OVER(PARTITION BY t1.transfer_season ORDER BY t1.total_transfers_value DESC, t1.n_players ASC) AS ranking_spending
	FROM (
		SELECT 
			hf.from_club_competition_id,
			hf.transfer_season,
			SUM(hf.transfer_fee) AS total_transfers_value,
			COUNT(hf.transfer_fee) AS n_players
		FROM CTE_Transfers_Already_Happened_From_Top15_leagues AS hf
		WHERE hf.from_club_id != hf.to_club_id
		GROUP BY hf.from_club_competition_id, hf.transfer_season
	) AS t1
) AS t2
WHERE t2.ranking_spending IN (1,2,3) AND t2.total_transfers_value > 0
*/

-- Top ligas que mais arrecadaram em transferências por season

SELECT 
	*
FROM (
	SELECT 
		*,
		ROW_NUMBER() OVER(PARTITION BY t1.transfer_season ORDER BY t1.total_transfers_value DESC, t1.n_players ASC) AS ranking_spending
	FROM (
		SELECT 
			ht.to_club_competition_id,
			ht.transfer_season,
			SUM(ht.transfer_fee) AS total_transfers_value,
			COUNT(ht.transfer_fee) AS n_players
		FROM CTE_Transfers_Already_Happened_To_Top15_leagues AS ht
		WHERE ht.from_club_id != ht.to_club_id
		GROUP BY ht.to_club_competition_id, ht.transfer_season
	) AS t1
) AS t2
WHERE t2.ranking_spending IN (1,2,3) AND t2.total_transfers_value > 0












