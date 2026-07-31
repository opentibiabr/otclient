-- Weekly Task action types
WEEKLY_ACTION_SELECT_DIFFICULTY = 0
WEEKLY_ACTION_DELIVER_ITEM = 1
WEEKLY_ACTION_REFRESH_DATA = 2

MAX_WEEKLY_TRACKER_SLOTS = 9

-- Progress bar thresholds: completed tasks at each section boundary
WEEKLY_THRESHOLDS = {0, 4, 8, 12, 16, 18}
WEEKLY_SECTIONS = 5

-- Difficulties available for the weekly task board. The server does not send
-- this table in the 15.21 protocol, so it lives client-side.
WEEKLY_DIFFICULTIES = {
    { id = 1, name = "Beginner", minLevel = 8 },
    { id = 2, name = "Adept",    minLevel = 30 },
    { id = 3, name = "Expert",   minLevel = 150 },
    { id = 4, name = "Master",   minLevel = 300 }
}

-- Points rewarded per completed kill task, indexed by difficulty id.
WEEKLY_KILL_TASK_POINTS = {
    [1] = 25,  -- Beginner
    [2] = 50,  -- Adept
    [3] = 100, -- Expert
    [4] = 200  -- Master
}

-- Points rewarded per completed delivery task (same across difficulties).
WEEKLY_DELIVERY_TASK_POINTS = 75

-- Default number of task slots (kill or delivery) per week.
WEEKLY_DEFAULT_TASK_SLOTS = 6

-- Soulseal points rewarded per completed task.
WEEKLY_SOULSEAL_POINTS_PER_TASK = 1
