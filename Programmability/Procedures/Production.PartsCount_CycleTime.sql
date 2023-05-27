SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE  [Production].[PartsCount_CycleTime] 
		@SelectPeriod	VARCHAR(500) = NULL,	
		@ThisDay		DATE = NULL,
		@DateFrom		DATE = NULL,
		@DateTo			DATE = NULL,
		@Week			VARCHAR(20) = NULL,
		@Month			VARCHAR(2) = NULL,
		@Variant		VARCHAR(500) = NULL,
		@Monolith		VARCHAR(1) = NULL
		
AS
BEGIN
	SET NOCOUNT ON
---------------------------------------------------------------------------------------------------	
---DECLARATION FOR START DATE AND END DATE
----------------------------------------------------------------------------------------------a-----
	DECLARE @StartDate	DATE,
			@EndDate	DATE 

---------------------------------------------------------------------------------------------------	
-- Adjust start and end date
---------------------------------------------------------------------------------------------------
	IF @ThisDay = '1900-01-01'
		SET @ThisDay = NULL
	IF @DateFrom = '1900-01-01' 
		SET @DateFrom = NULL 
	IF @DateTo = '2050-12-31'
		SET @DateTo  = NULL 
	IF (@SelectPeriod) IS NULL
		SET @SelectPeriod = 'DAILY'
	IF ISNULL(@Variant,'0') = '0'
		SET @Variant = NULL
	IF @Week = '0'
		SET @Week = NULL
	IF @Month = '0'
		SET @Month = NULL

	IF(@DateFrom IS NULL AND @DateTo is NULL)
	BEGIN
		SELECT @EndDate = MAX([A1494].[LineResults].[DenormalisedMegaView].[DateTimeCompleted])
		FROM	[A1494].[LineResults].[DenormalisedMegaView]
		WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
				AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
							
