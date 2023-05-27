SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE  [Production].[VariantsCount] 
		@Period			VARCHAR(500) = NULL,
		@ThisDay		DATE = NULL,
		@DateFrom		DATE = NULL,
		@DateTo			DATE = NULL,
		@Week			VARCHAR(20) = NULL,
		@Month			VARCHAR(2) = NULL,
		@Variant		VARCHAR(500) = NULL,		
		@ShiftNumber	INT = NULL,
		@Index			VARCHAR(1) = NULL	
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
	IF @Index = '0'
		SET @Index = NULL
	ELSE IF @Index = '1'
		SET  @Index = 'A'
	ELSE IF @Index = '2'
		SET  @Index = 'B'

	IF ISNULL(@Variant,'0') = '0'
		SET @Variant = NULL
	IF ISNULL(@ShiftNumber,0) = 0
		SET @ShiftNumber = NULL
	IF @Week = '0'
			SET @Week = NULL
	IF @Month = '0'
		SET @Month = NULL

---------------------------------------------------------------------------------------------------	
---GET THE LAST 8 DAYS DATA
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

		DECLARE @HourlyVariantCount TABLE(
			[Part Count]	INT,
			[Pass Count]	INT NULL,
			[Fail Count]	INT NULL,
			[Variant]		VARCHAR(1000),
			[Date]			DATETime
		)

		;WITH [PartsCount] AS (
						SELECT	[Date],
								[PartFaceDMC],
								[Pass],
								[Fail],
								[Shift],
								[Variant]
						FROM	(
								SELECT DISTINCT 
								[PartFaceDMC],
								[DateTimeCompleted]  AS [Date],				
								[Shift] AS [Shift],
								[*Variant Name] AS [Variant],
								CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
								CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail]
						FROM	[A1494].[LineResults].[DenormalisedMegaView]
						WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
								AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
								AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
								AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
												)a)
				INSERT INTO @HourlyVariantCount
				SELECT	COUNT([PartFaceDMC]) AS [PartsCount],
						SUM([Pass]),
						SUM([Fail]),
						[Variant],
						hd.StartTime
						
				FROM	[PartsCount] pc
				INNER JOIN @HourlyData hd ON pc.[Date] BETWEEN hd.StartTime AND hd.EndTime 
				WHERE	(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL)			
						AND [Shift] =	CASE WHEN @ShiftNumber IS NULL THEN [Shift] ELSE @ShiftNumber END  
				GROUP	BY hd.StartTime,[Variant]

				IF EXISTS (SELECT TOP 1 1 FROM @HourlyVariantCount)
					SELECT [Date], [Part Count], [Pass Count], [Fail Count], [Variant] FROM @HourlyVariantCount
				ELSE
					SELECT  0 [Part Count],
							0 [Pass],
							0 [Fail],
							'Variant' AS [Variant],
							COALESCE(@StartDate, @EndDate, @ThisDay, GETDATE()) [Date]
							 
	END
	ELSE IF (ISNULL((@Period), 'DAILY') = 'DAILY')
	BEGIN
