-- Bounty Task action types (must match BountyActionType on server)
-- LuaFormatter off
BOUNTY_ACTION_REROLL            = 0
BOUNTY_ACTION_SELECT            = 1
BOUNTY_ACTION_CLAIM_REWARD      = 2
BOUNTY_ACTION_CHANGE_DIFFICULTY = 3
BOUNTY_ACTION_REQUEST           = 4
BOUNTY_ACTION_CLAIM_DAILY       = 5

-- Bounty Preferred action types
BOUNTY_PREF_ACTION_REQUEST          = 0
BOUNTY_PREF_ACTION_BUY_SLOT         = 1
BOUNTY_PREF_ACTION_SET_PREFERRED    = 2
BOUNTY_PREF_ACTION_SET_UNWANTED     = 3
BOUNTY_PREF_ACTION_REMOVE_PREFERRED = 4
BOUNTY_PREF_ACTION_REMOVE_UNWANTED  = 5
-- LuaFormatter on
BOUNTY_PREF_BATCH_SIZE = 10

TALISMAN_ICONS = {
    [1] = '/game_taskboard/assets/images/icon-bountyring-damageagainstmonster',
    [2] = '/game_taskboard/assets/images/icon-bountyring-lifeleech',
    [3] = '/game_taskboard/assets/images/icon-bountyring-moreloot',
    [4] = '/game_taskboard/assets/images/icon-bountyring-doublebestiarychance'
}

TALISMAN_TITLES = {
    [1] = 'Damage Against\nCreatures',
    [2] = 'Life Leech',
    [3] = 'More Loot',
    [4] = 'Chance for Double\nBeast Scroll Progress'
}

REROLL_TOKEN_CAP = 10

RARITY_BACKDROPS = {
    [0] = '/game_taskboard/assets/images/backdrop_tasksystem_normal_task',
    [1] = '/game_taskboard/assets/images/backdrop_tasksystem_silver_task',
    [2] = '/game_taskboard/assets/images/backdrop_tasksystem_gold_task'
}
