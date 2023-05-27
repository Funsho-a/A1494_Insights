SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [Production].[Production_CycleTime]
			@SelectPeriod	VARCHAR(1500) = NULL,					
			@ThisDay		DATE = NULL,
			@DateFrom		DATE = NULL,		
			@DateTo			DATE = NULL,			
			@Week			VARCHAR(20) = NULL,			
			@Month			VARCHAR(2) = NULL,
			@VariantID		VARCHAR(1500) = NULL, 
			@Monolith		VARCHAR(1) = NULL,
			@Cycle			INT = NULL, 
			@page			INT = 0
AS
BEGIN
	SET NOCOUNT ON

		DECLARE @StartDate	DATE,
				@EndDate	DATE 


		IF @Monolith = '0'
			SET @Monolith = NULL
		IF ISNULL(@VariantID,'0') = '0'
			SET @VariantID = NULL
		IF ISNULL(@Cycle,0) = 0
			SET @Cycle = 1
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
		IF (@SelectPeriod) IS NULL
			SET @SelectPeriod = 'DAILY'		

	IF(@DateFrom IS NULL AND @DateTo is NULL)
		BEGIN
		SELECT @EndDate = MAX([A1494].[LineResults].[DenormalisedMegaView].[DateTimeCompleted])
		FROM	[A1494].[LineResults].[DenormalisedMegaView]
		WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)		
	
		
			IF((@SelectPeriod) = 'HOURLY')	
				SET	@StartDate = @EndDate
			ELSE IF((@SelectPeriod) = 'DAILY')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
			ELSE IF((@SelectPeriod) = 'WEEKLY')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
			ELSE IF((@SelectPeriod) = 'MONTHLY')
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE		
		END
		ELSE IF((@SelectPeriod) IS NOT NULL AND @DateFrom IS NOT NULL AND @DateTo is NOT NULL)
		BEGIN
			SET	@EndDate = @DateTo  
			IF (ISNULL((@SelectPeriod), 'DAILY') = 'DAILY')
			BEGIN
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom
			END
			ELSE IF((@SelectPeriod) = 'WEEKLY')	
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom							
			END
			ELSE IF((@SelectPeriod) = 'MONTHLY')
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom
			END	
		END

		IF ((@SelectPeriod)= 'HOURLY')
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
			SELECT  *
			FROM
			(  
				SELECT DISTINCT 
						PartFaceDMC,
						FORMAT([DateTimeCompleted],'yyyy-MM-dd HH:mm') AS [Date],
						[*Variant Name]  AS [Variant],
						[Index] AS [Monolith],
						[Cycle Time (s)],
						CAST(45 AS INT) AS [Expected CycleTime (s)],
						CASE	WHEN [Cycle Time (s)] <= 120 THEN 1
								WHEN [Cycle Time (s)] <= 1000 THEN 2
								ELSE 3  END AS [cycle_category]
						FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)	
						AND  CASE	WHEN @Cycle = 1 AND ([Cycle Time (s)]) <= 120 THEN 1
									WHEN @Cycle = 2 AND ([Cycle Time (s)]) > 120 AND ([Cycle Time (s)]) <= 1000 THEN 1
									WHEN @Cycle = 3 AND ([Cycle Time (s)]) > 1000 THEN 1
									ELSE 0
									END = 1
						AND [Index] =  'A'
			
				) AS SourceTable 		
				)
			SELECT	[Date],PartFaceDMC,Monolith,Variant,  [Cycle Time (s)],[Expected CycleTime (s)],[cycle_category]--,[GBD Measurement Duration (s)],[Monolith Measurement Duration (s)],[Other Processes Duration (s)]
			FROM	[CTE] c
			INNER JOIN @HourlyData hd ON c.[Date] BETWEEN hd.StartTime AND hd.EndTime 
			WHERE	[Monolith] =		CASE	WHEN @Monolith IS NULL 
												THEN [Monolith] 
												ELSE @Monolith END AND
					[Variant] =			CASE	WHEN @VariantID IS NULL 
												THEN [Variant]
												ELSE @VariantID END AND
					[cycle_category]  =	CASE	WHEN @Cycle IS NULL 
												THEN [cycle_category] 
												ELSE @Cycle END	AND
					(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
			GROUP BY 			[Date],	PartFaceDMC,	Monolith,	Variant,[Cycle Time (s)], [Expected CycleTime (s)],[cycle_category]--,[GBD Measurement Duration (s)],[Monolith Measurement Duration (s)],[Other Processes Duration (s)]	
		
			ORDER	BY [Date] DESC
			OFFSET ((@page - 1) * 200) ROWS
					FETCH NEXT 200 ROWS ONLY
		END
		ELSE IF (ISNULL((@SelectPeriod), 'DAILY') = 'DAILY')
		BEGIN
				;WITH [CTE]	AS (
		SELECT  *
		FROM
		(  
				SELECT DISTINCT 
						PartFaceDMC,
						[DateTimeCompleted] AS [Full Date],
						[DateTimeCompleted] AS [Date],
						[*Variant Name]  AS [Variant],
						[Index] AS [Monolith],
						[Cycle Time (s)],
					CAST(45 AS INT) AS [Expected CycleTime (s)],
						CASE	WHEN [Cycle Time (s)] <= 120 THEN 1
								WHEN [Cycle Time (s)] <= 1000 THEN 2
								ELSE 3  END AS [cycle_category]
						FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)	
						AND  CASE	WHEN @Cycle = 1 AND ([Cycle Time (s)]) <= 120 THEN 1
									WHEN @Cycle = 2 AND ([Cycle Time (s)]) > 120 AND ([Cycle Time (s)]) <= 1000 THEN 1
									WHEN @Cycle = 3 AND ([Cycle Time (s)]) > 1000 THEN 1
									ELSE 0
									END = 1
						AND [Index] =  'A'
			) AS SourceTable 			
			)
			SELECT	 
			SUBSTRING(DATENAME(dw,[DATE]), 1, 3 )+ ' ' + CAST(DAY([DATE]) AS VARCHAR(2))   AS [Date],
			[Full Date], [PartFaceDMC],	[Monolith],	[Variant], [Cycle Time (s)] [Cycle Time (s)], [Expected CycleTime (s)],[cycle_category]--,[GBD Measurement Duration (s)],[Monolith Measurement Duration (s)],[Other Processes Duration (s)]		
			FROM	[CTE] c			
			WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
			AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
			AND		(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL)
			AND		[Monolith] =		CASE	WHEN @Monolith IS NULL 
												THEN [Monolith] 
												ELSE @Monolith END 
			AND		[Variant] =			CASE	WHEN @VariantID IS NULL 
												THEN [Variant]
												ELSE @VariantID END 
			AND		[cycle_category] = CASE		WHEN @Cycle IS NULL
												THEN [cycle_category]
												ELSE [cycle_category] END 

			GROUP BY 	[Date],	[Full Date], [PartFaceDMC],	[Monolith],	[Variant],[Cycle Time (s)], [Expected CycleTime (s)],[cycle_category]--,[GBD Measurement Duration (s)],[Monolith Measurement Duration (s)],[Other Processes Duration (s)]	
				ORDER	BY c.[Date] DESC
							OFFSET ((@page - 1) * 200) ROWS
					FETCH NEXT 200 ROWS ONLY
		END
		ELSE IF((@SelectPeriod) = 'WEEKLY')
		BEGIN			
			
			;WITH [CTE]	AS (
			SELECT  *,
                ROW_NUMBER() OVER (ORDER BY [Date] DESC) AS RowNumber
			FROM
			( 
				SELECT DISTINCT 
						PartFaceDMC,
						CAST([DateTimeCompleted] AS DATETIME) AS [Date],
						[*Variant Name]  AS [Variant],
						[Index] AS [Monolith],
						[Cycle Time (s)],
					CAST(45 AS INT) AS [Expected CycleTime (s)],
						CASE	WHEN [Cycle Time (s)] <= 120 THEN 1
								WHEN [Cycle Time (s)] <= 1000 THEN 2
								ELSE 3  END AS [cycle_category]
						FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)	
						AND  CASE	WHEN @Cycle = 1 AND ([Cycle Time (s)]) <= 120 THEN 1
									WHEN @Cycle = 2 AND ([Cycle Time (s)]) > 120 AND ([Cycle Time (s)]) <= 1000 THEN 1
									WHEN @Cycle = 3 AND ([Cycle Time (s)]) > 1000 THEN 1
									ELSE 0
									END = 1
						AND [Index] =  'A'
				) AS SourceTable 
				)
				SELECT	
						'Week ' + CAST(DATEPART(wk,[Date]) AS VARCHAR(5)) AS [Date],
						DATEPART(wk,[Date])AS [Week],
						MONTH(CAST([Date] AS DATE)) AS [Month_Position],
						DATENAME(MONTH,CAST([Date] AS DATE)) AS [Month],
						YEAR(CAST([Date] AS DATE))AS [Year],
						CAST(DATENAME(month,CAST([Date] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([Date] AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
						CAST(c.[Date] AS DATE) AS [Timestamp],
						*
				FROM	[CTE] c			
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND		DATEPART(wk,[Date]) = CASE	WHEN @Week IS NULL THEN DATEPART(wk,[Date])  ELSE @Week END 
				AND		[Monolith] =		CASE	WHEN @Monolith IS NULL 
													THEN [Monolith] 
													ELSE @Monolith END 
				AND		[Variant] =			CASE	WHEN @VariantID IS NULL 
													THEN [Variant]
													ELSE @VariantID END
				AND		[cycle_category] = CASE		WHEN @Cycle IS NULL
												THEN [cycle_category]
												ELSE [cycle_category] END									
	
				ORDER	BY c.[Date] DESC
							OFFSET ((@page - 1) * 200) ROWS
					FETCH NEXT 200 ROWS ONLY
			END
			ELSE IF((@SelectPeriod) = 'MONTHLY')
			BEGIN 				
				;WITH [CTE]	AS (
			SELECT  *,
                ROW_NUMBER() OVER (ORDER BY [Date] DESC) AS RowNumber
			FROM
			( 
			SELECT DISTINCT 
						PartFaceDMC,
						CAST([DateTimeCompleted] AS DATETIME) AS [Date],
						[*Variant Name]  AS [Variant],
						[Index] AS [Monolith],
						[Cycle Time (s)],
					CAST(45 AS INT) AS [Expected CycleTime (s)],
						CASE	WHEN [Cycle Time (s)] <= 120 THEN 1
								WHEN [Cycle Time (s)] <= 1000 THEN 2
								ELSE 3  END AS [cycle_category]
						FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)	
						AND  CASE	WHEN @Cycle = 1 AND ([Cycle Time (s)]) <= 120 THEN 1
									WHEN @Cycle = 2 AND ([Cycle Time (s)]) > 120 AND ([Cycle Time (s)]) <= 1000 THEN 1
									WHEN @Cycle = 3 AND ([Cycle Time (s)]) > 1000 THEN 1
									ELSE 0
									END = 1
						AND [Index] =  'A'
				) AS SourceTable 				
				)
				SELECT	 
						CAST(DATENAME(MONTH, [Date]) AS VARCHAR(10)) + ', ' + CAST(YEAR([Date]) AS VARCHAR(10)) AS [Date],
						DATEPART(wk,[Date])AS [Week],
						MONTH(CAST([Date] AS DATE)) AS [Month_Position],
						DATENAME(MONTH,CAST([Date] AS DATE)) AS [Month],
						YEAR(CAST([Date] AS DATE))AS [Year],
						CAST(DATENAME(month,CAST([Date] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([Date] AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
						CAST(c.[Date] AS DATE) AS [Timestamp],
						*
				FROM	[CTE] c			
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND		MONTH(CAST([Date] AS DATE)) = CASE	WHEN @Month IS NULL THEN MONTH(CAST([Date] AS DATE)) ELSE @Month END 
				AND		[Monolith] =		CASE	WHEN @Monolith IS NULL 
													THEN [Monolith] 
													ELSE @Monolith END 
				AND		[Variant] =			CASE	WHEN @VariantID IS NULL 
													THEN [Variant]
													ELSE @VariantID END 
				AND		[cycle_category] = CASE		WHEN @Cycle IS NULL
													THEN [cycle_category]
													ELSE [cycle_category] END	

				ORDER	BY c.[Date] DESC	
							OFFSET ((@page - 1) * 200) ROWS
					FETCH NEXT 200 ROWS ONLY
	END
END
GO