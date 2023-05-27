SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE  [Production].[CauseOfFailure_Per_Variant] 
		@Period			VARCHAR(50) = NULL,
		@ThisDay		DATE = NULL,
		@Week			VARCHAR(20) = NULL,
		@Month			VARCHAR(2) = NULL,
		@DateFrom		DATE = NULL,
		@DateTo			DATE = NULL,
		@Index			VARCHAR(1) =NULL,
		@VariantID		VARCHAR(500) = NULL,		
		@ShiftNumber	INT = NULL		
AS
BEGIN
	SET NOCOUNT ON
---------------------------------------------------------------------------------------------------	
---DECLARATION FOR START DATE AND END DATE
---------------------------------------------------------------------------------------------------
	DECLARE @StartDate	DATE,
			@EndDate	DATE 
---------------------------------------------------------------------------------------------------	
--- Adjust start and end date
---------------------------------------------------------------------------------------------------
	IF @ThisDay = '1999-01-01'
		SET @ThisDay = NULL
	IF @DateFrom ='1999-01-01' 
		SET @DateFrom = NULL 
	IF @DateTo ='2050-12-31'
		SET @DateTo  = NULL 
	IF (@Period) IS NULL
		SET @Period = 'DAILY'

	IF(@DateFrom IS NULL AND @DateTo is NULL)
	BEGIN	
		SELECT	TOP 1 @EndDate = MAX([DateTimeCompleted])  
		FROM	[A1494].[LineResults].[DenormalisedMegaView]    --GET THE LAST AVAILABLE [MonoMeasuringTimeStamp] TO BE USED FOR END DATE
	
		IF((@Period) = 'HOURLY')	
			SET	@StartDate = @EndDate
		ELSE IF((@Period) = 'DAILY')	
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
		ELSE IF((@Period) = 'WEEKLY')	
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
		ELSE IF((@Period) = 'MONTHLY')
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE		
	END
	ELSE IF((@Period) IS NOT NULL AND @DateFrom IS NOT NULL AND @DateTo is NOT NULL)
	BEGIN
		SET	@EndDate = @DateTo  
		IF (ISNULL((@Period), 'DAILY') = 'DAILY')
		BEGIN
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom
		END
		ELSE IF((@Period) = 'WEEKLY')	
		BEGIN
			SET	@EndDate = @DateTo
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE

			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom							
		END
		ELSE IF((@Period) = 'MONTHLY')
		BEGIN
			SET	@EndDate = @DateTo
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE

			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom
		END
	
	END
---------------------------------------------------------------------------------------------------	
--- 0 IS THE DEFAULT VALUE THAT GETS ALL THE VARIANTS PRESENT IN THE TIMEFRAME
---------------------------------------------------------------------------------------------------
	IF @Index = '0'
		SET @Index = NULL
	ELSE IF @Index = '1'
		SET  @Index = 'A'
	ELSE IF @Index = '2'
		SET  @Index = 'B'

	IF ISNULL(@VariantID,0) = 0
		SET @VariantID = NULL
	IF ISNULL(@ShiftNumber,0) = 0
		SET @ShiftNumber = NULL
	IF @Week = '0'
			SET @Week = NULL
	IF @Month = '0'
		SET @Month = NULL
