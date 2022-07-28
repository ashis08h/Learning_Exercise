CREATE Procedure [dbo].[test_1]
AS
DECLARE @JobName SYSNAME;
DECLARE @ScheduleName SYSNAME;
DECLARE @ActiveStartTime INT;
DECLARE @FreqType INT;
DECLARE @FreqInterval INT;
DECLARE @ChangeTime DATETIME='01:00:00'
--Pass input date/time value to prepone/postpone the required SQL job by specified hours:minutes:seconds.
 
DECLARE CUR_SQL_JOB_MODIFY CURSOR FAST_FORWARD FOR

--Select required jobs/Schedules from the system tables to modify the current schedule time
SELECT	A.name AS Job_Name
		,C.name AS Schedule_Name
		,C.active_start_time
		,C.freq_type
		,C.freq_interval
FROM msdb.dbo.sysjobs A
INNER JOIN msdb.dbo.sysjobschedules B ON A.job_id=B.job_id
INNER JOIN msdb.dbo.sysschedules C ON B.schedule_id=C.schedule_id
WHERE A.name='DST Transition End'
--We can add more filters based on the required Job Name, Schedule Name, Job Enabled, Schedule Enabled etc to update only given job schedules
 
OPEN CUR_SQL_JOB_MODIFY
FETCH NEXT FROM CUR_SQL_JOB_MODIFY INTO @JobName,@ScheduleName,@ActiveStartTime,@FreqType,@FreqInterval
PRINT 'Active Start Time ' + CAST(@ActiveStartTime AS VARCHAR(10))
PRINT 'FETCH_STATUS ' + CAST(@@FETCH_STATUS AS VARCHAR(10))

WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @CurrentScheduleTime VARCHAR(8);
	DECLARE @CurrentScheduleTimeFormat VARCHAR(8);
	DECLARE @CurrentScheduleDateTime DATETIME;
	DECLARE @NewScheduleDateTime DATETIME;
	DECLARE @UpdateScheduleDateTime VARCHAR(6);

	--Getting current schedule time in the format of hhmmss(Exmaple 213010)
	SET @CurrentScheduleTime=(SELECT RIGHT(CONCAT('000000',CAST(@ActiveStartTime AS VARCHAR(50))),6))
	--Converting current schedule time to hh:mm:ss format
	SET @CurrentScheduleTimeFormat=(SELECT CONVERT(VARCHAR(15), STUFF(STUFF(@CurrentScheduleTime, 3, 0, ':'), 6, 0, ':'), 8))
	--Calculating new schedule time based on the given time frame
	SET @CurrentScheduleDateTime=(SELECT DATEADD(s,DATEDIFF(s,0,CONVERT(TIME,@CurrentScheduleTimeFormat)),(FORMAT(GETDATE(), 'yyyy-MM-dd'))))
	SET @NewScheduleDateTime=DATEADD(S,-DATEDIFF(S,0,@ChangeTime),@CurrentScheduleDateTime)
	SET @UpdateScheduleDateTime=REPLACE(CONVERT(VARCHAR,@NewScheduleDateTime,8),':','')

	--Preparing dynamic SQL query to update current SQL schedule time to given time(prepone/postpone schedule by taking input in hours format)
	DECLARE @SQL NVARCHAR(4000)
	--IF the job schedule is Weekly THEN below code runs
	PRINT 'FreqType ' + CAST(@FreqType AS VARCHAR(10))
	IF (@FreqType=8)
	BEGIN
		DECLARE @NewFreqInterval TINYINT
		DECLARE @Sunday TINYINT = 1,@Monday TINYINT = 2,@Tuesday TINYINT = 4,@Wednesday TINYINT = 8,@Thursday TINYINT = 16,@Friday TINYINT = 32,@Saturday TINYINT = 64, @Current_Freq_Interval TINYINT = @FreqInterval
	
		DROP TABLE IF EXISTS Stg_DST_Control CREATE TABLE Stg_DST_Control(Sunday VARCHAR(10),Monday VARCHAR(10),Tuesday VARCHAR(10),Wednesday VARCHAR(10),Thursday VARCHAR(10),Friday VARCHAR(10),Saturday VARCHAR(10))

		INSERT INTO Stg_DST_Control
		SELECT CASE WHEN @Current_Freq_Interval & @Sunday = @Sunday THEN 'Y' ELSE 'N' END AS Sunday,
		CASE WHEN @Current_Freq_Interval & @Monday = @Monday THEN 'Y' ELSE 'N' END AS Monday,
		CASE WHEN @Current_Freq_Interval & @Tuesday = @Tuesday THEN 'Y' ELSE 'N' END AS Tuesday,
		CASE WHEN @Current_Freq_Interval & @Wednesday = @Wednesday THEN 'Y' ELSE 'N' END AS Wednesday,
		CASE WHEN @Current_Freq_Interval & @Thursday = @Thursday THEN 'Y' ELSE 'N' END AS Thursday,
		CASE WHEN @Current_Freq_Interval & @Friday = @Friday THEN 'Y' ELSE 'N' END AS Friday,
		CASE WHEN @Current_Freq_Interval & @Saturday = @Saturday THEN 'Y' ELSE 'N' END AS Saturday

		DROP TABLE IF EXISTS Out_DST_Control CREATE TABLE Out_DST_Control(WeekDayName VARCHAR(15), CurrentFreqInterval INT,Flag VARCHAR(2),CurrentSchedule DATETIME,NewSchedule DATETIME,NewWeekDayName VARCHAR(15),NewFreqInterval INT)
		INSERT INTO Out_DST_Control(WeekDayName) SELECT COLUMN_NAME AS WeekDayName FROM INFORMATION_SCHEMA.columns WHERE TABLE_NAME='Stg_DST_Control'

		UPDATE Out_DST_Control SET CurrentFreqInterval=1,	Flag=(SELECT Sunday FROM Stg_DST_Control),		CurrentSchedule=(DATEADD(DAY,1-DATEPART(WEEKDAY,@CurrentScheduleDateTime),@CurrentScheduleDateTime)) WHERE WeekDayName='Sunday'
		UPDATE Out_DST_Control SET CurrentFreqInterval=2,	Flag=(SELECT Monday FROM Stg_DST_Control),		CurrentSchedule=(DATEADD(DAY,2-DATEPART(WEEKDAY,@CurrentScheduleDateTime),@CurrentScheduleDateTime)) WHERE WeekDayName='Monday'
		UPDATE Out_DST_Control SET CurrentFreqInterval=4,	Flag=(SELECT Tuesday FROM Stg_DST_Control),		CurrentSchedule=(DATEADD(DAY,3-DATEPART(WEEKDAY,@CurrentScheduleDateTime),@CurrentScheduleDateTime)) WHERE WeekDayName='Tuesday'
		UPDATE Out_DST_Control SET CurrentFreqInterval=8,	Flag=(SELECT Wednesday FROM Stg_DST_Control),	CurrentSchedule=(DATEADD(DAY,4-DATEPART(WEEKDAY,@CurrentScheduleDateTime),@CurrentScheduleDateTime)) WHERE WeekDayName='Wednesday'
		UPDATE Out_DST_Control SET CurrentFreqInterval=16,	Flag=(SELECT Thursday FROM Stg_DST_Control),	CurrentSchedule=(DATEADD(DAY,5-DATEPART(WEEKDAY,@CurrentScheduleDateTime),@CurrentScheduleDateTime)) WHERE WeekDayName='Thursday'
		UPDATE Out_DST_Control SET CurrentFreqInterval=32,	Flag=(SELECT Friday FROM Stg_DST_Control),		CurrentSchedule=(DATEADD(DAY,6-DATEPART(WEEKDAY,@CurrentScheduleDateTime),@CurrentScheduleDateTime)) WHERE WeekDayName='Friday'
		UPDATE Out_DST_Control SET CurrentFreqInterval=64,	Flag=(SELECT Saturday FROM Stg_DST_Control),	CurrentSchedule=(DATEADD(DAY,7-DATEPART(WEEKDAY,@CurrentScheduleDateTime),@CurrentScheduleDateTime)) WHERE WeekDayName='Saturday'

		UPDATE Out_DST_Control SET NewSchedule=DATEADD(s,-DATEDIFF(s,0,CONVERT(DATETIME,@ChangeTime)),CurrentSchedule)
		UPDATE Out_DST_Control SET NewWeekDayName=DATENAME(WEEKDAY,NewSchedule)
		UPDATE Out_DST_Control SET NewFreqInterval=CASE WHEN NewWeekDayName='Sunday' THEN 1 WHEN NewWeekDayName='Monday' THEN 2 WHEN NewWeekDayName='Tuesday' THEN 4 WHEN NewWeekDayName='Wednesday' THEN 8 WHEN NewWeekDayName='Thursday' THEN 16 WHEN NewWeekDayName='Friday' THEN 32 WHEN NewWeekDayName='Saturday' THEN 64 End

		SET @NewFreqInterval=(SELECT SUM(NewFreqInterval) FROM Out_DST_Control WHERE Flag='Y')
		PRINT 'NewFreqInterval ' + CAST(@NewFreqInterval AS VARCHAR(10))
		PRINT 'ScheduleName ' + CAST(@ScheduleName AS VARCHAR(10))
		PRINT 'UpdateScheduleDateTime ' + CAST(@UpdateScheduleDateTime AS VARCHAR(10))
		PRINT 'NewFreqInterval ' + CAST(@NewFreqInterval AS VARCHAR(10))
		SET @SQL='
		EXEC msdb.dbo.sp_update_schedule 
		@name = '+ '''' +@ScheduleName+ '''' +',
		@active_start_time = '+@UpdateScheduleDateTime +',
		@freq_interval = '+CAST(@NewFreqInterval AS VARCHAR(10));
	END
	--IF the job schedule is Daily/Monthly then below code runs
	ELSE
	BEGIN
		SET @SQL='
		EXEC msdb.dbo.sp_update_schedule 
		@name = '+ '''' +@ScheduleName+ '''' +',
		@active_start_time = '+@UpdateScheduleDateTime;
	END
	PRINT 'SQL ' + @SQL
	EXECUTE(@SQL)
	PRINT'Current Schedule TIME For The Job:'+@JobName+' Is Updated FROM '+@CurrentScheduleTime+' To '+@UpdateScheduleDateTime+' And Schedule Name Is:'+@ScheduleName

   FETCH NEXT FROM CUR_SQL_JOB_MODIFY INTO @JobName,@ScheduleName,@ActiveStartTime,@FreqType,@FreqInterval
   --SET @FETCH_STATUS = @FETCH_STATUS + 1;
END
 
CLOSE CUR_SQL_JOB_MODIFY
DEALLOCATE CUR_SQL_JOB_MODIFY