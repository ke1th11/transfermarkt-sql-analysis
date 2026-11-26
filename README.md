# Transfermarkt SQL Analysis

SQL Server analysis of European and international football data from Transfermarkt (players, clubs, matches, transfers and market values). The project takes the raw CSV files through a full pipeline (staging, validation, cleaning) and then answers seven business-style questions using T-SQL, CTEs and window functions.

**What this project shows:** data loading and validation, documented data-cleaning decisions, and analytical SQL on a large, messy, real-world dataset (about 89,000 games, 1.9 million appearances and 1.3 million game events).

---

## Table of contents

- [Dataset](#dataset)
- [Tools](#tools)
- [Project structure](#project-structure)
- [Method](#method)
- [Business questions and key insights](#business-questions-and-key-insights)
- [Data quality](#data-quality)
- [How to reproduce](#how-to-reproduce)
- [Limitations](#limitations)
- [Next steps](#next-steps)
- [About](#about)

---

## Dataset

- **Source:** [Football Data from Transfermarkt](https://www.kaggle.com/datasets/davidcariboo/player-scores) by David Cariboo, updated weekly. Please check the license on the dataset page before reusing the data.
- **Snapshot used:** latest game on 2026-07-06, latest appearance on 2026-06-28 and latest market valuation on 2026-06-12. The last complete season is 2025/26.
- **Scope of the analyses:** seasons 2012/13 to 2025/26 and, for time trends, the 14 leagues present in the data since 2012 (flagged as `is_core_league`).
- **Tables loaded into `staging` (12):** `appearances`, `club_games`, `clubs`, `competitions`, `countries`, `game_events`, `game_lineups`, `games`, `national_teams`, `player_valuations`, `players`, `transfers`.
- **Tables in the `clean` schema (9):** `appearances`, `club_games`, `club_name_map`, `clubs`, `competitions`, `games`, `player_valuations`, `players`, `transfers`.

The raw CSV files are not included in this repository.

## Tools

- SQL Server (T-SQL)
- SQL Server Management Studio (SSMS)
- Git and GitHub

## Project structure

```
transfermarkt-sql-analysis/
├── README.md
├── docs/
│   └── data_quality_notes.md      # profiling findings and cleaning decisions
├── results/                       # saved outputs of the analysis queries (q01 to q07)
└── sql/
    ├── 01_create_database_and_staging.sql
    ├── 02_load_staging.sql
    ├── 03_validate_staging.sql
    ├── 04_investigate_staging_issues.sql
    ├── 05_final_checks_before_cleaning.sql
    ├── 06_create_clean_dimensions.sql
    ├── 07_create_clean_facts.sql
    ├── 08_q01_home_advantage.sql
    ├── 09_q02_top_scorers.sql
    ├── 10_q03_market_value_evolution.sql
    ├── 11_q04_age_and_position_analysis.sql
    ├── 12_q05_transfer_market_spending.sql
    ├── 13_q06_league_standings_and_records.sql
    ├── 14_q07_additional_analyses.sql
    └── drafts/                    # my original first versions of the queries
```

The scripts are numbered by execution order. Every analysis script (08 to 14) has the same header: **Question**, **Approach**, **Insight** and **Note**. Scripts with several outputs label their questions A), B), C) and mark each query with `-- Output A`, `-- Output B` and so on.

## Method

1. **Load** the raw CSVs into a `staging` schema, with every column as text so that nothing is lost on import (`01`, `02`).
2. **Validate** the staging tables: row counts, duplicate keys, orphan keys, number and date conversion, and NULL handling (`03`, `04`, `05`).
3. **Clean:** build typed tables in a `clean` schema, applying the decisions documented in [`docs/data_quality_notes.md`](docs/data_quality_notes.md) (`06`, `07`).
4. **Analyse:** answer the business questions on the clean tables (`08` to `14`).

## Business questions and key insights

Each question links to its script and to the saved output. Full insights, with the approach and the limitations, are in the header of each script.

### Q1. Home advantage and COVID-19
*How has home advantage evolved across the top leagues and seasons, and how much did the pandemic affect it?*
Script: [`08_q01_home_advantage.sql`](sql/08_q01_home_advantage.sql) · Output: [`q01_home_advantage.txt`](results/q01_home_advantage.txt)

In the 8 leagues with full history, the home win rate was stable before the pandemic (44.7% to 47.9% per season, 45.8% on average). In 2020/21, when almost every game was played without fans, it fell to about 40% (-5.5 percentage points), and the drop appears in all 8 leagues. In about 3,100 games in empty stadiums the home win rate was about 39.7%, against about 48% in roughly 300 games with limited crowds. Since 2022/23 it has stayed slightly lower (about 43% in the last three seasons), which is not enough to claim a lasting change.

### Q2. Top scorers
*Who were the top scorers of each major league in each season, how long were their scoring streaks, how fast did they score and how did their market value change?*
Script: [`09_q02_top_scorers.sql`](sql/09_q02_top_scorers.sql) · Output: [`q02_top_scorers.txt`](results/q02_top_scorers.txt)

The results match known figures (for example Messi's 46 goals in 2012/13). The top scorer of a season averaged 32.6 goals in La Liga, 28.6 in the Bundesliga and 27.1 in the Premier League. Messi's streak of 21 games with a goal in 2012/13 is by far the longest, almost twice the next one. Finishing as top scorer does not guarantee a higher valuation: 34% of top scorers (44 of 128 with data) ended the season with the same or a lower market value than a year earlier.

### Q3. Evolution of market values
*Which players and clubs had the biggest rises, falls and fluctuations in market value?*
Script: [`10_q03_market_value_evolution.sql`](sql/10_q03_market_value_evolution.sql) · Output: [`q03_market_value_evolution.txt`](results/q03_market_value_evolution.txt)

The typical biggest yearly rise is a young breakout (median +500%, from 0.95M to 7.0M EUR), while the typical biggest fall is about -70%. PSG and Bayern had the most valuable squad in their league in all 14 seasons. The combined value of the top 3 Premier League clubs grew from 1.25B to 3.69B EUR, while Serie A peaked in 2018/19. At club level, 2019/20 has the deepest median fall (-34%), which fits the COVID-era correction.

### Q4. Age, position, performance and playing time
*At what age does market value peak, and how do performance and playing time change with age and position?*
Script: [`11_q04_age_and_position_analysis.sql`](sql/11_q04_age_and_position_analysis.sql) · Output: [`q04_age_and_position_analysis.txt`](results/q04_age_and_position_analysis.txt)

Players reach their highest market value at about 24 (attackers 24.1, midfielders 24.3, defenders 24.8) and goalkeepers later, at 26.4. 58% of all players peak between 22 and 27. Goal participations per 90 minutes peak about 1.3 years later than market value. The share of games played as a starter rises from 46% at age 17 to 78% to 81% from 25 to 35. Spain has the oldest squads on average (26.1) and Norway the youngest (22.7).

### Q5. Transfer market spending
*Which clubs and leagues spend and earn the most, and which transfers pay the biggest premium over market value?*
Script: [`12_q05_transfer_market_spending.sql`](sql/12_q05_transfer_market_spending.sql) · Output: [`q05_transfer_market_spending.txt`](results/q05_transfer_market_spending.txt)

The Premier League is the biggest spending league in all 14 seasons, from 189M EUR in 2012/13 to 2.48B EUR in 2025/26, and is a net buyer by a wide margin. Selling leagues such as Portugal, the Netherlands and Belgium received about 1.8 to 2.5 times what they spent (approximated with the top 3 clubs of each league and season). In the 706 ranked transfers, 89% had a fee above market value, but the extreme ratios come from very low valuations (414 of 706 have a market value under 1M EUR), which points to outdated valuations rather than overpaying.

### Q6. League standings and records
*How do clubs perform across the seasons and what are the records of each league?*
Script: [`13_q06_league_standings_and_records.sql`](sql/13_q06_league_standings_and_records.sql) · Output: [`q06_league_standings_and_records.txt`](results/q06_league_standings_and_records.txt)

Only one champion was unbeaten in the 14 seasons: Bayer Leverkusen in 2023/24 (28 wins, 6 draws, 0 losses). The points record is Juventus with 102 (2013/14), and the longest winning streak inside a season is Bayern's 19 games (2013/14). The lowest total in a full 38-game season is Southampton's 12 points (2024/25). The 2023/24 Premier League title race was decided in the last 10 games, where Manchester City took 28 points against Arsenal's 25 and Liverpool's 18.

### Q7. Additional analyses
Script: [`14_q07_additional_analyses.sql`](sql/14_q07_additional_analyses.sql) · Output: [`q07_additional_analyses.txt`](results/q07_additional_analyses.txt)

- **A) League position vs result:** the position gap between two clubs explains a lot. The home club wins 86.4% of games when it is 13 to 19 places above the visitor and only 8.1% when it is 13 to 19 places below. The home club needs to be about 3 places below to be the underdog.
- **B) Loyalty:** 447 sequences of 10 or more consecutive seasons at the same club. The longest is Igor Akinfeev with 24 seasons at CSKA Moskva, and Seamus Coleman (Everton, 18) leads the top 15 leagues.
- **C) Foreign players:** in 2025/26 the share is highest in Portugal (66.5%), Italy (63.7%) and England (63.1%), and lowest among the European leagues in Spain (37.7%).
- **D) Relative age effect:** players born in January are 145.7% of the expected number, against 61.3% for December. The effect appears in 30 of 31 country labels, and the exceptions fit a different school-year cut-off (England in September, Japan in April).
- **E, F) Formations:** 4-2-3-1 is the most used overall (31.6%) and the most used in 65 of 104 league-seasons in the 8 European leagues. Three-man defences became common from 2020/21.

## Data quality

The raw data needed careful handling. The full list of 17 findings and the decision taken for each is in [`docs/data_quality_notes.md`](docs/data_quality_notes.md). Some examples:

- **Scheduled transfers:** 520 transfers are dated after the snapshot date (up to 2030), so they are flagged with `is_scheduled` and excluded from the analysis.
- **Unknown fees:** 35% of transfers have no fee. They are kept as NULL (unknown, not zero), and the analyses exclude them explicitly.
- **Hidden characters:** some text values end with non-breaking spaces (`NCHAR(160)`) that `TRIM` does not remove and that split `GROUP BY` groups, so every text column is cleaned.
- **Inconsistent coverage:** about 17 extra leagues appear from 2024, so time trends use only the 14 leagues present since 2012.
- **Ambiguous transfers:** the transfers table does not say whether a move is permanent, a loan or a loan return, so conclusions about "free transfers" are avoided.

## How to reproduce

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/davidcariboo/player-scores) and extract the CSV files.
2. Copy the CSVs to a folder that SQL Server can read, for example `C:\sql_data\`. If you use another folder, change the path in `sql/02_load_staging.sql`.
3. Open the scripts in SSMS and run them **in order, from `01` to `07`**. This creates the `TransfermarktDB` database, loads and validates the raw data and builds the `clean` schema.
4. Run the analysis scripts `08` to `14`, in any order.
   - Scripts `10` to `14` contain several outputs (A, B, C...). Only one final `SELECT` runs at a time: the last output is active, and the others are commented out. To see another output, comment out the active query and uncomment the one you want.
   - Parameters such as minimum thresholds and top-N values are declared with `DECLARE` at the top of each script.

## Limitations

- Market values are Transfermarkt's estimates, not transaction prices, and valuations of young players are often outdated.
- The season 2025/26 is not complete in the snapshot, so changes in the last year should be read with care.
- Most findings are observational and describe patterns, not causes (for example the COVID effect in Q1).
- Leagues with only one or two seasons in the data (such as MLS, Argentina, Brazil, Colombia, Mexico and Norway) are not comparable with the European leagues in time trends.
- Net spending in Q5 is an approximation, because the transfers table does not separate permanent transfers from loans.

## Next steps

- Build a **Power BI dashboard** on top of the `clean` schema to present the main results visually (planned).
- Merge duplicated country labels (such as "Turkey" and "Turkiye") before the relative age analysis.
- Split `14_q07_additional_analyses.sql` into one script per theme.

## About

Made by **Bruno Sousa**, Physics Engineering graduate (University of Minho) and MSc student in Management and Industrial Decision-Making (ESTG - UTP), with an interest in data analysis, modelling and process optimisation.

The final versions of the analysis scripts (`08` to `14`) were reviewed and optimised with AI assistance. My original first versions are kept in [`sql/drafts/`](sql/drafts/).

GitHub: [ke1th11](https://github.com/ke1th11)