---------------------------------------------------------------------------------------------------	
--GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
---------------------------------------------------------------------------------------------------	
		IF((@SelectPeriod) = 'HOURLY')	
			SET	@StartDate = @EndDate
		ELSE IF((@SelectPeriod) = 'DAILY')	
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) 
---------------------------------------------------------------------------------------------------	
--GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
---------------------------------------------------------------------------------------------------
		ELSE IF((@SelectPeriod) = 'WEEKLY')	
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) 
---------------------------------------------------------------------------------------------------	
--GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE
---------------------------------------------------------------------------------------------------
		ELSE IF((@SelectPeriod) = 'MONTHLY')
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) 		
	END
	ELSE IF((@SelectPeriod) IS NOT NULL AND @DateFrom IS NOT NULL AND @DateTo is NOT NULL)
	BEGIN
		SET	@EndDate = @DateTo  
		IF (ISNULL((@SelectPeriod), 'DAILY') = 'DAILY')
		BEGIN
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) 
			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom
		END
		ELSE IF((@SelectPeriod) = 'WEEKLY')	
		BEGIN
			SET	@EndDate = @DateTo
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) 

			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom							
		END
		ELSE IF((@SelectPeriod) = 'MONTHLY')
		BEGIN
			SET	@EndDate = @DateTo
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) 

			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom
		END
	
	END

	IF ((@SelectPeriod) = 'HOURLY')
	BEGIN

	DECLARE @HDateFrom DATETIME = convert(varchar,@StartDate,101) 
	DECLARE @HDateTo DATETIME = @HDateFrom +' 23:59:59'

		DECLARE	@HourlyData TABLE (
			[ID]						INT IDENTITY(1,1),
			[StartTime]					DATETIME,
		    [EndTime]					DATETIME,
			[PassCount]					INT,
			[FailCount]					INT,
			[Avg Cycle Time (s)]		FLOAT,	
			[DATE]						DATETIME,
			[InProgress Count]			INT ,
			[Forced Part]				INT,
			[MonoCount]					INT
			)

		CREATE TABLE #HourlyPartsCount  (
			[ID]						INT IDENTITY(1,1),
			[StartTime]					DATETIME,
			PassCount					INT,
			FailCount					INT,
			[Avg Cycle Time (s)]		FLOAT,	
			[InProgress Count]			INT ,
			[Forced Part]				INT,
			[MonoCount]					INT		
			)

		INSERT INTO @HourlyData ([StartTime],[EndTime])
		SELECT	 StartTime = D
				,StopTime  = DateAdd(HOUR,1,D)
		FROM (
				SELECT top  (DateDiff(HOUR,@HDateFrom,@HDateTo)+1) 
						D=DateAdd(HOUR,-1+Row_Number() OVER (ORDER BY (SELECT NULL)),@HDateFrom) 
				FROM  master..spt_values n1
			 ) D

		;WITH CTE AS
		(	
		SELECT	DISTINCT 
				PartFaceDMC,
				[*Variant Name] AS [Variant],									
				[DateTimeCompleted] AS [Date],
				[Cycle Time (s)] As [Cycle Time (s)],
				[FinalResult] AS [Part Result],							
				CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [OK], 
				CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END AS [NOK],
				CASE	WHEN [FinalResult] = 'FAIL'  AND [Shift] IS NOT NULL AND [DateTimeCompleted] IS NOT NULL THEN 1 END AS [In Progress]
		FROM	[A1494].[LineResults].[DenormalisedMegaView]
		WHERE	PartFaceDMC IS NOT NULL
				AND (CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL) 
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
				AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
		)
		INSERT	INTO	#HourlyPartsCount 
		([StartTime],  
		[PassCount], 
		[FailCount], 
		[Avg Cycle Time (s)],	
		[InProgress Count])
		SELECT hd.StartTime ,
		SUM(ISNULL(OK,0)) PassCount,  
		SUM(ISNULL(NOK,0)) FailCount, 
		AVG(c.[Cycle Time (s)]),	
		SUM([InProgress Count])		
		FROM	[CTE] [c]  
		CROSS APPLY (
							SELECT AVG([Cycle Time (s)]) AS [Total Avg Cycle Time (s)]
							FROM [CTE] c
							WHERE	[Variant] = CASE	WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
			)TotAvg	
		RIGHT JOIN @HourlyData hd ON c.[Date] BETWEEN hd.StartTime AND hd.EndTime 
		WHERE	[Variant] = CASE	WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
		GROUP BY hd.StartTime, hd.EndTime 

		;WITH Mono_Count	AS 
		(		
							SELECT  DISTINCT COUNT(MonoFaceDMC) [MonoCount],
									hpc.StartTime AS [Date],
									[*Variant Name] AS [Variant]
							FROM	[A1494].[LineResults].[DenormalisedMegaView]
							INNER JOIN @HourlyData hpc on [DateTimeCompleted] BETWEEN hpc.StartTime AND hpc.EndTime 
							WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
									AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL) 
									AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
									AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
							GROUP BY hpc.StartTime,[*Variant Name]
		)
		UPDATE hpc
		SET hpc.MonoCount = ho.MonoCount 
		FROM Mono_Count ho 
		inner join #HourlyPartsCount hpc on ho.[Date] = hpc.StartTime
			   

		;WITH Forced_Part AS
		(
			SELECT   COUNT(DISTINCT PartFaceDMC) [Forced Part],
								hpc.[StartTime] AS [Timestamp]									
			FROM	[A1494].[LineResults].[DenormalisedMegaView]
			INNER JOIN #HourlyPartsCount hpc on  CAST(MonoMeasuringTimeStamp AS DATE) = hpc.[StartTime]		
			where FinalResult  = 'FAIL'
			AND [DateTimeCompleted] IS NULL
			GROUP BY  hpc.[StartTime]
		)
		UPDATE hpc
		SET [Forced Part] = fp.[Forced Part] 
		FROM Forced_Part fp
			inner join #HourlyPartsCount hpc on  fp.Timestamp = hpc.[StartTime] 


		UPDATE	[d]
		SET		
				[d].PassCount = [p].[PassCount] ,
				[d].[FailCount] = [p].[FailCount] ,
				[d].[Avg Cycle Time (s)] = [p].[Avg Cycle Time (s)],
				[d].[InProgress Count] = [p].[InProgress Count],
				[d].MonoCount = [p].MonoCount,
				[d].[Forced Part] = [p].[Forced Part]
		FROM	@HourlyData [d]	
		INNER JOIN #HourlyPartsCount [p] ON  [p].StartTime   BETWEEN [d].StartTime and [d].EndTime

		-----------------------------------------------------------------------------------------------------
		-----STEP 4: FINAL OUTPUT FOR METABASE REPORT
		-----------------------------------------------------------------------------------------------------
			
		IF EXISTS (SELECT TOP 1 1 FROM #HourlyPartsCount)
		SELECT	FORMAT(StartTime,'yyyy-MM-dd HH:mm') [Date],				
				ISNULL([PassCount], 0) [Pass Count],
				ISNULL([FailCount], 0) [Fail Count],
				ISNULL([Avg Cycle Time (s)], 0) [Avg Cycle Time (s)]	
				--ISNULL([Forced Part], 0) [Forced Part],
				--ISNULL([InProgress Count], 0) [InProgress Count],
				--ISNULL(MonoCount, 0) [MonoCount]
		FROM	@HourlyData
		ELSE
		SELECT	COALESCE(@DateFrom, @DateTo)[Date],	
				0 [Partcount],
				--0 [PassCount],
				--0 [FailCount],
				0 [Avg Cycle Time (s)]	
				--0 [InProgress Count],
				--0 [Forced Part],
				--0 [MonoCount]
	DROP TABLE #HourlyPartsCount
	END
	ELSE IF (ISNULL((@SelectPeriod), 'DAILY') = 'DAILY')
	BEGIN

		---DAILY DATA
		---STEP 1: CREATE TEMP TABLE @DailyDates AND @DailyPartCount
		---------------------------------------------------------------------------------------------------
			DECLARE @DailyDates TABLE (
					[Date]				DATE NULL,
					[Part Count]		INT NULL,
					[Pass Count]		INT NULL,
					[Fail Count]		INT NULL,
					[Avg Cycle Time (s)] FLOAT,	
					[InProgress Count]	INT ,
					[Forced Part]		INT,
					[MonoCount]			INT
					)

			CREATE TABLE #DailyPartCount (
						[PartsCount]		INT NULL,
						[Timestamp]			DATE NULL,
						[Pass Count]		INT NULL,
						[Fail Count]		INT NULL,
						[Avg Cycle Time (s)] FLOAT,	
						[Total Avg Cycle Time (s)] FLOAT,
						[InProgress Count]	INT ,
						[Forced Part]		 INT ,
						[MonoCount]			 INT
					) 


			INSERT	INTO @DailyDates ([Date])
			SELECT	DATEADD(DAY,number,@StartDate) [Date]
			FROM	MASTER..spt_values
			WHERE	TYPE = 'P'
					AND DATEADD(DAY,number,@StartDate) <= @EndDate

			;WITH	[CTE] AS (
				SELECT DISTINCT
				PartFaceDMC,				
				[*Variant Name] AS [Variant],									
				CAST([DateTimeCompleted] AS DATE) AS [Timestamp],
				[Cycle Time (s)] As [Cycle Time (s)],
				[FinalResult] AS [Part Result],							
				CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [OK], 
				CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END AS [NOK], 
				CASE	WHEN [DateTimeCompleted] IS NULL AND [FinalResult] IS NULL AND [Shift] IS NOT NULL AND [DateTimeCompleted] IS NOT NULL THEN 1 END AS [In Progress]

				FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	PartFaceDMC IS NOT NULL
				AND (CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL) 
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
				AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END

			)
			INSERT	INTO	#DailyPartCount ([PartsCount],[Timestamp],[Pass Count],[Fail Count], [Avg Cycle Time (s)])
			SELECT	COUNT([PartFaceDMC]) PartsCount, [Timestamp], SUM([OK]), SUM([NOK]), AVG(c.[Cycle Time (s)])
			FROM	[CTE] [c] 	
			RIGHT JOIN @DailyDates d ON [c].[Timestamp]  = [d].[Date]
			WHERE	[Variant] = CASE	WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
			GROUP	BY [Timestamp]

			;WITH Mono_Count	AS 
			(		
								SELECT  DISTINCT COUNT(MonoFaceDMC) [MonoCount],
										CAST([DateTimeCompleted] AS DATE) AS [Timestamp],
										[*Variant Name] AS [Variant]
								FROM	[A1494].[LineResults].[DenormalisedMegaView]
								inner join @DailyDates dd on CAST([DateTimeCompleted] AS DATE)  = dd.Date
								WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
										AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL) 
										AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
										AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
								GROUP BY CAST([DateTimeCompleted] AS DATE),[*Variant Name]
			)
			UPDATE hpc
			SET hpc.MonoCount = ho.MonoCount 
			FROM Mono_Count ho 
			inner join #DailyPartCount hpc on ho.[Timestamp] = hpc.[Timestamp]			

		---------------------------------------------------------------------------------------------------
		---STEP 3: GET THE TOTAL  PartsCount
		---------------------------------------------------------------------------------------------------
			UPDATE	[d]
			SET		[d].[Part Count] = [p].[PartsCount],
					[d].[Pass Count] = [p].[Pass Count] ,
					[d].[Fail Count] = [p].[Fail Count] ,
					[d].[Avg Cycle Time (s)] = [p].[Avg Cycle Time (s)],
					[d].[InProgress Count] = [p].[InProgress Count],
					[d].MonoCount = [p].MonoCount
			FROM	@DailyDates [d]	
			INNER JOIN #DailyPartCount [p] ON [d].[Date] = [p].[Timestamp]


			;WITH Forced_Part AS
			(
				SELECT   COUNT(DISTINCT PartFaceDMC) [Forced Part],
								 dpc.[Timestamp] AS [Timestamp]									
				FROM	[A1494].[LineResults].[DenormalisedMegaView]
				inner join #DailyPartCount dpc on  CAST(MonoMeasuringTimeStamp AS DATE) = dpc.[Timestamp]		
				where FinalResult  = 'FAIL'
				and [DateTimeCompleted] is null
				GROUP BY  dpc.[Timestamp]
				)
			UPDATE dpc
			SET [Forced Part] = fp.[Forced Part] 
			FROM Forced_Part fp
			inner join #DailyPartCount dpc on  fp.Timestamp = dpc.[Timestamp] 

		---------------------------------------------------------------------------------------------------
		---STEP 4: FINAL OUTPUT FOR METABASE REPORT
		---------------------------------------------------------------------------------------------------
			
		IF EXISTS (SELECT TOP 1 1 FROM #DailyPartCount)
		SELECT	[Timestamp]	 AS [This Day],
				SUBSTRING(CAST(DATENAME(dw, [Timestamp]) AS VARCHAR(3)), 1, 3) + ' ' + CAST(DAY([Timestamp]) AS VARCHAR(2)) + ', ' + CAST(YEAR([Timestamp]) AS VARCHAR(4)) AS [Date],
				ISNULL([PartsCount], 0) [Part Count],
				--ISNULL([Pass Count], 0) [Pass Count],
				--ISNULL([Fail Count], 0) [Fail Count],
				ISNULL([Avg Cycle Time (s)], 0) [Avg Cycle Time (s)]
				--ISNULL([InProgress Count], 0) [InProgress Count],
				--ISNULL([Forced Part], 0) [Forced Part],
				--ISNULL(MonoCount, 0) MonoCount
		FROM	#DailyPartCount
		ELSE
		SELECT	COALESCE(@DateFrom, @DateTo)[FulDate],
				0 [Part Count] ,
				--0 [Pass Count],
				--0 [Fail Count],					
				0 [Avg Cycle Time (s)]
				--0 [InProgress Count],
				--0 [Forced Part],
				--0 MonoCount
		END
---------------------------------------------------------------------------------------------------	
---GET THE LAST 13 WEEKS DATA
---------------------------------------------------------------------------------------------------
  
	ELSE IF((@SelectPeriod) = 'WEEKLY')
	BEGIN			
		---------------------------------------------------------------------------------------------------	
		---WEEKLY DATA
		---STEP 1: CREATE TEMP TABLE @WeeklyDates AND @WeeklyPartCount
		---------------------------------------------------------------------------------------------------
			DECLARE	@WeeklyDates TABLE (
					[Date]				VARCHAR(50),
					[StartDate]			DATE,
					[EndDate]			DATE,
					[Part Count]		INT,
					[Pass Count]		INT NULL,
					[Fail Count]		INT NULL,
					[Avg Cycle Time (s)] FLOAT,	
					[InProgress Count]	INT ,
					[Forced Part] INT ,
					[MonoCount] INT
					)

			CREATE TABLE #WeeklyPartCount (
					[PartsCount]		INT NULL,
					[Timestamp]			DATE NULL,
					[Pass Count]		INT NULL,
					[Fail Count]		INT NULL,
					[Avg Cycle Time (s)] FLOAT,	
					[InProgress Count]	INT ,
					[Forced Part] INT,
					[MonoCount] INT					
					)

			INSERT	INTO @WeeklyDates ([StartDate], [EndDate])
			SELECT	DATEADD(DAY,-(DATEPART(DW,DATEADD(WEEK, x.number, @StartDate))-2),
					DATEADD(WEEK, x.number, @StartDate)) AS [StartDate],
					DATEADD(DAY,-(DATEPART(DW,DATEADD(WEEK, x.number + 1, @StartDate))-1),
					DATEADD(WEEK, x.number + 1, @StartDate)) AS [EndDate]
			FROM MASTER.dbo.spt_values x
			WHERE [x].TYPE = 'P' 
				AND [x].number <= DATEDIFF(WEEK, @StartDate, DATEADD(WEEK,0,CAST(@EndDate AS DATE)))

			UPDATE	@WeeklyDates
			SET [Date] = CAST([StartDate] AS VARCHAR(10)) + ' To ' + CAST([EndDate] AS VARCHAR(10))

			
		;WITH [CTE]	AS (						
					SELECT DISTINCT 
					PartFaceDMC,					
					[*Variant Name] AS [Variant],									
					CAST ([DateTimeCompleted] as DATE) AS [Timestamp],
					[Cycle Time (s)] As [Cycle Time (s)],
					[FinalResult] AS [Part Result],							
					CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [OK], 
					CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END AS [NOK], 
					CASE	WHEN [DateTimeCompleted] IS NULL AND [FinalResult] IS NULL AND [Shift] IS NOT NULL AND [DateTimeCompleted] IS NOT NULL THEN 1 END AS [In Progress]

			FROM	[A1494].[LineResults].[DenormalisedMegaView]
			WHERE	PartFaceDMC IS NOT NULL
					AND (CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
					AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL) 
					AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
					AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
							)
		INSERT INTO #WeeklyPartCount ([PartsCount],[Timestamp],[Pass Count],[Fail Count],[Avg Cycle Time (s)],[InProgress Count],  [MonoCount])
		SELECT	COUNT([PartFaceDMC]) [PartsCount], [Timestamp], SUM([OK]), SUM([NOK]), AVG(c.[Cycle Time (s)]),	sum([InProgress Count]), SUM([MonoCount]) 
		FROM	[CTE] [c] 
		CROSS APPLY (
							SELECT AVG([Cycle Time (s)]) AS [Total Avg Cycle Time (s)]
							FROM [CTE] c
							WHERE	[Variant] = CASE	WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
			)TotAvg	
		RIGHT JOIN @WeeklyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate]
		GROUP	BY [Timestamp]
		
		;WITH Mono_Count	AS 
		(					
			SELECT	COUNT(MonoFaceDMC) [MonoCount], c.[Timestamp]
			FROM	(
						SELECT  Distinct MonoFaceDMC,
									CAST ([DateTimeCompleted] as DATE) AS [Timestamp],
									[*Variant Name] AS [Variant]
							FROM	[A1494].[LineResults].[DenormalisedMegaView]
							WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
									AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL) 
									AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
									AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
						) c		
			RIGHT JOIN @WeeklyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
			WHERE	[Variant] = CASE WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
			GROUP	BY [Timestamp]
		)

		UPDATE mpc
		SET mpc.MonoCount = mo.MonoCount 
		FROM Mono_Count mo 
		inner join #WeeklyPartCount mpc on mpc.Timestamp = mo.Timestamp 

			UPDATE	[d]  
			SET		[d].[Part Count] = [p].[PartsCount],
					[d].[Pass Count] = [p].[Pass Count],
					[d].[Fail Count] = [p].[Fail Count],
					[d].[Avg Cycle Time (s)] = [p].[Avg Cycle Time (s)],
					[d].[InProgress Count] = [p].[InProgress Count],
					[d].[MonoCount] = [p].[MonoCount]
				
			FROM	@WeeklyDates [d] INNER JOIN (
						SELECT	[Date], SUM([p].[PartsCount]) [PartsCount],SUM([p].[Pass Count])[Pass Count] , SUM([p].[Fail Count]) [Fail Count] , AVG([p].[Avg Cycle Time (s)]) [Avg Cycle Time (s)],SUM([p].[InProgress Count]) AS [InProgress Count],
						SUM([p].MonoCount) [MonoCount]
						FROM	@WeeklyDates [d] INNER JOIN #WeeklyPartCount [p] ON [p].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
						GROUP	BY [Date]	)		
					[p] ON [p].date = [d].Date 
			

			;WITH Forced_Part AS
			(
				SELECT   COUNT(DISTINCT PartFaceDMC) [Forced Part],
								 CAST(MonoMeasuringTimeStamp AS DATE) AS [Timestamp]									
				FROM	[A1494].[LineResults].[DenormalisedMegaView]
				inner join #WeeklyPartCount wpc on  CAST(MonoMeasuringTimeStamp AS DATE) = wpc.[Timestamp]		
				WHERE FinalResult  = 'FAIL'
				and [DateTimeCompleted] is null
				GROUP BY  CAST(MonoMeasuringTimeStamp AS DATE)
			)
			UPDATE wpc
			SET [Forced Part] = fp.[Forced Part] 
			FROM Forced_Part fp
			inner join @WeeklyDates wpc on  fp.Timestamp between wpc.StartDate and wpc.EndDate 
		

			DECLARE @PartsCount TABLE (
				[Date]				VARCHAR(50),
				[This Week Position]				INT,
				[Part Count]		INT,
				[Pass Count]		INT,
				[Fail Count]		INT,
				[Avg Cycle Time (s)] FLOAT,
				[InProgress Count]	INT ,
				[Forced Part]		INT,
				[MonoCount]			 INT

			)
			INSERT INTO @PartsCount
			SELECT	'Week ' + CAST(DATEPART(wk,[StartDate]) AS VARCHAR(5)) AS [Date],
					DATEPART(wk,[StartDate]) AS [This Week Position],
					[Part Count],
					[Pass Count],
					[Fail Count],
					[Avg Cycle Time (s)],	
					[InProgress Count],
					[Forced Part],
					[MonoCount]	
			FROM	@WeeklyDates
			WHERE	DATEPART(wk,[StartDate]) = CASE	WHEN @Week IS NULL THEN DATEPART(wk,[StartDate])  ELSE @Week END 

			IF EXISTS (SELECT TOP 1 1 FROM @PartsCount)
			SELECT  [Date],
					[This Week Position],
					ISNULL([Part Count], 0) [Part Count],
					--ISNULL([Pass Count], 0) [Pass Count],
					--ISNULL([Fail Count], 0) [Fail Count],
					ISNULL([Avg Cycle Time (s)], 0) [Avg Cycle Time (s)]	
					--ISNULL([Forced Part], 0) [Forced Part],
					--ISNULL([InProgress Count], 0) [InProgress Count],
				--ISNULL(MonoCount, 0) [MonoCount]
			FROM @PartsCount
			ELSE
			SELECT 'Week ' + CAST(DATEPART(wk,COALESCE(@DateFrom, @DateTo, GETDATE())) AS VARCHAR(5)) AS [Date],
					DATEPART(wk,COALESCE(@DateFrom, @DateTo, GETDATE())) AS [This Week Position],
					0 [Part Count],
					--0 [Pass Count],
					--0 [Fail Count],
					0 [Avg Cycle Time (s)]
					--0 [InProgress Count],
					--0 [Forced Part],
					--0 [MonoCount]
		END
		
