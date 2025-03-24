

---@class ColorSettings
---@field brighten_percent float

---returns the player settings related to color processing
---@param player_settings LuaCustomTable<string,ModSetting>
---@return ColorSettings
local function get_color_process_settings(player_settings)
	return {
		brighten_percent = player_settings["bc-color-fade"].value--[[@as float]]
	}
end

---Processes a color according to player settings
---@param color_settings ColorSettings
---@param color Color
---@return Color
local function process_color(color_settings, color)
	local new_color = {
		color[1] or color.r,
		color[2] or color.g,
		color[3] or color.b
	}
	--Brighten
	local brighten_inverse = 1/(1-color_settings.brighten_percent)
	new_color[1] = new_color[1]/brighten_inverse+color_settings.brighten_percent
	new_color[2] = new_color[2]/brighten_inverse+color_settings.brighten_percent
	new_color[3] = new_color[3]/brighten_inverse+color_settings.brighten_percent


	return new_color
end

---Formats the given tick in D+:HH:MM:SS
---@param tick int
---@return string
function format_time(tick)
	---@type int, int, int, int
	local seconds, minutes, hours, days
	seconds = tick / 60
	minutes, seconds = math.floor(seconds / 60), seconds % 60
	hours, minutes = math.floor(minutes / 60), minutes % 60
	days, hours = math.floor(hours / 24), hours % 24

	if days > 0 then
		return string.format("%d:%02d:%02d.%02d", days, hours, minutes, seconds)
	elseif hours > 0 then
		return string.format("%d:%02d.%02d", hours, minutes, seconds)
	else
		return string.format("%d.%02d", minutes, seconds)
	end
end
local format_time = format_time

---@param player ChatPlayer
local function print_player(player)
	local color = player.color
	return {"chat-localization.colored-text",
		player.name,
		color.r,
		color.g,
		color.b,
	}
end

--MARK: Chat Printing
---@type LuaPlayer
local printing_player
---@type boolean
local isChatOpen
---@type LuaCustomTable<string, ModSetting>
local player_settings
---@type boolean
local closeable
---@type Color
local default_color
---@type int
local message_linger
---@type boolean
local show_timestamp
---@type ColorSettings
local color_processing
---@type defines.print_sound
local sound = defines.print_sound.never
---@type SoundPath?
local sound_path
---@type float?
local volume_modifier

---@param chat Chat
---@param initial_message LocalisedString[]
local function general_chat_print(chat, initial_message)
	--Get general message color
	local color = chat.color or default_color

	if chat.process_color then
		color = process_color(color_processing, color)
	end

	local message = initial_message
	if show_timestamp then
		message[2] = format_time(chat.tick).." | "
	end

	--Print the message
	printing_player.print(message, {
		color = color,
		skip = defines.print_skip.never,

		sound = sound,
		sound_path = sound_path,
		volume_modifier = volume_modifier,
	})
	sound = defines.print_sound.never
	sound_path = nil
	volume_modifier = nil
end

---@param badge_key string
---@return fun(chat:Chat)
local function common_chat_print(badge_key)
	return function (chat)
		---@type LocalisedString[]
		local message = {"", nil, {badge_key}, nil, nil, chat.message}
		if chat.sender then
			message[4] = print_player(chat.sender)
			message[5] = ": "
		end
		general_chat_print(chat, message)
	end
end

---@type table<ChatMessageType,fun(chat:Chat)>
local specific_chat_print = {
	global = common_chat_print("chat-localization.bc-global-badge"),
	force = common_chat_print("chat-localization.bc-force-badge"),
	player = common_chat_print("chat-localization.bc-player-badge"),
	surface = common_chat_print("chat-localization.bc-surface-badge"),
	whisper = function (chat)
		local player_index = printing_player.index
		local is_sender = chat.sender.index == player_index

		---@type LocalisedString[]
		local message = {"", nil, {
			is_sender and "chat-localization.bc-whisper-to-header" or "chat-localization.bc-whisper-from-header",
			print_player(chat.recipient)
		}, chat.message}

		general_chat_print(chat, message)
	end,
	command = common_chat_print("chat-localization.bc-command-badge"),
}