---------------------------------------------------------------------------------------------------	
---GET THE LAST 8 DAYS Data
---------------------------------------------------------------------------------------------------	
	IF ((@Period) = 'HOURLY')
	BEGIN
		DECLARE @HDateFrom DATETIME = convert(varchar,@StartDate,101) 
		DECLARE @HDateTo DATETIME = @HDateFrom +' 23:59:59'

		DECLARE	@HourlyData TABLE (
			[ID] INT IDENTITY(1,1),
			[StartTime] DATETIME,
		    [EndTime] DATETIME)

		INSERT INTO @HourlyData ([StartTime],[EndTime])
		SELECT	 StartTime = D
				,StopTime  = DateAdd(HOUR,1,D)
		FROM (
				SELECT top  (DateDiff(HOUR,@HDateFrom,@HDateTo)+1) 
						D=DateAdd(HOUR,-1+Row_Number() OVER (ORDER BY (SELECT NULL)),@HDateFrom) 
				FROM  master..spt_values n1
			 ) D
		
		DECLARE @HourlyCOFCount TABLE(
					[Cause Of Failure] VARCHAR(1000),
					[Fail Count] INT,
					[Date] DATETIME,
					[Variant Name]  VARCHAR(1000)
				)

				;WITH PartsCount AS (
					SELECT	DISTINCT
							[PartFaceDMC],
							[DateTimeCompleted]   AS [Date],
							
							[*Variant Name]  AS [Variant Name],
							CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail],
							CASE	WHEN [FinalResult] = 'FAIL' THEN 
									CASE	WHEN ISNULL([Mono MM Result],'FAIL') = 'FAIL' THEN 'Mono Measurement Related'
											WHEN ISNULL([Total Pressing Result],'FAIL') = 'FAIL' THEN 'Pressing Related'
											WHEN ISNULL([Total GBD MM Result],'FAIL') = 'FAIL' THEN  'GBD Related'
											WHEN ISNULL([Marking Result],'FAIL') = 'FAIL' THEN 'Marking Related'
											WHEN [FinalResult] = 'FAIL' AND [DateTimeCompleted] IS NULL THEN  'Forced Part'	END 
												END AS  [Cause Of Failure]
					FROM    [A1494].[LineResults].[DenormalisedMegaView]
					UNION ALL
					SELECT   DISTINCT
							[PartFaceDMC],
							CAST(MonoMeasuringTimeStamp AS DATE)   AS [Date],
							[*Variant Name]  AS [Variant Name],
							CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail],
							'Forced Part' AS  [Cause Of Failure]									
					FROM	[A1494].[LineResults].[DenormalisedMegaView]
					INNER JOIN @HourlyData hpc on  CAST(MonoMeasuringTimeStamp AS DATE) = hpc.[StartTime]		
					where FinalResult  = 'FAIL'
					AND [DateTimeCompleted] IS NULL				
					)
				INSERT	INTO @HourlyCOFCount
				SELECT	
						[Cause Of Failure],
						SUM([Fail]) AS [Fail Count],
						[Date],
						[Variant Name]
				FROM	PartsCount pc
				INNER JOIN @HourlyData hd ON pc.[Date] BETWEEN hd.StartTime AND hd.EndTime 
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
						AND  (CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL)
						AND [Fail] = 1
				GROUP	BY [Date], [Cause Of Failure],[Variant Name]
				ORDER	BY [Date]

				IF EXISTS (SELECT TOP 1 1 from @HourlyCOFCount)
				SELECT [Date], [Fail Count], [Cause Of Failure], [Variant Name] FROM @HourlyCOFCount
				ELSE
				SELECT	COALESCE(@StartDate, @EndDate, @ThisDay, GETDATE())[Date],
						0 [Fail Count],
						'Cause Of Failure' [Cause Of Failure],
						'Variant Name' [Variant Name]

	END
	ELSE IF ((@Period) = 'DAILY')
	BEGIN
