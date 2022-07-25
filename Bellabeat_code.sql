/*
            BELlABEAT CASE STUDY MADE IN THE MICROSOFT SQL SERVER 2019
*/

/* ==========================================================================
   =============             1. Reviewing datasets            ===============
   ========================================================================== */


-- dailyActivity dataset, contains info about daily distances,
-- active time, calories burned and steps made
SELECT COUNT(*) AS number_of_rows FROM dailyActivity;
SELECT TOP 5 * FROM dailyActivity;

/* heartrateSeconds contains every users' heartrate record */ 
SELECT COUNT(*) AS number_of_rows FROM heartrateSeconds;
SELECT TOP 5 * FROM heartrateSeconds;

-- sleepDay is a dataset of every daily sleep record, including sleep time and time in bed
SELECT COUNT(*) AS numberOfRows FROM sleepDay;
SELECT TOP 5 * FROM sleepDay;

-- weightLogInfo is about users' weight info, including weight in kilograms
-- and pounds, and body mass index (BMI)
SELECT COUNT(*) AS numberOfRows FROM weightLogInfo;
SELECT TOP 5 * FROM weightLogInfo;

-- checking the number of unique users in each dataset (it should be 30)
SELECT COUNT(DISTINCT Id) AS dailyActivityIDs FROM dailyActivity;
SELECT COUNT(DISTINCT Id) AS heartrateIDs     FROM heartrateSeconds;
SELECT COUNT(DISTINCT Id) AS sleepDayIDs      FROM sleepDay;
SELECT COUNT(DISTINCT Id) AS weightLogIDs     FROM weightLogInfo;
-- only 'dailyActivity' dataset has 30+ unique ID's.
-- other datasets have 24, 22 and 8 unique user IDs


/* ===========================================================================
   =============              CLEANING DATASETS                ===============
   =========================================================================== */

/* -----------------    CLEANIING dailyActivity DATASET    ------------------- */

-- checking for duplicates
SELECT Id, ActivityDate, COUNT(*) AS numberOfRecords --count a number of each unique entry
FROM dailyActivity
GROUP BY Id, ActivityDate
HAVING COUNT(*) > 1 -- output those which have more than one entry (are duplicated)
-- there's no duplicates


-- removing unnecessary columns
-- 'SedentaryActiveDistance' column is a non-sense, 'cause human can't walk being sedentary. I used to remove the column
ALTER TABLE dailyActivity 
DROP COLUMN SedentaryActiveDistance;


-- rename column 'ActivityDate' to 'Date'
EXEC sp_rename 'dailyActivity.ActivityDate', 'Date', 'COLUMN';


-- checking the datatypes 
EXEC sp_help dailyActivity;
-- all the columns in all the imported tables have 'varchar' data type. this should be fixed


ALTER TABLE dailyActivity ALTER COLUMN Id bigint; -- change data type from string to long
ALTER TABLE dailyActivity ALTER COLUMN Date DATE; -- data type from string to date
ALTER TABLE dailyActivity ALTER COLUMN TotalSteps INTEGER; -- from string to integer
ALTER TABLE dailyActivity ALTER COLUMN TotalDistance FLOAT; -- from string to float, etc.
ALTER TABLE dailyActivity ALTER COLUMN TrackerDistance FLOAT;
ALTER TABLE dailyActivity ALTER COLUMN VeryActiveDistance FLOAT; 
ALTER TABLE dailyActivity ALTER COLUMN ModeratelyActiveDistance FLOAT;
ALTER TABLE dailyActivity ALTER COLUMN LightActiveDistance FLOAT;
ALTER TABLE dailyActivity ALTER COLUMN VeryActiveMinutes INTEGER;
ALTER TABLE dailyActivity ALTER COLUMN FairlyActiveMinutes INTEGER;
ALTER TABLE dailyActivity ALTER COLUMN LightlyActiveMinutes INTEGER;
ALTER TABLE dailyActivity ALTER COLUMN SedentaryMinutes INTEGER;
ALTER TABLE dailyActivity ALTER COLUMN Calories INTEGER;

