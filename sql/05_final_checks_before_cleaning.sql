/* =====================================================================
   05_final_checks_before_cleaning.sql
   Last read-only checks before building the clean schema.
   Run one block at a time and write down the results.
   ===================================================================== */

USE TransfermarktDB;
GO

/* ---------------------------------------------------------------------
   1) What are the competitions missing from the competitions table?
      Shows 3 example games for each one (look at the club names).
   --------------------------------------------------------------------- */
WITH examples AS (
    SELECT competition_id, season, home_club_name, away_club_name,
           ROW_NUMBER() OVER (PARTITION BY competition_id ORDER BY game_id) AS rn
    FROM staging.games
    WHERE competition_id IN ('POCP', 'CGB', 'COL1', 'KLUB', 'UKRS')
)
SELECT competition_id, season, home_club_name, away_club_name
FROM examples
WHERE rn <= 3
ORDER BY competition_id, rn;


/* ---------------------------------------------------------------------
   2) Extra characters at the end of city_of_birth.
      last_char_code: 32 = normal space, 160 = non-breaking space,
      13 = carriage return, 10 = line feed.
   --------------------------------------------------------------------- */
SELECT TOP 5
       city_of_birth,
       LEN(city_of_birth)                  AS len_chars,
       DATALENGTH(city_of_birth)           AS len_bytes,
       UNICODE(RIGHT(city_of_birth, 1))    AS last_char_code
FROM staging.players
WHERE city_of_birth LIKE 'Opole%';


/* ---------------------------------------------------------------------
   3) Transfers dated after the snapshot (latest game: 2026-07-06),
      grouped by month.
   --------------------------------------------------------------------- */
SELECT FORMAT(TRY_CAST(transfer_date AS DATE), 'yyyy-MM') AS transfer_month,
       COUNT(*) AS n_transfers
FROM staging.transfers
WHERE TRY_CAST(transfer_date AS DATE) > '2026-07-06'
GROUP BY FORMAT(TRY_CAST(transfer_date AS DATE), 'yyyy-MM')
ORDER BY transfer_month;


/* ---------------------------------------------------------------------
   4) Away clubs not found in clubs (same check done before for home clubs).
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS away_orphan_games
FROM staging.games g
WHERE NULLIF(g.away_club_id, '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.clubs c WHERE c.club_id = g.away_club_id);
