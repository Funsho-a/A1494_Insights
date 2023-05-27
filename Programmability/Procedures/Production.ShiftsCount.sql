SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE  [Production].[ShiftsCount] 
		@Period			VARCHAR(500) = NULL,
		@ThisDay		DATE = NULL,
		@DateFrom		DATE = NULL,
		@DateTo			DATE = NULL,
		@Week			VARCHAR(20) = NULL,
		@Month			VARCHAR(2) = NULL,
		@VariantID		VARCHAR(500) = NULL,		
		@ShiftNumber	VARCHAR(20) = NULL	
AS
BEGIN
	SET NOCOUNT ON
---------------------------------------------------------------------------------------------------	
---DECLARATION FOR START DATE AND END DATE
---------------------------------------------------------------------------------------------------
	DECLARE @StartDate	DATE,
			@EndDate	DATE 

---------------------------------------------------------------------------------------------------	
-- Adjust start and end date
---------------------------------------------------------------------------------------------------
	IF @ThisDay = '1900-01-01'
		SET @ThisDay =NULL
	IF @DateFrom ='1900-01-01' 
		SET @DateFrom = NULL 
	IF @DateTo ='2050-12-31'
		SET @DateTo  = NULL 
	IF (@Period) IS NULL
		SET @Period = 'DAILY'
---------------------------------------------------------------------------------------------------	
--GET THE LAST AVAILABLE [MonoMeasuringTimeStamp] TO BE USED FOR END DATE
---------------------------------------------------------------------------------------------------
	IF(@DateFrom IS NULL AND @DateTo IS NULL)
	BEGIN	
		SELECT @EndDate = MAX([A1494].[LineResults].[DenormalisedMegaView].[DateTimeCompleted])
		FROM	[A1494].[LineResults].[DenormalisedMegaView]
		WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
				AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)


---------------------------------------------------------------------------------------------------	
--GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
---------------------------------------------------------------------------------------------------	
		IF((@Period) = 'HOURLY')	
			SET	@StartDate = @EndDate
		ELSE IF((@Period) = 'DAILY')	
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) 
---------------------------------------------------------------------------------------------------	
--GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
---------------------------------------------------------------------------------------------------
		ELSE IF((@Period) = 'WEEKLY')	
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) 
---------------------------------------------------------------------------------------------------	
--GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE
---------------------------------------------------------------------------------------------------
		ELSE IF((@Period) = 'MONTHLY')
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) 		
	END
	ELSE IF((@Period) IS NOT NULL AND @DateFrom IS NOT NULL AND @DateTo is NOT NULL)
	BEGIN
		SET	@EndDate = @DateTo  
		IF (ISNULL((@Period), 'DAILY') = 'DAILY')
		BEGIN
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) 
			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom
		END
		ELSE IF((@Period) = 'WEEKLY')	
		BEGIN
			SET	@EndDate = @DateTo
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) 

			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom							
		END
		ELSE IF((@Period) = 'MONTHLY')
		BEGIN
			SET	@EndDate = @DateTo
			SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) 

			IF(@StartDate < @DateFrom)
				SET @StartDate = @DateFrom
		END
	
	END

