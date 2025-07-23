CREATE DATABASE fda_drug_analysis;

USE fda_drug_analysis;
show tables;
CREATE TABLE drug_events (
    report_id VARCHAR(50) PRIMARY KEY,
    receivedate DATE,
    patient_age INT,
    patient_sex VARCHAR(10),
    drug_name TEXT,
    reaction TEXT,
    outcome TINYINT
);

DELIMITER //
CREATE TRIGGER prevent_null_outcome
BEFORE INSERT ON drug_events
FOR EACH ROW
BEGIN
  IF NEW.outcome IS NULL THEN
    SET NEW.outcome = 0;
  END IF;
END;//
DELIMITER ;

SELECT * FROM drug_events LIMIT 10;
SELECT COUNT(*) FROM drug_events;

-- 1. Identify the Top 10 Most Frequently Reported Drugs Across All Cases
CREATE VIEW ranked_reported_drugs AS
SELECT 
    drug_name,
    total_reports,
    RANK() OVER (ORDER BY total_reports DESC) AS report_rank
FROM (
    SELECT 
        drug_name, 
        COUNT(*) AS total_reports
    FROM drug_events
    GROUP BY drug_name
) AS drug_counts;

SELECT * 
FROM ranked_reported_drugs
WHERE report_rank <= 10;


-- 2. Show Gender Distribution Along with Percentage Contribution
SELECT 
  patient_sex, 
  COUNT(*) AS total_reports,
  ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM drug_events), 2) AS gender_percentage
FROM drug_events
GROUP BY patient_sex;

-- 3.Show Death Report Distribution by Age
WITH death_counts AS (
  SELECT patient_age, COUNT(*) AS death_count
  FROM drug_events
  WHERE outcome = 1 AND patient_age != -1
  GROUP BY patient_age
  ORDER BY death_count DESC
)
SELECT *
FROM death_counts
LIMIT 10;
show tables;

-- 4. Retrieve the Most Frequently Reported Adverse Reactions
CREATE VIEW most_common_reactions AS
SELECT reaction, COUNT(*) AS frequency
FROM drug_events
GROUP BY reaction
ORDER BY frequency DESC;
select * from most_common_reactions
LIMIT 10;


-- 5. Total Death Cases Reported
SELECT COUNT(*) AS total_deaths
FROM drug_events
WHERE outcome = 1;

-- 6. Categorize and Count Reports Based on Patient Age Groups
SELECT
  CASE
    WHEN patient_age BETWEEN 0 AND 18 THEN '0–18'
    WHEN patient_age BETWEEN 19 AND 35 THEN '19–35'
    WHEN patient_age BETWEEN 36 AND 50 THEN '36–50'
    WHEN patient_age BETWEEN 51 AND 70 THEN '51–70'
    WHEN patient_age > 70 THEN '70+'
    ELSE 'Unknown'
  END AS age_group,
  COUNT(*) AS total
FROM drug_events
GROUP BY age_group
ORDER BY total DESC;

-- 7.Drug-wise Death Reports
SELECT drug_name, COUNT(*) AS death_count
FROM drug_events
WHERE outcome = 1
GROUP BY drug_name
ORDER BY death_count DESC
LIMIT 10;


-- 8. Reactions That Occur Most in Females
SELECT reaction, COUNT(*) AS female_reactions
FROM drug_events
WHERE patient_sex = 'Female'
GROUP BY reaction
ORDER BY female_reactions DESC
LIMIT 10;

-- 9. Reactions That Occur Most in Males
SELECT reaction, COUNT(*) AS Male_reactions
FROM drug_events
WHERE patient_sex = 'Male'
GROUP BY reaction
ORDER BY Male_reactions DESC
LIMIT 10;

-- 10. Top Drugs Reported by Male Patients
SELECT drug_name, COUNT(*) AS reports
FROM drug_events
WHERE patient_sex = 'Male'
GROUP BY drug_name
ORDER BY reports DESC
LIMIT 10;

-- 11. Analyze Year-wise Trends in Drug Reports
SELECT YEAR(receivedate) AS report_year, COUNT(*) AS total_reports
FROM drug_events
GROUP BY report_year
ORDER BY report_year;

-- 12. Drugs That Caused Multiple Reactions
CREATE VIEW drug_reaction_variability AS
SELECT drug_name, COUNT(DISTINCT reaction) AS unique_reactions
FROM drug_events
GROUP BY drug_name
ORDER BY unique_reactions DESC;
select * from drug_reaction_variability
LIMIT 10;


-- 13. Find Patients With Unknown Age and Sex
SELECT COUNT(*) AS unknown_demographics
FROM drug_events
WHERE patient_age = -1 AND patient_sex = 'Unknown';


-- 14. Top Drugs in Each Age Group Causing Death
SELECT 
  CASE
    WHEN patient_age BETWEEN 0 AND 18 THEN '0–18'
    WHEN patient_age BETWEEN 19 AND 35 THEN '19–35'
    WHEN patient_age BETWEEN 36 AND 50 THEN '36–50'
    WHEN patient_age BETWEEN 51 AND 70 THEN '51–70'
    WHEN patient_age > 70 THEN '70+'
    ELSE 'Unknown'
  END AS age_group,
  drug_name,
  COUNT(*) AS death_count
FROM drug_events
WHERE outcome = 1 AND patient_age != -1
GROUP BY age_group, drug_name
HAVING death_count > 1
ORDER BY age_group, death_count DESC;

