SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [Process].[ProcessCapabilty]
	@Variant		VARCHAR(500) = NULL,
	@Monolith		VARCHAR(1) = NULL,
	@TopRecords		INT = 500

AS
BEGIN

	DECLARE @Avg FLOAT, 
			@sigmahat FLOAT, 
			@LSL FLOAT,
			@USL FLOAT,
			@count INT;
	
	
	-- Validate mandatory parameters
	--IF @Variant IS NULL OR @Variant = ''
	--	RETURN 
	IF @Monolith = '0'
			SET @Monolith = NULL
	-- Set default value for @TopRecords
	IF @TopRecords IS NULL
		SET @TopRecords = 500
	
	CREATE TABLE #SPC_Data(
		[PartFaceDMC] VARCHAR(50) NOT NULL,
		[GBD Measurement] FLOAT NULL,
		[Monolith Diameter Measurement] FLOAT NULL,
		[Pressing Force Measurement] FLOAT NULL,
		[GBD Upper Tol] FLOAT NULL,
		[Mono Diam Upper Tol] FLOAT NULL,
		[Force Max] FLOAT NULL,
		[GBD Lower Tol] FLOAT NULL,
		[Mono Diam Lower Tol] FLOAT NULL,
		[Force Min] FLOAT NULL,
		[Variant] [varchar](50) NOT NULL,
		[Date] [datetime] NULL,
		[Monolith] [varchar](1) NULL
		)

	INSERT INTO #SPC_Data
	SELECT	TOP (@TopRecords)	
			[MonoFaceDMC],
			CAST([Comp Crit Overall Avg GBD (g/cm^3)] AS FLOAT) AS [GBD Measurement],
			CAST([Mono Overall Avg Diam (mm)] AS FLOAT) AS [Monolith Diameter Measurement],
			CAST([Pressing Force (N)] AS FLOAT) AS [Pressing Force Measurement],
			CAST([*Comp Crit Overall Avg GBD Upper Tol (g/cm^3)] AS FLOAT) AS [GBD Upper Tol],
			CAST([*Mono Overall Avg Diam Upper Tol (mm)] AS FLOAT) AS [Mono Diam Upper Tol],
			CAST([*Pressing Force Max (N)] AS FLOAT) AS [Force Max],
			CAST([*Comp Crit Overall Avg GBD Lower Tol (g/cm^3)] AS FLOAT) AS [GBD Lower Tol],
			CAST([*Mono Overall Avg Diam Lower Tol (mm)] AS FLOAT) AS [Mono Diam Lower Tol],
			CAST([*Pressing Force Min (N)] AS FLOAT) AS [Force Min],
			[*Variant Name]  AS [Variant],
			[DateTimeCompleted] AS [Date],
			[Index] AS [Monolith]
	FROM	[A1494].[LineResults].[DenormalisedMegaView]
	WHERE	[PartFaceDMC] IS NOT NULL AND [Comp Crit Overall Avg GBD (g/cm^3)] IS NOT NULL AND [Mono Overall Avg Diam (mm)]IS NOT NULL AND [Pressing Force (N)] IS NOT NULL
			AND [Index] = CASE	WHEN @Monolith IS NULL THEN [Index] 	ELSE @Monolith END 
			AND [*Variant Name] = CASE	WHEN @Variant IS NULL THEN [*Variant Name]	ELSE @Variant END
	ORDER	BY [Date] DESC
		
	CREATE TABLE #Final_SPC
	(
		Process VARCHAR(1000),
		[Number of Data Points] FLOAT,
		[Average] FLOAT,
		[LSL]	FLOAT,
		[USL] FLOAT,
		[UCL] FLOAT,
		[LCL] FLOAT,
		[Standard Deviation] FLOAT,	
		[Cpk]	INT,
		[SPC Rule 1 Triggered (%)] FLOAT,
		[SPC Rule 2 Triggered (%)] FLOAT,
		[SPC Rule 3 Triggered (%)] FLOAT,	
		[SPC Rule 4 Triggered (%)] FLOAT,
		[Cpk Comment] VARCHAR(200)
	)

	CREATE TABLE #ControlTable
	(
		ControlProcess VARCHAR(1000)
	)
	
	DECLARE @ControlProcess VARCHAR(1000),
			@TriggeredRulePer3 FLOAT,
			@TriggeredRulePer4 FLOAT

	INSERT INTO #ControlTable 
	VALUES ('GBD Measurement'), ('Monolith Diameter Measurement'), ('Pressing Force Measurement')

	WHILE EXISTS (SELECT * FROM #ControlTable)
	BEGIN

			SELECT @ControlProcess = (SELECT TOP 1 ControlProcess
										FROM #ControlTable
										ORDER BY ControlProcess
										),
					@TriggeredRulePer3 = NULL,	
					@TriggeredRulePer4 = NULL
			SELECT	
					@sigmahat =  STDEV(CAST(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
								WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
								WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END AS FLOAT)), 
					@Avg = AVG(CAST(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
								WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
								WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END AS FLOAT)),
					@Count = Count([PartFaceDMC]),
					@USL = CASE WHEN @ControlProcess='GBD Measurement' THEN (SELECT MAX ([*Comp Crit Overall Avg GBD Upper Tol (g/cm^3)]) FROM [A1494].[LineResults].[DenormalisedMegaView])
							WHEN @ControlProcess='Monolith Diameter Measurement' THEN (SELECT MAX ([*Mono Overall Avg Diam Upper Tol (mm)]) FROM [A1494].[LineResults].[DenormalisedMegaView])
							 WHEN @ControlProcess='Pressing Force Measurement' THEN (SELECT MAX ([*Pressing Force Max (N)]) FROM [A1494].[LineResults].[DenormalisedMegaView]) END,
					@LSL = CASE WHEN @ControlProcess='GBD Measurement' THEN (SELECT MAX ([*Comp Crit Overall Avg GBD Lower Tol (g/cm^3)]) FROM [A1494].[LineResults].[DenormalisedMegaView])
							   WHEN @ControlProcess='Monolith Diameter Measurement' THEN (SELECT MAX ([*Mono Overall Avg Diam Lower Tol (mm)]) FROM [A1494].[LineResults].[DenormalisedMegaView])
								WHEN @ControlProcess='Pressing Force Measurement' THEN (SELECT MAX ([*Pressing Force Min (N)]) FROM [A1494].[LineResults].[DenormalisedMegaView]) END
					FROM #SPC_Data
							
			;WITH DeviationChart
			AS 
			(
				SELECT  
					@Avg AS [Average], 
					@sigmahat AS [Standard Deviation],
					@Avg + (3 * @sigmahat) AS [UCL],
					@Avg - (3 * @sigmahat) AS [LCL],
					MAX(CASE WHEN @ControlProcess = 'GBD Measurement' THEN [GBD Upper Tol] 
							WHEN @ControlProcess = 'Monolith Diameter Measurement' THEN [Mono Diam Upper Tol]
							WHEN @ControlProcess = 'Pressing Force Measurement' THEN [Force Max]
								END) AS [USL],
					MAX(CASE WHEN @ControlProcess = 'GBD Measurement' THEN [GBD Lower Tol] 
							WHEN @ControlProcess = 'Monolith Diameter Measurement' THEN [Mono Diam Lower Tol]
							WHEN @ControlProcess = 'Pressing Force Measurement' THEN [Force Min]
								END) AS [LSL],

		--------------------BOC Rule 1 --------------------------------------------------------------------
					CASE WHEN ROUND(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END,4) < ROUND(CAST(( @Avg - 3 * @sigmahat) AS FLOAT),4) OR
								ROUND(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END,4) > ROUND(CAST((@Avg + 3 * @sigmahat) AS FLOAT),4) 
						THEN  'TRUE' ELSE 'FALSE' END AS [RuleOneTriggered],
		--------------------EOC Rule 1 --------------------------------------------------------------------

		--------------------BOC Rule 2 --------------------------------------------------------------------
				-- Zone A -> 2 out of 3 consecutive points in Zone A or beyond
				--CASE WHEN 
				--	CASE 
				--		WHEN (CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END BETWEEN (@Avg + 2 * @sigmahat) AND (@Avg + 3 * @sigmahat)) THEN 1 
				--	END +
				--	CASE WHEN (LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END) OVER (ORDER BY date) BETWEEN (@Avg + 2 * @sigmahat) AND (@Avg + 3 * @sigmahat)) THEN 1 
				--	END +
				--	CASE WHEN (LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END, 2) OVER (ORDER BY date) BETWEEN (@Avg + 2 * @sigmahat) AND (@Avg + 3 * @sigmahat)) THEN 1 
				--	END >= 2 OR
				--	CASE 
				--		WHEN (CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END BETWEEN (@Avg - 3 * @sigmahat) AND (@Avg - 2 * @sigmahat)) THEN 1 
				--	END +
				--	CASE WHEN (LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END) OVER (ORDER BY date) BETWEEN (@Avg - 3 * @sigmahat) AND (@Avg - 2 * @sigmahat)) THEN 1 
				--	END +
				--	CASE WHEN (LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] END, 2) OVER (ORDER BY date) BETWEEN (@Avg - 3 * @sigmahat) AND (@Avg - 2 * @sigmahat)) THEN 1 
				--	END >= 2 THEN 'TRUE' ELSE 'FALSE' 
				--END AS [RuleTwoTriggered]

				---------------------------------------

			--CASE 
			--	WHEN (
			--		(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
			--			  WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
			--			  WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
			--		 END > @Avg + (2 * @sigmahat)) 
			--		AND 
			--		(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
			--			  WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
			--			  WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
			--		 END < @Avg - (2 * @sigmahat))
			--	) 
			--	OR 
			--	(
			--		(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
			--			  WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
			--			  WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
			--		 END > @Avg + (2 * @sigmahat)) 
			--		AND 
			--		(LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
			--				   WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
			--				   WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
			--			  END) OVER (ORDER BY date) > @Avg + (2 * @sigmahat))
			--	)
			--	OR 
			--	(
			--		(LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
			--				   WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
			--				   WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
			--			  END) OVER (ORDER BY date) > @Avg + (2 * @sigmahat))
			--		AND 
			--		(LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
			--				   WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
			--				   WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
			--			  END, 2) OVER (ORDER BY date) > @Avg + (2 * @sigmahat))
			--	)
			--	THEN 'TRUE' ELSE 'FALSE'
			--END AS [RuleTwoTriggered]

			--------------------------------

				CASE WHEN (
				(
					(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
						  WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
						  WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
					 END > @Avg + (2 * @sigmahat)) 
					OR 
					(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
						  WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
						  WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
					 END < @Avg - (2 * @sigmahat))
				) 
				AND 
				(
					(
						(LAG(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
								  WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
								  WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
							 END) OVER (ORDER BY date) > @Avg + (2 * @sigmahat))
						OR 
						(LAG(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
								  WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
								  WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
							 END) OVER (ORDER BY date) < @Avg - (2 * @sigmahat))
					)
					OR 
					(
						(LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
								   WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
								   WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
							  END) OVER (ORDER BY date) > @Avg + (2 * @sigmahat))
						OR 
						(LEAD(CASE WHEN @ControlProcess='GBD Measurement' THEN [GBD Measurement] 
								   WHEN @ControlProcess='Monolith Diameter Measurement' THEN [Monolith Diameter Measurement] 
								   WHEN @ControlProcess='Pressing Force Measurement' THEN [Pressing Force Measurement] 
							  END) OVER (ORDER BY date) < @Avg - (2 * @sigmahat))
					)
				)
			) THEN 'TRUE' ELSE 'FALSE'
			END AS [RuleTwoTriggered]






		--------------------EOC Rule 2 --------------------------------------------------------------------

			FROM #SPC_Data
			GROUP BY  [#SPC_Data].[Date],[#SPC_Data].[GBD Measurement],  #SPC_Data.[Monolith Diameter Measurement],  #SPC_Data.[Pressing Force Measurement]
			)
			INSERT INTO  #Final_SPC	(Process,[Number of Data Points], USL, Average, LSL,[UCL], [LCL],[Standard Deviation], Cpk, [SPC Rule 1 Triggered (%)], [SPC Rule 2 Triggered (%)])
			SELECT  DISTINCT @ControlProcess, @Count, USL,	Average, LSL, UCL, LCL,	[Standard Deviation],

                 CASE WHEN (@USL - @Avg) / (3 * @sigmahat) <  (@Avg - @LSL) / (3 * @sigmahat)
                 THEN (@USL - @Avg) / (3 * @sigmahat)
                 ELSE (@Avg - @LSL) / (3 * @sigmahat)  END AS [Cpk],

	
			(CAST([RuleOneCount] AS FLOAT) / @Count) * 100 AS [SPC Rule 1 Triggered (%)],
			(CAST([RuleTwoCount] AS FLOAT) / @Count) * 100 AS [SPC Rule 2 Triggered (%)]
			FROM DeviationChart

			CROSS APPLY (
				SELECT COUNT(CASE WHEN [RuleOneTriggered] = 'TRUE' THEN 1 ELSE NULL END) AS [RuleOneCount],
						COUNT(CASE WHEN [RuleTwoTriggered] = 'TRUE' THEN 1 ELSE NULL END) AS [RuleTwoCount]
				FROM DeviationChart 

			) t

		  ;WITH DeviationChart
		  AS 
		  (
			  SELECT *,
					 LAG(RuleThreeTriggered, 1) OVER (ORDER BY [Date]) LAG_is_within_range1,
					 LAG(RuleThreeTriggered, 2) OVER (ORDER BY [Date]) LAG_is_within_range2,
					 LAG(RuleThreeTriggered, 3) OVER (ORDER BY [Date]) LAG_is_within_range3,
					 LEAD(RuleThreeTriggered, 1) OVER (ORDER BY [Date]) LEAD_is_within_range1,
					 LEAD(RuleThreeTriggered, 2) OVER (ORDER BY [Date]) LEAD_is_within_range2,
					 LEAD(RuleThreeTriggered, 3) OVER (ORDER BY [Date]) LEAD_is_within_range3
			  FROM 
			  (
			 		SELECT DISTINCT	[Date],
						 --------------------BOC Rule 3 -------------------------------
						 -- Zone B -> 4 out of 5 consecutive points in Zone B or beyond
						 CASE
							WHEN (LAG([GBD Measurement], 1) OVER (ORDER BY [Date]) > round(CAST(( 2 * @sigmahat + @Avg) AS FLOAT),2) OR
								  round(CAST(( -2 * @sigmahat + @Avg) AS FLOAT),2) > LAG([GBD Measurement], 1) OVER (ORDER BY [Date]))
								AND ( round(CAST(( -2 * @sigmahat + @Avg) AS FLOAT),2) > round([GBD Measurement],2) OR 
									round([GBD Measurement],2) > round(CAST(( 2 * @sigmahat + @Avg) AS FLOAT),2) )
								AND (LEAD([GBD Measurement], 1) OVER (ORDER BY [Date]) > round(CAST(( 2 * @sigmahat + @Avg) AS FLOAT),2) OR
									  round(CAST(( -2 * @sigmahat + @Avg) AS FLOAT),2) > LEAD([GBD Measurement], 1) OVER (ORDER BY [Date]))
							THEN 1 ELSE 0 END AS RuleThreeTriggered
						--------------------EOC Rule 3 -------------------------------
					FROM #SPC_Data	
					WHERE  [Variant] = CASE WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 
								GROUP BY #SPC_Data.[Date],[#SPC_Data].[GBD Measurement]
				)t
		)
		SELECT DISTINCT @TriggeredRulePer3 =  (CAST([RuleThreeCount] as FLOAT) / @Count) * 100 
		FROM DeviationChart dc
		CROSS APPLY (
			SELECT COUNT(RuleThreeTriggered) AS [RuleThreeCount]
			FROM DeviationChart 
			WHERE (
				RuleThreeTriggered = 1
				AND LAG_is_within_range1 = 1
				AND LAG_is_within_range2 = 1
				AND LAG_is_within_range3 = 1
			) OR (
				RuleThreeTriggered = 1
				AND LEAD_is_within_range1 = 1
				AND LEAD_is_within_range1 = 1
				AND LEAD_is_within_range1 = 1
			)
		) t
		
		;with DeviationChart
		AS
		(
			SELECT DISTINCT								
					CASE 
						WHEN COUNT(*) >= 7 THEN 'TRUE' ELSE 'FALSE' 
					END AS RuleFourTriggered
			FROM (
				SELECT	[Date],
						CASE	WHEN round(CAST(( -1 * @sigmahat + @Avg) AS FLOAT),2) > round([GBD Measurement],2) OR 
									round([GBD Measurement],2) > round(CAST(( 1 * @sigmahat + @Avg) AS FLOAT),2) 
							THEN 1 ELSE 0 
						END AS within_range,
					ROW_NUMBER() OVER (ORDER BY [DATE]) AS row_num
				FROM #SPC_Data		
				WHERE  [Variant] = CASE WHEN @Variant IS NULL THEN [Variant] ELSE @Variant END 	
			) AS subquery
			GROUP BY 			
					[Date],					
					within_range					
			HAVING within_range = 1
		)
		SELECT DISTINCT @TriggeredRulePer4 = (CAST([RuleFourCount] as FLOAT) / @Count) * 100 
		FROM DeviationChart
		CROSS APPLY (
			SELECT COUNT(RuleFourTriggered) AS [RuleFourCount]
			FROM DeviationChart 
			WHERE RuleFourTriggered ='TRUE'
			)t

		UPDATE #Final_SPC  
		SET [SPC Rule 3 Triggered (%)] = @TriggeredRulePer3,	[SPC Rule 4 Triggered (%)] = @TriggeredRulePer4
		WHERE Process = @ControlProcess

		UPDATE #Final_SPC 
		SET [Cpk Comment]= CASE	WHEN [Cpk] BETWEEN 1 AND 1.333 THEN	'Poor'
							WHEN [Cpk] BETWEEN 1.33 AND 2 THEN	'Capable'
							WHEN [Cpk] > 2 THEN					'Excellent' 
							WHEN [Cpk] IS NULL THEN				'No Result'
							ELSE								'Not Capable' END 	


		DELETE #ControlTable
		WHERE ControlProcess = @ControlProcess

	END
	   
	SELECT * FROM #Final_SPC

	DROP TABLE #SPC_Data
	DROP TABLE #ControlTable
	DROP TABLE #Final_SPC
END





GO