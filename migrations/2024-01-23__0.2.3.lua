---@diagnostic disable: inject-field, no-unknown, undefined-field
local ChatHistoryManager = require "__better-chat__.runtime.ChatHistoryManager"

---@diagnostic disable-next-line: param-type-mismatch
local first_player = pairs(game.players)(0) --[[@as int]]
-- Don't do this migration if the global chatlog has the size field
-- Checks the first player chatlog
if global.PlayerChatLog[first_player].top_index then
  return log("skipping")
end

---Migrate the old ChatLog linked list into rolling buffers (basically arrays)
---@return ChatLog
local function linkedListMigration(list)
  local log = ChatHistoryManager.__newChatLog()
  local array = log.chat_array

  local length = 0
  local link = list.first_chat
  while link do
    length = length + 1
    array[length] = link.value
    link = link.next
  end
  log.size = length
  log.top_index = 1
  log.last_index = length

  return log
end

global.GlobalChatLog = linkedListMigration(global.GlobalChatLog)
for force_index in pairs(global.ForceChatLog) do
  global.ForceChatLog[force_index] = linkedListMigration(global.ForceChatLog[force_index])
end
for player_index in pairs(global.PlayerChatLog) do
  global.PlayerChatLog[player_index] = linkedListMigration(global.PlayerChatLog[player_index])
end