---------------------------------------------------------------------------------------------------
---DAILY DATA
---STEP 1: CREATE TEMP TABLE @DailyDates AND @DailyPartCount
---------------------------------------------------------------------------------------------------
			DECLARE @DailyCOFCount TABLE(
					--PartsCount INT,
					[Cause Of Failure]	VARCHAR(1000),
					[Fail Count]		INT,
					[Date]				DATE,
					[Variant Name]		VARCHAR(1000)
				)
				;WITH PartsCount AS (
					SELECT	DISTINCT
							[PartFaceDMC],
							CAST([DateTimeCompleted] AS DATE)  AS [Date],
							
							[*Variant Name]  AS [Variant Name],
							CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail],
							CASE	WHEN [FinalResult] = 'FAIL' THEN 
									CASE	WHEN ISNULL([Mono MM Result],'FAIL') = 'FAIL' THEN 'Mono Measurement Related'
											WHEN ISNULL([Total Pressing Result],'FAIL') = 'FAIL' THEN 'Pressing Related'
											WHEN ISNULL([Total GBD MM Result],'FAIL') = 'FAIL' THEN  'GBD Related'
											--WHEN ISNULL([Mat Position Result],'FAIL') = 'FAIL' THEN  'Mat Position Related'
											WHEN ISNULL([Marking Result],'FAIL') = 'FAIL' THEN 'Marking Related'
											WHEN ([Mono MM Result] = 'PASS' AND [Total Pressing Result] = 'PASS' AND [Total GBD MM Result] = 'PASS' AND [Marking Result] = 'PASS' AND [FinalResult] = 'FAIL') THEN 'Scan DMC Error'
											ELSE 'Forced Part'	END 
													END AS  [Cause Of Failure]
					FROM    [A1494].[LineResults].[DenormalisedMegaView]
					UNION ALL
					SELECT   DISTINCT
							[PartFaceDMC],
							CAST(MonoMeasuringTimeStamp AS DATE)   AS [Date],
							[*Variant Name]  AS [Variant Name],
							CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail],
							'Forced Part' AS  [Cause Of Failure]									
					FROM	[A1494].[LineResults].[DenormalisedMegaView]						
					where FinalResult  = 'FAIL'
					AND [DateTimeCompleted] IS NULL	
								)
				INSERT	INTO @DailyCOFCount
				SELECT	
						[Cause Of Failure],
						SUM([Fail]) AS [Fail Count],
						[Date],
						[Variant Name]
				FROM	PartsCount
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
						AND  (CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL)
						AND [Fail] = 1
				GROUP	BY [Date], [Cause Of Failure],[Variant Name]
				ORDER	BY [Date]

				IF EXISTS (SELECT TOP 1 1 from @DailyCOFCount)
				SELECT [Date], [Fail Count], [Cause Of Failure], [Variant Name] FROM @DailyCOFCount
				ELSE
				SELECT	COALESCE(@StartDate, @EndDate, @ThisDay, GETDATE())[Date],
						0 [Fail Count],
						'Cause Of Failure' [Cause Of Failure],
						'Variant Name' [Variant Name]
	END
---------------------------------------------------------------------------------------------------	
---GET THE LAST 13 WEEKS DATA
---------------------------------------------------------------------------------------------------
  	ELSE IF((@Period) = 'WEEKLY')
	BEGIN			
---------------------------------------------------------------------------------------------------	
--WEEKLY DATA
--STEP 1: CREATE TEMP TABLE @WeeklyDates AND @WeeklyPartCount
---------------------------------------------------------------------------------------------------
		DECLARE	@WeeklyDates TABLE (
				[Date]				VARCHAR(50),
				[StartDate]			DATE,
				[EndDate]			DATE,				
				[Fail Count]		INT NULL,
				[Cause Of Failure]	VARCHAR(1000),
				[Variant Name]		VARCHAR(1000))
		DECLARE @WeeklyPartCount TABLE(				
				[Timestamp]			DATE NULL,				
				[Fail Count]		INT NULL,
				[Cause Of Failure]	VARCHAR(1000),
				[Variant Name]		VARCHAR(1000))