---------------------------------------------------------------------------------------------------	
--- 0 IS THE DEFAULT VALUE THAT GETS ALL THE VARIANTS PRESENT IN THE TIMEFRAME
---------------------------------------------------------------------------------------------------

	IF ISNULL(@VariantID,'0') = '0'
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
		--DECLARE @HDateFrom DATETIME = convert(varchar,@StartDate,101) 
		--DECLARE @HDateTo DATETIME = @HDateFrom +' 23:59:59'

		--DECLARE	@HourlyData TABLE (
		--	[ID] INT IDENTITY(1,1),
		--	[StartTime] DATETIME,
		--    [EndTime] DATETIME)

		--INSERT INTO @HourlyData ([StartTime],[EndTime])
		--SELECT	 StartTime = D
		--		,StopTime  = DateAdd(HOUR,1,D)
		--FROM (
		--		SELECT top  (DateDiff(HOUR,@HDateFrom,@HDateTo)+1) 
		--				D=DateAdd(HOUR,-1+Row_Number() OVER (ORDER BY (SELECT NULL)),@HDateFrom) 
		--		FROM  master..spt_values n1
		--	 ) D
		DECLARE @HourlyShiftCount TABLE(
						[Part Count]	INT,
						[Pass]			INT,
						[Fail]			INT,
						[Shift]			VARCHAR(200),
						[Date]			DATETIME,
						Failure_Rate	FLOAT
					)
		;WITH PartsCount AS (
			SELECT  PartFaceDMC,								
					[Shift],+
					[Timestamp],
					[Pass],
					[Fail]
			FROM (
					SELECT	DISTINCT PartFaceDMC,												
							'Shift ' + CAST(ISNULL([Shift],000) AS VARCHAR(5)) AS [Shift],
							CAST([DateTimeCompleted] AS DATE) AS [Timestamp],
							CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
							CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END AS [Fail]
					FROM	[A1494].[LineResults].[DenormalisedMegaView]
					WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
							AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
							AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
						)t) 
		INSERT INTO @HourlyShiftCount
		SELECT	COUNT([PartFaceDMC]) AS [PartsCount],
				SUM([Pass]), 
				SUM([Fail]), 
				[Shift],
				[Timestamp],
				(CAST(SUM([Fail]) AS FLOAT) / CAST(COUNT([PartFaceDMC]) AS FLOAT))* 100 as Failure_Rate 
		FROM	[PartsCount] pc
		--INNER JOIN @HourlyData hd ON pc.[Timestamp] BETWEEN hd.StartTime AND hd.EndTime 
		WHERE	[Shift] =	CASE WHEN @ShiftNumber IS NULL THEN [Shift] ELSE @ShiftNumber END 				
		GROUP	BY [Shift], [Timestamp]

		IF EXISTS (SELECT TOP 1 1 FROM @HourlyShiftCount)
		SELECT CAST([Date] AS DATE) [Date], [Part Count], [Pass] [Pass Count], [Fail] [Fail Count],[Shift] , Failure_Rate
		FROM @HourlyShiftCount
		ELSE
		SELECT  0 [Part Count], 
		0 [Pass Count],
		0 [Fail Count],
				--0 [PartsPerShift],
		'Shift' [Shift],
		COALESCE(@StartDate, @EndDate, @ThisDay, GETDATE())[Date],
		0 Failure_Rate
	END
	ELSE IF (ISNULL((@Period), 'DAILY') = 'DAILY')
	BEGIN
---------------------------------------------------------------------------------------------------
--DAILY DATA
--STEP 1: CREATE TEMP TABLE @DailyDates AND @DailyPartCount
---------------------------------------------------------------------------------------------------
	DECLARE @DailyShiftCount TABLE(
					[Part Count]	INT,
					[Pass]			INT,
					[Fail]			INT,
					[Shift]			VARCHAR(200),
					[Date]			DATE,
					Failure_Rate	FLOAT
				)

	;WITH [PartsCount] AS 
	(
		SELECT	DISTINCT
				[PartFaceDMC],
				CAST([DateTimeCompleted] AS DATE) AS [Date],				
				'Shift ' + CAST(ISNULL([Shift],000) AS VARCHAR(5)) AS [Shift],				
				CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
				CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END AS [Fail]
		FROM	[A1494].[LineResults].[DenormalisedMegaView]
		WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
				AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)				
	)
	INSERT INTO @DailyShiftCount
	SELECT	COUNT([PartFaceDMC]) AS [PartsCount],
			SUM([Pass]), 
			SUM([Fail]), 
			[Shift],
			[Date],
			(CAST(SUM([Fail]) AS FLOAT) / CAST(COUNT([PartFaceDMC]) AS FLOAT))* 100 as Failure_Rate 
	FROM	[PartsCount]
	WHERE  [Shift] =	CASE WHEN @ShiftNumber IS NULL THEN [Shift] ELSE @ShiftNumber END 
	GROUP	BY [Date],[Shift]


	IF EXISTS (SELECT TOP 1 1 FROM @DailyShiftCount)	
	SELECT CAST([Date] AS DATE) [Date], [Part Count], [Pass] [Pass Count], [Fail] [Fail Count],[Shift] , Failure_Rate	
	FROM @DailyShiftCount
	order by Date 
	--GROUP BY  CAST([Date] AS DATE), [Shift],[Pass],  [Fail]	
	ELSE
	SELECT  0 [Part Count], 
			--0 [PartsPerShift],
				0 [Pass Count],
				0 [Fail Count],
			'Shift' [Shift],
			 COALESCE(@StartDate, @EndDate, @ThisDay, GETDATE())[Date],
			 0 Failure_Rate
