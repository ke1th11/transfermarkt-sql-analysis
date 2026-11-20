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
		MONTH(p.date_of_birth) AS month
	FROM clean.players AS p
	WHERE MONTH(p.date_of_birth) IS NOT NULL
)

SELECT 
	t.transfer_season,
	t.to_club_id,
	t.player_id
FROM clean.transfers AS t
WHERE t.is_scheduled = 0
ORDER BY t.transfer_season, t.to_club_id, t.player_id