---------------------------------------------------------------------------------------------
-- adding column 'CaloriesLevel', which labels all the calories burned >=2000 kal as normal,
-- and all that are less than 2000 - low.
ALTER TABLE dailyActivity 
ADD CaloriesLevel AS 
(
    CASE WHEN Calories < 2000 THEN 'Low' 
    ELSE 'Normal' 
    END
);


------------------ checking the outliers in the numbers of records by date----------------
WITH records AS 
(
    SELECT
        Date,
        COUNT(*) OVER (PARTITION BY Date ORDER BY Date) AS NumberOfRecords -- counting num of records made each day
    FROM dailyActivity
),
stats AS
(
    SELECT 
        STDEV(NumberOfRecords) AS StDeviation, -- counting standard deviation 
        AVG(NumberOfRecords) AS Average -- counting average value
    FROM records
)
-- defining a date outlier 
SELECT DISTINCT Date, NumberOfRecords
FROM records, stats
WHERE 
    NumberOfRecords < Average - 3 * StDeviation OR 
    NumberOfRecords > Average + 3 * StDeviation;
-- 2016-05-12 is an outlier with far less records made by users, because it was 
-- the last day of tracking


-------------------- checking the steps made each day-----------------------------
WITH stats AS
(
    SELECT 
        STDEV(TotalSteps) AS StDeviation, -- counting standard deviation 
        AVG(TotalSteps) AS Average -- counting average value
    FROM dailyActivity
)
-- defining a date outlier 
SELECT DISTINCT Id, Date, TotalSteps
FROM dailyActivity, stats
WHERE 
    TotalSteps < Average - 3 * StDeviation OR 
    TotalSteps > Average + 3 * StDeviation;
-- there are 6 outliers than need an additional analysis to define what to do with them


---------------- checking the calories burned by users each date ----------------------
WITH stats AS
(
    SELECT 
        STDEV(Calories) AS StDeviation, -- counting standard deviation 
        AVG(Calories) AS Average -- counting average value
    FROM dailyActivity
)
-- defining a date outlier 
SELECT DISTINCT Id, Date, Calories
FROM dailyActivity, stats
WHERE 
    Calories < Average - 3 * StDeviation OR 
    Calories > Average + 3 * StDeviation
ORDER BY Date;
-- there are 12 outliers that need some additional analysis

/* Well, according to https://www.sleepfoundation.org/how-sleep-works/how-your-body-uses-calories-while-you-sleep#:~:text=How%20Many%20Calories%20Do%20You,metabolic%20rate2%20(BMR).
Human burns at least 50 calories per hour even when doing nothing, 
sleeping and being sedentary. That's 1200 calories per day, so there's no way to burn 
less. I used to remove all the numbers less than 1200.*/
DELETE FROM dailyActivity WHERE Calories < 1200;


--------------------  Cleaning 'heartrateSeconds' ------------------------------------

----------------------- changing the datatypes ---------------------------------------
ALTER TABLE heartrateSeconds ALTER COLUMN Id bigint; -- from varchar to int
ALTER TABLE heartrateSeconds ALTER COLUMN Time datetime; -- from varchar to datetime
ALTER TABLE heartrateSeconds ALTER COLUMN Value INTEGER; -- from varchar to int


---------------------- making column names clearer -----------------------------------
EXEC sp_rename 'heartrateSeconds.Value', 'Heartrate', 'COLUMN';
-- rename 'Value'  field to 'Heartrate'

--------------------------- adding variables -----------------------------------------
ALTER TABLE heartrateSeconds ADD 
    Date AS (CAST(Time AS date)), -- separate date
    Hour AS DATEPART(HOUR, Time), -- hour


--------------------------- modifying columns -----------------------------------------
ALTER TABLE heartrateSeconds ADD Datetime AS FORMAT(Time, 'dd-MM-yyyy HH:mm');
-- datetime without seconds 