END
---------------------------------------------------------------------------------------------------	
--GET THE LAST 13 WEEKS DATA
---------------------------------------------------------------------------------------------------
  
	ELSE IF((@Period) = 'WEEKLY')
	BEGIN			
---------------------------------------------------------------------------------------------------	
--WEEKLY DATA
--STEP 1: CREATE TEMP TABLE @WeeklyDates AND @WeeklyPartCount
---------------------------------------------------------------------------------------------------
	DECLARE	@WeeklyDates TABLE (
			[ID] INT IDENTITY(1,1),
			[Date]			VARCHAR(50),
			[StartDate]		DATE,
			[EndDate]		DATE,
			[Part Count]	INT,
			[Pass Count]	INT,
			[Fail Count]	INT,
			[Shift]			VARCHAR(50)
			)
	DECLARE @WeeklyShiftCount TABLE(
			[PartsCount]	INT NULL,
			[PassCount]	INT,
			[FailCount]	INT,
			[Timestamp]		DATE NULL,
			[Shift]			VARCHAR(50)
			)
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
		SELECT  DISTINCT 
				[PartFaceDMC],
				'Shift ' + CAST(ISNULL([Shift],000) AS VARCHAR(5)) AS [Shift],
				CAST([DateTimeCompleted] AS DATE) AS [Timestamp],
				CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
				CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END AS [Fail]
		FROM	[A1494].[LineResults].[DenormalisedMegaView]
		WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
				AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
						)
		INSERT INTO @WeeklyShiftCount ([PartsCount],[Timestamp],[PassCount],[FailCount], [Shift])

		SELECT	COUNT([PartFaceDMC]) [Parts Count], [Timestamp], SUM(ISNULL([Pass],0)) [Pass Count], SUM(ISNULL([Fail],0)) [Fail Count], c.[Shift]

		FROM	[CTE] [c] RIGHT JOIN @WeeklyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
		GROUP	BY [Timestamp],c.[Shift]
		
---------------------------------------------------------------------------------------------------
--STEP 3: GET THE TOTAL ShiftCount
---------------------------------------------------------------------------------------------------
		INSERT INTO @WeeklyDates 
		SELECT	d.[Date],
				d.[StartDate] ,
				d.[EndDate] ,
				p.[PartsCount],
				p.[PassCount],
				p.[FailCount],
				p.[Shift]				
		FROM	@WeeklyDates [d] INNER JOIN (
		--  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
				SELECT	[Date], SUM([p].[PartsCount]) [PartsCount], SUM(ISNULL([p].[PassCount],0)) [PassCount], SUM(ISNULL([p].[FailCount],0)) [FailCount], [p].[Shift]
		--  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
				FROM	@WeeklyDates [d] INNER JOIN @WeeklyShiftCount [p] ON [p].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
				GROUP	BY [Date],p.[Shift])				
				[p] ON [p].[Date] = [d].[Date] 

