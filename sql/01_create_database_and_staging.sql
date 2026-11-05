/* =====================================================================
   01_create_database_and_staging.sql
   Creates the database, the staging schema and one staging table per CSV.
   All columns are text (NVARCHAR) on purpose: staging keeps the raw data
   exactly as it arrives. Types are converted later, in the clean schema.
   Safe to re-run: tables are dropped and recreated.
   ===================================================================== */

-- 1) Database --------------------------------------------------------
IF DB_ID('TransfermarktDB') IS NULL
    CREATE DATABASE TransfermarktDB;
GO

USE TransfermarktDB;
GO

-- 2) Schema ----------------------------------------------------------
IF SCHEMA_ID('staging') IS NULL
    EXEC('CREATE SCHEMA staging');
GO

-- 3) Staging tables (column order = CSV header order) ----------------

DROP TABLE IF EXISTS staging.appearances;
CREATE TABLE staging.appearances (
    appearance_id           NVARCHAR(100),
    game_id                 NVARCHAR(50),
    player_id               NVARCHAR(50),
    player_club_id          NVARCHAR(50),
    player_current_club_id  NVARCHAR(50),
    [date]                  NVARCHAR(50),
    player_name             NVARCHAR(500),
    competition_id          NVARCHAR(50),
    yellow_cards            NVARCHAR(50),
    red_cards               NVARCHAR(50),
    goals                   NVARCHAR(50),
    assists                 NVARCHAR(50),
    minutes_played          NVARCHAR(50)
);

DROP TABLE IF EXISTS staging.club_games;
CREATE TABLE staging.club_games (
    game_id                 NVARCHAR(50),
    club_id                 NVARCHAR(50),
    own_goals               NVARCHAR(50),
    own_position            NVARCHAR(50),
    own_manager_name        NVARCHAR(500),
    opponent_id             NVARCHAR(50),
    opponent_goals          NVARCHAR(50),
    opponent_position       NVARCHAR(50),
    opponent_manager_name   NVARCHAR(500),
    hosting                 NVARCHAR(50),
    is_win                  NVARCHAR(50)
);

DROP TABLE IF EXISTS staging.clubs;
CREATE TABLE staging.clubs (
    club_id                 NVARCHAR(50),
    club_code               NVARCHAR(500),
    [name]                  NVARCHAR(500),
    domestic_competition_id NVARCHAR(50),
    total_market_value      NVARCHAR(100),
    squad_size              NVARCHAR(50),
    average_age             NVARCHAR(50),
    foreigners_number       NVARCHAR(50),
    foreigners_percentage   NVARCHAR(50),
    national_team_players   NVARCHAR(50),
    stadium_name            NVARCHAR(500),
    stadium_seats           NVARCHAR(50),
    net_transfer_record     NVARCHAR(100),
    coach_name              NVARCHAR(500),
    last_season             NVARCHAR(50),
    [filename]              NVARCHAR(500),
    url                     NVARCHAR(1000)
);

DROP TABLE IF EXISTS staging.competitions;
CREATE TABLE staging.competitions (
    competition_id          NVARCHAR(50),
    competition_code        NVARCHAR(500),
    [name]                  NVARCHAR(500),
    sub_type                NVARCHAR(500),
    [type]                  NVARCHAR(500),
    country_id              NVARCHAR(50),
    country_name            NVARCHAR(500),
    domestic_league_code    NVARCHAR(500),
    confederation           NVARCHAR(500),
    total_clubs             NVARCHAR(50),
    url                     NVARCHAR(1000)
);

DROP TABLE IF EXISTS staging.countries;
CREATE TABLE staging.countries (
    country_id              NVARCHAR(50),
    country_name            NVARCHAR(500),
    country_code            NVARCHAR(500),
    confederation           NVARCHAR(500),
    total_clubs             NVARCHAR(50),
    total_players           NVARCHAR(50),
    average_age             NVARCHAR(50),
    url                     NVARCHAR(1000)
);

DROP TABLE IF EXISTS staging.game_events;
CREATE TABLE staging.game_events (
    game_event_id           NVARCHAR(100),
    [date]                  NVARCHAR(50),
    game_id                 NVARCHAR(50),
    [minute]                NVARCHAR(50),
    [type]                  NVARCHAR(500),
    club_id                 NVARCHAR(50),
    club_name               NVARCHAR(500),
    player_id               NVARCHAR(50),
    [description]           NVARCHAR(1000),
    player_in_id            NVARCHAR(50),
    player_assist_id        NVARCHAR(50)
);