---------------------------------------------------------------------------------------------------	
---GET THE LAST 13 MONTHS DATA
---------------------------------------------------------------------------------------------------
	ELSE IF((@SelectPeriod) = 'MONTHLY')
	BEGIN 	
		---------------------------------------------------------------------------------------------------	
		---MONTHLY DATA
		---STEP 1: CREATE TEMP TABLE @MonthlyDates AND @WeeklyPartCount
		---------------------------------------------------------------------------------------------------
		DECLARE @MonthlyDates TABLE  (
			[Date]				VARCHAR(50),
			[StartDate]			DATE,
			[EndDate]			DATE,
			[Part Count]		INT,
			[Pass Count]		INT NULL,
			[Fail Count]		INT NULL,
			[Avg Cycle Time (s)] FLOAT,	
			[InProgress Count]	INT ,
			[Forced Part]		INT ,
			[MonoCount]			INT
			)

		DECLARE @MonthlyPartCount TABLE(
			[PartsCount]		INT NULL,
			[Timestamp]			DATE NULL,
			[Pass Count]		INT NULL,
			[Fail Count]		INT NULL,
			[Avg Cycle Time (s)] FLOAT,	
			[InProgress Count]	INT ,
			[Forced Part]		 INT,
			[MonoCount]			 INT
			)

		;WITH	[CTE] AS (
				SELECT	@startdate AS [cte_start_date]
				UNION	ALL
				SELECT	DATEADD(MONTH, 1, [cte_start_date])
				FROM	CTE
				WHERE	DATEADD(MONTH, 1, cte_start_date) <= @enddate)
		INSERT	INTO @MonthlyDates ([Date],[StartDate], [EndDate])
		SELECT	CAST(DATENAME(MONTH, [cte_start_date]) AS VARCHAR(10)) + ', ' + CAST(YEAR([cte_start_date]) AS VARCHAR(10)), 
				CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, [cte_start_date]), 0) AS DATE) AS [StartDate],
				EOMONTH ([cte_start_date]) [EndDate]
		FROM	[CTE]	


		;WITH [CTE]	AS 
		(
			SELECT  DISTINCT
					PartFaceDMC,					
					[*Variant Name] AS [Variant],									
					CAST ([DateTimeCompleted] as DATE) AS [Timestamp],
					[Cycle Time (s)] As [Cycle Time (s)],
					[FinalResult] AS [Part Result],							
					CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [OK], 
					CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END AS [NOK], 
					CASE	WHEN [FinalResult] = 'FAIL'  AND [Shift] IS NOT NULL AND [DateTimeCompleted] IS NOT NULL THEN 1 END AS [In Progress]

			FROM	[A1494].[LineResults].[DenormalisedMegaView]
			WHERE	PartFaceDMC IS NOT NULL
					AND (CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
					AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL) 
					AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
					AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
					)
		INSERT	INTO @MonthlyPartCount([PartsCount],[Timestamp],[Pass Count],[Fail Count], [Avg Cycle Time (s)],	[InProgress Count])
		SELECT	COUNT([PartFaceDMC]) [PartsCount], [Timestamp], SUM([OK]), SUM([NOK]), AVG(c.[Cycle Time (s)]), sum([InProgress Count])
		FROM	[CTE] [c] 
		CROSS APPLY (
							SELECT AVG([Cycle Time (s)]) AS [Total Avg Cycle Time (s)]
							FROM [CTE] c
							WHERE	[Variant] = CASE	WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
			)TotAvg	
		RIGHT JOIN @MonthlyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
		WHERE	[Variant] = CASE WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
		GROUP	BY [Timestamp]
		

		;WITH Mono_Count	AS 
		(					
			SELECT	COUNT(MonoFaceDMC) [MonoCount], c.[Timestamp]
			FROM	(
						SELECT  Distinct MonoFaceDMC,
									CAST ([DateTimeCompleted] as DATE) AS [Timestamp],
									[*Variant Name] AS [Variant]
							FROM	[A1494].[LineResults].[DenormalisedMegaView]
							WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
									AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL) 
									AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
									AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
						) c		
			RIGHT JOIN @MonthlyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
			WHERE	[Variant] = CASE WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
			GROUP	BY [Timestamp]
		)
		UPDATE mpc
		SET mpc.MonoCount = mo.MonoCount 
		FROM Mono_Count mo 
		inner join @MonthlyPartCount mpc on mpc.Timestamp = mo.Timestamp 


		UPDATE	[d] 
		SET		[d].[Part Count] = [p].[PartsCount],
				--[d].[Pass Count] = [p].[Pass Count] ,
				--[d].[Fail Count] = [p].[Fail Count] ,
				[d].[Avg Cycle Time (s)] = [p].[Avg Cycle Time (s)]
				--[d].[InProgress Count] = [p].[InProgress Count],
				--[d].[MonoCount] = [p].[MonoCount]
		FROM	@MonthlyDates [d] 
		INNER JOIN (
					SELECT	[Date], SUM([p].[PartsCount]) [PartsCount],SUM([p].[Pass Count])[Pass Count] , SUM([p].[Fail Count]) [Fail Count], AVG([p].[Avg Cycle Time (s)]) [Avg Cycle Time (s)],	sum([p].[InProgress Count]) [InProgress Count],  SUM([p].MonoCount) [MonoCount]
					FROM	@MonthlyDates [d] INNER JOIN @MonthlyPartCount [p] ON [p].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate]
					GROUP	BY [Date]) 
				[p] ON [p].date = [d].Date


		;WITH Forced_Part AS
			(
				SELECT  COUNT(DISTINCT PartFaceDMC) [Forced Part],
								 mpc.[Date] AS [Timestamp]									
				FROM	[A1494].[LineResults].[DenormalisedMegaView]
				inner join @MonthlyDates mpc on  CAST(MonoMeasuringTimeStamp AS DATE) BETWEEN mpc.[StartDate] AND mpc.[EndDate]
				WHERE FinalResult  = 'FAIL'
				and [DateTimeCompleted] is null
				GROUP BY   mpc.[Date]
			)
		UPDATE mpc
		SET [Forced Part] = fp.[Forced Part] 
		FROM Forced_Part fp
		inner join @MonthlyDates mpc on  fp.Timestamp  = mpc.Date 


		SELECT	[Date], 
				MONTH(CAST([StartDate] AS DATE)) AS [This Month Position],
				--DATENAME(MONTH,CAST([StartDate] AS DATE)) AS [Month],
				--YEAR(CAST([StartDate] AS DATE)) AS [Year],
				--DATENAME(m,[Date])+' '+CAST(DATEPART(yyyy,[Date]) AS varchar) AS [MonthYear],
				ISNULL([Part Count], 0) [Part Count],
				--ISNULL([Pass Count], 0) [Pass Count],
				--ISNULL([Fail Count], 0) [Fail Count],
				ISNULL([Avg Cycle Time (s)], 0) [Avg Cycle Time (s)]	
				--ISNULL([Forced Part], 0) [Forced Part],
				--ISNULL([InProgress Count], 0) [InProgress Count],
				--ISNULL(MonoCount, 0) [MonoCount]
		FROM	@MonthlyDates
		WHERE	MONTH(CAST([Date] AS DATE)) = CASE	WHEN @Month IS NULL THEN MONTH(CAST([Date] AS DATE)) ELSE @Month END 
	END

END
GO