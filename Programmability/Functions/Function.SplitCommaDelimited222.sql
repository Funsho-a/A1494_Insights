SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [Function].[SplitCommaDelimited222]
(
    @Str VARCHAR(max)	-- Receive string input to be split
)
RETURNS @Values TABLE (
    Position INT,
    Value FLOAT
)
AS
BEGIN
    DECLARE @Split CHAR(1) = ','	-- Split character in received string
    
    -- Check if the input string is null or empty
    IF @Str IS NULL OR @Str = ''
        RETURN
    
    DECLARE @SplitCache TABLE (
        Position INT PRIMARY KEY,
        Value FLOAT
    )
    
    -- Split the input string and insert the results into the cache table
    INSERT INTO @SplitCache (Position, Value)
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), CAST(value AS FLOAT)
    FROM STRING_SPLIT(@Str, @Split)
    
    -- Return the split results as a table-valued result set
    INSERT INTO @Values (Position, Value)
    SELECT Position, Value FROM @SplitCache
    
    RETURN
END
GO