-- 15. Compare Death Count by Age Group
WITH age_death_data AS (
  SELECT
    CASE
      WHEN patient_age BETWEEN 0 AND 18 THEN '0–18'
      WHEN patient_age BETWEEN 19 AND 35 THEN '19–35'
      WHEN patient_age BETWEEN 36 AND 50 THEN '36–50'
      WHEN patient_age BETWEEN 51 AND 70 THEN '51–70'
      WHEN patient_age > 70 THEN '70+'
      ELSE 'Unknown'
    END AS age_group,
    COUNT(*) AS total_reports,
    SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) AS deaths
  FROM drug_events
  WHERE patient_age != -1
  GROUP BY age_group
)
SELECT *, ROUND(100 * deaths / total_reports, 2) AS death_rate
FROM age_death_data
ORDER BY death_rate DESC;

-- 16. % of Reports That Ended in Death (Using Subquery)
SELECT 
  ROUND(100.0 * (
    SELECT COUNT(*) FROM drug_events WHERE outcome = 1
  ) / COUNT(*), 2) AS death_rate_percentage
FROM drug_events;

-- 17. Drugs With Death Rate > 20%
CREATE VIEW ranked_death_reports AS
SELECT 
  drug_name,
  COUNT(*) AS total_reports,
  SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) AS death_reports,
  ROUND(100.0 * SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS death_rate,
  RANK() OVER (
    ORDER BY ROUND(100.0 * SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) DESC
  ) AS death_rank
FROM drug_events
GROUP BY drug_name;
select * from ranked_death_reports
where death_rate > 20;


-- 18. Validate Death Rate Trends for Drugs with At Least 10 Reports
SELECT drug_name,
       COUNT(*) AS total_reports,
       SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) AS total_deaths,
       ROUND(100 * SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS death_rate
FROM drug_events
GROUP BY drug_name
HAVING total_reports >= 10
ORDER BY death_rate DESC;

-- 19. Identify Top 3 Reactions for Each Gender
WITH reaction_ranked AS (
  SELECT 
    patient_sex, reaction, COUNT(*) AS reaction_count,
    RANK() OVER (PARTITION BY patient_sex ORDER BY COUNT(*) DESC) AS Rank_
  FROM drug_events
  GROUP BY patient_sex, reaction
)
SELECT * FROM reaction_ranked
WHERE Rank_ <= 3;



-- 20. Age Brackets with High % of Deaths
SELECT
  CASE
    WHEN patient_age BETWEEN 0 AND 18 THEN '0–18'
    WHEN patient_age BETWEEN 19 AND 35 THEN '19–35'
    WHEN patient_age BETWEEN 36 AND 50 THEN '36–50'
    WHEN patient_age BETWEEN 51 AND 70 THEN '51–70'
    WHEN patient_age > 70 THEN '70+'
    ELSE 'Unknown'
  END AS age_group,
  COUNT(*) AS total,
  SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) AS death_cases,
  ROUND(100 * SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END)/COUNT(*), 2) AS death_rate
FROM drug_events
GROUP BY age_group
ORDER BY death_rate DESC;


-- 21. Total Reports, Total Deaths, Death Rate
SELECT 
  COUNT(*) AS total_reports,
  SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) AS total_deaths,
  ROUND(100 * SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS death_rate_percentage
FROM drug_events;

-- 22. Reports by Gender with Percentage
SELECT 
  patient_sex,
  COUNT(*) AS total,
  ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM drug_events), 2) AS percentage
FROM drug_events
GROUP BY patient_sex;

-- 23. Average Age of Patients (Excluding Unknowns)
SELECT ROUND(AVG(patient_age), 1) AS average_age
FROM drug_events
WHERE patient_age != -1;


-- 24. Track Deaths Caused by Each Drug-Reaction Combination
SELECT drug_name, reaction, COUNT(*) AS death_cases
FROM drug_events
WHERE outcome = 1
GROUP BY drug_name, reaction
ORDER BY death_cases DESC
LIMIT 10;

-- 25. Generate a KPI Summary Dashboard View
CREATE VIEW kpi_summary AS
SELECT 
  COUNT(*) AS total_reports,
  SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) AS total_deaths,
  ROUND(100 * SUM(CASE WHEN outcome = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS death_rate
FROM drug_events;
select * from kpi_summary;

-- 26. Create a Stored Procedure to Get Report Count for Any Drug
DELIMITER //
CREATE PROCEDURE GetDrugReports(IN drug VARCHAR(255))
BEGIN
  SELECT COUNT(*) AS report_count
  FROM drug_events
  WHERE drug_name = drug;
END;//
DELIMITER ; 

-- 27. Exportable Table for Power BI: Gender-Based Reaction Heatmap
CREATE VIEW gender_reaction_matrix AS
SELECT patient_sex, reaction, COUNT(*) AS report_count
FROM drug_events
GROUP BY patient_sex, reaction;
select * from gender_reaction_matrix;

-- 28. Highlight Unusual Drug Reporting (Outliers)
SELECT drug_name, COUNT(*) AS total_reports
FROM drug_events
GROUP BY drug_name
HAVING total_reports > (SELECT AVG(total) + 2 * STDDEV(total)
                        FROM (SELECT COUNT(*) AS total FROM drug_events GROUP BY drug_name) AS subquery)
ORDER BY total_reports DESC;

-- 29. Identify Drugs Reported by Both Male and Female Patients
SELECT 
    ROW_NUMBER() OVER () AS row_index,
    drug_name
FROM (
	SELECT drug_name
	FROM drug_events
	WHERE patient_sex IN ('Male', 'Female')
	GROUP BY drug_name
	HAVING COUNT(DISTINCT patient_sex) = 2
) AS both_sex_drugs;