DROP TABLE IF EXISTS staging.game_lineups;
CREATE TABLE staging.game_lineups (
    game_lineups_id         NVARCHAR(100),
    [date]                  NVARCHAR(50),
    game_id                 NVARCHAR(50),
    player_id               NVARCHAR(50),
    club_id                 NVARCHAR(50),
    player_name             NVARCHAR(500),
    [type]                  NVARCHAR(500),
    [position]              NVARCHAR(500),
    [number]                NVARCHAR(50),
    team_captain            NVARCHAR(50)
);

DROP TABLE IF EXISTS staging.games;
CREATE TABLE staging.games (
    game_id                 NVARCHAR(50),
    competition_id          NVARCHAR(50),
    season                  NVARCHAR(50),
    [round]                 NVARCHAR(500),
    [date]                  NVARCHAR(50),
    home_club_id            NVARCHAR(50),
    away_club_id            NVARCHAR(50),
    home_club_goals         NVARCHAR(50),
    away_club_goals         NVARCHAR(50),
    home_club_position      NVARCHAR(50),
    away_club_position      NVARCHAR(50),
    home_club_manager_name  NVARCHAR(500),
    away_club_manager_name  NVARCHAR(500),
    stadium                 NVARCHAR(500),
    attendance              NVARCHAR(50),
    referee                 NVARCHAR(500),
    url                     NVARCHAR(1000),
    home_club_formation     NVARCHAR(500),
    away_club_formation     NVARCHAR(500),
    home_club_name          NVARCHAR(500),
    away_club_name          NVARCHAR(500),
    [aggregate]             NVARCHAR(500),
    competition_type        NVARCHAR(500)
);

DROP TABLE IF EXISTS staging.national_teams;
CREATE TABLE staging.national_teams (
    national_team_id        NVARCHAR(50),
    [name]                  NVARCHAR(500),
    team_code               NVARCHAR(500),
    country_id              NVARCHAR(50),
    country_name            NVARCHAR(500),
    country_code            NVARCHAR(500),
    confederation           NVARCHAR(500),
    team_image_url          NVARCHAR(1000),
    squad_size              NVARCHAR(50),
    average_age             NVARCHAR(50),
    foreigners_number       NVARCHAR(50),
    foreigners_percentage   NVARCHAR(50),
    total_market_value      NVARCHAR(100),
    coach_name              NVARCHAR(500),
    fifa_ranking            NVARCHAR(50),
    last_season             NVARCHAR(50),
    url                     NVARCHAR(1000)
);

DROP TABLE IF EXISTS staging.player_valuations;
CREATE TABLE staging.player_valuations (
    player_id                            NVARCHAR(50),
    [date]                               NVARCHAR(50),
    market_value_in_eur                  NVARCHAR(100),
    current_club_name                    NVARCHAR(500),
    current_club_id                      NVARCHAR(50),
    player_club_domestic_competition_id  NVARCHAR(50)
);

DROP TABLE IF EXISTS staging.players;
CREATE TABLE staging.players (
    player_id                             NVARCHAR(50),
    first_name                            NVARCHAR(500),
    last_name                             NVARCHAR(500),
    [name]                                NVARCHAR(500),
    last_season                           NVARCHAR(50),
    current_club_id                       NVARCHAR(50),
    player_code                           NVARCHAR(500),
    country_of_birth                      NVARCHAR(500),
    city_of_birth                         NVARCHAR(500),
    country_of_citizenship                NVARCHAR(500),
    date_of_birth                         NVARCHAR(50),
    sub_position                          NVARCHAR(500),
    [position]                            NVARCHAR(500),
    foot                                  NVARCHAR(100),
    height_in_cm                          NVARCHAR(50),
    contract_expiration_date              NVARCHAR(50),
    agent_name                            NVARCHAR(500),
    image_url                             NVARCHAR(1000),
    international_caps                    NVARCHAR(50),
    international_goals                   NVARCHAR(50),
    current_national_team_id              NVARCHAR(50),
    url                                   NVARCHAR(1000),
    current_club_domestic_competition_id  NVARCHAR(50),
    current_club_name                     NVARCHAR(500),
    market_value_in_eur                   NVARCHAR(100),
    highest_market_value_in_eur           NVARCHAR(100)
);

DROP TABLE IF EXISTS staging.transfers;
CREATE TABLE staging.transfers (
    player_id               NVARCHAR(50),
    transfer_date           NVARCHAR(50),
    transfer_season         NVARCHAR(50),
    from_club_id            NVARCHAR(50),
    to_club_id              NVARCHAR(50),
    from_club_name          NVARCHAR(500),
    to_club_name            NVARCHAR(500),
    transfer_fee            NVARCHAR(100),
    market_value_in_eur     NVARCHAR(100),
    player_name             NVARCHAR(500)
);
GO

-- 4) Check: should list 12 tables ------------------------------------
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'staging'
ORDER BY TABLE_NAME;