---------------------------------------------------------------------------------------------------
--STEP 4: FINAL OUTPUT FOR METABASE REPORT
---------------------------------------------------------------------------------------------------
	DECLARE @WeeklyShiftCountFinal TABLE(
				--[Date] VARCHAR(100) NULL,
				[Week]			INT NULL,
				--[Month_Position] INT NULL,
				--[Month] NVARCHAR(100) NULL,
				--[Year] INT NULL,
				[MonthYear]		VARCHAR(100) NULL,					
				[Part Count]	INT,
				[Pass Count]	INT,
				[Fail Count]	INT,
				[Shift]			VARCHAR(500) NULL
			)
		INSERT	INTO @WeeklyShiftCountFinal
		SELECT	--'Week ' + CAST(DATEPART(wk,[StartDate]) AS VARCHAR(5)) AS [Date],
				DATEPART(wk,[StartDate]) AS [Week],
				--MONTH(CAST([StartDate] AS DATE)) AS [Month_Position],
				--DATENAME(MONTH,CAST([StartDate] AS DATE)) AS [Month],
				--YEAR(CAST([StartDate] AS DATE))AS [Year],
				CAST(DATENAME(MONTH,CAST([StartDate] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([StartDate] AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
				[Part Count],		
				[Pass Count],
				[Fail Count],
				[Shift]
		FROM	@WeeklyDates	
		WHERE	[Shift] IS NOT NULL
				AND DATEPART(wk,[StartDate]) = CASE	WHEN @Week IS NULL THEN DATEPART(wk,[StartDate])  ELSE @Week END 
		ORDER BY WEEK 


		IF EXISTS (SELECT TOP 1 1 FROM @WeeklyShiftCountFinal)
			SELECT [Week], [Part Count],[Pass Count],[Fail Count], [Shift], (CAST([Fail Count] AS FLOAT) / CAST([Part Count] AS FLOAT)) * 100 as Failure_Rate 
			FROM @WeeklyShiftCountFinal
		ELSE
			SELECT --'Week ' + CAST(DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE())) AS VARCHAR(5)) AS [Date],
					DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE()))AS [Week],
					--MONTH(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month_Position],
					--DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month],
					--YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE))AS [Year],
					CAST(DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
					0 [Part Count],
					0 [Fail Count],
					0 [Pass Count],
					'Shift' [Shift],
					0 as Failure_Rate 
		END
---------------------------------------------------------------------------------------------------	
--GET THE LAST 13 MONTHS DATA
---------------------------------------------------------------------------------------------------
	ELSE IF((@Period) = 'MONTHLY')
	BEGIN 	
---------------------------------------------------------------------------------------------------	
--MONTHLY DATA
--STEP 1: CREATE TEMP TABLE @MonthlyDates AND @WeeklyPartCount
---------------------------------------------------------------------------------------------------

	DECLARE @MonthlyDates TABLE  (
		[ID]			INT IDENTITY(1,1),
		[Date]			VARCHAR(50),
		[StartDate]		DATE,
		[EndDate]		DATE,
		[Part Count]	INT,
		[Pass Count]	INT,
		[Fail Count]	INT,
		[Shift]			VARCHAR(50)
		---[PartsPerShift] BIGINT
		)

	DECLARE @MonthlyShiftCount TABLE(
		[PartsCount]	INT NULL,
		[Pass Count]	INT NULL,
		[Fail Count]	INT NULL,
		[Timestamp]		DATE NULL,
		[Shift]			VARCHAR(50)
		--[PartsPerShift] BIGINT
		)
	DECLARE @MonthShiftCountFinal TABLE(
		--[Date] DATE,
		[Week]			INT,	
		--[Month_Position] INT,
		--[Month] VARCHAR(40),
		--[Year] INT,
		[MonthYear]		VARCHAR(50),	
		[Part Count]	INT,
		[Pass Count]	INT,
		[Fail Count]	INT,
		[Shift]			VARCHAR(50)
		--[PartsPerShift] BIGINT
		)

	;WITH	[CTE] AS (
			SELECT	@startdate AS [cte_start_date]
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
		SELECT	DISTINCT 
				[PartFaceDMC],
				'Shift ' + CAST(ISNULL([Shift],000) AS VARCHAR(5)) AS [Shift],
				CAST([DateTimeCompleted] AS DATE) AS [Timestamp],
				CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
				CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END AS [Fail]
		FROM	[A1494].[LineResults].[DenormalisedMegaView]
		WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
				AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
												)					
	INSERT	INTO @MonthlyShiftCount([PartsCount], [Pass Count], [Fail Count], [Timestamp],[Shift])
	SELECT	COUNT([PartFaceDMC]) [Part Count], SUM(ISNULL([Pass],0)) [Pass Count], SUM(ISNULL([Fail],0)) [Fail Count], [Timestamp], c.[Shift]
	FROM	[CTE] [c] RIGHT JOIN @MonthlyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
	GROUP	BY [Timestamp],c.[Shift]
---------------------------------------------------------------------------------------------------
--STEP 3: GET THE TOTAL PartsCount
-----------------------------------------------------------------------------------------------------	
	INSERT	INTO   @MonthlyDates
	SELECT	d.[Date], [StartDate],	[EndDate], p.[PartsCount],p.[Pass Count], p.[Fail Count], p.[Shift]
	FROM	@MonthlyDates [d] INNER JOIN (
				SELECT	[Date], SUM([p].[PartsCount]) [PartsCount], p.[Shift], SUM(ISNULL(p.[Pass Count],0)) [Pass Count], SUM(ISNULL(p.[Fail Count],0)) [Fail Count]
				FROM	@MonthlyDates [d] INNER JOIN @MonthlyshiftCount [p] ON [p].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate]
				GROUP	BY [Date],p.[Shift]) 
						[p] ON [p].date = [d].Date

