﻿SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [Production].[Production_Avg_CycleTime]
			@SelectPeriod	VARCHAR(500) = NULL,
			@ThisDay		DATE = NULL,
			@DateFrom		DATE = NULL,		
			@DateTo			DATE = NULL,
			@Week			VARCHAR(20) = NULL,		
			@Month			VARCHAR(2) = NULL

AS
BEGIN
	SET NOCOUNT ON

		DECLARE @StartDate	DATE,
				@EndDate	DATE 

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
			SET @SelectPeriod = 'DAY'		

	IF(@DateFrom IS NULL AND @DateTo is NULL)
		BEGIN
		SELECT @EndDate = MAX([A1494].[LineResults].[DenormalisedMegaView].[DateTimeCompleted])
			FROM	[A1494].[LineResults].[DenormalisedMegaView]
			WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)	
	
		
			IF((@SelectPeriod) = 'HOUR')	
				SET	@StartDate = @EndDate
			ELSE IF((@SelectPeriod) = 'DAY')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
			ELSE IF((@SelectPeriod) = 'WEEK')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
			ELSE IF((@SelectPeriod) = 'MONTH')
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE		
		END
		ELSE IF((@SelectPeriod) IS NOT NULL AND @DateFrom IS NOT NULL AND @DateTo is NOT NULL)
		BEGIN
			SET	@EndDate = @DateTo  
			IF (ISNULL((@SelectPeriod), 'DAY') = 'DAY')
			BEGIN
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom
			END
			ELSE IF((@SelectPeriod) = 'WEEK')	
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom							
			END
			ELSE IF((@SelectPeriod) = 'MONTH')
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom
			END	
		END


		IF (ISNULL((@SelectPeriod), 'HOUR') = 'HOUR')
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
						[Cycle Time (s)]
						--DATEDIFF(SECOND, DateTimeCreated, DateTimeCompleted) AS [Calc Cycle Time (s)]
				FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)		
				) AS SourceTable 		
				)
			SELECT	[Date],PartFaceDMC,AVG([Cycle Time (s)]) AS [Avg Cycle Time (s)], TotAvg.[Total Avg Cycle Time (s)]
			FROM	[CTE] c
			CROSS APPLY (
							select AVG([Cycle Time (s)]) AS [Total Avg Cycle Time (s)]
							FROM [CTE] ct
							INNER JOIN @HourlyData hdd ON ct.[Date] BETWEEN hdd.StartTime AND hdd.EndTime 
							WHERE	(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL) 						
			)TotAvg
			INNER JOIN @HourlyData hd ON c.[Date] BETWEEN hd.StartTime AND hd.EndTime 
			WHERE	(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
			GROUP BY 			[Date], PartFaceDMC,  TotAvg.[Total Avg Cycle Time (s)]
			ORDER	BY [Date] DESC

		END
		ELSE IF (ISNULL((@SelectPeriod), 'DAY') = 'DAY')
		BEGIN
				;WITH [CTE]	AS (
		SELECT  *
		FROM
		(  
				SELECT DISTINCT 
						PartFaceDMC,
						FORMAT([DateTimeCompleted],'yyyy-MM-dd HH:mm') AS [Date],
						[Cycle Time (s)]
						--DATEDIFF(SECOND, DateTimeCreated, DateTimeCompleted) AS [Calc Cycle Time (s)]
				FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
			) AS SourceTable 			
			)
			SELECT	 
			--SUBSTRING(DATENAME(dw,[DATE]), 1, 3 )+ ' ' + CAST(DAY([DATE]) AS VARCHAR(2))   AS [Date],
			[Date], [PartFaceDMC],	 AVG([Cycle Time (s)]) AS [Avg Cycle Time (s)],	TotAvg.[Total Avg Cycle Time (s)]
			FROM	[CTE] c
			CROSS APPLY (
							select AVG([Cycle Time (s)]) AS [Total Avg Cycle Time (s)]
							FROM [CTE] c
							WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
							AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
							AND		(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
			)TotAvg			
			WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
			AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
			AND		(CAST([Date] AS DATE) = @ThisDay OR @ThisDay IS NULL)
			GROUP	BY 	[Date],	[PartFaceDMC], 	TotAvg.[Total Avg Cycle Time (s)]
				ORDER	BY c.[Date] DESC
		END
		ELSE IF((@SelectPeriod) = 'WEEK')
		BEGIN			
			;WITH [CTE]	AS (
			SELECT  *
			FROM
			( 
				SELECT DISTINCT 
						PartFaceDMC,
						FORMAT([DateTimeCompleted],'yyyy-MM-dd HH:mm') AS [Date],
						[Cycle Time (s)]
						--DATEDIFF(SECOND, DateTimeCreated, DateTimeCompleted) AS [Calc Cycle Time (s)]
				FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
				) AS SourceTable 
				)
				SELECT	
						--'Week ' + CAST(DATEPART(wk,[Date]) AS VARCHAR(5)) AS [Date],
						DATEPART(wk,[Date])AS [This Week Position],
						MONTH(CAST([Date] AS DATE)) AS [This Month Position],
						--DATENAME(MONTH,CAST([Date] AS DATE)) AS [Month],
						--YEAR(CAST([Date] AS DATE))AS [Year],
						--CAST(DATENAME(month,CAST([Date] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([Date] AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
						CAST(c.[Date] AS DATE) AS [Timestamp],
						--AVG([Cycle Time (s)]) AS [Avg Cycle Time (s)],
						PartFaceDMC,
						TotAvg.[Total Avg Cycle Time (s)]
				FROM	[CTE] c
				CROSS APPLY (
								SELECT AVG([Cycle Time (s)]) AS [Total Avg Cycle Time (s)]
								FROM [CTE] c
								WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
								AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
								AND		DATEPART(wk,[Date]) = CASE	WHEN @Week IS NULL THEN DATEPART(wk,[Date])  ELSE @Week END 
				)TotAvg			
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND		DATEPART(wk,[Date]) = CASE	WHEN @Week IS NULL THEN DATEPART(wk,[Date])  ELSE @Week END 
				GROUP	BY 	[Date],PartFaceDMC,TotAvg.[Total Avg Cycle Time (s)]
				ORDER	BY c.[Date] DESC
			END
			ELSE IF((@SelectPeriod) = 'MONTH')
			BEGIN 				
				;WITH [CTE]	AS (
			SELECT  *
			FROM
			( 
				SELECT DISTINCT 
						PartFaceDMC,
						FORMAT([DateTimeCompleted],'yyyy-MM-dd HH:mm') AS [Date],
						[Cycle Time (s)]
						--DATEDIFF(SECOND, DateTimeCreated, DateTimeCompleted) AS [Calc Cycle Time (s)]
				FROM	[A1494].[LineResults].[DenormalisedMegaView]
				WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
						AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
						AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 	
				) AS SourceTable 				
				)
				SELECT	 
						--CAST(DATENAME(MONTH, [Date]) AS VARCHAR(10)) + ', ' + CAST(YEAR([Date]) AS VARCHAR(10)) AS [Date],
						DATEPART(wk,[Date])AS [This Week Position],
						MONTH(CAST([Date] AS DATE)) AS [This Month Position],
						--DATENAME(MONTH,CAST([Date] AS DATE)) AS [Month],
						--YEAR(CAST([Date] AS DATE))AS [Year],
						--CAST(DATENAME(month,CAST([Date] AS DATE)) AS VARCHAR(10)) + ', ' + CAST(YEAR(CAST([Date] AS DATE)) AS VARCHAR(10)) AS [MonthYear],	
						--CAST(c.[Date] AS DATE) AS [Timestamp],
						--AVG([Cycle Time (s)]) AS [Avg Cycle Time (s)],
						c.*,	TotAvg.[Total Avg Cycle Time (s)]
				FROM	[CTE] c
				CROSS APPLY (
								select AVG([Cycle Time (s)]) AS [Total Avg Cycle Time (s)]
								FROM [CTE] c
								WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
								AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
								AND		MONTH(CAST([Date] AS DATE)) = CASE	WHEN @Month IS NULL THEN MONTH(CAST([Date] AS DATE)) ELSE @Month END 
				)TotAvg			
				WHERE	(CAST([Date] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND		(CAST([Date] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND		MONTH(CAST([Date] AS DATE)) = CASE	WHEN @Month IS NULL THEN MONTH(CAST([Date] AS DATE)) ELSE @Month END 
				GROUP	BY 	[Date],[PartFaceDMC],[Cycle Time (s)],	TotAvg.[Total Avg Cycle Time (s)]
				ORDER	BY c.[Date] DESC	
	END
END
GO