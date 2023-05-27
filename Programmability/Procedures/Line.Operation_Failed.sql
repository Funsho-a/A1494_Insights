SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [Line].[Operation_Failed]		
		@Period				VARCHAR(500) = 'DAILY',		
		@DateFrom			DATE = NULL,
		@DateTo				DATE = NULL,
		@Monolith			VARCHAR(1) = NULL,
    	@Variant			VARCHAR(3000) = NULL,
		@PartOutcome		VARCHAR(20) = NULL,
		@TopRecords			BIGINT = 9999999,
		@ThisDay			DATE = NULL,
		@Week				VARCHAR(20) = NULL,
		@Month				VARCHAR(20) = NULL


AS
BEGIN
	SET NOCOUNT ON

		DECLARE @StartDate		DATE,
				@EndDate		DATE,
				@sql			VARCHAR(MAX),
				@SELECT_Query	VARCHAR(MAX) = '',
				@Table_Query	VARCHAR(MAX),				
				@Where_Query	VARCHAR(MAX)

		IF ISNULL(@Variant,'0') = '0'
			SET @Variant = NULL
		IF @Monolith = '0'
			SET @Monolith = NULL		
		IF @ThisDay = '1999-01-01'
			SET @ThisDay = NULL
		IF @Week = '0'
			SET @Week = NULL
		IF @Month = '0'
			SET @Month = NULL
		IF ISNULL(@PartOutcome,'0') = '0'
			SET @PartOutcome = NULL
		IF @DateFrom ='1999-01-01' 
			SET @DateFrom = NULL 
		IF @DateTo ='2050-12-31'
			SET @DateTo  = NULL 


		IF(@DateFrom IS NULL AND @DateTo IS NULL)
		BEGIN	
			SELECT	@EndDate = MAX([DateTimeCompleted] ) ,
					@StartDate = Min([DateTimeCompleted] ) 
			FROM	[A1494].[LineResults].[DenormalisedMegaView]    --GET THE LAST AVAILABLE [MonoMeasuringTimeStamp] TO BE USED FOR END DATE
			WHERE	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL) 
					AND (CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
					AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)			

			IF((@Period) = 'HOURLY')	
				SET	@StartDate = @EndDate
			ELSE IF((@Period) = 'DAILY')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(DAY, -6, @EndDate),101) AS DATE) --GET THE PREVIOUS 8 DAYS DATE TO BE USED FOR START DATE
			ELSE IF((@Period) = 'WEEKLY')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
			ELSE IF((@Period) = 'MONTHLY')
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE		
		END
		ELSE IF((@Period) IS NOT NULL AND @DateFrom IS NOT NULL AND @DateTo IS NOT NULL)
		BEGIN
			SET	@EndDate = @DateTo  
			IF ((@Period) = 'DAILY')
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

		SELECT 
			[DateTimeCompleted] AS [Date],
			PartFaceDMC,
			MAX(CASE WHEN [Index] = 'A' THEN MonoFaceDMC ELSE NULL END) AS [A_MonoFaceDMC],
			MAX(CASE WHEN [Index] = 'B' THEN MonoFaceDMC ELSE NULL END) AS [B_MonoFaceDMC],
			[*Variant Name] AS [Variant Name],
			CASE WHEN [FinalResult] = 'PASS' THEN 'OK'  
			WHEN [FinalResult] IS NULL THEN 'Rework' 
			WHEN [FinalResult] = 'FAIL' THEN 'NOK' END AS [Final Result],
			MAX(CASE WHEN [Index] = 'A' THEN [Mono Overall Avg Diam (mm)] ELSE NULL END) AS [A_Mono Average Diameter (mm)],
			MAX(CASE WHEN [Index] = 'B' THEN [Mono Overall Avg Diam (mm)] ELSE NULL END) AS [B_Mono Average Diameter (mm)],
			MAX(CASE WHEN [Index] = 'A' THEN [Can Crit Overall Avg Diam (mm)] ELSE NULL END) AS [A_Can Average Diameter (mm)],
			MAX(CASE WHEN [Index] = 'B' THEN [Can Crit Overall Avg Diam (mm)] ELSE NULL END) AS [B_Can Average Diameter (mm)],
			MAX(CASE WHEN [Index] = 'A' THEN [Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) ELSE NULL END) AS [A_Mono Average level 1 (mm)],
			MAX(CASE WHEN [Index] = 'B' THEN [Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) ELSE NULL END) AS [B_Mono Average level 1 (mm)],
			MAX(CASE WHEN [Index] = 'A' THEN [Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) ELSE NULL END) AS [A_Mono Average level 2 (mm)],
			MAX(CASE WHEN [Index] = 'B' THEN [Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) ELSE NULL END) AS [B_Mono Average level 2 (mm)],
			MAX(CASE WHEN [Index] = 'A' THEN [Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) ELSE NULL END) AS [A_Mono Average level 3 (mm)],
			MAX(CASE WHEN [Index] = 'B' THEN [Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) ELSE NULL END) AS [B_Mono Average level 3 (mm)],
			MAX(CASE WHEN [Index] = 'A' THEN [Comp Crit Overall Avg GBD (g/cm^3)] ELSE NULL END) AS [A_Average GBD (g/cm^3)],
			MAX(CASE WHEN [Index] = 'B' THEN [Comp Crit Overall Avg GBD (g/cm^3)] ELSE NULL END) AS [B_Average GBD (g/cm^3)],
			MAX(CASE WHEN [Index] = 'A' 
				THEN [Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 4)
				ELSE NULL 
				END) AS [A_GBD Average level 1 (g/cm^3)],
			MAX(CASE WHEN [Index] = 'B' 
				THEN [Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 1)
				ELSE NULL 
				END) AS [B_GBD Average level 1 (g/cm^3)],
			MAX(CASE WHEN [Index] = 'A' 
				THEN [Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 5)
				ELSE NULL 
				END) AS [A_GBD Average level 2 (g/cm^3)],
			MAX(CASE WHEN [Index] = 'B' 
				THEN [Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 2)
				ELSE NULL 
				END) AS [B_GBD Average level 2 (g/cm^3)],
			MAX(CASE WHEN [Index] = 'A' 
				THEN [Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 6)
				ELSE NULL 
				END) AS [A_GBD Average level 3 (g/cm^3)],
			MAX(CASE WHEN [Index] = 'B' 
				THEN [Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 3)
				ELSE NULL 
				END) AS [B_GBD Average level 3 (g/cm^3)],
			MAX(CASE WHEN [Index] = 'A' THEN [Pressing Force (N)] ELSE NULL END) AS [A_Pressing Force (N)],
			MAX(CASE WHEN [Index] = 'B' THEN [Pressing Force (N)] ELSE NULL END) AS [B_Pressing Force (N)],
			MAX(CASE WHEN [Index] = 'A' THEN [Mat Mass (g)] ELSE NULL END) AS [A_Mat Mass (g)],
			MAX(CASE WHEN [Index] = 'B' THEN [Mat Mass (g)] ELSE NULL END) AS [B_Mat Mass (g)]
			INTO #FinalData
		FROM 
			[A1494].LineResults.DenormalisedMegaView			
		WHERE 
			[DateTimeCompleted] IS NOT NULL 
			AND PartFaceDMC IS NOT NULL
			AND	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
			AND	(CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
			AND	(CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
			AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
			AND [Index]	 =	CASE WHEN @Monolith IS NULL THEN [Index] ELSE @Monolith END 
			AND [*Variant Name]  =	CASE WHEN @Variant IS NULL THEN [*Variant Name] ELSE @Variant END 
			AND [FinalResult] = 'FAIL'					
		GROUP BY 
			[DateTimeCompleted],
			PartFaceDMC,
			[*Variant Name],
			[FinalResult]

		IF (@Period = 'HOURLY')
		BEGIN
			DECLARE @HDateFrom DATETIME = convert(varchar,@StartDate,101) 
			DECLARE @HDateTo DATETIME = @HDateFrom +' 23:59:59'

			CREATE TABLE #HourlyData (
				[ID] INT IDENTITY(1,1),
				[StartTime] DATETIME,
				[EndTime] DATETIME)
			INSERT INTO #HourlyData ([StartTime],[EndTime])
			SELECT	 StartTime = D
					,StopTime  = DateAdd(HOUR,1,D)
			FROM (
					SELECT TOP  (DateDiff(HOUR,@HDateFrom,@HDateTo)+1) 
							D=DateAdd(HOUR,-1+Row_Number() OVER (ORDER BY (SELECT NULL)),@HDateFrom) 
					FROM  master..spt_values n1
				 ) D 

		SET @Table_Query = 'FROM  #FinalData
							INNER JOIN #HourlyData hd ON [Date] BETWEEN hd.StartTime AND hd.EndTime '
		END
		ELSE 
		BEGIN
			SELECT  @Table_Query = 'FROM  #FinalData ' 
		END		
			
		SELECT @sql= 'SELECT TOP (' + CAST(@TopRecords as VARCHAR(20)) + ')  * '	
	
		IF((@Period) = 'WEEKLY')
		BEGIN
		SELECT @SELECT_Query = @SELECT_Query +
					' ,  DATEPART(wk,[Date]) AS [Week Position] ',
					@Where_Query  = CASE WHEN @Week IS NULL THEN '' ELSE ' WHERE CAST(DATEPART(wk,[Date]) AS VARCHAR(5)) = ' + @Week  END
		END
		ELSE IF((@Period) = 'MONTHLY')					
		BEGIN 	
		SELECT @SELECT_Query = @SELECT_Query + 
					' , MONTH(CAST([Date] AS DATE)) AS [Month_Position] ',
				@Where_Query  = CASE WHEN @Month IS NULL THEN '' ELSE ' WHERE  MONTH(CAST([Date] AS DATE)) = ' + @Month  END
		END
		SET @sql = @sql + @SELECT_Query + @Table_Query + CASE WHEN @Where_Query IS NULL THEN '' ELSE @Where_Query end + ' ORDER	BY [Date] DESC'		
		
		EXECUTE(@sql )
			
		DROP TABLE #FinalData
		IF ((@Period) = 'HOURLY')
			DROP TABLE #HourlyData			

END
GO