if not ImbuementSelection then
  ImbuementSelection = {
    pickItem = nil,
  }
end

ImbuementSelection.__index = ImbuementSelection

local self = ImbuementSelection
function ImbuementSelection.startUp()
  self.pickItem = g_ui.createWidget('UIWidget')
  self.pickItem:setVisible(false)
  self.pickItem:setFocusable(false)
  self.pickItem.onMouseRelease = self.onChooseItemMouseRelease
end

function ImbuementSelection:shutdown()
  if self.pickItem then
    self.pickItem:destroy()
    self.pickItem = nil
  end
end

function ImbuementSelection:selectItem()
  if not self.pickItem then
    self:startUp()
  end

  if g_mouse.isPressed() then 
    return 
  end
  
  self.isSelectingScroll = false
  self.pickItem:grabMouse()
  g_mouse.pushCursor('target')
end

function ImbuementSelection:selectScroll()
  if not self.pickItem then
    self:startUp()
  end

  if g_mouse.isPressed() then 
    return 
  end
  
  self.isSelectingScroll = true
  self.pickItem:grabMouse()
  g_mouse.pushCursor('target')
end

function ImbuementSelection.onChooseItemMouseRelease(widget, mousePosition, mouseButton)
  local item = nil
  if mouseButton == MouseLeftButton then
    local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
    if clickedWidget then
      if clickedWidget:getClassName() == 'UIGameMap' then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
          local thing = tile:getTopMoveThing()
          if thing and thing:isItem() then
            item = thing
          end
        end
      elseif clickedWidget:getClassName() == 'UIItem' and not clickedWidget:isVirtual() then
        item = clickedWidget:getItem()
      end
    end
  end

  if item and item:isPickupable() then
    local pos = item:getPosition()
    local itemId = item:getId()
    local stackPos = item:getStackPos()
    
    if self.isSelectingScroll then
      g_game.selectImbuementScroll()
    else
      g_game.selectImbuementItem(itemId, pos, stackPos)
    end
    
    self.pickItem:ungrabMouse()
    g_mouse.popCursor('target')
    
    return true
  else
    modules.game_textmessage.displayFailureMessage(tr('Sorry, not possible.'))
  end

  self.pickItem:ungrabMouse()
  g_mouse.popCursor('target')
  return true
end
