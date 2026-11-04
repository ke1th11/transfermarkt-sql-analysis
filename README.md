# Transfermarkt SQL Analysis

SQL Server analysis of football data (players, clubs, matches, transfers and market values), 
answering business-style questions with CTEs and window functions.

## Dataset
- Source: [Football Data from Transfermarkt](https://www.kaggle.com/datasets/davidcariboo/player-scores) 
  (David Cariboo), updated weekly. Check the license on the dataset page.
- Tables used: (list them)
- Data was downloaded on (date). Raw files are not included in this repository.

## Tools
- SQL Server, SSMS, (VS Code), Git/GitHub, (Power BI, if used)

## Project structure
- `data/` – raw CSV files (not tracked)
- `sql/` – scripts, numbered by execution order
- `docs/` – data model diagram and notes

## Method
1. Load raw CSVs into a `staging` schema (all columns as text)
2. Validate: row counts, duplicates, orphan keys
3. Build typed, clean tables in a `clean` schema
4. Answer the business questions

## Business questions and key insights
(Question 1 – insight in one or two sentences – link to the script)

## How to reproduce
(Order in which to run the scripts)