---------------------------------------------------------------------------------------------------
--STEP 2: INSERT DATA INTO @WeeklyDates and @WeeklyPartCount
---------------------------------------------------------------------------------------------------
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
			SELECT	DISTINCT
			[PartFaceDMC],	
			CAST([DateTimeCompleted] AS DATE) AS [Timestamp],
					[*Variant Name]  AS [Variant Name],				
					CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail],	
					CASE	WHEN [FinalResult] = 'FAIL' THEN 
							CASE	WHEN ISNULL([Mono MM Result],'FAIL') = 'FAIL' THEN 'Mono Measurement Related'
									WHEN ISNULL([Total Pressing Result],'FAIL') = 'FAIL' THEN 'Pressing Related'
									WHEN ISNULL([Total GBD MM Result],'FAIL') = 'FAIL' THEN  'GBD Related'
									WHEN ISNULL([Marking Result],'FAIL') = 'FAIL' THEN 'Marking Related'
									WHEN ([Mono MM Result] = 'PASS' AND [Total Pressing Result] = 'PASS' AND [Total GBD MM Result] = 'PASS' AND [Marking Result] = 'PASS' AND [FinalResult] = 'FAIL') THEN 'Scan DMC Error'
									ELSE 'Forced Part'	END 
											END AS  [Cause Of Failure]
			FROM    [A1494].[LineResults].[DenormalisedMegaView] 
			WHERE	[PartFaceDMC] IS NOT NULL AND
							(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) AND
							(CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
			UNION ALL
					SELECT   DISTINCT
							[PartFaceDMC],
							CAST(MonoMeasuringTimeStamp AS DATE)   AS [Date],							
							[*Variant Name]  AS [Variant Name],
							CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail],
							'Forced Part' AS  [Cause Of Failure]									
					FROM	[A1494].[LineResults].[DenormalisedMegaView]						
					where FinalResult  = 'FAIL'
					AND [DateTimeCompleted] IS NULL	)
		INSERT INTO @WeeklyPartCount ([Timestamp],[Fail Count],[Cause Of Failure],[Variant Name])
		SELECT	 [Timestamp],  SUM([Fail]), c.[Cause Of Failure],c.[Variant Name]
		FROM	[CTE] [c] RIGHT JOIN @WeeklyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate]
		GROUP	BY [Timestamp],c.[Cause Of Failure],c.[Variant Name]
---------------------------------------------------------------------------------------------------
--STEP 3: GET THE TOTAL PartsCount
---------------------------------------------------------------------------------------------------
		INSERT INTO @WeeklyDates
		SELECT 	d.[Date],
				d.[StartDate],
				d.[EndDate],			
				p.[Fail Count],
				p.[Cause Of Failure],
				p.[Variant Name]
		FROM	@WeeklyDates [d] INNER JOIN (
					SELECT	[Date],  SUM([p].[Fail Count]) [Fail Count], p.[Cause Of Failure],p.[Variant Name]
					FROM	@WeeklyDates [d] INNER JOIN @WeeklyPartCount [p] ON [p].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
					GROUP	BY [Date],p.[Cause Of Failure],p.[Variant Name])				
				[p] on [p].[Date] = [d].[Date] 