---------------------------------------------------------------------------------------------------
--STEP 4: FINAL OUTPUT FOR METABASE REPORT
---------------------------------------------------------------------------------------------------
	INSERT INTO @MonthShiftCountFinal
	SELECT	--[Date], 
			DATEPART(wk,[StartDate]) AS [Week],
			--MONTH(CAST([StartDate] AS DATE)) AS [Month_Position],
			--DATENAME(MONTH,CAST([StartDate] AS DATE)) AS [Month],
			--YEAR(CAST([StartDate] AS DATE)) AS [Year],
			DATENAME(m,[Date])+' '+CAST(DATEPART(yyyy,[Date]) AS VARCHAR) AS [MonthYear],
			[Part Count],
			[Pass Count],
			[Fail Count],
			[Shift]
	FROM	@MonthlyDates
	WHERE	[Part Count] IS NOT NULL
			AND MONTH(CAST([Date] AS DATE)) = CASE	WHEN @Month IS NULL THEN MONTH(CAST([Date] AS DATE)) ELSE @Month END  
			
	ORDER	BY WEEK

	IF EXISTS (SELECT TOP 1 1 FROM @MonthShiftCountFinal)
		SELECT [MonthYear], [Part Count],[Pass Count],[Fail Count], [Shift], (CAST([Fail Count] AS FLOAT) / CAST([Part Count] AS FLOAT)) * 100 as Failure_Rate 
		FROM @MonthShiftCountFinal
	ELSE
		SELECT  COALESCE(@StartDate, @EndDate, GETDATE()) [Date], 
			--DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE()))AS [Week],
			MONTH(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month_Position],
			DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month],
			YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Year],
			CAST(DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) AS [MonthYear],
			0 [Part Count],
			0 [PassCount],
			0 [FailCount],
			'Shift' [Shift],
			0 [PartsPerShift],
			0 as Failure_Rate 
	END
END
GO