---------------------------------------------------------------------------------------------------
---DAILY DATA
---STEP 1: CREATE TEMP TABLE @DailyDates AND @DailyPartCount
---------------------------------------------------------------------------------------------------
			DECLARE @DailyVariantCount TABLE(
					[Part Count]	INT,
					[Pass Count]	INT NULL,
					[Fail Count]	INT NULL,
					[Variant]		VARCHAR(1000),
					[Date]			DATE
				)

			IF(@Index IS NULL)
				BEGIN
					;WITH [PartsCount] AS (
						SELECT	[Date],
								[PartFaceDMC],
								[Pass],
								[Fail],
								[Shift],
								[Variant]
						FROM	(
								SELECT DISTINCT 
								[PartFaceDMC],
								CAST([DateTimeCompleted] AS DATE) AS [Date],				
								[Shift] AS [Shift],
								[*Variant Name] AS [Variant],
								CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
								CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail]
						FROM	[A1494].[LineResults].[DenormalisedMegaView]
						WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
								AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
								AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
								AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
								)a)
				INSERT INTO @DailyVariantCount
				SELECT	COUNT([PartFaceDMC]) AS [PartsCount],
						SUM([Pass]),
						SUM([Fail]),
						[Variant],
						[Date]
				FROM	[PartsCount]
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
						AND  (CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL)			
						AND [Shift] =	CASE WHEN @ShiftNumber IS NULL THEN [Shift] ELSE @ShiftNumber END  
				GROUP	BY [Date],[Variant]
				END
				ELSE
				BEGIN
					;WITH [PartsCount] AS (
							SELECT 	[Date],
									PartFaceDMC,
									[Shift],
									[Pass],
									[Fail],
									[Variant]
							FROM	(
							SELECT	DISTINCT [PartFaceDMC],
									CAST([DateTimeCompleted] AS DATE) AS [Date],
								[Shift] AS [Shift],
								[*Variant Name] AS [Variant],
								CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
								CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail]
						FROM	[A1494].[LineResults].[DenormalisedMegaView]
						WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
								AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
								AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)

									)a)
					INSERT INTO @DailyVariantCount
					SELECT	COUNT([PartFaceDMC]) AS [Part Count],
							SUM([Pass]),
							SUM([Fail]),
							[Variant],
							[Date]
					FROM	PartsCount
					WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
							AND  (CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
							AND [Shift] =	CASE WHEN @ShiftNumber IS NULL THEN [Shift] ELSE @ShiftNumber END  
					GROUP	BY [Date],[Variant]
					ORDER	BY [Date]
				END
				IF EXISTS (SELECT TOP 1 1 FROM @DailyVariantCount)
					SELECT [Date], [Part Count], [Pass Count], [Fail Count], [Variant] FROM @DailyVariantCount
				ELSE
					SELECT  0 [Part Count],
							0 [Pass],
							0 [Fail],
							'Variant' AS [Variant],
							COALESCE(@StartDate, @EndDate, @ThisDay, GETDATE()) [Date]
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
			[ID]			INT IDENTITY(1,1),
			[Date]			VARCHAR(50),
			[StartDate]		DATE,
			[EndDate]		DATE,
			[Part Count]	INT,
			[Pass Count]	INT NULL,
			[Fail Count]	INT NULL,
			[Variant]		VARCHAR(50))

	DECLARE @WeeklyPartCount TABLE(
			[Part Count]	INT NULL,
			[Pass Count]	INT NULL,
			[Fail Count]	INT NULL,
			[Timestamp]		DATE NULL,
			[Variant]		VARCHAR(50))
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
					SELECT PartFaceDMC,
						   [Timestamp],
						   [Pass],
						   [Fail],
						   [Variant]
					FROM (	
					SELECT  DISTINCT 
							[PartFaceDMC],
							[*Variant Name] AS [Variant],
							CAST([DateTimeCompleted] AS DATE) AS [Timestamp],
							CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
							CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail]
					FROM	[A1494].[LineResults].[DenormalisedMegaView]
					WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
							AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
							AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
							AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
							)t)
		INSERT INTO @WeeklyPartCount ([Part Count],[Pass Count],[Fail Count],[Timestamp],[Variant])
		SELECT	COUNT([PartFaceDMC]) [Parts Count], SUM([Pass]),SUM([Fail]),[Timestamp], c.[Variant]
		FROM	[CTE] [c] RIGHT JOIN @WeeklyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
		GROUP	BY [Timestamp],c.[Variant]
