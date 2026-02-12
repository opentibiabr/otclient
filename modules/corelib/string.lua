-- @docclass string
function string:split(delim)
    local start = 1
    local results = {}
    while true do
        local pos = string.find(self, delim, start, true)
        if not pos then
            break
        end
        table.insert(results, string.sub(self, start, pos - 1))
        start = pos + string.len(delim)
    end
    table.insert(results, string.sub(self, start))
    table.removevalue(results, '')
    return results
end

function string:starts(start)
    return string.sub(self, 1, #start) == start
end

function string:ends(test)
    return test == '' or string.sub(self, -string.len(test)) == test
end

function string:trim()
    return string.match(self, '^%s*(.*%S)') or ''
end

function string:explode(sep, limit)
    if type(sep) ~= 'string' or tostring(self):len() == 0 or sep:len() == 0 then
        return {}
    end

    local i, pos, tmp, t = 0, 1, '', {}
    for s, e in function()
        return string.find(self, sep, pos)
    end do
        tmp = self:sub(pos, s - 1):trim()
        table.insert(t, tmp)
        pos = e + 1

        i = i + 1
        if limit ~= nil and i == limit then
            break
        end
    end

    tmp = self:sub(pos):trim()
    table.insert(t, tmp)
    return t
end

function string:contains(str, checkCase, start, plain)
    if (not checkCase) then
        self = self:lower()
        str = str:lower()
    end
    return string.find(self, str, start and start or 1, plain == nil and true or false)
end

function string:wrap(width)
    local wrapped = ""
    local lineWidth = 0
    for word in self:gmatch("%S+") do
        local wordWidth = #word * 10  -- Assuming each character is 10 pixels wide
        if lineWidth + wordWidth > width then
            wrapped = wrapped .. "\n" .. word .. " "
            lineWidth = wordWidth + 1
        else
            wrapped = wrapped .. word .. " "
            lineWidth = lineWidth + wordWidth + 1
        end
    end
    return wrapped
end

function string.empty(str)  
    return str == nil or str == "" or #str == 0  
end

function string:titleCase()
    return self:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

function string.unpack_custom(format, data)
  local result = {}
  local index = 1

  local i = 1
  while i <= #format do
      local fmt = format:sub(i, i)
      local nextChar = format:sub(i + 1, i + 1)
      local specifier = fmt

      if nextChar:match("%d") then
          specifier = fmt .. nextChar
          i = i + 1
      end

      if specifier == "I1" then
          result[#result + 1] = string.byte(data, index)
          index = index + 1

      elseif specifier == "I2" then
          local b1, b2 = string.byte(data, index, index + 1)
          result[#result + 1] = b1 + (b2 * 256)
          index = index + 2

      elseif specifier == "I4" then
          local b1, b2, b3, b4 = string.byte(data, index, index + 3)
          result[#result + 1] = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
          index = index + 4

      else
          error("Invalid format specifier: " .. specifier)
      end

      i = i + 1
  end

  return unpack(result)
end

function setStringColor(t, text, color)
    table.insert(t, text)
    table.insert(t, color)
end

function setStringFont(t, text, color, font)
  table.insert(t, text)
  table.insert(t, color)
  table.insert(t, font)
end

function string.pack_custom(format, ...)
  local args = {...}
  local result = {}
  local index = 1

  local i = 1
  while i <= #format do
      local fmt = format:sub(i, i)
      local nextChar = format:sub(i + 1, i + 1)
      local specifier = fmt

      if nextChar:match("%d") then
          specifier = fmt .. nextChar
          i = i + 1
      end

      local value = args[index] or 0

      if specifier == "I1" then
          if value < 0 or value > 255 then
              error("Value out of range for I1: " .. tostring(value))
          end
          table.insert(result, string.char(value))

      elseif specifier == "I2" then
          if value < 0 or value > 65535 then
              error("Value out of range for I2: " .. tostring(value))
          end
          table.insert(result, string.char(value % 256, math.floor(value / 256)))

      elseif specifier == "I4" then
          if value < 0 or value > 4294967295 then
              error("Value out of range for I4: " .. tostring(value))
          end
          table.insert(result, string.char(
              value % 256,
              math.floor(value / 256) % 256,
              math.floor(value / 65536) % 256,
              math.floor(value / 16777216)
          ))

      else
          error("Invalid format specifier: " .. specifier)
      end

      index = index + 1
      i = i + 1
  end

  return table.concat(result)
end

function string.capitalize(str)
    if not str or str == "" then
        return str
    end
    -- Zamiana pierwszej litery na wielką, reszta pozostaje bez zmian
    return str:sub(1,1):upper() .. str:sub(2)
end