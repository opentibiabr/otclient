setDefaultTab("HP")
local panelName = "ConditionPanel"
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Conditions')

  Button
    id: conditionList
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

  ]])
  ui:setId(panelName)

  if not HealBotConfig[panelName] then
    HealBotConfig[panelName] = {
      enabled = false,
      curePosion = false,
      poisonCost = 20,
      cureCurse = false,
      curseCost = 80,
      cureBleed = false,
      bleedCost = 45,
      cureBurn = false,
      burnCost = 30,
      cureElectrify = false,
      electrifyCost = 22,
      cureParalyse = false,
      paralyseCost = 40,
      paralyseSpell = "utani hur",
      holdHaste = false,
      hasteCost = 40,
      hasteSpell = "utani hur",
      holdUtamo = false,
      utamoCost = 40,
      holdUtana = false,
      utanaCost = 440,
      holdUtura = false,
      uturaType = "",
      uturaCost = 100,
      ignoreInPz = true,
      stopHaste = false
    }
  end

  local config = HealBotConfig[panelName]

  ui.title:setOn(config.enabled)
  ui.title.onClick = function(widget)
    config.enabled = not config.enabled
    widget:setOn(config.enabled)
    vBotConfigSave("heal")
  end

  ui.conditionList.onClick = function(widget)
    conditionsWindow:show()
    conditionsWindow:raise()
    conditionsWindow:focus()
  end

  local rootWidget = g_ui.getRootWidget()
  if rootWidget then
    conditionsWindow = UI.createWindow('ConditionsWindow', rootWidget)
    conditionsWindow:hide()

    conditionsWindow.onVisibilityChange = function(widget, visible)
      if not visible then
        vBotConfigSave("heal")
      end
    end

    -- text edits
    conditionsWindow.Cure.PoisonCost:setText(config.poisonCost)
    conditionsWindow.Cure.PoisonCost.onTextChange = function(widget, text)
      config.poisonCost = tonumber(text)
    end

    conditionsWindow.Cure.CurseCost:setText(config.curseCost)
    conditionsWindow.Cure.CurseCost.onTextChange = function(widget, text)
      config.curseCost = tonumber(text)
    end

    conditionsWindow.Cure.BleedCost:setText(config.bleedCost)
    conditionsWindow.Cure.BleedCost.onTextChange = function(widget, text)
      config.bleedCost = tonumber(text)
    end

    conditionsWindow.Cure.BurnCost:setText(config.burnCost)
    conditionsWindow.Cure.BurnCost.onTextChange = function(widget, text)
      config.burnCost = tonumber(text)
    end

    conditionsWindow.Cure.ElectrifyCost:setText(config.electrifyCost)
    conditionsWindow.Cure.ElectrifyCost.onTextChange = function(widget, text)
      config.electrifyCost = tonumber(text)
    end

    conditionsWindow.Cure.ParalyseCost:setText(config.paralyseCost)
    conditionsWindow.Cure.ParalyseCost.onTextChange = function(widget, text)
      config.paralyseCost = tonumber(text)
    end

    conditionsWindow.Cure.ParalyseSpell:setText(config.paralyseSpell)
    conditionsWindow.Cure.ParalyseSpell.onTextChange = function(widget, text)
      config.paralyseSpell = text
    end

    conditionsWindow.Hold.HasteSpell:setText(config.hasteSpell)
    conditionsWindow.Hold.HasteSpell.onTextChange = function(widget, text)
      config.hasteSpell = text
    end

    conditionsWindow.Hold.HasteCost:setText(config.hasteCost)
    conditionsWindow.Hold.HasteCost.onTextChange = function(widget, text)
      config.hasteCost = tonumber(text)
    end

    conditionsWindow.Hold.UtamoCost:setText(config.utamoCost)
    conditionsWindow.Hold.UtamoCost.onTextChange = function(widget, text)
      config.utamoCost = tonumber(text)
    end

    conditionsWindow.Hold.UtanaCost:setText(config.utanaCost)
    conditionsWindow.Hold.UtanaCost.onTextChange = function(widget, text)
      config.utanaCost = tonumber(text)
    end

    conditionsWindow.Hold.UturaCost:setText(config.uturaCost)
    conditionsWindow.Hold.UturaCost.onTextChange = function(widget, text)
      config.uturaCost = tonumber(text)
    end

    -- combo box
    conditionsWindow.Hold.UturaType:setOption(config.uturaType)
    conditionsWindow.Hold.UturaType.onOptionChange = function(widget)
      config.uturaType = widget:getCurrentOption().text
    end

    -- checkboxes
    conditionsWindow.Cure.CurePoison:setChecked(config.curePoison)
    conditionsWindow.Cure.CurePoison.onClick = function(widget)
      config.curePoison = not config.curePoison
      widget:setChecked(config.curePoison)
    end

    conditionsWindow.Cure.CureCurse:setChecked(config.cureCurse)
    conditionsWindow.Cure.CureCurse.onClick = function(widget)
      config.cureCurse = not config.cureCurse
      widget:setChecked(config.cureCurse)
    end

    conditionsWindow.Cure.CureBleed:setChecked(config.cureBleed)
    conditionsWindow.Cure.CureBleed.onClick = function(widget)
      config.cureBleed = not config.cureBleed
      widget:setChecked(config.cureBleed)
    end

    conditionsWindow.Cure.CureBurn:setChecked(config.cureBurn)
    conditionsWindow.Cure.CureBurn.onClick = function(widget)
      config.cureBurn = not config.cureBurn
      widget:setChecked(config.cureBurn)
    end

    conditionsWindow.Cure.CureElectrify:setChecked(config.cureElectrify)
    conditionsWindow.Cure.CureElectrify.onClick = function(widget)
      config.cureElectrify = not config.cureElectrify
      widget:setChecked(config.cureElectrify)
    end

    conditionsWindow.Cure.CureParalyse:setChecked(config.cureParalyse)
    conditionsWindow.Cure.CureParalyse.onClick = function(widget)
      config.cureParalyse = not config.cureParalyse
      widget:setChecked(config.cureParalyse)
    end

    conditionsWindow.Hold.HoldHaste:setChecked(config.holdHaste)
    conditionsWindow.Hold.HoldHaste.onClick = function(widget)
      config.holdHaste = not config.holdHaste
      widget:setChecked(config.holdHaste)
    end

    conditionsWindow.Hold.HoldUtamo:setChecked(config.holdUtamo)
    conditionsWindow.Hold.HoldUtamo.onClick = function(widget)
      config.holdUtamo = not config.holdUtamo
      widget:setChecked(config.holdUtamo)
    end

    conditionsWindow.Hold.HoldUtana:setChecked(config.holdUtana)
    conditionsWindow.Hold.HoldUtana.onClick = function(widget)
      config.holdUtana = not config.holdUtana
      widget:setChecked(config.holdUtana)
    end

    conditionsWindow.Hold.HoldUtura:setChecked(config.holdUtura)
    conditionsWindow.Hold.HoldUtura.onClick = function(widget)
      config.holdUtura = not config.holdUtura
      widget:setChecked(config.holdUtura)
    end

    conditionsWindow.Hold.IgnoreInPz:setChecked(config.ignoreInPz)
    conditionsWindow.Hold.IgnoreInPz.onClick = function(widget)
      config.ignoreInPz = not config.ignoreInPz
      widget:setChecked(config.ignoreInPz)
    end

    conditionsWindow.Hold.StopHaste:setChecked(config.stopHaste)
    conditionsWindow.Hold.StopHaste.onClick = function(widget)
      config.stopHaste = not config.stopHaste
      widget:setChecked(config.stopHaste)
    end

    -- buttons
    conditionsWindow.closeButton.onClick = function(widget)
      conditionsWindow:hide()
    end

    Conditions = {}
    Conditions.show = function()
      conditionsWindow:show()
      conditionsWindow:raise()
      conditionsWindow:focus()
    end
  end

  local utanaCast = nil
  macro(500, function()
    if not config.enabled or modules.game_cooldown.isGroupCooldownIconActive(2) then return end
    if hppercent() > 95 then
      if config.curePoison and mana() >= config.poisonCost and isPoisioned() then say("exana pox")
      elseif config.cureCurse and mana() >= config.curseCost and isCursed() then say("exana mort")
      elseif config.cureBleed and mana() >= config.bleedCost and isBleeding() then say("exana kor")
      elseif config.cureBurn and mana() >= config.burnCost and isBurning() then say("exana flam")
      elseif config.cureElectrify and mana() >= config.electrifyCost and isEnergized() then say("exana vis")
      end
    end
    if (not config.ignoreInPz or not isInPz()) and config.holdUtura and mana() >= config.uturaCost and canCast(config.uturaType) and hppercent() < 90 then say(config.uturaType)
    elseif (not config.ignoreInPz or not isInPz()) and config.holdUtana and mana() >= config.utanaCost and (not utanaCast or (now - utanaCast > 120000)) then say("utana vid") utanaCast = now
    end
  end)

  macro(50, function()
    if not config.enabled then return end
    if (not config.ignoreInPz or not isInPz()) and config.holdUtamo and mana() >= config.utamoCost and not (hasManaShield() or hasNewManaShield()) then say("utamo vita")
    elseif ((not config.ignoreInPz or not isInPz()) and standTime() < 5000 and config.holdHaste and mana() >= config.hasteCost and not hasHaste() and not getSpellCoolDown(config.hasteSpell) and (not target() or not config.stopHaste or TargetBot.isCaveBotActionAllowed())) and standTime() < 3000 then say(config.hasteSpell)
    elseif config.cureParalyse and mana() >= config.paralyseCost and isParalyzed() and not getSpellCoolDown(config.paralyseSpell) then say(config.paralyseSpell)
    end
  end)
