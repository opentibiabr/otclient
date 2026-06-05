HTTP = {
  timeout = 2,
  websocketTimeout = 15,
  agent = "Mozilla/5.0",
  imageId = 1000,
  images = {},
  operations = {},
  enableTimeOut = false, -- only work in read/write
}

function HTTP.get(url, callback)
  if not g_http or not g_http.get then
    return error("HTTP.get is not supported")
  end
  local operation = g_http.get(url, HTTP.timeout)
  HTTP.operations[operation] = { type = "get", url = url, callback = callback }
  return operation
end

function HTTP.getJSON(url, callback)
  if not g_http or not g_http.get then
    return error("HTTP.getJSON is not supported")
  end
  local operation = g_http.get(url, HTTP.timeout)
  HTTP.operations[operation] = { type = "get", json = true, url = url, callback = callback }
  return operation
end

function HTTP.post(url, data, callback, checkContentLength)
  if not g_http or not g_http.post then
    return error("HTTP.post is not supported")
  end
  local is_json = false
  if type(data) == "table" then
    data = json.encode(data)
    is_json = true
  end

  if checkContentLength == nil then
    checkContentLength = true
  end

  local operation = g_http.post(url, data, HTTP.timeout, is_json, checkContentLength)
  HTTP.operations[operation] = { type = "post", url = url, callback = callback }
  return operation
end

function HTTP.postJSON(url, data, callback)
  if not g_http or not g_http.post then
    return error("HTTP.postJSON is not supported")
  end
  if type(data) == "table" then
    data = json.encode(data)
  end
  local operation = g_http.post(url, data, HTTP.timeout, true)
  HTTP.operations[operation] = { type = "post", json = true, url = url, callback = callback }
  return operation
end

function HTTP.download(url, file, callback, progressCallback)
  if not g_http or not g_http.download then
    return error("HTTP.download is not supported")
  end
  local operation = g_http.download(url, file, HTTP.timeout)
  HTTP.operations[operation] = {
    type = "download",
    url = url,
    file = file,
    callback = callback,
    progressCallback = progressCallback
  }
  return operation
end

function HTTP.downloadImage(url, callback)
  if not g_http or not g_http.download then
    return error("HTTP.downloadImage is not supported")
  end
  if HTTP.images[url] ~= nil then
    if callback then
      callback('/downloads/' .. HTTP.images[url], nil)
    end
    return
  end
  local file = "autoimage_" .. HTTP.imageId .. ".png"
  HTTP.imageId = HTTP.imageId + 1
  local operation = g_http.download(url, file, HTTP.timeout)
  HTTP.operations[operation] = { type = "image", url = url, file = file, callback = callback }
  return operation
end

function HTTP.webSocket(url, callbacks, timeout, jsonWebsocket)
  if not g_http or not g_http.ws then
    return error("WebSocket is not supported")
  end
  if not timeout or timeout < 1 then
    timeout = HTTP.websocketTimeout
  end
  local operation = g_http.ws(url, timeout)
  HTTP.operations[operation] = { type = "ws", json = jsonWebsocket, url = url, callbacks = callbacks }
  return {
    id = operation,
    url = url,
    close = function()
      g_http.wsClose(operation)
    end,
    send = function(message)
      if type(message) == "table" then
        message = json.encode(message)
      end
      g_http.wsSend(operation, message)
    end
  }
end

HTTP.WebSocket = HTTP.webSocket

function HTTP.webSocketJSON(url, callbacks, timeout)
  return HTTP.webSocket(url, callbacks, timeout, true)
end

HTTP.WebSocketJSON = HTTP.webSocketJSON

function HTTP.cancel(operationId)
  if not g_http or not g_http.cancel then
    return
  end
  HTTP.operations[operationId] = nil
  return g_http.cancel(operationId)
end

function HTTP.onGet(operationId, url, err, data)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
  if err and err:len() == 0 then
    err = nil
  end
  if not err and operation.json then
    if data:len() == 0 then
      data = "null"
    end
    local status, result = pcall(function() return json.decode(data) end)
    if not status then
      err = "JSON ERROR: " .. result
      if data and data:len() > 0 then
        err = err .. " (" .. data:sub(1, 100) .. ")"
      end
    end
    data = result
  end
  if operation.callback then
    operation.callback(data, err)
  end
end

function HTTP.onGetProgress(operationId, url, progress)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
end

function HTTP.onPost(operationId, url, err, data)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
  if err and err:len() == 0 then
    err = nil
  end
  if not err and operation.json then
    if data:len() == 0 then
      data = "null"
    end
    local status, result = pcall(json.decode, data)
    if not status then
      err = "JSON ERROR: " .. result
      if data and data:len() > 0 then
        err = err .. " (" .. data:sub(1, 100) .. ")"
      end
    end
    data = result
  end
  if operation.callback then
    operation.callback(data, err)
  end
end

function HTTP.onPostProgress(operationId, url, progress)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
end

function HTTP.onDownload(operationId, url, err, path, checksum)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
  if err and err:len() == 0 then
    err = nil
  end
  if operation.callback then
    if operation["type"] == "image" then
      if not err then
        HTTP.images[url] = path
      end
      operation.callback('/downloads/' .. path, err)
    else
      operation.callback(path, checksum, err)
    end
  end
end

function HTTP.onDownloadProgress(operationId, url, progress, speed)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
  if operation.progressCallback then
    operation.progressCallback(progress, speed)
  end
end

function HTTP.onWsOpen(operationId, message)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
  if operation.callbacks.onOpen then
    operation.callbacks.onOpen(message, operationId)
  end
end

function HTTP.onWsMessage(operationId, message)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
  if operation.callbacks.onMessage then
    if operation.json then
      if message:len() == 0 then
        message = "null"
      end
      local status, result = pcall(function() return json.decode(message) end)
      local err = nil
      if not status then
        err = "JSON ERROR: " .. result
        if message and message:len() > 0 then
          err = err .. " (" .. message:sub(1, 100) .. ")"
        end
      end
      if err then
        if operation.callbacks.onError then
          operation.callbacks.onError(err, operationId)
        end
      else
        operation.callbacks.onMessage(result, operationId)
      end
    else
      operation.callbacks.onMessage(message, operationId)
    end
  end
end

function HTTP.onWsClose(operationId, message)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
  if operation.callbacks.onClose then
    operation.callbacks.onClose(message, operationId)
  end
end

function HTTP.onWsError(operationId, message)
  local operation = HTTP.operations[operationId]
  if operation == nil then
    return
  end
  if operation.callbacks.onError then
    operation.callbacks.onError(message, operationId)
  end
end

function HTTP.addCustomHeader(headerTable)
  for name, value in pairs(headerTable) do
    g_http.addCustomHeader(name, value)
  end
end

connect(g_http,
  {
    onGet = HTTP.onGet,
    onGetProgress = HTTP.onGetProgress,
    onPost = HTTP.onPost,
    onPostProgress = HTTP.onPostProgress,
    onDownload = HTTP.onDownload,
    onDownloadProgress = HTTP.onDownloadProgress,
    onWsOpen = HTTP.onWsOpen,
    onWsMessage = HTTP.onWsMessage,
    onWsClose = HTTP.onWsClose,
    onWsError = HTTP.onWsError,
  })

g_http.setUserAgent(HTTP.agent)
g_http.setEnableTimeOutOnReadWrite(HTTP.enableTimeOut)