-- make heartrate dataset shorter without losing consistency
-- heartrate is measured in beats per MINUTE, but there a lot of multiple minute
-- values, so i used to count average heartrate per minute and make the dataset
-- 10x times more compact
SELECT Id, Datetime, Date, Hour, CAST(AVG(Heartrate) AS int) AS HeartRate
INTO heartrateMinutes
FROM heartrateSeconds
GROUP BY Id, Datetime, Date, Hour;

-------------------------- adding variable 'heartrateLevel' ---------------------------
ALTER TABLE heartrateMinutes ADD HeartrateLevel AS
(
    CASE 
        WHEN HeartRate < 60 THEN 'Low'   -- if a heartrate is lower than 60 bpm, then that's a low heartrate
        WHEN HeartRate > 100 THEN 'High' -- if a heartrate is higher than 100 bpm, then that's a high heartrate
        ELSE 'Normal'                    -- if a heartrate is 60-100 bpm, then that's a normal heartrate
    END
);

--------------------------- checking for duplicates -----------------------------------
SELECT Id, Datetime, COUNT(*) AS numOfDuplicates
FROM heartrateMinutes
GROUP BY Id, Datetime
HAVING COUNT(*) > 1; -- checking rows that have multiple entries = duplicates
-- there's no duplicates


---------------------------------------------------------------------------------------
------------------------ PROCESSING 'sleepDay' DATASET --------------------------------

------------ changing data types 
ALTER TABLE sleepDay ALTER COLUMN Id bigint; -- changing datatype of Id from varchar to big integer
ALTER TABLE sleepDay ALTER COLUMN SleepDay Date; -- changing datatype from varchar to date
ALTER TABLE sleepDay ALTER COLUMN TotalSleepRecords int; -- from varchar to int
ALTER TABLE sleepDay ALTER COLUMN TotalMinutesAsleep int; -- from varchar to int
ALTER TABLE sleepDay ALTER COLUMN TotalTimeInBed int; -- from varchar to int


------------ checking for duplicates
SELECT 
    Id,
    SleepDay,
    COUNT(*) AS NumOfDuplicates
FROM sleepDay
GROUP BY Id, SleepDay
HAVING COUNT(*) > 1; -- detect records that are repeated in the table (duplicates)
-- there are 3 duplicate entries, so I used to delete them.

WITH duplicateTable AS 
(
    SELECT *, 
        ROW_NUMBER() OVER -- count the number of unique entries
        (
            PARTITION BY Id, SleepDay -- group by primary key (Id + SleepDay) but not change the number of rows
            ORDER BY Id, SleepDay -- sort by primary key
        ) AS numOfRecords
    FROM sleepDay
)
DELETE FROM duplicateTable WHERE numOfRecords <> 1; -- delete all the non-unique entries with keeping the original

-- there's another way to delete duplicates
SELECT DISTINCT * INTO sleepDay2 FROM sleepDay;
DROP TABLE sleepDay;
EXEC sp_rename 'bellabeat.sleepDay2', 'sleepDay'; -- same result


-- rename 'sleepDay' column to 'Date'
EXEC sp_rename 'sleepDay.SleepDay', 'Date', 'COLUMN';


------------------- add 'SleepRate' column
-- daily sleeping norm is 7-9 hours. I used to rate sleep time of the users
ALTER TABLE sleepDay 
ADD SleepRate AS
(
    CASE 
    WHEN TotalMinutesAsleep < 420 THEN 'Lack of sleep' -- if the sleep time < 420 minutes (7 hours)
    WHEN TotalMinutesAsleep > 540 THEN 'Oversleeping' -- if the sleep time > 540 (9 hours)
    ELSE 'Normal sleep'
    END
);

--------------------- checking for outliers in the number of records by date
WITH stats AS
(
    SELECT 
        STDEV(TotalMinutesAsleep) AS StDeviation, -- counting standard deviation 
        AVG(TotalMinutesAsleep) AS Average -- counting average value
    FROM sleepDay
)
-- defining a date outlier 
SELECT DISTINCT Id, Date, TotalMinutesAsleep
FROM sleepDay, stats
WHERE TotalMinutesAsleep < Average - 3 * StDeviation OR TotalMinutesAsleep > Average + 3 * StDeviation;
-- 6 outliers than need an additional analysis

