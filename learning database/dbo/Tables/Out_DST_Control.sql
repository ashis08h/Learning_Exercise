CREATE TABLE [dbo].[Out_DST_Control] (
    [WeekDayName]         VARCHAR (15) NULL,
    [CurrentFreqInterval] INT          NULL,
    [Flag]                VARCHAR (2)  NULL,
    [CurrentSchedule]     DATETIME     NULL,
    [NewSchedule]         DATETIME     NULL,
    [NewWeekDayName]      VARCHAR (15) NULL,
    [NewFreqInterval]     INT          NULL
);

