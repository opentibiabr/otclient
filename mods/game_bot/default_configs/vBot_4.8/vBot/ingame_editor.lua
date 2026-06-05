setDefaultTab("Tools")
-- allows to test/edit bot lua scripts ingame, you can have multiple scripts like this, just change storage.ingame_lua
UI.Button("Ingame script editor", function(newText)
    UI.MultilineEditorWindow(storage.ingame_hotkeys or "", {title="Hotkeys editor", description="You can add your custom scripts here"}, function(text)
      storage.ingame_hotkeys = text
      reload()
    end)
  end)

  UI.Separator()

  for _, scripts in pairs({storage.ingame_hotkeys}) do
    if type(scripts) == "string" and scripts:len() > 3 then
      local status, result = pcall(function()
        if _VERSION == "Lua 5.1" and type(jit) ~= "table" then
          return assert(loadstring(scripts))()
        else        
          assert(load(scripts, "ingame_editor"))()
        end
      end)
      if not status then
        error("Ingame edior error:\n" .. result)
      end
    end
  end

  UI.Separator()