---------------------------------------------------------------------------------------------------
--STEP 3: GET THE TOTAL PartsCount
---------------------------------------------------------------------------------------------------
		INSERT INTO @WeeklyDates
		SELECT	[d].[Date],
				[d].[StartDate],
				[d].[EndDate],
				[p].[Part Count],
				[p].[Pass Count],
				[p].[Fail Count],
				[p].[Variant]
		FROM	@WeeklyDates [d] INNER JOIN (
					SELECT	[Date], SUM([p].[Part Count]) [Part Count],SUM([p].[Pass Count])[Pass Count] , SUM([p].[Fail Count]) [Fail Count], p.[Variant]
					FROM	@WeeklyDates [d] INNER JOIN @WeeklyPartCount [p] ON [p].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
					GROUP	BY [Date], p.[Variant])				
				[p] ON [p].[Date] = [d].[Date]  

---------------------------------------------------------------------------------------------------
---STEP 4: FINAL OUTPUT FOR METABASE REPORT
---------------------------------------------------------------------------------------------------
		DECLARE @WeeklyShiftCount TABLE(
				--[Date] VARCHAR(100) NULL,
				[Week]			INT NULL,
				--[Month_Position] INT NULL,
				--[Month] NVARCHAR(100) NULL,
				--[Year] INT NULL,
				[MonthYear]		VARCHAR(100) NULL,			
				[Part Count]	INT NULL,
				[Pass Count]	INT,
				[Fail Count]	INT,
				[Variant]		VARCHAR(500) NULL
			)
		INSERT	INTO @WeeklyShiftCount
		SELECT	--'Week ' + CAST(DATEPART(wk,[StartDate]) AS VARCHAR(5)) AS [Date],
				DATEPART(wk,[StartDate]) AS [Week],
				--MONTH(CAST([StartDate] AS DATE)) AS [Month_Position],
				--DATENAME(MONTH,CAST([StartDate] AS DATE)) AS [Month],
				--YEAR(CAST([StartDate] AS DATE))AS [Year],
				CAST(DATENAME(MONTH,CAST([StartDate] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([StartDate] AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
				[Part Count],
				[Pass Count],
				[Fail Count],
				[Variant]
		FROM	@WeeklyDates	
		WHERE	[Variant] IS NOT NULL
				AND DATEPART(wk,[StartDate]) = CASE	WHEN @Week IS NULL THEN DATEPART(wk,[StartDate])  ELSE @Week END 
		 
		ORDER BY WEEK 

		IF EXISTS (SELECT TOP 1 1 FROM @WeeklyShiftCount)
			SELECT * FROM @WeeklyShiftCount
		ELSE
			SELECT 'Week ' + CAST(DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE())) AS VARCHAR(5)) AS [Date],
					DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE()))AS [Week],
					MONTH(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month_Position],
					DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month],
					YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE))AS [Year],
					CAST(DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
					0 [Part Count],
					0 [Pass Count],
					0 [Fail Count],
					'Variant' [Variant]
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
		[ID] INT IDENTITY(1,1),
		[Date]			VARCHAR(50),
		[StartDate]		DATE,
		[EndDate]		DATE,
		[Part Count]	INT,
		[Pass Count]	INT,
		[Fail Count]	INT,
		[Variant]		VARCHAR(50))

	DECLARE @MonthlyPartCount TABLE(
		[Part Count]	INT NULL,
		[Pass Count]	INT NULL,
		[Fail Count]	INT NULL,
		[Timestamp]		DATE NULL,
		[Variant]		VARCHAR(50))
		

	DECLARE @MonthShiftCount TABLE(
		--[Date] DATE,
		[Week]			INT,	
		--[Month_Position] INT,
		--[Month] VARCHAR(40),
		--[Year] INT,
		[MonthYear]		VARCHAR(50),	
		[Part Count]	INT,
		[Pass Count]	INT NULL,
		[Fail Count]	INT NULL,
		[Variant]		VARCHAR(1000)
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
					SELECT PartFaceDMC,
						   [Timestamp],
						   [Pass],
						   [Fail],
						   [Variant]
					FROM ( SELECT	DISTINCT 
									[PartFaceDMC],
									[*Variant Name] AS [Variant],
									CAST([DateTimeCompleted] AS DATE) AS [Timestamp],
									CASE	WHEN [FinalResult] = 'PASS' THEN 1 END AS [Pass], 
									CASE	WHEN [FinalResult] = 'FAIL' THEN 1 END AS [Fail]
							FROM	[A1494].[LineResults].[DenormalisedMegaView]
							WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
									AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
									AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
									AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
							)t)					
	INSERT	INTO @MonthlyPartCount([Part Count] ,[Pass Count],[Fail Count],[Timestamp],[Variant])
	SELECT	COUNT([PartFaceDMC]) [Part Count], SUM([Pass]), SUM([Fail]), [Timestamp], c.[Variant]
	FROM	[CTE] [c] RIGHT JOIN @MonthlyDates [d] ON [c].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate] 
	GROUP	BY [Timestamp],c.[Variant]
	
