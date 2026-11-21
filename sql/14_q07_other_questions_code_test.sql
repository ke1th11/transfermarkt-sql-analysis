/* Questions: 1. Posição na tabela vs. resultado (a mais forte).
			  2. Lealdade de jogadores.
			  3. Liga Portugal: % de minutos de estrangeiros.
			  4. Idade relativa.
*/

USE TransfermarktDB;

WITH CTE_Month_Birth AS
(
	SELECT 
		p.player_id,
		p.country_of_citizenship,
		MONTH(p.date_of_birth) AS month_of_birth
	FROM clean.players AS p
	WHERE MONTH(p.date_of_birth) IS NOT NULL
),

CTE_Month_Name AS
(
	SELECT 
		mb.month_of_birth,
		CASE 
			WHEN mb.month_of_birth = 1
				THEN 'January'
			WHEN mb.month_of_birth = 2
				THEN 'February'
			WHEN mb.month_of_birth = 3
				THEN 'March'
			WHEN mb.month_of_birth = 4
				THEN 'April'
			WHEN mb.month_of_birth = 5
				THEN 'May'
			WHEN mb.month_of_birth = 6
				THEN 'June'
			WHEN mb.month_of_birth = 7
				THEN 'July'
			WHEN mb.month_of_birth = 8
				THEN 'August'
			WHEN mb.month_of_birth = 9
				THEN 'September'
			WHEN mb.month_of_birth = 10
				THEN 'October'
			WHEN mb.month_of_birth = 11
				THEN 'November'
			WHEN mb.month_of_birth = 12
				THEN 'December'
		END AS month_name
	FROM CTE_Month_Birth AS mb
),

CTE_N_Players_By_Month_Of_Birth AS
(
	SELECT 
		country_of_citizenship, 
		mb.month_of_birth,
		COUNT(*) AS n_players
	FROM CTE_Month_Birth AS mb
	WHERE mb.country_of_citizenship IS NOT NULL
	GROUP BY mb.country_of_citizenship, mb.month_of_birth
),

CTE_N_Players_By_Country_Of_Citizenship AS
(
	SELECT 
		p.country_of_citizenship,
		COUNT(*) AS n_players_by_country
	FROM clean.players AS p
	WHERE p.country_of_citizenship IS NOT NULL
	GROUP BY p.country_of_citizenship
)

SELECT
	t2.country_of_citizenship,
	CASE 
		WHEN t2.month_of_birth = 1
			THEN 'January'
		WHEN t2.month_of_birth = 2
			THEN 'February'
		WHEN t2.month_of_birth = 3
			THEN 'March'
		WHEN t2.month_of_birth = 4
			THEN 'April'
		WHEN t2.month_of_birth = 5
			THEN 'May'
		WHEN t2.month_of_birth = 6
			THEN 'June'
		WHEN t2.month_of_birth = 7
			THEN 'July'
		WHEN t2.month_of_birth = 8
			THEN 'August'
		WHEN t2.month_of_birth = 9
			THEN 'September'
		WHEN t2.month_of_birth = 10
			THEN 'October'
		WHEN t2.month_of_birth = 11
			THEN 'November'
		WHEN t2.month_of_birth = 12
			THEN 'December'
	END AS month_name,
	t2.n_players_expected,
	t2.n_players,
	CAST((CAST(t2.n_players AS DECIMAL(20,2)) / t2.n_players_expected) * 100 AS DECIMAL(20,2)) AS [relative_representation (%)]
FROM (
	SELECT 
		t1.*,
		CAST((CAST(cc.n_players_by_country AS DECIMAL(20,2)) * t1.n_days_by_month) / 365 AS DECIMAL(20,2)) AS n_players_expected
	FROM (
		SELECT 
			np.country_of_citizenship,
			np.month_of_birth,
			np.n_players,
			CASE
				WHEN np.month_of_birth = 1
					THEN 31
				WHEN np.month_of_birth = 2
					THEN 29
				WHEN np.month_of_birth = 3
					THEN 31
				WHEN np.month_of_birth = 4
					THEN 30
				WHEN np.month_of_birth = 5
					THEN 31
				WHEN np.month_of_birth = 6
					THEN 30
				WHEN np.month_of_birth = 7
					THEN 31
				WHEN np.month_of_birth = 8
					THEN 31
				WHEN np.month_of_birth = 9
					THEN 30
				WHEN np.month_of_birth = 10
					THEN 31
				WHEN np.month_of_birth = 11
					THEN 30
				WHEN np.month_of_birth = 12
					THEN 31
			END AS n_days_by_month
		FROM CTE_N_Players_By_Month_Of_Birth AS np
	) AS t1
	INNER JOIN CTE_N_Players_By_Country_Of_Citizenship AS cc
		ON t1.country_of_citizenship = cc.country_of_citizenship
) AS t2
ORDER BY t2.country_of_citizenship, t2.month_of_birth








/*
SELECT 
	t.transfer_season,
	t.to_club_id,
	t.player_id
FROM clean.transfers AS t
WHERE t.is_scheduled = 0
ORDER BY t.transfer_season, t.to_club_id, t.player_id
*/