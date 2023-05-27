SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [Line].[Operation(OLDCombined)]
		@Visualization		VARCHAR(500) = NULL,
		@Period				VARCHAR(500) = NULL,		
		@DateFrom			DATE = NULL,
		@DateTo				DATE = NULL,
		@Monolith			VARCHAR(1) = NULL,
    	@Variant			VARCHAR(3000) = NULL,
		@FinalResult		VARCHAR(20) = NULL,
		@TopRecords			BIGINT = NULL,
		@ThisDay			DATE = NULL,
		@Week				VARCHAR(20) = NULL,
		@Month				VARCHAR(20) = NULL,
		@MonolithMMResult	VARCHAR(20) = NULL,
		@GBDResult			VARCHAR(20) = NULL,
		@PressingResult		VARCHAR(20) = NULL,
		@MatWeightResult	VARCHAR(20) = NULL,
		@MarkingResult		VARCHAR(20) = NULL

AS
BEGIN
	SET NOCOUNT ON

		DECLARE @StartDate		DATE,
				@EndDate		DATE,
				@sql			VARCHAR(MAX),
				@SELECT_Query	VARCHAR(MAX),
				@Table_Query	VARCHAR(MAX),				
				@Where_Query	VARCHAR(MAX)

		IF ISNULL(@Variant,'0') = '0'
			SET @Variant = NULL
		IF @Monolith = '0'
			SET @Monolith = NULL		
		IF ISNULL(@TopRecords,0) = 0
			SET @TopRecords = 0
		IF (@Visualization = 'All') and @TopRecords = 0
			SET @TopRecords = 9999999999
		IF @ThisDay = '1999-01-01'
			SET @ThisDay = NULL
		IF @Week = '0'
			SET @Week = NULL
		IF @Month = '0'
			SET @Month = NULL
		IF ISNULL(@FinalResult,'0') = '0'
			SET @FinalResult = NULL
		IF @DateFrom ='1999-01-01' 
			SET @DateFrom = NULL 
		IF @DateTo ='2050-12-31'
			SET @DateTo  = NULL 
		IF ISNULL(@MonolithMMResult,'0') = '0'
			SET @MonolithMMResult = NULL
		IF ISNULL(@GBDResult,'0') = '0'
			SET @GBDResult = NULL
		IF ISNULL(@PressingResult,'0') = '0'
			SET @PressingResult	= NULL
		IF ISNULL(@MatWeightResult,'0') = '0'
			SET @MatWeightResult = NULL
		IF ISNULL(@MatWeightResult,'0') = '0'
			SET @MatWeightResult = NULL
		IF ISNULL(@MarkingResult,'0') = '0'
			SET @MarkingResult = NULL


		IF(@DateFrom IS NULL AND @DateTo is NULL)
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
		ELSE IF((@Period) IS NOT NULL AND @DateFrom IS NOT NULL AND @DateTo is NOT NULL)
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


		;WITH [CTE]	AS (
				SELECT	DISTINCT	TOP (@TopRecords)
						[PartFaceDMC],
						FORMAT([DateTimeCompleted],'yyyy-MM-dd HH:mm') AS [Date],
						[MonoFaceDMC],
						[Index]  AS [Monolith],
						[*Variant Name]  AS [Variant],
						CASE	WHEN [FinalResult] = 'PASS' THEN 'OK'  
								WHEN [FinalResult] IS NULL THEN 'Rework' 
								WHEN [FinalResult] = 'FAIL' THEN 'NOK' 
									END AS [Final Result],

						---Mono / Levels Fields 
 						CASE	WHEN (ISNULL( CAST([Mono Overall Avg Diam (mm)] AS FLOAT), 1)) = 0 THEN 1 ELSE  CAST([Mono Overall Avg Diam (mm)] AS FLOAT) END AS [Mono Average Diameter (mm)],
						CASE	WHEN CAST(ISNULL([*Mono Overall Avg Diam Lower Tol (mm)], 0) AS FLOAT) <= 0 THEN 1 ELSE CAST([*Mono Overall Avg Diam Lower Tol (mm)] AS FLOAT) END AS [Mono Diameter LSL],
						CASE	WHEN CAST(ISNULL([*Mono Overall Avg Diam Upper Tol (mm)], 0) AS FLOAT) <= 0 THEN 1 ELSE CAST([*Mono Overall Avg Diam Upper Tol (mm)] AS FLOAT) END AS [Mono Diameter USL],
						--CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 1) AS FLOAT) END AS [Mono Average level 1 (mm)],
						--CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 2) AS FLOAT) END AS [Mono Average level 2 (mm)],
						--CASE	WHEN (ISNULL( CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT), 1)) = 0 THEN 1 ELSE   CAST([Function].[ValueFromCommaDelimited]([Mono L1..3 Avg Diam (mm)], 3) AS FLOAT) END AS [Mono Average level 3 (mm)],				
						CASE	WHEN [Mono MM Result] = 'PASS' THEN 'OK'
								WHEN [Mono MM Result] = 'FAIL' THEN 'NOK' 
								END AS [Monolith Measurement Result],

						---GBD /Levels
						CASE	WHEN (ISNULL( CAST([Comp Crit Overall Avg GBD (g/cm^3)] AS FLOAT), 1)) = 0 THEN 1 ELSE  CAST([Comp Crit Overall Avg GBD (g/cm^3)] AS FLOAT) END AS [Average GBD (g/cm^3)],
						CASE	WHEN (ISNULL( CAST([*Comp Crit Overall Avg GBD Lower Tol (g/cm^3)] AS FLOAT), 1)) = 0 THEN 1 ELSE  CAST([*Comp Crit Overall Avg GBD Lower Tol (g/cm^3)] AS FLOAT) END AS [GBD LSL],
						CASE	WHEN (ISNULL( CAST([*Comp Crit Overall Avg GBD Upper Tol (g/cm^3)] AS FLOAT), 1)) = 0 THEN 1 ELSE CAST([*Comp Crit Overall Avg GBD Upper Tol (g/cm^3)] AS FLOAT) END AS [GBD USL],
						--CASE	WHEN [Index] = 'A' THEN
						--		CASE WHEN ISNULL(CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 4) AS FLOAT), 0.0001) = 0 THEN 0.0001
						--		ELSE CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 4) AS FLOAT)
						--		END										
						--		ELSE CASE WHEN ISNULL(CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 1) AS FLOAT), 0.0001) = 0 THEN 0.0001
						--		ELSE CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 1) AS FLOAT)
						--		END	
						--		END AS [GBD Average level 1 (g/cm^3)],
						--CASE	WHEN [Index] = 'A' THEN
						--		CASE WHEN ISNULL(CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 5) AS FLOAT), 0.0001) = 0 THEN 0.0001
						--		ELSE CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 5) AS FLOAT)
						--		END
						--		ELSE CASE WHEN ISNULL(CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 2) AS FLOAT), 0.0001) = 0 THEN 0.0001
						--		ELSE CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 2) AS FLOAT)
						--		END
						--		END AS [GBD Average level 2 (g/cm^3)],
						--CASE	WHEN [Index] = 'A' THEN
						--		CASE  WHEN ISNULL(CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 6) AS FLOAT), 0.0001) = 0 THEN 0.0001
						--		ELSE CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 6) AS FLOAT)
						--		END
						--		ELSE CASE WHEN ISNULL(CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 3) AS FLOAT), 0.0001) = 0 THEN 0.0001
						--		ELSE CAST([Function].[ValueFromCommaDelimited]([Comp Crit L1..6 Avg GBD (g/cm^3)], 3) AS FLOAT)
						--		END
						--		END AS [GBD Average level 3 (g/cm^3)],
						CASE	WHEN [Total GBD MM Result] = 'PASS' THEN 'OK'
								WHEN [Total GBD MM Result] = 'FAIL' THEN 'NOK' 
								END AS [GBD Result],
					
						---Pressing Fields 
						CASE	WHEN (ISNULL( CAST([Pressing Force (N)] AS FLOAT), 1)) = 0 THEN 1 ELSE  CAST([Pressing Force (N)] AS FLOAT) END AS [Pressing Force (N)],
						CASE	WHEN (ISNULL( CAST([*Pressing Force Min (N)] AS FLOAT), 1)) = 0 THEN 1 ELSE  CAST([*Pressing Force Min (N)] AS FLOAT) END AS [Pressing Force LSL],
						CASE	WHEN (ISNULL( CAST([*Pressing Force Max (N)] AS FLOAT), 1)) = 0 THEN 1 ELSE  CAST([*Pressing Force Max (N)] AS FLOAT) END AS [Pressing Force USL],
						CASE	WHEN [Total Pressing Result] = 'PASS' THEN 'OK'
								WHEN [Total Pressing Result] = 'FAIL' THEN 'NOK'
								END AS  [Pressing Force Result],

						---Matweight Fields 
						CASE	WHEN (ISNULL( CAST([Mat Mass (g)] AS FLOAT), 0.0001)) = 0 THEN  0.0001 ELSE  CAST([Mat Mass (g)] AS FLOAT) END AS [Mat Weight (g)],
						CASE	WHEN (ISNULL( CAST([*Mat Min Mass (g)] AS FLOAT),  0.0001)) = 0 THEN  0.0001 ELSE CAST([*Mat Min Mass (g)] AS FLOAT) END AS [Mat Weight LSL],
						CASE	WHEN (ISNULL( CAST([*Mat Max Mass (g)] AS FLOAT),  0.0001)) = 0 THEN  0.0001 ELSE   CAST([*Mat Max Mass (g)] AS FLOAT) END AS [Mat Weight USL],
						CASE	WHEN [Mat Mass (g)] < [*Mat Min Mass (g)] THEN  'NOK'
								WHEN [Mat Mass (g)] > [*Mat Max Mass (g)] THEN 'NOK'
								ELSE 'OK'END AS  [Mat Weight Result],					
					
						CASE	WHEN [Marking Result] = 'PASS' THEN 'OK'
								WHEN [Marking Result] = 'FAIL' THEN  'NOK'
							END AS  [Marking Result]

				FROM    [A1494].LineResults.DenormalisedMegaView 
				WHERE	[PartFaceDMC] IS NOT NULL
				AND	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND	(CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND	(CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
				AND [Index]	 =	CASE	WHEN @Monolith IS NULL THEN [Index] ELSE @Monolith END 
				AND [*Variant Name]  =	CASE	WHEN @Variant IS NULL THEN [*Variant Name] ELSE @Variant END 
				ORDER	BY [Date] DESC
			)
		SELECT  [PartFaceDMC],	[Date],[MonoFaceDMC], [Monolith],	[Variant], [Final Result],
		[Mono Average Diameter (mm)],[Mono Diameter LSL],[Mono Diameter USL],
		--[Mono Average level 1 (mm)],[Mono Average level 2 (mm)],[Mono Average level 3 (mm)],
		[Average GBD (g/cm^3)], [GBD LSL],	[GBD USL],
		--[GBD Average level 1 (g/cm^3)],[GBD Average level 2 (g/cm^3)],[GBD Average level 3 (g/cm^3)],	
		[Pressing Force (N)], [Pressing Force LSL], [Pressing Force USL], [Pressing Force Result], 
		[Mat Weight (g)], [Mat Weight Result], [Mat Weight LSL], [Mat Weight USL],
		[Monolith Measurement Result],[Marking Result],[GBD Result]
		INTO #FinalData
		FROM	[CTE] c
		WHERE	
					
				[Final Result]					=		CASE	WHEN @FinalResult IS NULL 
																THEN [Final Result] 
																ELSE @FinalResult END	AND
				[Monolith Measurement Result]   =		CASE	WHEN @MonolithMMResult	 IS NULL 
																THEN [Monolith Measurement Result] 
																ELSE @MonolithMMResult	 END	AND
				[GBD Result]					=		CASE	WHEN @GBDResult IS NULL 
																THEN [GBD Result] 
																ELSE @GBDResult END	AND
				[Pressing Force Result]			=		CASE	WHEN @PressingResult IS NULL 
																THEN [Pressing Force Result] 
																ELSE @PressingResult END	AND
				[Mat Weight Result]				=		CASE	WHEN @MatWeightResult IS NULL 
																THEN [Mat Weight Result] 
																ELSE @MatWeightResult END	AND
				[Marking Result]				=		CASE	WHEN @MarkingResult IS NULL 
																THEN [Marking Result] 
																ELSE @MarkingResult END	

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

		SET @Table_Query = '	FROM  #FinalData
								INNER JOIN #HourlyData hd ON [Date] BETWEEN hd.StartTime AND hd.EndTime '
		END
		ELSE 
		BEGIN
			SELECT  @Table_Query = ' FROM  #FinalData ' 
		END

			
		SELECT @sql= 'SELECT  [MonoFaceDMC],[PartFaceDMC],[Date],[Monolith],[Variant],[Final Result], '				

		IF(@Visualization ='All')
		BEGIN
			SELECT @SELECT_Query = '[Mono Average Diameter (mm)], [Mono Diameter LSL], [Mono Diameter USL],  [Monolith Measurement Result],
									[Mono Average level 1 (mm)],[Mono Average level 2 (mm)],[Mono Average level 3 (mm)],
									[GBD Average level 1 (g/cm^3)],[GBD Average level 2 (g/cm^3)],[GBD Average level 3 (g/cm^3)],
									[Pressing Force (N)], [Pressing Force LSL], [Pressing Force USL], [Pressing Force Result],
									[Mat Weight (g)], [Mat Weight LSL], [Mat Weight USL], [Mat Weight Result],[Marking Result]
									'					
		END
		ELSE IF(@Visualization ='Mono')
		BEGIN
			SELECT @SELECT_Query = '[Mono Average Diameter (mm)], [Mono Diameter LSL], [Mono Diameter USL],  [Monolith Measurement Result]'					
		END
		ELSE IF(@Visualization ='MonoLevel')
		BEGIN
			SELECT @SELECT_Query = 
									'[Mono Average Diameter (mm)], [Monolith Measurement Result],
									[Mono Average level 1 (mm)]AS [Mono Level 1], 
									[Mono Average level 2 (mm)] AS [Mono Level 2],
									[Mono Average level 3 (mm)] AS [Mono Level 3]'					
		END
		ELSE IF(@Visualization ='GBD')
		BEGIN
			SELECT @SELECT_Query = '[Average GBD (g/cm^3)], [GBD LSL], [GBD USL], [GBD Result]'
		END
		ELSE IF(@Visualization ='GBDLevel')
		BEGIN
			SELECT @SELECT_Query = '[Average GBD (g/cm^3)], [GBD Result], 
									[GBD Average level 1 (g/cm^3)] AS [GBD Average level 1 (g/cm^3)], 
									[GBD Average level 2 (g/cm^3)] AS [GBD Average level 2 (g/cm^3)],
									[GBD Average level 3 (g/cm^3)] AS [GBD Average level 3 (g/cm^3)]'
		END
		ELSE IF(@Visualization ='PressingForce')
		BEGIN
			SELECT @SELECT_Query = '[Pressing Force (N)], [Pressing Force LSL], [Pressing Force USL], [Pressing Force Result]'
		END
		ELSE IF(@Visualization ='MatWeight')
		BEGIN
			SELECT @SELECT_Query = '[Mat Weight (g)], [Mat Weight LSL], [Mat Weight USL], [Mat Weight Result]'
		END
	
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