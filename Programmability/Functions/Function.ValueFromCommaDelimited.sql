SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE      FUNCTION [Function].[ValueFromCommaDelimited]
(
	@Str VARCHAR(max),  --Receive String input to be splitted
	@Pos INT			--Receive input for position
)
RETURNS FLOAT AS		--
BEGIN 

	DECLARE @Split CHAR(1) = ',',	--split character in received string
			@X xml,					--declare xml field to perform the split
			@returnValue FLOAT		--declare float value to be retured by function

	DECLARE @table TABLE			--Table to store splitted values
	( 
		Id INT IDENTITY(1,1),		--ID auto increment valued to get the ID's
		value FLOAT					--Save the splitted float value
	)

	--Logic to convert the input string into xml format
	SELECT @X = CONVERT(xml,' <root> <myvalue>' + REPLACE(@Str,@Split,'</myvalue> <myvalue>') + '</myvalue>   </root> ')

	--Split the xml into rows and save the result into a temp table
	INSERT INTO @table (value)
	SELECT  [T].[c].value('.','varchar(20)')      
	FROM @X.nodes('/root/myvalue') [T]([c])

	--Get the float value based on the input position
	SELECT @returnValue = value  
	FROM @table 
	WHERE ID = @Pos

	RETURN @returnValue --Return the selected float value

END; 
GO