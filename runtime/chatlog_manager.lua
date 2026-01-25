local chatlog = require("chatlog")

---MARK: Manager

---@class ChatLogManager : event_handler
local manager = {
	events = {}--[[@as event_handler.events]],
	remote_interfaces = {}--[[@as event_handler.remote_interfaces]]
}

---@param player_index uint
local function build_player_log(player_index)
	local player = game.get_player(player_index)
	---@cast player -?
	if storage.player_logs[player_index] then return log("Player already had a log. '"..player.name.."' at "..player_index) end
	storage.player_logs[player_index] = chatlog.new(storage.master_log, player)
	--[[NOTE:
		I have considered retroactively adding them to the list of recipients for their force
		But... that's hightly likely to add people to 'player' force messages only for some other script to assign them to a force
		If any mod has an actual team under 'player', this means that newly joining players might see secrets

		I wonder if it makes sense to wait a tick before doing so?
	]]
end
---Adds a new chatlog for player_index if it didn't exist before
manager.events[defines.events.on_player_created] = function (event)
	build_player_log(event.player_index)
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
		if chat.type == "player" then
			if chat.recipient.index == player_index then
				log:remove(chat_id)
			end

		elseif chat.type == "surface"
			or chat.type == "force" then
			chat.recipients[player_index] = nil
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
	--TODO: also clean the master log of messages exclusive to this player ..?
end

---@alias PlayerReference ChatPlayer|PlayerIdentification

---@class ChatParams.base
---The contents of the message.
---@field message LocalisedString
---The index of the player who the message will be attributed to.
---@field sender? PlayerReference
---The base color of the message. Defaults to white
---@field color? Color
---Whether or not the message is faded out by the player's settings. Defaults to `false`.
---@field process_color? boolean
---
---If a sound should be emitted for this message. Defaults to `defines.print_sound.use_player_settings` if clear is `false`. Otherwise defaults to `defines.print_sound.never`.
---@field sound? defines.print_sound
---The sound to play. If not given, [UtilitySounds::console\_message](https://lua-api.factorio.com/latest/prototypes/UtilitySounds.html#console_message) will be used instead.
---@field sound_path? SoundPath
---The volume of the sound to play. Must be between 0 and 1 inclusive. Defaults to `1`.
---@field volume_modifier? float

---@class ChatParams.global : ChatParams.base
---@field type "global"|"command"
---@field recipient nil

---@class ChatParams.force : ChatParams.base
---@field type "force"
---The force that received the message.
---@field recipient ForceID

---@class ChatParams.surface : ChatParams.base
---@field type "surface"
---The surface that received the message.
---@field recipient SurfaceIdentification

---@class ChatParams.player : ChatParams.base
---@field type "player"
---The player that received the message.
---@field recipient PlayerReference

---@alias ChatParams
---| ChatParams.global
---| ChatParams.force
---| ChatParams.surface
---| ChatParams.player

---@class ChatParamsValidated.global : ChatParams.global
---@field sender ChatPlayer?
---@class ChatParamsValidated.force : ChatParams.force
---@field sender ChatPlayer?
---@field recipient uint
---@class ChatParamsValidated.surface : ChatParams.surface
---@field sender ChatPlayer?
---@field recipient uint
---@class ChatParamsValidated.player : ChatParams.player
---@field sender ChatPlayer?
---@field recipient ChatPlayer
---@alias ChatParamsValidated
---| ChatParamsValidated.global
---| ChatParamsValidated.force
---| ChatParamsValidated.surface
---| ChatParamsValidated.player
---Adds a message to chat history
---@param tentative_chat ChatParamsValidated
manager.add_message = function(tentative_chat)
	---@type Chat
	local new_chat = {
		chat_id = storage.master_log.last_index + 1,
		tick = game.ticks_played,

		type = tentative_chat.type,
		message = tentative_chat.message,
		sender = tentative_chat.sender,
		color = tentative_chat.color,
		process_color = tentative_chat.process_color,
	}

	if new_chat.type == "surface" then
		---@cast tentative_chat ChatParamsValidated.surface
		local surface_index = tentative_chat.recipient
		new_chat.recipient_index = surface_index
		---@type uint[]
		local list, count = {}, 0
		new_chat.recipients = list

		for index, player in pairs(game.players) do
			---@cast index uint
			if surface_index == player.surface_index then
				count = count + 1
				list[count] = index
			end
		end

	elseif new_chat.type == "force" then
		---@cast tentative_chat ChatParamsValidated.force
		local force_index = tentative_chat.recipient
		new_chat.recipient_index = force_index
		---@type table<uint,true>
		local list = {}
		new_chat.recipients = list

		for _, player in pairs(game.forces[force_index].players) do
			list[player.index] = true
		end

	elseif new_chat.type == "player" then
		---@cast tentative_chat ChatParamsValidated.player
		new_chat.recipient = tentative_chat.recipient
	end


	storage.master_log:add(new_chat, settings.global["bc-global-chat-history"].value--[[@as int]],
		nil -- This would be used to clean up any outside references to a chat
	)

	for player_index, player in pairs(game.players) do
		---@cast player_index uint

		if chatlog.passes_filter(new_chat, {
			player_index = player_index,
		}) then
			-- Only add to it if it was already built
			-- It should be automatically added when building it
			local player_log = storage.player_logs[player_index]
			if player_log then
				player_log:add(new_chat, 36) --TODO: Figure out what to do with this value
			else
				build_player_log(player_index) --FIXME: this also doesn't use the 36 of the other method
			end
		end
	end
end

manager.events[defines.events.on_runtime_mod_setting_changed] = function (event)
	--FIXME: This is *entirely* old
  local setting = event.setting
  if event.setting_type == "runtime-global" then
    if setting == "bc-global-chat-history" then
      -- Send a message to notify the setting change
      -- Also to cause the ChatHistoryManager to fix a chatlog that's too long
      manager.add_message{
				type = "global",
        message = {
					"chat-localization.bc-global-history-changed",
					settings.global[setting].value
				}
      }
      -- printer.print_chat("global")
    end
  else
    local player_index = event.player_index
    if not player_index then return log("Who changed their setting???") end
    if setting == "bc-player-closeable-chat" then
      -- Clear opened value when closeable is disabled
      -- Also does it when enabled, but they should just be in main menu
      -- storage.isChatOpen[player_index--[[@as int]]] = nil
      -- Update chat to now match the openness it Should be now
      -- printer.print_chat("player", player_index)
    elseif (
      setting == "bc-color-fade" or
      setting == "bc-default-color" or
      setting == "bc-error-color" or
      setting == "bc-warn-color" or
      setting == "bc-debug-color"
    ) then
      -- Reprint chat to update the the printed chat
      -- printer.print_chat("player", player_index)
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