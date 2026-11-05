/* Question: How has home advantage evolved across top 15 football leagues, according to Global Football Rankings, and seasons, and to what extent did the COVID-19 pandemic affect this advantage?
   Approach: tables used and logic in one or two lines
   Insight: (written after seeing the result) 
   Note: The English second division, known as the Championship, will not be included in this analysis, as there is no data available for it. Consequently, only 14 of the 15 major men’s football leagues worldwide will be considered. */


/* Note: Due to a lack of data required for the analysis of the period corresponding to the COVID-19 pandemic (seasons 2019/2020 and 2020/2021), professional football leagues from the following countries will not be included in the analysis: Brazil, Argentina, Norway, Mexico, the USA, and Colombia.*/
SELECT *
FROM clean.competitions
ORDER BY country_name

SELECT *
FROM staging.games
WHERE competition_id = 'BRA1'

SELECT *
FROM staging.competitions
ORDER BY country_name




