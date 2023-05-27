CREATE TABLE [dbo].[GBDPredict] (
  [index] [bigint] NULL,
  [DateTimeCompleted] [datetime] NULL,
  [MonoFaceDMC] [bigint] NULL,
  [Monolith] [varchar](max) NULL,
  [Variant] [varchar](max) NULL,
  [GBD] [float] NULL,
  [Level 1] [float] NULL,
  [Level 2] [float] NULL,
  [Level 3] [float] NULL,
  [Monolith_encode] [bigint] NULL,
  [Predicted GBD] [float] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [ix_dbo_GBDPredict_index]
  ON [dbo].[GBDPredict] ([index])
  ON [PRIMARY]
GO