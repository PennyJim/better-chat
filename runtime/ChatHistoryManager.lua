local interface = require("__better-chat__.runtime.ChatInterface")
local chatlog = require("__better-chat__.runtime.ChatLog")
local printer = require("__better-chat__.runtime.ChatPrinter")

---MARK: Manager

---@alias historyLevel "global"|"force"|"player"|"surface"
---@class ChatLogManager : custom_event_handler
local manager = {events = {}--[[@as event_handler.events]], remote_interfaces = {}--[[@as custom_event_handler.remote_interfaces]]}

---Adds a new chatlog for player_index if it didn't exist before
manager.events[defines.events.on_player_created] = function (event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	---@cast player -?
	if storage.player_logs[player_index] then return log("Player already had a log!?? '"..player.name.."' at "..player_index) end -- HMMM??
	storage.player_logs[player_index] = chatlog.new(storage.master_log, player)
end

---Removes a chatlog for deleted force
manager.events[defines.events.on_forces_merged] = function (event)
	-- TODO: Make this a setting, and possibly just *remove* those chats?
	local destination_index = event.destination.index
	for _, chat in storage.master_log:filter{
		force_index = event.source_index,
		type = {force = true}
	} do
		chat.recipient_index = destination_index
	end
end
---Removes a chatlog for removed player
manager.events[defines.events.on_player_removed] = function (event)
	local player_index = event.player_index
	storage.player_logs[player_index] = nil

	--- Remove references to this player's index
	local log = storage.master_log
	for chat_id, chat in log:from() do
		---@cast chat Chat.whisper|Chat.force_player
		if chat.type == "whisper" then
			if chat.recipient.index == player_index then
				log:remove(chat_id)
			end
		elseif chat.type == "player" then
			---@cast chat Chat.force_player
			if chat.recipient_index == player_index then
				log:remove(chat_id)
			end
		end

		if chat.sender and chat.sender.index == player_index then
			chat.sender.index = nil
		end
	end
end

---Empties the print log for the given player
---Messages will still be visible in the chat history
---@param player_index int
manager.clear = function (player_index)
	storage.player_logs[player_index] = chatlog.new()
	interface.clear_chat(player_index)
end

---@class ChatParams.base
---@field type "global"
---@field message LocalisedString
---@field sender? ChatPlayer
---@field color? Color
---@field process_color? boolean

---@class ChatParams.force_player : ChatParams.base
---@field type "force"|"player"
---@field recipient_index uint

---@class ChatParams.surface : ChatParams.base
---@field type "surface"
---@field recipients uint[]

---@class ChatParams.whisper : ChatParams.base
---@field type "whisper"
---@field sender ChatPlayer
---@field recipient ChatPlayer

---@alias ChatParams Chat.base|Chat.force_player|Chat.surface|Chat.whisper
---Adds a message to chat history
---@param tentative_chat ChatParams
manager.add_message = function(tentative_chat)
	---@type Chat
	local newChat = util.copy(tentative_chat)
	newChat.chat_id = storage.master_log.last_index + 1
	newChat.tick = game.ticks_played
	storage.master_log:add(newChat, settings.global["bc-global-chat-history"].value--[[@as int]],
		interface.remove_chat
	)

	for player_index, player in pairs(game.players) do
		---@cast player_index uint
		local force_index = player.force_index
		if chatlog.passes_filter(tentative_chat, {
			player_index = player_index,
			force_index = force_index
		}) then
			storage.player_logs[player_index]:add(tentative_chat, 36)
		end
	end
end

manager.events[defines.events.on_runtime_mod_setting_changed] = function (event)
  local setting = event.setting
  if event.setting_type == "runtime-global" then
    if setting == "bc-global-chat-history" then
      -- Send a message to notify the setting change
      -- Also to cause the ChatHistoryManager to fix a chatlog that's too long
      send_message{
        message = {
					"chat-localization.bc-global-history-changed",
					settings.global[setting].value
				},
        send_level = "global"
      }
      printer.print_chat("global")
    end
  else
    local player_index = event.player_index
    if not player_index then return log("Who changed their setting???") end
    if setting == "bc-player-closeable-chat" then
      -- Clear opened value when closeable is disabled
      -- Also does it when enabled, but they should just be in main menu
      storage.isChatOpen[player_index--[[@as int]]] = nil
      -- Update chat to now match the openness it Should be now
      printer.print_chat("player", player_index)
    elseif (
      setting == "bc-color-fade" or
      setting == "bc-default-color" or
      setting == "bc-error-color" or
      setting == "bc-warn-color" or
      setting == "bc-debug-color"
    ) then
      -- Reprint chat to update the the printed chat
      printer.print_chat("player", player_index)
    end
  end
end

---@class BetterChatStorage
---@field master_log ChatLog
---@field player_logs table<int, ChatLog>

---Initializes Chat History
manager.on_init = function()
	local master_log = chatlog.new()
	storage.master_log = master_log
	storage.player_logs = {}
	for _, player in pairs(game.players) do
		local player_index = player.index
		storage.player_logs[player_index] = chatlog.new();
	end
end

manager.remote_interfaces["better-chat"] = {
	clear = manager.clear
}

return manager