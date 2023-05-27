CREATE TABLE [MachineLearning].[GBDOutlier] (
  [index] [bigint] NULL,
  [DateTimeCompleted] [datetime] NULL,
  [MonoFaceDMC] [bigint] NULL,
  [Monolith] [varchar](max) NULL,
  [Variant] [varchar](max) NULL,
  [GBD] [float] NULL,
  [Level_1] [float] NULL,
  [Level_2] [float] NULL,
  [Level_3] [float] NULL,
  [Outlier] [bit] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [ix_MachineLearning_GBDOutlier_index]
  ON [MachineLearning].[GBDOutlier] ([index])
  ON [PRIMARY]
GO