---------------------- adding 'TimeBeforeSleep' column
-- which is counted as a difference between total time in bed and sleep time
ALTER TABLE sleepDay ADD TimeBeforeSleep AS (TotalTimeInBed - TotalMinutesAsleep);

----------------------------------------------------------------------------------------
---------------------- CLEANING 'weightLogInfo' dataset --------------------------------

--------------------- checking 'FAT' column
SELECT COUNT(*) AS NumberOfNAs FROM weightLogInfo 
WHERE FAT = ''; 
-- 65/67 entries in the column are empty, so this field is totally inconsistent.
ALTER TABLE weightLogInfo DROP COLUMN FAT; -- delete column


----------------------- changing data types
ALTER TABLE weightLogInfo ALTER COLUMN Id bigint; -- change 'Id' data type from varchar to big integer
ALTER TABLE weightLogInfo ALTER COLUMN Date date; -- change 'Date' data type from varchar to date
ALTER TABLE weightLogInfo ALTER COLUMN WeightKg float; -- change 'WeightKg' data type from varchar to float
ALTER TABLE weightLogInfo ALTER COLUMN WeightPounds float; -- change 'WeightPounds' data type from varchar to float
ALTER TABLE weightLogInfo ALTER COLUMN BMI float; -- change 'BMI' data type from varchar to float
ALTER TABLE weightLogInfo ALTER COLUMN IsManualReport bit; -- change 'IsManualReport' data type from varchar to bit
ALTER TABLE weightLogInfo ALTER COLUMN LogId bigint; -- change 'LogId' data type from varchar to big integer


----------------------- checking for duplicates
SELECT 
    Id,
    Date,
    COUNT(*) AS NumOfDuplicates -- count the number of primary key (Id + Date) entries
FROM weightLogInfo
GROUP BY Id, Date
HAVING COUNT(*) > 1; -- output all the non-unique values
-- no duplicates there.

-- rename weightLogInfo column from BMI to BodyMassIndex using sp_rename function
EXEC sp_rename 'weightLogInfo.BMI', 'BodyMassIndex', 'COLUMN';

------------------------ adding a variable
ALTER TABLE weightLogInfo ADD BodyFatRank AS -- add column 'BodyFatRank' which is calculated as:
(
    CASE
    WHEN BodyMassIndex < 18.5 THEN 'Underweight' -- if a BMI is lower than 18.4, then a person is underweight
    WHEN BodyMassIndex > 24.9 THEN 'Overweight' -- if a BMI is higher than 24.9, then a person is overweight
    ELSE 'Normal' -- if a BMI is 18.5-24.9, the person has normal body fat
    END
);


/* ======================================================================================
   ==================================== ANALYSIS ========================================
   ======================================================================================*/


---------------------------- average distances in 'dailyActivity'
SELECT
    Id,
    AVG(TotalSteps) AS AvgSteps,
    AVG(VeryActiveDistance) AS AvgVeryActiveDistance,
    AVG(VeryActiveMinutes) AS AvgVeryActiveMinutes,
    AVG(SedentaryMinutes) AS AvgSedentary,
    AVG(Calories) AS AvgCalories
FROM dailyActivity
GROUP BY Id;

-------------------  checking the relation between active distances and calories burned
SELECT TOP 100
    Id,
    Date,
    Calories,
    VeryActiveDistance, 
    ModeratelyActiveDistance, 
    LightActiveDistance
FROM dailyActivity
ORDER BY Calories DESC;

-- checking a relation between activity minutes and calories burned
SELECT TOP 100 -- top 100 only for exploratory and memory saving
    Id,
    Date,
    Calories,
    VeryActiveMinutes, 
    FairlyActiveMinutes, 
    LightlyActiveMinutes,
    SedentaryMinutes
FROM dailyActivity
ORDER BY Calories DESC;

--------------------- a proportion between normal and low calories level
SELECT CaloriesLevel, COUNT(*) AS Frequency
FROM dailyActivity
GROUP BY CaloriesLevel;
-- there is 571 records of 'Normal' level, and 351 - of 'Low'.


