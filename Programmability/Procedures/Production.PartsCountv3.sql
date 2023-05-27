SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
create PROCEDURE  [Production].[PartsCountv3] 
		@Period			VARCHAR(500) = NULL,	
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

	IF @ThisDay = '1900-01-01'
		SET @ThisDay = NULL
	IF @DateFrom = '1900-01-01' 
		SET @DateFrom = NULL 
	IF @DateTo = '2100-12-31'
		SET @DateTo  = NULL 
	IF (@Period) IS NULL
		SET @Period = 'DAILY'
	IF ISNULL(@Variant,'0') = '0'
		SET @Variant = NULL
	IF @Week = '0'
		SET @Week = NULL
	IF @Month = '0'
		SET @Month = NULL

	SELECT @DateFrom = StartDate, @DateTo = EndDate
	FROM [Function].GetDateFromPeriod(@Period,@DateFrom,@DateTo,@ThisDay)

	CREATE TABLE #Dates    
	(				
		[StartTime]		DATETIME NULL,
		[EndTime]		DATETIME NULL,
		[StartDate]		DATE NULL, 
		[EndDate]		DATE NULL
	)

	DECLARE @Select_1 VARCHAR(MAX) = ' ;With Master_Data AS 
									(SELECT ISNULL(SUM([PassCount]), 0) [Pass Count],
											ISNULL(SUM([FailCount]), 0) [Fail Count],
											ISNULL(SUM([MonoCount]), 0) [MonoCount],
											ISNULL(SUM([MonoPassCount]), 0) [MonoPassCount],
											ISNULL(SUM([MonoFailCount]), 0) [MonoFailCount]',
			@From_PC VARCHAR(MAX) = ' FROM	(
									  SELECT	[DateTimeCompleted] AS [Date],
													COUNT(DISTINCT [PartFaceDMC]) [PartsCount],									
													CASE	WHEN [FinalResult] = ''PASS'' THEN 1 ELSE 0 END AS [PassCount], 
													CASE	WHEN [FinalResult] = ''FAIL''  THEN 1 ELSE 0 END AS [FailCount],
													COUNT(DISTINCT [MonoFaceDMC]) [MonoCount],				
													SUM(ISNULL(CASE	WHEN [FinalResult] = ''PASS'' THEN 1 END,0)) [MonoPassCount],  
													SUM(ISNULL(CASE	WHEN [FinalResult] = ''FAIL''  THEN 1 END,0)) [MonoFailCount] 
											FROM	[A1494].[LineResults].[DenormalisedMegaView]
											WHERE	[PartFaceDMC] IS NOT NULL
													AND (CAST([DateTimeCompleted] AS DATE) >= ''' + CAST(@DateFrom AS VARCHAR(50)) + ''' OR ''' + CAST(@DateFrom AS VARCHAR(50)) + ''' IS NULL)
													AND (CAST([DateTimeCompleted] AS DATE) <= ''' + CAST(@DateTo AS VARCHAR(50)) + ''' OR ''' + CAST(@DateTo AS VARCHAR(50)) + ''' IS NULL)' +
													CASE WHEN @ThisDay IS NOT NULL THEN 'AND (CAST([DateTimeCompleted] AS DATE) = ''' + CAST(@ThisDay AS VARCHAR(50)) + ''')' ELSE ' ' END  +
													CASE WHEN @Variant IS NOT NULL THEN 'AND [*Variant Name] = ' +CAST(@Variant AS VARCHAR(500)) ELSE ' ' END +							
											' GROUP BY [DateTimeCompleted],[FinalResult]
									)  pc',
			@Select_2 VARCHAR(MAX) = ' SELECT [Date], [Pass Count], [Fail Count], ISNULL([Forced Part], 0) [Forced Part], [MonoCount], [MonoPassCount], [MonoFailCount]
									FROM Master_Data hd
									LEFT JOIN 
									(
										SELECT COUNT(DISTINCT [PartFaceDMC]) [Forced Part], ReplaceTextSelect [TimeStamp]							
										FROM [A1494].[LineResults].[DenormalisedMegaView]
										INNER JOIN #Dates hpc on  CAST([MonoMeasuringTimeStamp] AS DATE)=  CAST(hpc.[StartTime] AS DATE)
										WHERE [FinalResult]  = ''FAIL'' AND [DateTimeCompleted] IS NULL	
										GROUP BY ReplaceTextSelect 
									) t ON ReplaceTextON',
			@Join VARCHAR(MAX) = '',
			@SQL VARCHAR(MAX) = ''

	IF ((@Period) = 'HOURLY')
	BEGIN
		SET @Select_1 = 'INSERT INTO #Dates ([StartTime],[EndTime])
						SELECT	 StartTime = D
								,StopTime  = DateAdd(HOUR,1,D)
						FROM (
								SELECT TOP  (DateDiff(HOUR,convert(varchar,''' + CAST(@DateFrom AS VARCHAR(50)) + ''',101),( convert(varchar,''' + CAST(@DateFrom AS VARCHAR(50)) + ''',101) +'' 23:59:59''))+1) 
										D=DateAdd(HOUR,-1+Row_Number() OVER (ORDER BY (SELECT NULL)),convert(varchar,''' + CAST(@DateFrom AS VARCHAR(50)) + ''',101)) 
								FROM  master..spt_values n1
								) D' +		
		 @Select_1 + ' , FORMAT(hpc.StartTime,''yyyy-MM-dd HH:mm'') [Date]'	
		 
		SET @Join = ' RIGHT JOIN #Dates hpc ON  pc.Date BETWEEN hpc.[StartTime] AND hpc.[EndTime] 
					 GROUP BY FORMAT(hpc.StartTime,''yyyy-MM-dd HH:mm''))'
			
		SELECT @Select_2 = REPLACE(REPLACE(	@Select_2, 'ReplaceTextSelect', 'FORMAT(MonoMeasuringTimeStamp,''yyyy-MM-dd HH:00'') '),'ReplaceTextON','t.[TimeStamp] = hd.[Date]')

		SET @SQL = @Select_1 + @From_PC + @Join + @Select_2 + ' ORDER BY [Date]'

		EXECUTE(@SQL)
	END
	ELSE IF (ISNULL((@Period), 'DAILY') = 'DAILY')
	BEGIN

	SET @Select_1 = '
						INSERT	INTO #Dates ([StartDate])
						SELECT	DATEADD(DAY,number,''' + CAST(@DateFrom AS VARCHAR(50)) + ''') [Date]
						FROM	MASTER..spt_values
						WHERE	TYPE = ''P''
						AND DATEADD(DAY,number,''' + CAST(@DateFrom AS VARCHAR(50)) + ''') <= ''' + CAST(@DateTo AS VARCHAR(50)) + ''''	 +		
		 @Select_1 + ' , CAST(pc.[Date] AS DATE)	 AS [This Day],
						SUBSTRING(CAST(DATENAME(dw, CAST(pc.[Date] AS DATE)) AS VARCHAR(3)), 1, 3)
							+ '' '' + CAST(DATENAME(month, CAST(pc.[Date] AS DATE)) AS VARCHAR(3))
							+ '' '' + CAST(DAY(CAST(pc.[Date] AS DATE)) AS VARCHAR(2))
							+ '', '' + CAST(YEAR(CAST(pc.[Date] AS DATE)) AS VARCHAR(4)) AS [Date]'

		SET @Join = ' RIGHT JOIN #Dates dpc ON  CAST(pc.[Date] AS DATE) = dpc.[StartDate]
						GROUP BY CAST(pc.[Date] AS DATE))'
		
		SELECT @Select_2 = REPLACE(REPLACE(	@Select_2, 'ReplaceTextSelect', 'CAST([MonoMeasuringTimeStamp] AS DATE) '),'ReplaceTextON','t.[TimeStamp] = hd.[This Day]')
		
		SET @SQL = @Select_1 + @From_PC + @Join + @Select_2 + ' ORDER BY [Date]'

		EXECUTE(@SQL)

	END

	ELSE IF((@Period) = 'WEEKLY')
	BEGIN						
		INSERT	INTO #Dates ([StartDate], [EndDate])
		SELECT	DATEADD(DAY,-(DATEPART(DW,DATEADD(WEEK, x.number, @DateFrom))-2), DATEADD(WEEK, x.number, @DateFrom)) AS [StartDate],
				DATEADD(DAY,-(DATEPART(DW,DATEADD(WEEK, x.number + 1, @DateFrom))-1),DATEADD(WEEK, x.number + 1, @DateFrom)) AS [EndDate]
		FROM MASTER.dbo.spt_values x
		WHERE [x].TYPE = 'P' 
			AND [x].number <= DATEDIFF(WEEK, @DateFrom, DATEADD(WEEK,0,CAST(@DateTo AS DATE)))

			;With Master_Data AS
			(
				SELECT	
					'Week ' + CAST(DATEPART(wk,COALESCE([StartDate], [EndDate], GETDATE())) AS VARCHAR(5)) AS Date,
					DATEPART(wk,COALESCE([StartDate], [EndDate], GETDATE())) AS [This Week Position],
					dpc.[StartDate],
					dpc.[EndDate],
					ISNULL(SUM([PartsCount]), 0) [Part Count],
					ISNULL(SUM([PassCount]), 0) [Pass Count],
					ISNULL(SUM([FailCount]), 0) [Fail Count],				
					ISNULL(SUM([MonoCount]), 0) [MonoCount],
					ISNULL(SUM([MonoPassCount]), 0) [MonoPassCount],
					ISNULL(SUM([MonoFailCount]), 0) [MonoFailCount]
				FROM	
				(				
					SELECT	[DateTimeCompleted] AS [Date],
							COUNT(DISTINCT [PartFaceDMC]) PartsCount,									
							CASE	WHEN [FinalResult] = 'PASS' THEN 1 ELSE 0 END AS [PassCount], 
							CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 ELSE 0 END AS [FailCount],
							COUNT(DISTINCT [MonoFaceDMC]) [MonoCount],				
							SUM(ISNULL(CASE	WHEN [FinalResult] = 'PASS' THEN 1 END,0)) [MonoPassCount],  
							SUM(ISNULL(CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END,0)) [MonoFailCount] 
					FROM	[A1494].[LineResults].[DenormalisedMegaView]
					WHERE	[PartFaceDMC] IS NOT NULL
							AND (CAST([DateTimeCompleted] AS DATE) >= @DateFrom OR @DateFrom IS NULL)
							AND (CAST([DateTimeCompleted] AS DATE) <= @DateTo OR @DateTo IS NULL) 
							AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
							AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
					GROUP BY [DateTimeCompleted],[FinalResult]
				)pc
				RIGHT JOIN #Dates dpc ON  CAST(pc.[Date] AS DATE) between dpc.StartDate and dpc.EndDate 
				GROUP BY dpc.[StartDate],dpc.EndDate
			)
			SELECT [Date], [This Week Position],[Part Count],[Pass Count], [Fail Count], ISNULL([Forced Part], 0) [Forced Part], [MonoCount], [MonoPassCount], [MonoFailCount]
			FROM Master_Data hd
			LEFT JOIN 
			(
				SELECT COUNT(DISTINCT [PartFaceDMC]) [Forced Part], hpc.[StartDate] [TimeStamp]								
				FROM [A1494].[LineResults].[DenormalisedMegaView]
				INNER JOIN #Dates hpc ON  CAST([MonoMeasuringTimeStamp] AS DATE) between hpc.[StartDate] AND hpc.[EndDate]
				WHERE FinalResult  = 'FAIL' AND [DateTimeCompleted] IS NULL	
				GROUP BY hpc.[StartDate]
			) t ON  t.[TimeStamp] BETWEEN [StartDate] AND [EndDate]
			ORDER BY hd.[This Week Position]

		END
		
	ELSE IF((@Period) = 'MONTHLY')
	BEGIN 	
		
		;WITH	[CTE] AS (
				SELECT	@DateFrom AS [cte_start_date]
				UNION	ALL
				SELECT	DATEADD(MONTH, 1, [cte_start_date])
				FROM	CTE
				WHERE	DATEADD(MONTH, 1, [cte_start_date]) <= @DateTo)
		INSERT	INTO #Dates ([StartDate], [EndDate])
		SELECT	CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, [cte_start_date]), 0) AS DATE) AS [StartDate],
				EOMONTH ([cte_start_date]) [EndDate]
		FROM	[CTE]	
					
			;With Master_Data AS
			(
				SELECT	
					CAST(DATENAME(MONTH, [StartDate]) AS VARCHAR(10)) + ', ' + CAST(YEAR([StartDate]) AS VARCHAR(10))  AS Date,
					MONTH(CAST([StartDate] AS DATE)) AS [This Month Position],
					dpc.[StartDate],
					dpc.[EndDate],
					ISNULL(SUM([PartsCount]), 0) [Part Count],
					ISNULL(SUM([PassCount]), 0) [Pass Count],
					ISNULL(SUM([FailCount]), 0) [Fail Count],				
					ISNULL(SUM([MonoCount]), 0) [MonoCount],
					ISNULL(SUM([MonoPassCount]), 0) [MonoPassCount],
					ISNULL(SUM([MonoFailCount]), 0) [MonoFailCount]
				FROM	(
				SELECT	[DateTimeCompleted] AS starttime,
							COUNT(DISTINCT [PartFaceDMC]) [PartsCount],									
							CASE	WHEN [FinalResult] = 'PASS' THEN 1 ELSE 0 END AS [PassCount], 
							CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 ELSE 0 END AS [FailCount],
							COUNT(DISTINCT MonoFaceDMC) [MonoCount],				
							SUM(ISNULL(CASE	WHEN [FinalResult] = 'PASS' THEN 1 END,0)) [MonoPassCount],  
							SUM(ISNULL(CASE	WHEN [FinalResult] = 'FAIL'  THEN 1 END,0)) [MonoFailCount] 
					FROM	[A1494].[LineResults].[DenormalisedMegaView]
					WHERE	[PartFaceDMC] IS NOT NULL
							AND (CAST([DateTimeCompleted] AS DATE) >= @DateFrom OR @DateFrom IS NULL)
							AND (CAST([DateTimeCompleted] AS DATE) <= @DateTo OR @DateTo IS NULL) 
							AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL) 
							AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
					GROUP BY [DateTimeCompleted],[FinalResult]
				) pc
				RIGHT JOIN #Dates dpc ON  CAST(pc.[StartTime] AS DATE) BETWEEN dpc.StartDate AND dpc.EndDate 
				GROUP BY dpc.[StartDate], dpc.[EndDate]
			)
			SELECT [Date], [This Month Position],[Part Count],[Pass Count], [Fail Count], ISNULL([Forced Part], 0) [Forced Part], [MonoCount], [MonoPassCount], [MonoFailCount]
			FROM Master_Data hd
			LEFT JOIN 
			(
				SELECT COUNT(DISTINCT PartFaceDMC) [Forced Part], hpc.[StartDate] [TimeStamp]								
				FROM [A1494].[LineResults].[DenormalisedMegaView]
				INNER JOIN #Dates hpc ON   CAST([MonoMeasuringTimeStamp] AS DATE) BETWEEN hpc.StartDate AND hpc.EndDate 
				WHERE [FinalResult]  = 'FAIL' AND [DateTimeCompleted] IS NULL	
				GROUP BY hpc.[StartDate]
			) t ON  t.[TimeStamp] BETWEEN [StartDate] AND [EndDate]
			ORDER BY [StartDate]

END
END
GO