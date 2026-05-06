InspectConst = {
    HTML_PATH = "template/html/inspect.html",

    SLOT_INACTIVE_SOURCE      = "/images/game/imbuing/slot_inactive",
    SLOT_ACTIVE_SOURCE_PREFIX = "/images/game/imbuing/icons/",
    SLOT_EMPTY_CLIP           = "0 0 64 64",

    CYCLOPEDIA_VIEW_INVENTORY = 1,
    CYCLOPEDIA_VIEW_OUTFIT    = 2,

    CYCLOPEDIA_PLAYER_ICON    = "/game_cyclopedia/images/icon-playerdetails",
    CYCLOPEDIA_EQUIPMENT_ICON = "/game_cyclopedia/images/icon-equipmentdetails",

    CYCLOPEDIA_SLOT_BORDER          = "#16161600",
    CYCLOPEDIA_SELECTED_SLOT_BORDER = "#ffffff",

    CYCLOPEDIA_SLOT_WIDGETS = {
        [0] = "headSlot",
        [1] = "amouletSlot",
        [2] = "BagSlot",
        [3] = "armorSlot",
        [4] = "RightSlot",
        [5] = "LeftSlot",
        [6] = "legsSlot",
        [7] = "feetSlot",
        [8] = "RingSlot",
        [9] = "ammoSlot"
    },

    LAYOUTS = {
        NPCTRADE = {
            inspectWindow  = { width = 450,    height = 258 },
            inspectContent = { width = "100%", height = 216 },
            cyclopediaPanel = { width = 225,   height = 335 },
            mainColumn     = { width = "100%", height = 216 },
            headerRow      = { width = "100%", height = 60  },
            itemInfoScroll = { width = "98%",  height = 145 }
        },
        CYCLOPEDIA = {
            inspectWindow  = { width = 668,  height = 355 },
            inspectContent = { width = "100%", height = 309 },
            cyclopediaPanel = { width = 225, height = 309 },
            mainColumn     = { width = 450,  height = 309 },
            headerRow      = { width = 450,  height = 12  },
            itemInfoScroll = { width = 445,  height = 286 }
        }
    }
}