---------------------------------------------------------------------------------------------------
--STEP 4: FINAL OUTPUT FOR METABASE REPORT
---------------------------------------------------------------------------------------------------
		DECLARE @WeeklyCOFCount TABLE(
			--[Date] VARCHAR](100) NULL,
			[Week]				INT NULL,
			--[Month_Position] INT NULL,
			--[Month] NVARCHAR(100) NULL,
			--[Year] INT NULL,
			[MonthYear]			VARCHAR(100) NULL,			
			[Fail Count]		INT NULL,
			[Cause Of Failure]	VARCHAR(1000) NULL,
			[Variant Name]		VARCHAR(1000) NULL
		)

		INSERT INTO @WeeklyCOFCount
		SELECT	--'Week ' + CAST(DATEPART(wk,[StartDate]) AS VARCHAR(5)) AS [Date],
				DATEPART(wk,[StartDate]) AS [Week],
				--MONTH(CAST([StartDate] AS DATE)) AS [Month_Position],
				--DATENAME(MONTH,CAST([StartDate] AS DATE)) AS [Month],
				--YEAR(CAST([StartDate] AS DATE))AS [Year],
				CAST(DATENAME(MONTH,CAST([StartDate] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([StartDate] AS DATE)) AS VARCHAR(10)) AS [MonthYear],					
				[Fail Count],
				[Cause Of Failure],
				[Variant Name]
		FROM	@WeeklyDates	
		WHERE	[Cause Of Failure] IS NOT NULL
		AND DATEPART(wk,[StartDate]) = CASE	WHEN @Week IS NULL THEN DATEPART(wk,[StartDate])  ELSE @Week END 
		ORDER BY WEEK

		IF EXISTS (SELECT TOP 1 1 FROM @WeeklyCOFCount)
		SELECT * FROM @WeeklyCOFCount
		ELSE
		SELECT 'Week ' + CAST(DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE())) AS VARCHAR(5)) AS [Date],
				DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE()))AS [Week],
				MONTH(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month_Position],
				DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month],
				YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE))AS [Year],
				CAST(DATENAME(month,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
				0 [Fail Count],
				'Cause Of Failure' [Cause Of Failure],
				'Variant Name' [Variant Name]
		END

---------------------------------------------------------------------------------------------------	
---GET THE LAST 13 MONTHS DATA
---------------------------------------------------------------------------------------------------
	ELSE IF((@Period) = 'MONTHLY')
	BEGIN 	
---------------------------------------------------------------------------------------------------	
--MONTHLY DATA
--STEP 1: CREATE TEMP TABLE @MonthlyDates AND @WeeklyPartCount
---------------------------------------------------------------------------------------------------
			
		DECLARE @MonthlyDates TABLE  (
		[ID]				INT IDENTITY(1,1),
		[Date]				VARCHAR(50),
		[StartDate]			DATE,
		[EndDate]			DATE,
		[Part Count]		INT,
		--[Pass Count] INT NULL,
		[Fail Count]		INT NULL,
		[Cause Of Failure]	VARCHAR(1000),
		[Variant Name]		VARCHAR(1000))

	DECLARE @MonthlyCOFCount TABLE(
		[PartsCount]		INT NULL,
		[Timestamp]			DATE NULL,
		--[Pass Count] INT NULL,
		[Fail Count]		INT NULL,
		[Cause Of Failure]	VARCHAR(1000),
		[Variant Name]		VARCHAR(1000))

		;WITH	[CTE] AS (
			SELECT	@StartDate AS [cte_start_date]
			UNION	ALL
			SELECT	DATEADD(MONTH, 1, [cte_start_date])
			FROM	CTE
			WHERE	DATEADD(MONTH, 1, cte_start_date) <= @enddate)
	INSERT	INTO @MonthlyDates ([Date],[StartDate], [EndDate])
	SELECT	CAST(DATENAME(MONTH, [cte_start_date]) AS VARCHAR(10)) + ',' + CAST(YEAR([cte_start_date]) AS VARCHAR(10)), 
			CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, [cte_start_date]), 0) AS DATE) AS [StartDate],
			EOMONTH ([cte_start_date]) [EndDate]
	FROM	[CTE]	

	;WITH [CTE]	AS (
			SELECT DISTINCT
			[PartFaceDMC],
			CAST([DateTimeCompleted] AS DATE)  AS [Timestamp], 
			[*Variant Name]  AS [Variant Name],
			CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail],
					CASE	WHEN [FinalResult] = 'FAIL' THEN 
					CASE	WHEN ISNULL([Mono MM Result],'FAIL') = 'FAIL' THEN 'Mono Measurement Related'
							WHEN ISNULL([Total Pressing Result],'FAIL') = 'FAIL' THEN 'Pressing Related'
							WHEN ISNULL([Total GBD MM Result],'FAIL') = 'FAIL' THEN  'GBD Related'
							WHEN ISNULL([Marking Result],'FAIL') = 'FAIL' THEN 'Marking Related'
							WHEN ([Mono MM Result] = 'PASS' AND [Total Pressing Result] = 'PASS' AND [Total GBD MM Result] = 'PASS' AND [Marking Result] = 'PASS' AND [FinalResult] = 'FAIL') THEN 'Scan DMC Error'
							ELSE 'Forced Part'	END 
								END AS  [Cause Of Failure]				
			FROM    [A1494].[LineResults].[DenormalisedMegaView] 
			WHERE	[PartFaceDMC] IS NOT NULL AND
							(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) AND
							(CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
			UNION ALL
			SELECT   DISTINCT
					[PartFaceDMC],
					CAST(MonoMeasuringTimeStamp AS DATE)   AS [Date],							
					[*Variant Name]  AS [Variant Name],
					CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail],
					'Forced Part' AS  [Cause Of Failure]									
			FROM	[A1494].[LineResults].[DenormalisedMegaView]						
					WHERE FinalResult  = 'FAIL'
					AND [DateTimeCompleted] IS NULL			
					)
	INSERT	INTO @MonthlyCOFCount([PartsCount],[Timestamp],[Fail Count],[Cause Of Failure],[Variant Name])
	SELECT	COUNT([PartFaceDMC]) AS PartsCount, [Timestamp], SUM([Fail]),c.[Cause Of Failure],c.[Variant Name]
	FROM	[CTE] [c] RIGHT JOIN @MonthlyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
	GROUP	BY [Timestamp],c.[Cause Of Failure],c.[Variant Name]
