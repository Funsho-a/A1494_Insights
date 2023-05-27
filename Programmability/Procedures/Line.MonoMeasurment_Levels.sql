SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [Line].[MonoMeasurment_Levels]
		@SelectPeriod	VARCHAR(50) = NULL,
		@DateFrom		DATE = NULL,
		@DateTo			DATE = NULL,
		@Monolith		VARCHAR(1) = NULL,
    	@Variant		VARCHAR(500) = NULL,
		@MonoMMResult	VARCHAR(50) = NULL,
		@TopRecords		INT = NULL,
		@ThisDay		DATE = NULL,
		@Week			VARCHAR(20) = NULL,
		@Month			VARCHAR(2) = NULL
AS
BEGIN
	SET NOCOUNT ON

		DECLARE @StartDate	DATE,
				@EndDate	DATE 

		IF @Monolith = '0'
			SET @Monolith = NULL
		IF ISNULL(@Variant,'0') = '0'
			SET @Variant = NULL
		IF ISNULL(@TopRecords,0) = 0
			SET @TopRecords = 999999
		IF ISNULL(@MonoMMResult,'0') = '0'
			SET @MonoMMResult = NULL
		IF @ThisDay = '1999-01-01'
			SET @ThisDay = NULL
		IF @Week = '0'
			SET @Week = NULL
		IF @Month = '0'
			SET @Month = NULL

		IF @DateFrom ='1999-01-01' 
			SET @DateFrom = NULL 
		IF @DateTo ='2050-12-31'
			SET @DateTo  = NULL 
		IF UPPER(@SelectPeriod) IS NULL
			SET @SelectPeriod = '0'		

		IF(@DateFrom IS NULL AND @DateTo is NULL)
		BEGIN	
			SELECT	TOP 1 @EndDate = MAX([DateTimeCompleted])  
			FROM	[A1494].[LineResults].[DenormalisedMegaView]    --GET THE LAST AVAILABLE [MonoMeasuringTimeStamp] TO BE USED FOR END DATE
		
			IF(UPPER(@SelectPeriod) = 'HOUR')	
				SET	@StartDate = @EndDate
			ELSE IF(UPPER(@SelectPeriod) = 'DAY')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
			ELSE IF(UPPER(@SelectPeriod) = 'WEEK')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
			ELSE IF(UPPER(@SelectPeriod) = 'MONTH')
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE		
		END
		ELSE IF(UPPER(@SelectPeriod) IS NOT NULL AND @DateFrom IS NOT NULL AND @DateTo is NOT NULL)
		BEGIN
			SET	@EndDate = @DateTo  
			IF (ISNULL(UPPER(@SelectPeriod), 'DAY') = 'DAY')
			BEGIN
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom
			END
			ELSE IF(UPPER(@SelectPeriod) = 'WEEK')	
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom							
			END
			ELSE IF(UPPER(@SelectPeriod) = 'MONTH')
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom
			END	
		END

		--IF(@Monolith IS NULL AND @Variant IS NULL AND @TopRecords = 999999 AND @MonoMMResult IS NULL)
		--	SET @TopRecords = 0 

		IF (UPPER(@SelectPeriod) = 'HOUR')
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

			;WITH [CTE]	AS (
				SELECT	 FORMAT([DateTimeCompleted],'yyyy-MM-dd HH:mm') AS [Date],
						[MonoFaceDMC],
					[Index] AS [Monolith],
					[*Variant Name] AS [Variant],
 						CASE	WHEN (ISNULL( CAST([Mono Overall Avg Diam (mm)] AS FLOAT), 1)) = 0 THEN 1 ELSE  CAST([Mono Overall Avg Diam (mm)] AS FLOAT) END AS [Mono Average Diameter (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT) END AS [Mono Average level 1 (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT) END AS [Mono Average level 2 (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT) END AS [Mono Average level 3 (mm)],				
						CASE	WHEN [Mono MM Result] = 'PASS' THEN 'OK'
								WHEN [Mono MM Result] = 'FAIL' THEN 'NOK' 
								END AS [Monolith Measurement Result]
				FROM    [A1494].LineResults.DenormalisedMegaView 
				WHERE	[*Variant Name] IS NOT NULL							)
			SELECT	TOP (@TopRecords) c.*
			FROM	[CTE] c
			INNER JOIN @HourlyData hd ON c.[Date] BETWEEN hd.StartTime AND hd.EndTime 
			WHERE	[Monolith] =		CASE	WHEN @Monolith IS NULL 
												THEN [Monolith] 
												ELSE @Monolith END AND
					[Variant] =			CASE	WHEN @Variant IS NULL 
												THEN [Variant]
												ELSE @Variant END AND
					[Monolith Measurement Result]  =	CASE	WHEN @MonoMMResult IS NULL 
												THEN [Monolith Measurement Result] 
												ELSE @MonoMMResult END	AND
					(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL)
			ORDER	BY [Date] DESC
		END
		ELSE IF (ISNULL(UPPER(@SelectPeriod), 'DAY') = 'DAY')
		BEGIN
				;WITH [CTE]	AS (
				SELECT	[DateTimeCompleted] AS [Full Date],
						[DateTimeCompleted] AS [Date],
						[MonoFaceDMC],
					[Index] AS [Monolith],
					[*Variant Name] AS [Variant],
 						CASE	WHEN (ISNULL( CAST([Mono Overall Avg Diam (mm)] AS FLOAT), 1)) = 0 THEN 1 ELSE  ISNULL( CAST([Mono Overall Avg Diam (mm)] AS FLOAT), 1) END AS [Mono Average Diameter (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT) END AS [Mono Average level 1 (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT) END AS [Mono Average level 2 (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT) END AS [Mono Average level 3 (mm)],				
						CASE	WHEN [Mono MM Result] = 'PASS' THEN 'OK'
								WHEN [Mono MM Result] = 'FAIL' THEN 'NOK' 
								END AS [Monolith Measurement Result]
				FROM    [A1494].LineResults.DenormalisedMegaView 
				WHERE	[*Variant Name] IS NOT NULL							)
			SELECT	TOP (@TopRecords) 
			SUBSTRING(DATENAME(dw,[DATE]), 1, 3 )+ ' ' + CAST(DAY([DATE]) AS VARCHAR(2))   AS [Date],
			[Full Date], [MonoFaceDMC],	[Monolith],	[Variant],	[Mono Average Diameter (mm)],	[Mono Average level 1 (mm)],	[Mono Average level 2 (mm)],[Mono Average level 3 (mm)],	[Monolith Measurement Result]
			FROM	[CTE] c			
			WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
			AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
			AND		(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL)
			AND		[Monolith] =		CASE	WHEN @Monolith IS NULL 
												THEN [Monolith] 
												ELSE @Monolith END 
			AND		[Variant] =			CASE	WHEN @Variant IS NULL 
												THEN [Variant]
												ELSE @Variant END 
			AND		[Monolith Measurement Result]  =	CASE	WHEN @MonoMMResult IS NULL 
												THEN [Monolith Measurement Result] 
												ELSE @MonoMMResult END										
			ORDER	BY c.[Date] DESC		
		END
		ELSE IF(UPPER(@SelectPeriod) = 'WEEK')
		BEGIN			
			
			;WITH [CTE]	AS (
					SELECT	CAST([DateTimeCompleted] AS DATETIME) AS [Date],
							[MonoFaceDMC],
					[Index] AS [Monolith],
					[*Variant Name] AS [Variant],
 						CASE	WHEN (ISNULL( CAST([Mono Overall Avg Diam (mm)] AS FLOAT), 1)) = 0 THEN 1 ELSE  ISNULL( CAST([Mono Overall Avg Diam (mm)] AS FLOAT), 1) END AS [Mono Average Diameter (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT) END AS [Mono Average level 1 (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT) END AS [Mono Average level 2 (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT) END AS [Mono Average level 3 (mm)],				
						CASE	WHEN [Mono MM Result] = 'PASS' THEN 'OK'
								WHEN [Mono MM Result] = 'FAIL' THEN 'NOK' 
								END AS [Monolith Measurement Result]
					FROM    [A1494].LineResults.DenormalisedMegaView 
					WHERE	[*Variant Name] IS NOT NULL							)
				SELECT	TOP (@TopRecords) 
						--'Week ' + CAST(DATEPART(wk,[Date]) AS VARCHAR(5)) AS [Date],
						DATEPART(wk,[Date])AS [Week Position],
						--MONTH(CAST([Date] AS DATE)) AS [Month_Position],
						--DATENAME(MONTH,CAST([Date] AS DATE)) AS [Month],
						--YEAR(CAST([Date] AS DATE))AS [Year],
						--CAST(DATENAME(month,CAST([Date] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([Date] AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
						--CAST(c.[Date] AS DATE) AS [Timestamp],
						*
				FROM	[CTE] c			
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND		DATEPART(wk,[Date]) = CASE	WHEN @Week IS NULL THEN DATEPART(wk,[Date])  ELSE @Week END 
				AND		[Monolith] =		CASE	WHEN @Monolith IS NULL 
													THEN [Monolith] 
													ELSE @Monolith END 
				AND		[Variant] =			CASE	WHEN @Variant IS NULL 
													THEN [Variant]
													ELSE @Variant END 
				AND		[Monolith Measurement Result]  =	CASE	WHEN @MonoMMResult IS NULL 
													THEN [Monolith Measurement Result] 
													ELSE @MonoMMResult END										
				ORDER	BY c.[Date] DESC	
			END
			ELSE IF(UPPER(@SelectPeriod) = 'MONTH')
			BEGIN 				
				;WITH [CTE]	AS (
					SELECT	CAST([DateTimeCompleted] AS DATETIME) AS [Date],
							[MonoFaceDMC],
					[Index] AS [Monolith],
					[*Variant Name] AS [Variant],
 						CASE	WHEN (ISNULL( CAST([Mono Overall Avg Diam (mm)] AS FLOAT), 1)) = 0 THEN 1 ELSE  ISNULL( CAST([Mono Overall Avg Diam (mm)] AS FLOAT), 1) END AS [Mono Average Diameter (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT) END AS [Mono Average level 1 (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT) END AS [Mono Average level 2 (mm)],
						CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT) END AS [Mono Average level 3 (mm)],				
						CASE	WHEN [Mono MM Result] = 'PASS' THEN 'OK'
								WHEN [Mono MM Result] = 'FAIL' THEN 'NOK' 
								END AS [Monolith Measurement Result]
					FROM    [A1494].LineResults.DenormalisedMegaView 
					WHERE	[*Variant Name] IS NOT NULL							)
				SELECT	TOP (@TopRecords) 
						--CAST(DATENAME(MONTH, [Date]) AS VARCHAR(10)) + ', ' + CAST(YEAR([Date]) AS VARCHAR(10)) AS [Date],
						--DATEPART(wk,[Date])AS [Week],
						MONTH(CAST([Date] AS DATE)) AS [Month_Position],
						--DATENAME(MONTH,CAST([Date] AS DATE)) AS [Month],
						--YEAR(CAST([Date] AS DATE))AS [Year],
						--CAST(DATENAME(month,CAST([Date] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([Date] AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
						--CAST(c.[Date] AS DATE) AS [Timestamp],
						*
				FROM	[CTE] c			
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND		MONTH(CAST([Date] AS DATE)) = CASE	WHEN @Month IS NULL THEN MONTH(CAST([Date] AS DATE)) ELSE @Month END 
				AND		[Monolith] =		CASE	WHEN @Monolith IS NULL 
													THEN [Monolith] 
													ELSE @Monolith END 
				AND		[Variant] =			CASE	WHEN @Variant IS NULL 
													THEN [Variant]
													ELSE @Variant END 
				AND		[Monolith Measurement Result]  =	CASE	WHEN @MonoMMResult IS NULL 
													THEN [Monolith Measurement Result] 
													ELSE @MonoMMResult END										
				ORDER	BY c.[Date] DESC	
	END
END
GO