---Prints the chats to the passed player
---@param player LuaPlayer
local function print_chats(player)
	local player_index = player.index
	printing_player = player
	isChatOpen = storage.isChatOpen:check(player_index)

	--Obtain relevant settings
	player_settings = settings.get_player_settings(player_index)
	closeable = player_settings["bc-player-closeable-chat"].value--[[@as boolean]]
	default_color = player_settings["bc-default-color"].value--[[@as Color]]
	message_linger = math.floor(player_settings["bc-message-linger"].value--[[@as double]] * 60)
	show_timestamp = player_settings["bc-show-timestamp"].value--[[@as boolean]]
	color_processing = get_color_process_settings(player_settings)

	player.clear_console()
	for _,chat in storage.player_logs[player_index]:from() do
		--Skip chat if doesn't need to be logged
		if closeable and not (isChatOpen or printing_player.controller_type == defines.controllers.spectator)
		and game.ticks_played > chat.tick + message_linger then
			-- Skip printing message
		else
			specific_chat_print[chat.type](chat)
		end
	end
end

---Prints the latest message from the player
---@param player LuaPlayer
local function print_chat(player)
	local player_index = player.index
	printing_player = player
	-- isChatOpen not necessary as closeable set to false

	--Obtain relevant settings
	player_settings = settings.get_player_settings(player_index)
	closeable = false -- Set to false to exit the skip printing check asap
	default_color = player_settings["bc-default-color"].value--[[@as Color]]
	-- message_linger not necessary as closeable set to false
	show_timestamp = player_settings["bc-show-timestamp"].value--[[@as boolean]]
	color_processing = get_color_process_settings(player_settings)

	local log = storage.player_logs[player_index]
	local chat = log.chat_array[log.last_index]

	specific_chat_print[chat.type](chat)
end

---@type table<PrintLevel, fun(index?:int,func:fun(player:LuaPlayer))>
local print_level_switch = {
	["global"] = function (index, func)
		for _, player in pairs(game.players) do
			func(player)
		end
	end,
	["force"] = function (index, func)
		---@cast index int
		for _, player in pairs(game.forces[index].players) do
			func(player)
		end
	end,
	["surface"] = function (index, func)
		---@cast index int
		for _, player in pairs(game.players) do
			if player.surface_index == index then func(player) end
		end
	end,
	["player"] = function (index, func)
		---@cast index int
		local player = game.get_player(index)
		if not player then return log("[ERR] Player getting printed to does not exist") end
		func(player)
	end
}

---@class ChatPrinter
local printer = {}

---Print out all messages for a group
---@param chat_level PrintLevel
---@param chat_index int?
---@param print_sound defines.print_sound?
---@param print_sound_path SoundPath?
---@param print_volume float?
printer.print_chat = function(chat_level, chat_index, print_sound, print_sound_path, print_volume)
	local func = print_level_switch[chat_level]
	if not func then return log({"invalid-destination"}) end

	sound = print_sound or defines.print_sound.never
	sound_path = print_sound_path
	volume_modifier = print_volume
	func(chat_index, print_chats)
end

---Print the latest message in the group without clearing chat first
---@param chat_level PrintLevel
---@param chat_index int?
---@param print_sound defines.print_sound? Defaults to `defines.print_sound.never`
---@param print_sound_path SoundPath?
---@param print_volume float?
printer.print_latest = function(chat_level, chat_index, print_sound, print_sound_path, print_volume)
	local func = print_level_switch[chat_level]
	if not func then return log({"invalid-destination"}) end

	sound = print_sound or defines.print_sound.never
	sound_path = print_sound_path
	volume_modifier = print_volume
	func(chat_index, print_chat)
end



return printer