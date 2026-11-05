/* =====================================================================
   02_load_staging.sql
   Loads the 12 CSV files into the staging tables with BULK INSERT.

   BEFORE RUNNING
   1) Copy the CSVs to a folder SQL Server can read, e.g. C:\sql_data\
   2) If your folder is different, use Find & Replace (Ctrl+H) to change
      C:\sql_data\ in this file.
   3) Run 01_create_database_and_staging.sql first.

   Safe to re-run: each table is emptied before loading.
   If you get errors, see the notes at the bottom of this file.
   ===================================================================== */

USE TransfermarktDB;
GO

TRUNCATE TABLE staging.appearances;
BULK INSERT staging.appearances
FROM 'C:\sql_data\appearances.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.club_games;
BULK INSERT staging.club_games
FROM 'C:\sql_data\club_games.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.clubs;
BULK INSERT staging.clubs
FROM 'C:\sql_data\clubs.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.competitions;
BULK INSERT staging.competitions
FROM 'C:\sql_data\competitions.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.countries;
BULK INSERT staging.countries
FROM 'C:\sql_data\countries.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.game_events;
BULK INSERT staging.game_events
FROM 'C:\sql_data\game_events.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.game_lineups;
BULK INSERT staging.game_lineups
FROM 'C:\sql_data\game_lineups.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.games;
BULK INSERT staging.games
FROM 'C:\sql_data\games.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.national_teams;
BULK INSERT staging.national_teams
FROM 'C:\sql_data\national_teams.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.player_valuations;
BULK INSERT staging.player_valuations
FROM 'C:\sql_data\player_valuations.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.players;
BULK INSERT staging.players
FROM 'C:\sql_data\players.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE staging.transfers;
BULK INSERT staging.transfers
FROM 'C:\sql_data\transfers.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);
GO

-- Row counts: compare with what you expect (games ~70k+, appearances >1M, etc.)
SELECT 'appearances'      AS table_name, COUNT(*) AS row_count FROM staging.appearances
UNION ALL SELECT 'club_games',        COUNT(*) FROM staging.club_games
UNION ALL SELECT 'clubs',             COUNT(*) FROM staging.clubs
UNION ALL SELECT 'competitions',      COUNT(*) FROM staging.competitions
UNION ALL SELECT 'countries',         COUNT(*) FROM staging.countries
UNION ALL SELECT 'game_events',       COUNT(*) FROM staging.game_events
UNION ALL SELECT 'game_lineups',      COUNT(*) FROM staging.game_lineups
UNION ALL SELECT 'games',             COUNT(*) FROM staging.games
UNION ALL SELECT 'national_teams',    COUNT(*) FROM staging.national_teams
UNION ALL SELECT 'player_valuations', COUNT(*) FROM staging.player_valuations
UNION ALL SELECT 'players',           COUNT(*) FROM staging.players
UNION ALL SELECT 'transfers',         COUNT(*) FROM staging.transfers
ORDER BY table_name;

/* =====================================================================
   TROUBLESHOOTING
   - "Cannot bulk load because the file could not be opened / Access denied":
     SQL Server cannot read that folder. Use a folder outside your user
     profile (e.g. C:\sql_data\) and check the path and file names.
   - Loaded 0 rows, or a row-terminator / "unexpected end of file" error:
     the file probably uses Windows line endings. Replace
     ROWTERMINATOR = '0x0a' with ROWTERMINATOR = '\r\n' (or remove it).
   - "String or binary data would be truncated": a value is longer than the
     column. Widen that column in script 01 (e.g. NVARCHAR(4000)) and re-run.
   - Empty values: check afterwards whether they arrived as NULL or as ''
     (empty text). Handle with NULLIF(column, '') when cleaning.
   ===================================================================== */

   