function controllerNpcTrader:onOptionsClick()
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption("Sort by Name", function()
        self:setSortBy('name')
    end)
    menu:addOption("Sort by Price", function()
        self:setSortBy('price')
    end)
    menu:addOption("Sort by Weight", function()
        self:setSortBy('weight')
    end)
    menu:addSeparator()
    if self.tradeMode == controllerNpcTrader.BUY then
        menu:addCheckBox("Ignore Capacity", self.ignoreCapacity, function(widget, checked)
            self:toggleIgnoreCapacity()
        end)
        if self.currencyId == controllerNpcTrader.DEFAULT_CURRENCY_ID then
            menu:addCheckBox("Buy with Backpack", self.buyWithBackpack, function(widget, checked)
                self:toggleBuyWithBackpack()
            end)
        end
    else
        menu:addCheckBox("Sell Equipped", not self.ignoreEquipped, function(widget, checked)
            self:toggleIgnoreEquipped()
        end)
    end
    menu:display()
end

function controllerNpcTrader:sortTradeItems(items)
    if not items then
        return
    end
    table.sort(items, function(a, b)
        if self.sortBy == 'price' then
            return a.price < b.price
        elseif self.sortBy == 'weight' then
            return a.weight < b.weight
        else
            return a.name:lower() < b.name:lower()
        end
    end)
end

function controllerNpcTrader:setSortBy(sort)
    self.sortBy = sort
    self:filterTradeList(self.searchText or "")
end

function controllerNpcTrader:toggleIgnoreCapacity()
    self.ignoreCapacity = not self.ignoreCapacity
    self:updateAmount(self.amount)
end

function controllerNpcTrader:toggleBuyWithBackpack()
    self.buyWithBackpack = not self.buyWithBackpack
    self:updateAmount(self.amount)
end

function controllerNpcTrader:toggleIgnoreEquipped()
    self.ignoreEquipped = not self.ignoreEquipped
    self:refreshPlayerGoods()
    self:updateAmount(self.amount)
end
