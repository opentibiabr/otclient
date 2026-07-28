-- Line-oriented OTML parser/writer.
--
-- The file is not rebuilt from the tree: we keep the original lines and change
-- only the ones that must change. That preserves comments, blank lines,
-- alignment and ordering exactly as they were written.
--
-- Rules mirrored from the C++ parser (src/framework/otml/otmlparser.cpp):
--   * two spaces of indentation per level
--   * '//' and '#' start a comment (the line is trimmed before the check)
--   * a node whose line contains ':' is UNIQUE, and unique nodes are
--     PROPERTIES; without ':' the node becomes a CHILD WIDGET (uimanager.cpp:735)
--   * a value of '|', '|-' or '|+' starts a multiline block (indented below)

Otml = {}

-- ============================================================ reading

local function splitLines(text)
  local trailing = text:sub(-1) == '\n'
  local padded = trailing and text or (text .. '\n')
  local lines = {}
  for line in padded:gmatch('([^\n]*)\n') do
    lines[#lines + 1] = (line:gsub('\r$', ''))
  end
  return lines, trailing
end

local function isComment(content)
  return content:sub(1, 2) == '//' or content:sub(1, 1) == '#'
end

-- Splits "key: value" following the C++ rule: any ':' marks a property.
-- Returns tag, value, isProp.
local function splitNode(content)
  local colon = content:find(':', 1, true)
  if not colon then
    return content, nil, false
  end
  local tag = content:sub(1, colon - 1):trim()
  local value = content:sub(colon + 1):trim()
  return tag, value, true
end

function Otml.parse(text)
  local lines, trailing = splitLines(text)

  local doc = {
    lines = lines,
    eol = text:find('\r\n', 1, true) and '\r\n' or '\n',
    trailingNewline = trailing,
    roots = {},
    styleDefs = {},
    root = nil,
  }

  local stack = {}
  local skipDeeperThan = nil

  for i, raw in ipairs(lines) do
    local content = raw:trim()
    local skip = (content == '' or isComment(content))

    if not skip then
      local indent = #(raw:match('^ *') or '')

      -- inside a multiline block the content is text/code, not OTML
      if skipDeeperThan and indent > skipDeeperThan then
        skip = true
      else
        skipDeeperThan = nil
      end

      if not skip then
        local tag, value, isProp = splitNode(content)

        local node = {
          tag = tag,
          value = value,
          isProp = isProp,
          indent = indent,
          line = i,
          children = {},
          parent = nil,
        }

        while #stack > 0 and stack[#stack].indent >= indent do
          table.remove(stack)
        end

        local parent = stack[#stack]
        if parent then
          node.parent = parent
          table.insert(parent.children, node)
        else
          table.insert(doc.roots, node)
          if tag:find('<', 1, true) then
            table.insert(doc.styleDefs, node)
          elseif not isProp and not doc.root then
            doc.root = node
          end
        end

        table.insert(stack, node)

        if isProp and value and value:sub(1, 1) == '|' then
          skipDeeperThan = indent
        end
      end
    end
  end

  return doc
end

-- ============================================================ queries

-- Children that become widgets (lines without ':'), in the same order in which
-- createWidgetFromOTML instantiates them.
function Otml.widgetChildren(node)
  local out = {}
  for _, child in ipairs(node.children) do
    if not child.isProp and not child.tag:find('<', 1, true) then
      table.insert(out, child)
    end
  end
  return out
end

function Otml.properties(node)
  local out = {}
  for _, child in ipairs(node.children) do
    if child.isProp then
      table.insert(out, child)
    end
  end
  return out
end

function Otml.findProperty(node, key)
  for _, child in ipairs(node.children) do
    if child.isProp and child.tag == key then
      return child
    end
  end
  return nil
end

-- Last line occupied by the node, including the block indented below it.
function Otml.lastLineOf(node)
  local last = node.line
  for _, child in ipairs(node.children) do
    local childLast = Otml.lastLineOf(child)
    if childLast > last then last = childLast end
  end
  return last
end

-- ============================================================ writing
-- Every function that inserts/removes lines invalidates the line numbers held
-- in the tree. Callers must reparse before the next edit (Otml.reparse).

function Otml.reparse(doc)
  local text = Otml.serialize(doc)
  return Otml.parse(text)
end

-- Where a new property goes: right after the node's last direct property, so
-- properties stay above child widgets.
local function insertionLine(node)
  local line = node.line
  for _, child in ipairs(node.children) do
    if child.isProp then
      local last = Otml.lastLineOf(child)
      if last > line then line = last end
    end
  end
  return line + 1
end

function Otml.setProperty(doc, node, key, value)
  local prop = Otml.findProperty(node, key)

  if prop then
    if #prop.children > 0 then
      return false, 'composite property (block); edit it in the file'
    end
    doc.lines[prop.line] = string.rep(' ', prop.indent) .. key .. ': ' .. value
    return true
  end

  local text = string.rep(' ', node.indent + 2) .. key .. ': ' .. value
  table.insert(doc.lines, insertionLine(node), text)
  return true
end

function Otml.removeProperty(doc, node, key)
  local prop = Otml.findProperty(node, key)
  if not prop then
    return false, 'property not present in the file'
  end
  local last = Otml.lastLineOf(prop)
  for i = last, prop.line, -1 do
    table.remove(doc.lines, i)
  end
  return true
end

-- Appends a child widget at the end of the parent's block. Lines go in with the
-- indentation of the level below, the only step the C++ parser accepts
-- (otmlparser.cpp: "must indent every 2 spaces").
-- props is an ordered list of { key, value } written under the new widget. A
-- widget with no anchors at all cannot be positioned or dragged, so callers
-- pass sensible defaults here.
function Otml.addChildWidget(doc, parentNode, styleName, id, props)
  if not parentNode then
    return false, 'no parent widget'
  end

  local indent = string.rep(' ', parentNode.indent + 2)
  local at = Otml.lastLineOf(parentNode) + 1

  local block = {}
  -- blank line separating it from the previous content, if any
  if #parentNode.children > 0 then
    table.insert(block, '')
  end
  table.insert(block, indent .. styleName)
  if id and id ~= '' then
    table.insert(block, indent .. '  id: ' .. id)
  end
  for _, prop in ipairs(props or {}) do
    table.insert(block, indent .. '  ' .. prop[1] .. ': ' .. prop[2])
  end

  for i = #block, 1, -1 do
    table.insert(doc.lines, at, block[i])
  end

  return true
end

-- Removes a node and the whole block indented below it (a widget takes its
-- children along). Also drops one blank line directly above it, so repeated
-- removals do not pile up empty gaps in the file.
function Otml.removeNode(doc, node)
  if not node then
    return false, 'no node given'
  end

  local first = node.line
  local last = Otml.lastLineOf(node)

  if first > 1 then
    local above = doc.lines[first - 1]
    if above and above:trim() == '' then
      first = first - 1
    end
  end

  for i = last, first, -1 do
    table.remove(doc.lines, i)
  end
  return true
end

-- Skeleton for a brand new screen.
function Otml.skeleton(styleName, id, title)
  return table.concat({
    styleName,
    '  id: ' .. id,
    "  !text: '" .. title .. "'",
    '  size: 300 200',
    '',
  }, '\n')
end

function Otml.serialize(doc)
  local text = table.concat(doc.lines, doc.eol)
  if doc.trailingNewline then
    text = text .. doc.eol
  end
  return text
end
