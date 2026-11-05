# Data quality notes

Findings from profiling the raw (staging) tables, and the decisions taken for the `clean` schema.
Checks come from `sql/03_validate_staging.sql`, `04_investigate_staging_issues.sql` and `05_final_checks_before_cleaning.sql`.

**Snapshot of the data:** latest game 2026-07-06, latest appearance 2026-06-28, latest valuation 2026-06-12.
The last complete season is 2025 (2025/26). Club-level data (appearances) starts in 2012.
The dataset does not seem to have been updated since July 2026 (check "last updated" on the Kaggle page and note it here).

## 1. Checks that passed

- No duplicate primary keys in any table (including composite keys in `club_games` and `player_valuations`).
- Every non-empty date and number converts without errors (no shifted columns).
- Empty values arrived as real NULLs, not as empty text or "NA".
- `club_games` has exactly 2 rows per game (177,916 = 2 x 88,958 games).
- Event types add up to the row count of `game_events` (1,274,469).
- No games without a score (no scheduled/unplayed games in `games`).

## 2. Issues and decisions

| # | Table / column | Finding | Decision |
|---|---|---|---|
| 1 | `appearances.player_id` | 2 rows point to a player that does not exist (player 380365, no name, Copa del Rey 2018). | Exclude from `clean.appearances` and log it. Negligible (2 of 1.89M rows). |
| 2 | `games.competition_id` | 1,214 games use competitions missing from `competitions`: POCP (602), CGB (246), COL1 (200), KLUB (156), UKRS (10). By club names: POCP = Portuguese cup, KLUB = FIFA Club World Cup, COL1 = Colombian league (2025), UKRS = Ukrainian Super Cup, CGB = English clubs from 2022 (probably the EFL Cup, to confirm). | Keep the games. Add the 5 competitions to `clean.competitions` with a name and group set manually. |
| 3 | `games.home_club_id` / `away_club_id` | 12,818 games have a home club and 11,242 an away club not in `clubs`. Only 692 home cases are national teams. Most are clubs from leagues the dataset does not cover (domestic cups, European qualifiers), e.g. Ludogorets, Qarabag, Maccabi Tel Aviv. 50 national-team games are not in `national_teams` either. | Build `clean.clubs` from `clubs` + `national_teams` + names found in `games`, with a flag showing whether the club is in the source `clubs` table. |
| 4 | `transfers.transfer_date` | 520 transfers are dated after the snapshot (2026-07-06), up to 2030-06-30. 396 are in 2026-12 and 48 in 2027. They look like scheduled loan returns or contract ends, not real transfers. | Add an `is_scheduled` flag using the snapshot date (not today's date). Exclude scheduled rows from analysis. |
| 5 | `players.position` | 586 rows contain the text "Missing". | Convert to NULL. |
| 6 | Several columns | Genuine NULLs: `transfer_fee` 61,526 (35%), `market_value_in_eur` 8,621, `foot` 5,893, `attendance` 10,803, `referee` 678, `date_of_birth` 49. | Keep as NULL, do not fill. NULL fee means unknown, not zero. Analyses exclude NULLs explicitly. |
| 7 | `games.season` coverage | 2024 and 2025 have about 10k games per season (about 5.7k-6.0k before) because about 17 extra leagues appear from 2024 (MLS, Brazil, Saudi, Poland, Japan...). Some calendar-year leagues are incomplete in 2025. | Add `is_core_league` to `clean.competitions` (the 14 leagues present since 2012, including `PO1` Liga Portugal). Time-trend analyses use only these. |
| 8 | Cup coverage | Some cups have uneven coverage. POCP has 602 games overall but only 37, 7 and 7 in 2023, 2024 and 2025. CGB has no games in 2024. | Do not compare cups across seasons. Use leagues for trends. |
| 9 | `competitions.type` | Inconsistent: Champions League and UEFA Super Cup are `international_cup`, but Europa League and Conference League are `other`. | Create my own `competition_group` column in `clean.competitions`. |
| 10 | `games.season` (national tournaments) | World Cup / Euro use the year before the tournament (World Cup 2010 is season 2009). | Document it. Do not mix national tournaments into club season analysis. |
| 11 | `club_games.is_win` | Only marks wins (0 = draw or loss). | Derive the result (win/draw/loss) from the goals. |
| 12 | Numeric text | Numbers such as `185.0` and `700000.000`; dates such as `1978-06-09 00:00:00`. | Convert with `TRY_CAST` to DECIMAL / DATE (via FLOAT for integers). |
| 13 | Text columns | Non-breaking spaces (character code 160) at the end of some values, e.g. `city_of_birth` "Opole" + 2 of them (7 characters instead of 5). `LTRIM`/`RTRIM` do not remove them, and `GROUP BY` treats "Opole" and "Opole  " as different values. | Clean every text column with `REPLACE(col, NCHAR(160), ' ')` then trim. |
| 14 | `transfers` | The table does not say whether a move is a permanent transfer, a loan or a loan return. A fee of 0 can be any of them. | State this limit in the analysis. Avoid conclusions about "free transfers" or net spending without it. |
| 15 | Club names | Defunct clubs carry a suffix with the year, e.g. "CF União Madeira (-2021)", "Metalurg Donetsk (- 2015)". | Keep as is for now. Create a display name without the suffix if needed. |
| 16 | `games.season` (calendar-year leagues) | Games from July 2026 of leagues played in the calendar year (e.g. Allsvenskan) have season 2025, so the label is shifted for these leagues. | Use season only for the 14 core leagues. |
| 17 | Club names | Some names have double spaces inside (e.g. "Idrottsföreningen  Brommapojkarna"). | Cosmetic. Fix with REPLACE if names are shown in the dashboard. |

## 3. Scope for the analysis

- Club analyses: seasons 2012-2025, core leagues (`is_core_league = 1`).
- Portugal focus: `PO1` (Liga Portugal) complete for every season (306 games each), plus `POSU` and `POCP` (cup, partial coverage).
- Transfers: only rows dated up to the snapshot date.

## 4. Still to confirm

- The exact name of competition CGB.
- The date of the last update of the dataset.
