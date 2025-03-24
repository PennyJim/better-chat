---@diagnostic disable: inject-field, no-unknown
local chatlog = require("__better-chat__.runtime.ChatLog")
local ChatHistoryManager = require "__better-chat__.runtime.ChatHistoryManager"

-- Don't do this migration if chatHistroy doesn't exist
if not storage.chatHistory then return log("skipping") end

-- block reduce oldHistory's scope
local oldHistory = storage.chatHistory
storage.chatHistory = nil;

--Replicate ChatHistoryManager.init
storage.master_log = chatlog.new()
storage.player_logs = {}
for index,player in pairs(game.players) do
  ---@cast index uint
  storage.player_logs[index] = chatlog.new()
end

--Migrate old chat history into new one's global chat
for _, chat in pairs(oldHistory) do
  ChatHistoryManager.add_message{
    message = chat.msg,
    color = chat.color,
    type = "global"
  }
end