--------------------- body mass index level stats
SELECT DISTINCT Id, BodyFatRank, COUNT (*) AS Frequency -- count a number of records of each body fat level
FROM weightLogInfo
GROUP BY Id, BodyFatRank;
-- 5/8 users tested are overweight, but that data can be not clear, 
-- because of 33 users tested the app, not 8 only.


---------- average sleep time, average time in bed, average time before sleep by each user
SELECT 
    Id,
    AVG(TotalMinutesAsleep) AS AverageSleepTime,
    AVG(TotalTimeInBed) AS AverageTimeInBed,
    AVG(TimeBeforeSleep) AS AverageTimeBeforeSleep
FROM sleepDay
GROUP BY Id
ORDER BY AverageSleepTime;


---------------------- total sleep quality stats
SELECT SleepRate, -- lack of sleep, normal or oversleeping
    COUNT (*) AS Frequency
FROM sleepDay
GROUP BY SleepRate;
-- there are 190 records - Normal sleep, 181 - lack of sleep, 39 - oversleeping


---------------------- sleep quality stats by each user
SELECT Id, SleepRate, COUNT(*) AS Frequency
FROM sleepDay
GROUP BY Id, SleepRate
ORDER BY Id;


---------------------- average all month heartrate of each user
SELECT 
    Id, CAST(AVG(Heartrate) AS INTEGER) AS AverageHeartrate
FROM heartrateMinutes
GROUP BY Id
ORDER BY AverageHeartrate;


---------------------- daily average heartrate statistics of each user
SELECT 
    Id, Date, CAST(AVG(Heartrate) AS INTEGER) AS AverageHeartrate
FROM heartrateMinutes
GROUP BY Id, Date
ORDER BY Id, Date;


---------------------- daily heartrate level stats by each user
SELECT Id, Date, HeartrateLevel, COUNT(*) AS Frequency
FROM heartrateMinutes
GROUP BY Id, Date, HeartrateLevel
ORDER BY Id, Date;


---------------------- total  heartrate stats by each user
SELECT Id, HeartrateLevel, COUNT(*) AS Frequency
FROM heartrateMinutes
GROUP BY Id, HeartrateLevel
ORDER BY Id;


---------------------- this output shows how the heartrate level changes during a day 
SELECT Hour, HeartrateLevel, COUNT(*) AS Frequency
FROM heartrateMinutes
GROUP BY Hour, HeartrateLevel
ORDER BY Hour;


-- a relation between sedentary minutes and sleep time, and between total steps 
-- made and sleep time
SELECT 
    SedentaryMinutes, 
    TotalSteps,
    sleepDay.TotalMinutesAsleep
FROM dailyActivity
INNER JOIN sleepDay
ON (dailyActivity.Id = sleepDay.Id AND dailyActivity.Date = sleepDay.Date)
ORDER BY SedentaryMinutes DESC;


----------- a relation between sedentary time, total steps made and body mass index
SELECT 
    SedentaryMinutes,
    TotalSteps,
    weightLogInfo.BodyMassIndex
FROM dailyActivity
INNER JOIN weightLogInfo 
ON (dailyActivity.Id = weightLogInfo.Id AND dailyActivity.Date = weightLogInfo.Date)
ORDER BY BodyMassIndex;


-- a relation between how much time people spend sedentary and how it affects their heart
WITH dailyHeartrate AS
(
    SELECT Id, Date, HeartrateLevel, COUNT(*) AS Frequency
    FROM heartrateMinutes
    GROUP BY Id, Date, HeartrateLevel
)
SELECT 
    SedentaryMinutes,
    dailyHeartrate.HeartrateLevel,
    dailyHeartrate.Frequency
FROM dailyActivity
INNER JOIN dailyHeartrate 
ON (dailyActivity.Id = dailyHeartrate.Id AND 
    dailyActivity.Date = dailyHeartrate.Date)
ORDER BY SedentaryMinutes DESC;