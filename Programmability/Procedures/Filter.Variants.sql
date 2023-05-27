SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [Filter].[Variants]
	@VariantID  AS VARCHAR (MAX) = NULL
AS
BEGIN
WITH CTE AS	(
	SELECT	DISTINCT [*Variant Name] AS [Variant Name],
				[*Variant Name]   AS [Variant ID]
FROM    [A1494].LineResults.DenormalisedMegaView 
	)
SELECT	 CAST([Variant ID] AS VARCHAR (MAX)) AS [Variant ID], 
		CASE	WHEN [Variant ID] IS NULL THEN 'NULL'
				WHEN [Variant ID] = @VariantID
				THEN [Variant Name]  + '   '
				ELSE RTRIM([Variant Name]) END  AS [Variant Name]
FROM	CTE
WHERE [Variant Name] IS NOT NULL
ORDER	BY CAST([Variant Name] AS VARCHAR(500))

END 
GO