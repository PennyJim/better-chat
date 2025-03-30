local chatlog = require("__better-chat__.runtime.ChatLog")

---@diagnostic disable: no-unknown, undefined-field
local header_switch = {
  ["chat-localization.bc-empty-header"] = "empty",
  ["chat-localization.bc-message-header"] = "force",
  ["chat-localization.bc-shout-header"] = "global",
  ["chat-localization.bc-whisper-to-header"] = "to-whisper",
  ["chat-localization.bc-whisper-from-header"] = "whisper",
}--[[@as table<string,ChatMessageType|"empty"|"to-whisper">]]

---@type table<Chat,true>
local to_whispers = {}
---@type table<Chat,true>
local from_whispers = {}

---@param chat Chat
---@param fallback ChatMessageType
---@return ChatMessageType
local function get_type(chat, fallback)
  local type
  if type(chat.message) == "table" and chat.message[1] == ""
  and type(chat.message[2]) == "table" and type(chat.message[2][1]) == "string" then
    
    local header_key = chat.message[2][1]
    type = header_switch[header_key]
  end

  if type == "to-whisper" then
    type = "whisper"
    to_whispers[chat] = true
  elseif type == "whisper" then
    from_whispers[chat] = true
  end
  ---@cast type -"to-whisper"

  if type ~= "empty" then
    ---@cast type ChatMessageType
    return type
  else
    return fallback
  end
end

---@class (private) OldChat : {message:LocalisedString,tick:uint,color:Color?,process_color:boolean?}

---@type table<OldChat,{type:ChatMessageType,recipients?:uint[], recipient?:uint}>
local all_messages = {}
for _,chat in storage.GlobalChatLog:from() do
  all_messages[chat] = {
    type = get_type(chat, "global")
  }
end
for force_index, ChatLog in pairs(storage.ForceChatLog) do
  for _,chat in ChatLog:from() do
    if not all_messages[chat] then
      all_messages[chat] = {
        type = get_type(chat, "force"),
        recipient = force_index,
        recipients = {}
      }
    end
  end
end
for player_index, ChatLog in pairs(storage.PlayerChatLog) do
  for _,chat in ChatLog:from() do
    if not all_messages[chat] then
      all_messages[chat] = {
        type = get_type(chat, "player"),
        recipients = {player_index}
      }
    elseif all_messages[chat].recipients then
      table.insert(all_messages[chat].recipients, player_index)
    end
  end
end

---@type Chat[]
local chat_array, count = {}, 0



for chat, additional_information in pairs(all_messages) do
  -- Process additonal_information

  ---@cast chat Chat
  chat.type = additional_information.type
  local recipient_count = additional_information.recipients and #additional_information.recipients or 0

  if chat.type == "player" and recipient_count > 1 then
    chat.type = "surface"
    chat.recipients = additional_information.recipients

  end

  count = count + 1
  chat_array[count] = chat
end

---@param a Chat
---@param b Chat
table.sort(chat_array, function (a, b)
  return a.tick < b.tick
end)

local master_log = chatlog.new()
storage.master_log = master_log
for i, chat in pairs(chat_array) do
  chat.chat_id = i
  master_log:add(chat)
end

storage.player_logs = {}

for player_index, oldlog in pairs(storage.PlayerChatLog) do
  local newlog = chatlog.new()
  storage.player_logs[player_index] = newlog
  for _, chat in oldlog:from() do
    newlog:add(chat, 36)
  end
end

storage.GlobalChatLog = nil
storage.ForceChatLog = nil
storage.PlayerChatLog = nil