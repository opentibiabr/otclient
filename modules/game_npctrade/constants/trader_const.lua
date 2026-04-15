-- LuaFormatter off

-- ==============================================================================================
-- TRADE MODE CONSTANTS
-- ==============================================================================================
controllerNpcTrader.BUY = 1
controllerNpcTrader.SELL = 2

-- ==============================================================================================
-- UI LAYOUT CONSTANTS
-- ==============================================================================================
controllerNpcTrader.DEFAULT_CONSOLE_WIDTH = 395
controllerNpcTrader.TRADE_CONSOLE_WIDTH = 600

-- ==============================================================================================
-- VIRTUAL SCROLLING CONSTANTS
-- ==============================================================================================
controllerNpcTrader.ITEM_BATCH_SIZE = 30
controllerNpcTrader.ITEM_ROW_HEIGHT = 48
controllerNpcTrader.SCROLL_THRESHOLD = 50

-- ==============================================================================================
-- DEFAULT CURRENCY
-- ==============================================================================================
controllerNpcTrader.DEFAULT_CURRENCY_ID = 3031
controllerNpcTrader.DEFAULT_CURRENCY_NAME = "Gold Coin"

-- ==============================================================================================
-- DEFAULT SETTINGS
-- ==============================================================================================
controllerNpcTrader.DEFAULT_SORT_BY = 'name'
controllerNpcTrader.DEFAULT_IGNORE_CAPACITY = false
controllerNpcTrader.DEFAULT_BUY_WITH_BACKPACK = false
controllerNpcTrader.DEFAULT_IGNORE_EQUIPPED = true

-- ==============================================================================================
-- ITEM DISPLAY LIMITS
-- ==============================================================================================
controllerNpcTrader.MAX_ITEM_NAME_LENGTH = 18
controllerNpcTrader.MAX_ITEM_INFO_LENGTH = 22

-- ==============================================================================================
-- AMOUNT LIMITS
-- ==============================================================================================
controllerNpcTrader.MIN_AMOUNT = 1
controllerNpcTrader.MAX_AMOUNT_NORMAL = 100
controllerNpcTrader.MAX_AMOUNT_STACKABLE = 10000

-- ==============================================================================================
-- KEYWORD BUTTON ICONS
-- ==============================================================================================

KeywordButtonIcon = {
  KEYWORDBUTTONICON_GENERALTRADE   = 0,
  KEYWORDBUTTONICON_POTIONTRADE    = 1,
  KEYWORDBUTTONICON_EQUIPMENTTRADE = 2,
  KEYWORDBUTTONICON_SAIL           = 3,
  KEYWORDBUTTONICON_DEPOSITALL     = 4,
  KEYWORDBUTTONICON_WITHDRAW       = 5,
  KEYWORDBUTTONICON_BALANCE        = 6,
  KEYWORDBUTTONICON_YES            = 7,
  KEYWORDBUTTONICON_NO             = 8,
  KEYWORDBUTTONICON_BYE            = 9,
}

IconSpriteIndex = {
  [KeywordButtonIcon.KEYWORDBUTTONICON_GENERALTRADE]   = 1,
  [KeywordButtonIcon.KEYWORDBUTTONICON_POTIONTRADE]    = 2,
  [KeywordButtonIcon.KEYWORDBUTTONICON_EQUIPMENTTRADE] = 3,
  [KeywordButtonIcon.KEYWORDBUTTONICON_SAIL]           = 0,
  [KeywordButtonIcon.KEYWORDBUTTONICON_DEPOSITALL]     = 5,
  [KeywordButtonIcon.KEYWORDBUTTONICON_WITHDRAW]       = 6,
  [KeywordButtonIcon.KEYWORDBUTTONICON_BALANCE]        = 4,
  [KeywordButtonIcon.KEYWORDBUTTONICON_YES]            = 7,
  [KeywordButtonIcon.KEYWORDBUTTONICON_NO]             = 8,
  [KeywordButtonIcon.KEYWORDBUTTONICON_BYE]            = 9,
}

controllerNpcTrader.buttonsDefault = {
    [1] = { id = KeywordButtonIcon.KEYWORDBUTTONICON_YES, text = "yes" },
    [2] = { id = KeywordButtonIcon.KEYWORDBUTTONICON_NO, text = "no" },
    [3] = { id = KeywordButtonIcon.KEYWORDBUTTONICON_BYE, text = "bye" },
    [4] = { id = KeywordButtonIcon.KEYWORDBUTTONICON_GENERALTRADE, text = "trade" }
}
-- LuaFormatter on

function controllerNpcTrader:getIconClip(id)
    local index = IconSpriteIndex[id] or 0
    local x = index * 32
    return x .. " 0 32 32"
end
