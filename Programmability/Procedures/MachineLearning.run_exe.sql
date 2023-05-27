SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [MachineLearning].[run_exe]
AS
BEGIN
  EXEC xp_cmdshell 'C:\Users\funshoa\Desktop\ODIN_Insights_AI\A1494_AutoEncoder\myapp.exe'
END
GO