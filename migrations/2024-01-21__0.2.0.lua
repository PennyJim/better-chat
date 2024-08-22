---@diagnostic disable: inject-field, no-unknown
local ChatHistoryManager = require "__better-chat__.runtime.ChatHistoryManager"

-- Don't do this migration if chatHistroy doesn't exist
if not global.chatHistory then return log("skipping") end

-- block reduce oldHistory's scope
local oldHistory = global.chatHistory
global.chatHistory = nil;

--Replicate ChatHistoryManager.init
global.GlobalChatLog = ChatHistoryManager.__newChatLog()
global.ForceChatLog = {}
for _,force in pairs(game.forces) do
  global.ForceChatLog[force.index] = ChatHistoryManager.__newChatLog();
end
global.PlayerChatLog = {}
for _,player in pairs(game.players) do
  local player_index = player.index
  global.PlayerChatLog[player_index] = ChatHistoryManager.__newChatLog();
end

--Migrate old chat history into new one's global chat
for _, chat in pairs(oldHistory) do
  ChatHistoryManager.add_message{
    message = chat.msg,
    color = chat.color,
    level = "global"
  }
end