---------------------------------------------------------------------------------------------------
--STEP 3: GET THE TOTAL PartsCount
---------------------------------------------------------------------------------------------------	

	INSERT INTO   @MonthlyDates
	SELECT [d].[Date], [StartDate],	[EndDate], [p].[Part Count], [p].[Pass Count], [p].[Fail Count], [p].[Variant] 
	FROM	@MonthlyDates [d] INNER JOIN (
				SELECT	[Date], SUM([p].[Part Count]) [Part Count], SUM([p].[Pass Count])[Pass Count] , SUM([p].[Fail Count]) [Fail Count], [p].[Variant]
				FROM	@MonthlyDates [d] INNER JOIN @MonthlyPartCount [p] ON [p].[Timestamp] BETWEEN [d].[StartDate] AND [d].[EndDate]
				GROUP	BY [Date],p.[Variant]) 
	[p] ON [p].[Date] = [d].[Date]

---------------------------------------------------------------------------------------------------
--STEP 4: FINAL OUTPUT FOR METABASE REPORT
---------------------------------------------------------------------------------------------------

	INSERT INTO @MonthShiftCount
	SELECT	--[Date], 
			DATEPART(wk,[StartDate])AS [Week],
			--MONTH(CAST([StartDate] AS DATE)) AS [Month_Position],
			--DATENAME(MONTH,CAST([StartDate] AS DATE)) AS [Month],
			--YEAR(CAST([StartDate] AS DATE)) AS [Year],
			DATENAME(m,[Date])+' '+cast(DATEPART(yyyy,[Date]) AS VARCHAR) AS [MonthYear],
			[Part Count],
			[Pass Count],
			[Fail Count],
			[Variant]
	FROM	@MonthlyDates
	WHERE	([Part Count] IS NOT NULL OR [Variant] IS NOT NULL)
			AND MONTH(CAST([Date] AS DATE)) = CASE	WHEN @Month IS NULL THEN MONTH(CAST([Date] AS DATE)) ELSE @Month END 
	 
	ORDER	BY WEEK

	IF EXISTS (SELECT TOP 1 1 from @MonthShiftCount)
		SELECT * FROM @MonthShiftCount
	ELSE
		SELECT  COALESCE(@StartDate, @EndDate, GETDATE()) [Date], 
				DATEPART(wk,COALESCE(@StartDate, @EndDate, GETDATE()))AS [Week],
				MONTH(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month_Position],
				DATENAME(MONTH,CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Month],
				YEAR(CAST(COALESCE(@StartDate, @EndDate, GETDATE()) AS DATE)) AS [Year],
				DATENAME(m,COALESCE(@StartDate, @EndDate, GETDATE()))+' '+CAST(DATEPART(yyyy,COALESCE(@StartDate, @EndDate, GETDATE())) AS VARCHAR) AS [MonthYear],
				0 [Part Count],
				0 [Pass Count],
				0 [Fail Count],
				'Variant' [Variant]

	END
END
GO