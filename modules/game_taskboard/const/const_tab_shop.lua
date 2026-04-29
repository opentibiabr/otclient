-- LuaFormatter off
-- Shop offer types
SHOP_OFFER_TYPE_ITEM             = 0
SHOP_OFFER_TYPE_MOUNT            = 1
SHOP_OFFER_TYPE_OUTFIT           = 2
SHOP_OFFER_TYPE_ITEM_DOUBLE      = 3
SHOP_OFFER_TYPE_BONUS_PROMOTION  = 4
SHOP_OFFER_TYPE_WEEKLY_EXPANSION = 5

SHOP_BACKDROP_IMAGES = {
    [SHOP_OFFER_TYPE_OUTFIT]          = '/game_taskboard/assets/images/backdrop_huntingtaskpoint_shop_outfit',
    [SHOP_OFFER_TYPE_MOUNT]           = '/game_taskboard/assets/images/backdrop_huntingtaskpoint_shop_Mount',
    [SHOP_OFFER_TYPE_ITEM]            = '/game_taskboard/assets/images/backdrop_huntingtaskpoint_shop_decoration',
    [SHOP_OFFER_TYPE_ITEM_DOUBLE]     = '/game_taskboard/assets/images/backdrop_huntingtaskpoint_shop_decoration',
    [SHOP_OFFER_TYPE_BONUS_PROMOTION] = '/game_taskboard/assets/images/backdrop_huntingtaskpoint_shop_boost',
}

-- Display texts for offer types that are not provided by the server (bonus promotion).
SHOP_BONUS_DEFAULTS = {
    [SHOP_OFFER_TYPE_BONUS_PROMOTION] = {
        title       = "Wheel Bonus",
        description = "Gain Wheel of Destiny promotion points.",
        image       = '/game_taskboard/assets/images/icon_tasksystem_promotionpoint'
    }
}

-- Purchase result codes from server
SHOP_ERR_NOT_FOUND    = 1
SHOP_ERR_ALREADY_BOUGHT = 2
SHOP_ERR_NO_POINTS    = 3
SHOP_ERR_NEED_BASE    = 4
SHOP_ERR_STORE_INBOX  = 5
-- LuaFormatter on