----------------------------------------------------------------------------------------------------
---STEP 3: GET THE TOTAL PartsCount
-----------------------------------------------------------------------------------------------------	
	INSERT INTO   @MonthlyDates
	SELECT d.[Date], [StartDate],	[EndDate], p.[PartsCount], p.[Fail Count],p.[Cause Of Failure],p.[Variant Name]
	FROM	@MonthlyDates [d] INNER JOIN (
				SELECT	[Date], SUM([p].[PartsCount]) [PartsCount] , SUM([p].[Fail Count]) [Fail Count],p.[Cause Of Failure],p.[Variant Name]
				FROM	@MonthlyDates [d] INNER JOIN @MonthlyCOFCount [p] ON [p].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate]
				GROUP	BY [Date],p.[Cause Of Failure],p.[Variant Name]) 
						[p] ON [p].[Date] = [d].[Date]
---------------------------------------------------------------------------------------------------
---STEP 4: FINAL OUTPUT FOR METABASE REPORT
---------------------------------------------------------------------------------------------------
	DECLARE @MonthCOFCount TABLE(
			--[Date] [VARCHAR](100) NULL,
			[Week]				INT NULL,
			--[Month_Position] INT NULL,
			--[Month] NVARCHAR(100) NULL,
			--[Year] INT NULL,
			[MonthYear]			VARCHAR(100) NULL,
			--[Part Count] INT NULL,
			--[Pass Count] INT NULL,
			[Fail Count]		INT NULL,
			[Cause Of Failure]	VARCHAR(1000) NULL,
			[Variant Name]		VARCHAR(1000) NULL
		)
	INSERT INTO @MonthCOFCount
	SELECT	--[Date], 
			DATEPART(wk,[StartDate]) AS [Week],
			--MONTH(CAST([StartDate] AS DATE)) AS [Month_Position],
			--DATENAME(MONTH,CAST([StartDate] AS DATE)) AS [Month],
			--YEAR(CAST([StartDate] AS DATE)) AS [Year],
			DATENAME(m,[Date])+' '+CAST(DATEPART(yyyy,[Date]) AS VARCHAR) AS [MonthYear],
			--[Part Count],
			--[Pass Count],
			[Fail Count],
			[Cause Of Failure],
			[Variant Name]
	FROM	@MonthlyDates
	WHERE	[Cause Of Failure] IS NOT NULL
	AND ([Part Count] IS NOT NULL OR [Fail Count] IS NOT NULL )
	AND MONTH(CAST([Date] AS DATE)) = CASE	WHEN @Month IS NULL THEN MONTH(CAST([Date] AS DATE)) ELSE @Month END 
	ORDER BY WEEK
	IF EXISTS (SELECT TOP 1 1 from @MonthCOFCount)
		SELECT * FROM @MonthCOFCount
		ELSE
		SELECT 'Week ' + CAST(DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE())) AS VARCHAR(5)) AS [Date],
				DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE()))AS [Week],
				MONTH(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month_Position],
				DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month],
				YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE))AS [Year],
				CAST(DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST(COALESCE(@StartDate, @DateTo, GETDATE()) AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
				0 [Fail Count],
				'Cause Of Failure' [Cause Of Failure],
				'Variant Name' [Variant Name]
	END
END
GO