SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE   FUNCTION [Function].[GetDateFromPeriod]
	(
		@Period		VARCHAR(500),		
		@DateFrom	DATE = NULL,
		@DateTo		DATE = NULL,
		@ThisDay	DATE = NULL
	)
RETURNS @Dates TABLE 
	(
		StartDate	DATE  NULL,
		EndDate		DATE  NULL
	)
AS
BEGIN
	DECLARE @StartDate	DATE = NULL,
			@EndDate	DATE = NULL

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
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -7, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE
			ELSE IF((@Period) = 'MONTHLY')
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE		
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
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(WEEK, -7, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 WEEKS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom							
			END
			ELSE IF((@Period) = 'MONTHLY')
			BEGIN
				SET	@EndDate = @DateTo
				SET	@StartDate = CAST(CONVERT(VARCHAR,DATEADD(MONTH, -3, @EndDate),101) AS DATE) --GET THE PREVIOUS 13 MONTHS DAYS DATE TO BE USED FOR START DATE

				IF(@StartDate < @DateFrom)
					SET @StartDate = @DateFrom
			END	
		END
		
		INSERT @Dates
        SELECT @StartDate, @EndDate

		RETURN

END
GO