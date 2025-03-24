
local header_switch = {
  ["chat-localization.bc-empty-header"] = "empty",
  ["chat-localization.bc-message-header"] = "force",
  ["chat-localization.bc-shout-header"] = "global",
  ["chat-localization.bc-whisper-to-header"] = "whisper",
  ["chat-localization.bc-whisper-from-header"] = "whisper",
}--[[@as table<string,ChatMessageType|"empty">]]

---@param header_key string
---@param fallback ChatMessageType
---@return ChatMessageType
local function get_type(header_key, fallback)
  local type = header_switch[header_key]
  if type ~= "empty" then
    return fallback
  else
    ---@cast type ChatMessageType
    return type
  end
end