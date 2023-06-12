SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [Process].[ProcessTrend]
		@Visualization		VARCHAR(500) = 'All',
		@Period				VARCHAR(500) = 'DAILY',		
		@DateFrom			DATE = '1999-01-01' ,
		@DateTo				DATE = '2050-12-31',
		@Monolith			VARCHAR(1) = '0',
    	@Variant			VARCHAR(3000) = '0',
		@PartOutcome		VARCHAR(20) = '0',
		@TopRecords			BIGINT = 0,
		@ThisDay			DATE = '1999-01-01',
		@Week				VARCHAR(20) =  '0',
		@Month				VARCHAR(20) =  '0',
		@MonolithMMResult	VARCHAR(20) =  '0',
		@GBDResult			VARCHAR(20) =  '0',
		@PressingResult		VARCHAR(20) =  '0',
		@MatWeightResult	VARCHAR(20) =  '0',
		@MarkingResult		VARCHAR(20) =  '0',
		@PartFaceDMC		VARCHAR(50) =  '0'


AS
BEGIN
	SET NOCOUNT ON

		DECLARE @StartDate		DATE,
				@EndDate		DATE,
				@sql			VARCHAR(MAX),
				@SELECT_Query	VARCHAR(MAX),
				@Table_Query	VARCHAR(MAX),				
				@Where_Query	VARCHAR(MAX)

		IF ISNULL(@Variant,'0') = '0' and ISNULL(@PartFaceDMC,'0') <> '0' 
			SET @Variant = NULL
		IF @Monolith = '0'
			SET @Monolith = NULL		
		--IF ISNULL(@TopRecords,0) = 0
		--	SET @TopRecords = NULL
		IF (@Visualization = 'All') AND @TopRecords = 0
			SET @TopRecords = 999999
			--SET @Period = 'Monthly'
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
		IF ISNULL(@PartFaceDMC,'0') = '0'
			SET @PartFaceDMC = NULL

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
			ELSE IF((@Period) =  'WEEKLY')	
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
			ELSE IF((@Period) =  'MONTHLY')
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
			ELSE IF((@Period) =  'WEEKLY')	
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom							
			END
			ELSE IF((@Period) =  'MONTHLY')
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -11, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom
			END	
		END

		;WITH [CTE]	AS (
				SELECT	TOP (@TopRecords)				
				[DateTimeCompleted] AS [Date],
				--FORMAT([DateTimeCompleted],'yyyy-MM-dd HH:mm') AS [Date],
				[PartFaceDMC],
				[MonoFaceDMC],
				[*Variant Name]  AS [Variant],
				[Index]  AS [Monolith],
				CASE 
					WHEN [FinalResult] = 'PASS' THEN 'OK'  
					WHEN [FinalResult] IS NULL THEN 'Rework' 
					WHEN [FinalResult] = 'FAIL' THEN 'NOK' 
					END AS [Part Outcome],
			-------------------------------------------------Mono / Levels-------------------------------------------------- 
				CAST([Mono Overall Avg Diam (mm)] AS FLOAT)  AS [Mono Diameter],
				CAST([*Mono Overall Avg Diam Lower Tol (mm)] AS FLOAT)  AS [Mono Diameter LSL],
				CAST([*Mono Overall Avg Diam Upper Tol (mm)] AS FLOAT)  AS [Mono Diameter USL],
				s2.Value1 AS [Mono Level 1],
				s2.Value2 AS [Mono Level 2],
				s2.Value3 AS [Mono Level 3],
				CASE	
				WHEN [Mono MM Result] = 'PASS' THEN 'OK'
				WHEN [Mono MM Result] = 'FAIL' THEN 'NOK' 
				END AS [Monolith Measurement Result],
			-------------------------------------------------Can / Levels-------------------------------------------------- 
			
				CAST([Can Crit Overall Avg Diam (mm)] AS FLOAT)  AS [Can Diameter],
				CAST([*Can Crit Overall Avg Diam Lower Tol (mm)] AS FLOAT)  AS [Can Diameter LSL],
				CAST([*Can Crit Overall Avg Diam Nom (mm)] AS FLOAT)  AS [Can Diameter USL],
				CASE [Index] 
					WHEN 'A' THEN s3.Value4 
					WHEN 'B' THEN s3.Value1 
					ELSE NULL 
				END AS [Can Level 1], 
				CASE [Index] 
					WHEN 'A' THEN s3.Value5 
					WHEN 'B' THEN s3.Value2 
					ELSE NULL 
				END AS [Can Level 2], 
				CASE [Index] 
					WHEN 'A' THEN s3.Value6 
					WHEN 'B' THEN s3.Value3 
					ELSE NULL 
				END AS [Can Level 3],
			-------------------------------------------------GBD / Levels-------------------------------------------------
				CAST([Comp Crit Overall Avg GBD (g/cm^3)] AS FLOAT)  AS [GBD],
				CAST([*Comp Crit Overall Avg GBD Lower Tol (g/cm^3)] AS FLOAT)  AS [GBD LSL],
				CAST([*Comp Crit Overall Avg GBD Upper Tol (g/cm^3)] AS FLOAT)  AS [GBD USL],
				CASE [Index] 
					WHEN 'A' THEN s1.Value4 
					WHEN 'B' THEN s1.Value1 
					ELSE NULL 
				END AS [GBD Level 1], 
				CASE [Index] 
					WHEN 'A' THEN s1.Value5 
					WHEN 'B' THEN s1.Value2 
					ELSE NULL 
				END AS [GBD Level 2], 
				CASE [Index] 
					WHEN 'A' THEN s1.Value6 
					WHEN 'B' THEN s1.Value3 
					ELSE NULL 
				END AS [GBD Level 3],
				CASE	
					WHEN [Total GBD MM Result] = 'PASS' THEN 'OK'
					WHEN [Total GBD MM Result] = 'FAIL' THEN 'NOK' 
				END AS [GBD Result],
			-------------------------------------------------Pressing------------------------------------------------- 
				CAST([Pressing Force (N)] AS FLOAT)  AS [Pressing Force (N)],
				CAST([*Pressing Force Min (N)] AS FLOAT)  AS [Pressing Force LSL],
				--CAST([*Pressing Force Max (N)] AS FLOAT)  AS [Pressing Force USL],
				CAST(10000 AS INT) AS [Pressing Force USL], ---Used this for POC only
				CASE	
					WHEN [Total Pressing Result] = 'PASS' THEN 'OK'
					WHEN [Total Pressing Result] = 'FAIL' THEN 'NOK'
					END AS  [Pressing Force Result],
			-------------------------------------------------Matweight------------------------------------------------- 
				CAST([Mat Mass (g)] AS FLOAT) AS [Mat Weight (g)],
				CAST([*Mat Min Mass (g)] AS FLOAT) AS [Mat Weight LSL],
				CAST([*Mat Max Mass (g)] AS FLOAT) AS [Mat Weight USL],
				CASE	
					WHEN [Mat Mass (g)] < [*Mat Min Mass (g)] THEN  'NOK'
					WHEN [Mat Mass (g)] > [*Mat Max Mass (g)] THEN 'NOK'
					ELSE 'OK'
				END AS  [Mat Weight Result],					
				
				CASE	
					WHEN [Marking Result] = 'PASS' THEN 'OK'
					WHEN [Marking Result] = 'FAIL' THEN  'NOK'
					END AS [Marking Result]

			FROM [A1494].LineResults.DenormalisedMegaView

			CROSS APPLY (
				SELECT 
					MAX(CASE WHEN Id = 1 THEN VALUE END) AS Value1,
					MAX(CASE WHEN Id = 2 THEN VALUE END) AS Value2,
					MAX(CASE WHEN Id = 3 THEN VALUE END) AS Value3
				FROM (
					SELECT 
						ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Id, 
						CAST(VALUE AS FLOAT) AS VALUE
					FROM STRING_SPLIT([Can Crit L1..6 Avg Diam (mm)], ','
					)
				) t
				WHERE Id BETWEEN 1 AND 3
			) s2
			CROSS APPLY (
				SELECT 
					MAX(CASE WHEN Id = 1 THEN value END) AS Value1,
					MAX(CASE WHEN Id = 2 THEN value END) AS Value2,
					MAX(CASE WHEN Id = 3 THEN value END) AS Value3,
					MAX(CASE WHEN Id = 4 THEN value END) AS Value4,
					MAX(CASE WHEN Id = 5 THEN value END) AS Value5,
					MAX(CASE WHEN Id = 6 THEN value END) AS Value6
				FROM (
					SELECT 
						ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Id, 
						CAST(value AS FLOAT) AS value
					FROM STRING_SPLIT([Comp Crit L1..6 Avg GBD (g/cm^3)], ','
					)
				) t
				WHERE Id BETWEEN 1 AND 6
			) s1

			CROSS APPLY (
				SELECT 
					MAX(CASE WHEN Id = 1 THEN value END) AS Value1,
					MAX(CASE WHEN Id = 2 THEN value END) AS Value2,
					MAX(CASE WHEN Id = 3 THEN value END) AS Value3,
					MAX(CASE WHEN Id = 4 THEN value END) AS Value4,
					MAX(CASE WHEN Id = 5 THEN value END) AS Value5,
					MAX(CASE WHEN Id = 6 THEN value END) AS Value6
				FROM (
					SELECT 
						ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Id, 
						CAST(value AS FLOAT) AS value
					FROM STRING_SPLIT([Comp Crit L1..6 Avg GBD (g/cm^3)], ','
					)
				) t
				WHERE Id BETWEEN 1 AND 6
			) s3

			WHERE [PartFaceDMC] IS NOT NULL
				AND	(CAST([DateTimeCompleted] AS DATE) >= @StartDate OR @StartDate IS NULL)
				AND	(CAST([DateTimeCompleted] AS DATE) <= @EndDate OR @EndDate IS NULL)
				AND	(CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
				AND (CAST([DateTimeCompleted] AS DATE) = @ThisDay OR @ThisDay IS NULL)
				AND [Index]	 =	CASE WHEN @Monolith IS NULL THEN [Index] ELSE @Monolith END 
				AND [*Variant Name]  =	CASE WHEN @Variant IS NULL THEN [*Variant Name] ELSE @Variant END 
				AND [PartFaceDMC]  =	CASE WHEN @PartFaceDMC IS NULL THEN [PartFaceDMC] ELSE @PartFaceDMC END				
				ORDER BY [date] desc
			)
		SELECT  
		[Date],[MonoFaceDMC], [Monolith], [Variant], [Part Outcome],
		[Mono Diameter],[Mono Diameter LSL],[Mono Diameter USL],
		[Mono Level 1],[Mono Level 2],[Mono Level 3],
		[Can Diameter],[Can Diameter LSL],[Can Diameter USL],
		[Can Level 1],[Can Level 2],[Can Level 3],
		[GBD], [GBD LSL], [GBD USL],
		[GBD Level 1],[GBD Level 2],[GBD Level 3],	
		[Pressing Force (N)], [Pressing Force LSL], [Pressing Force USL], [Pressing Force Result], 
		[Mat Weight (g)], [Mat Weight Result], [Mat Weight LSL], [Mat Weight USL],
		[Monolith Measurement Result],[GBD Result],
		[Marking Result]
		INTO #FinalData
		FROM	[CTE] c
		WHERE	
			
				[Part Outcome]					=		CASE	WHEN @PartOutcome IS NULL 
																THEN [Part Outcome] 
																ELSE @PartOutcome END	AND
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
			
		SELECT @sql= 'SELECT TOP (' + CAST(@TopRecords as VARCHAR(20)) + ')  [Date],[MonoFaceDMC],[Variant],[Monolith],[Part Outcome], '	

		IF(@Visualization ='All')
		BEGIN
			SELECT @SELECT_Query = '[Mono Diameter], [Mono Diameter LSL], [Mono Diameter USL],  [Monolith Measurement Result],
									[Mono Level 1],[Mono Level 2],[Mono Level 3],
									[Can Diameter], [Can Diameter LSL], [Can Diameter USL],
									[Can Level 1], [Can Level 2], [Can Level 3],
									[GBD Level 1],[GBD Level 2],[GBD Level 3],[GBD Result],
									[Pressing Force (N)], [Pressing Force LSL], [Pressing Force USL], [Pressing Force Result],
									[Mat Weight (g)], [Mat Weight LSL], [Mat Weight USL], [Mat Weight Result],[Marking Result]
									'					
		END
		ELSE IF(@Visualization ='Mono')
		BEGIN
			SELECT @SELECT_Query = '[Mono Diameter], [Mono Diameter LSL], [Mono Diameter USL],  [Monolith Measurement Result]'					
		END
		IF(@Visualization ='MonoLevel')
		BEGIN
			SELECT @SELECT_Query = 
									'[Mono Level 1], [Mono Level 2], [Mono Level 3], [Monolith Measurement Result]'					
		END
		ELSE IF(@Visualization ='Can')
		BEGIN
			SELECT @SELECT_Query = '[Can Diameter], [Can Diameter LSL], [Can Diameter USL]'					
		END
		IF(@Visualization ='CanLevel')
		BEGIN
			SELECT @SELECT_Query = 
									'[Can Level 1], [Can Level 2], [Can Level 3]'					
		END
		ELSE IF(@Visualization ='GBD')
		BEGIN
			SELECT @SELECT_Query = '[GBD], [GBD LSL], [GBD USL], [GBD Result]'
		END
		ELSE IF(@Visualization ='GBDLevel')
		BEGIN
			SELECT @SELECT_Query = '[GBD Level 1], [GBD Level 2], [GBD Level 3], [GBD Result]'
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