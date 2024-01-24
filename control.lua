---@alias historyLevel "global"|"force"|"player"
require("runtime_migrations")

local reloaded = false
local ChatHistoryManager = require("ChatHistoryManager")

remote.add_interface("emojipack registration", {
	add = function (mod_name, shortcode_dictionary)
		if not script.active_mods[mod_name] then return end
		global.emojipacks = global.emojipacks or {}

		global.emojipacks[mod_name] = shortcode_dictionary
	end
})

---Replaces all instances of a pattern with the output of the provided function
---@param text string
---@param pattern string
---@param replaceFun fun(match:string):string
---@return unknown
local function replace_all(text, pattern, replaceFun)
	local output = text
	for match in text:gmatch(pattern) do
		local front, back = output:find(match, 1, true)
		local firsthalf = output:sub(1, front-1)
		local secondHalf = output:sub(back+1)
		output = firsthalf..replaceFun(match)..secondHalf
	end
	return output
end

---Clean emojipacks of unloaded mods
local function clean_emojipacks()
	local defunct_mods = {}
	for mod_name in pairs(global.emojipacks) do
		if not script.active_mods[mod_name] then
			defunct_mods[#defunct_mods+1] = mod_name
		end
	end
	for _, defunct_mod in pairs(defunct_mods) do
		global.emojipacks[defunct_mod] = nil
	end
end

---Replaces `:<shortcodes>:` into their emoji
---@param text string
local function replace_shortcodes(text)
	if reloaded then clean_emojipacks() end

	return replace_all(text, "%:%S+%:", function (shortcode)
		local item = nil
		for _, dictionary in pairs(global.emojipacks) do
			item = dictionary[shortcode:sub(2,-2)] or item
		end
		return item or shortcode
	end)
end

---Turns the message into a chat message
---@param sender LuaPlayer
---@param text string
---@return string
local function processMessage(sender, text)
	-- local fullMessage = ""

	-- -- Add player name
	-- fullMessage = fullMessage..sender.name..": "

	--Process Item codes with images
	local message = replace_shortcodes(text)

	--- Dropdown based icon settings
	-- ---@alias icon-replacement-setting "bc-icon-none"|"bc-icon-signals"|"bc-icon-items"|"bc-icon-entities"|"bc-icon-almost-everything"|"bc-icon-everything"
	-- local replacement_level = settings.get_player_settings(sender)["bc-icon-replacement"].value --[[@as icon-replacement-setting]]

	-- if replacement_level == "bc-icon-everything" then goto everything
	-- elseif replacement_level == "bc-icon-almost-everything" then goto almost_everything
	-- elseif replacement_level == "bc-icon-entities" then goto entities
	-- elseif replacement_level =="bc-icon-items" then goto items
	-- elseif replacement_level == "bc-icon-signals" then goto signals
	-- elseif replacement_level == "bc-icon-none" then goto none
	-- end

	-- ::everything::
	-- message = replace_all(message, "%[achievement=%S+]", function (match)
	-- 	return "[img=achievement."..match:sub(9)
	-- end)
	-- message = replace_all(message, "%[tile=%S+]", function (match)
	-- 	return "[img=tile."..match:sub(9)
	-- end)
	-- message = replace_all(message, "%[item-group=%S+]", function (match)
	-- 	return "[img=item-group."..match:sub(9)
	-- end)

	-- ::almost_everything::
	-- message = replace_all(message, "%[technology=%S+]", function (match)
	-- 	return "[img=technology."..match:sub(9)
	-- end)
	-- message = replace_all(message, "%[recipe=%S+]", function (match)
	-- 	return "[img=recipe."..match:sub(9)
	-- end)

	-- ::entities::
	-- message = replace_all(message, "%[entity=%S+]", function (match)
	-- 	return "[img=entity."..match:sub(9)
	-- end)

	-- ::items::
	-- message = replace_all(message, "%[item=%S+]", function (match)
	-- 	return "[img=item."..match:sub(7)
	-- end)
	-- message = replace_all(message, "%[fluid=%S+]", function (match)
	-- 	return "[img=fluid."..match:sub(8)
	-- end)

	-- ::signals::
	-- message = replace_all(message, "%[virtual%-signal=%S+]", function (match)
	-- 	return "[img=virtual-signal."..match:sub(17)
	-- end)

	-- ::none::

	--- Toggle based icon settings
	local player_settings = settings.get_player_settings(sender)
	local icons = {"item","entity","technology","recipe","item-group","fluid","tile","virtual-signal","achievement"}

	for _,icon in pairs(icons) do
		if(player_settings["bc-"..icon.."-icon"].value) then
			message = replace_all(message, "%["..icon:gsub("%-", "%%-").."=%S+]", function (match)
				return "[img="..icon.."."..match:sub(3+#icon)
			end)
		end
	end
	return message
end

---Processes messsage, saves it to history, then sends latest x messages
---@param header LocalisedString
---@param message string
---@param color Color?
---@param send_level historyLevel
---@param recipient integer?
local function send_message(header, message, color, send_level, recipient)
---@diagnostic disable-next-line: need-check-nil
	header[1] = header[1] or "chat-localization.bc-empty-header"

	if send_level ~= "global" and not recipient then
		return log("Wasn't given a location to send the message!!\n")
	end

	ChatHistoryManager.add_message{
		message = message,
		header = header,
		color = color,
		level = send_level,
		chat_index = recipient
	}

	ChatHistoryManager.print_chat(send_level, recipient)
end

---Sends an ephemeral warning message to player
---@param player LuaPlayer
---@param message LocalisedString
local function warn(player, message)
	player.print(message, settings.get_player_settings(player)["bc-warn-color"].value--[[@as Color]])
end

-- TODO: Add Nicknames?

---Sends a message globally
---@param player LuaPlayer
---@param message string
local function shout(player, message)
	message = processMessage(player, message)
	send_message({"chat-localization.bc-shout-header", player.name}, message, player.chat_color, "global")
end
---Sends a message to a player
---@param player LuaPlayer
---@param recipient LuaPlayer
---@param message string
local function whisper(player, recipient, message)
	message = processMessage(player, message)
	send_message({"chat-localization.bc-whisper-to-header", recipient.name}, message, player.chat_color, "player", player.index)
	send_message({"chat-localization.bc-whisper-from-header", player.name}, message, player.chat_color, "player", recipient.index)
end

script.on_event(defines.events.on_console_chat, function (event)
	local player = game.get_player(event.player_index)
	if not player then return end
	local message = processMessage(player, event.message)
	send_message({"chat-localization.bc-message-header", player.name}, message, player.chat_color, "force", player.force_index)
	-- log{"", "global-chat-log", serpent.block(global.GlobalChatLog), "\n"}
	-- log{"", "force-chat-log", serpent.block(global.ForceChatLog), "\n"}
	-- log{"", "player-chat-log", serpent.block(global.PlayerChatLog), "\n"}
end)

script.on_event(defines.events.on_console_command, function (event)
	local player = game.get_player(event.player_index)
	if not player then return end
	if event.command == "shout" then
		shout(player, event.parameters)
	elseif event.command == "whisper" then
		local target = event.parameters:match("%S+")
		local recipient = game.get_player(target);

		if not recipient then
			-- FIXME: How do I send this *after* the command response?
			-- Maybe add a delay-send command?
			return warn(player, {"player-doesnt-exist", target})
		end

		local message = event.parameters:sub(#target+2);
		whisper(player, recipient, message)
	end
end)

script.on_init(function ()
	global.emojipacks = {}
	ChatHistoryManager.init()
end)
script.on_load(function ()
	reloaded = true
end)

--#region Players/Forces Created/Destroyed
script.on_event(defines.events.on_player_created, function (event)
	ChatHistoryManager.add_player(event.player_index)
end)
script.on_event(defines.events.on_force_created, function (event)
	ChatHistoryManager.add_force(event.force.index)
end)
script.on_event(defines.events.on_player_removed, function (event)
	ChatHistoryManager.remove_player(event.player_index)
end)
script.on_event(defines.events.on_forces_merged, function (event)
	ChatHistoryManager.remove_force(event.source_index)
end)
--#endregion

-- TODO: also handle command events to replace their error messages
-- and handle the messages without events, like admin list messages
--#region System messages
script.on_event(defines.events.on_player_joined_game, function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one joined???") end
	send_message({"multiplayer.player-joined-game", player.name}, "", player.chat_color, "global")
end)
script.on_event(defines.events.on_player_left_game, function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one left???") end
	send_message({"multiplayer.player-left-game", player.name}, "", player.chat_color, "global")
end)
script.on_event(defines.events.on_player_died, function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one died???") end
	if not player.character then return log("Player.character doesn't exist on death, change to pre-death") end
	local message = {
		"multiplayer.player-died",
		player.name,
		player.character.gps_tag --[[@as LocalisedString]]
	}
	if event.cause then
		message[1] = "multiplayer.player-died-by"
		message[4] = message[3]
		message[3] = event.cause.localised_name
	end
	send_message(message, "", player.chat_color, "global")
end)

--Research -- TODO: figure out if you can know about queuing
script.on_event(defines.events.on_research_finished, function (event)
	if event.by_script then return end
	send_message({"technology-researched", event.research.localised_name}, "",
		settings.global["bc-default-color"].value--[[@as Color]], "global")
end)

--Admin promotion and demotion
script.on_event(defines.events.on_player_promoted, function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("Who was promoted??") end
	local message = {
		"player-was-promoted",
		player.name,
		"unknown" -- TODO: Figure out how to know this
	}
	send_message(message, "", player.chat_color, "global")
end)
script.on_event(defines.events.on_player_demoted, function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("Who was demoted??") end
	local message = {
		"player-was-demoted",
		player.name,
		"unknown" -- TODO: Figure out how to know this
	}
	send_message(message, "", player.chat_color, "global")
end)

--Banned and kicked
script.on_event(defines.events.on_player_banned, function (event)
	local player = game.get_player(event.by_player)
	if not player then
	---@diagnostic disable-next-line: missing-fields
		player = {
			name = "console",
			chat_color = settings.global["bc-default-color"].value --[[@as Color]]
		}
	end
	local message = {
		"player-was-banned",
		event.player_name,
		player.name,
		event.reason or "unspecified"
	}
	if not event.player_index then message[1] = "unknown-player-was-banned" end
	send_message(message, "", player.chat_color, "global")
end)
script.on_event(defines.events.on_player_unbanned, function (event)
	local player = game.get_player(event.by_player)
	if not player then
	---@diagnostic disable-next-line: missing-fields
		player = {
			name = "console",
			chat_color = settings.global["bc-default-color"].value --[[@as Color]]
		}
	end
	local message = {
		"player-was-unbanned",
		event.player_name,
		player.name
	}
	send_message(message, "", player.chat_color, "global")
end)
script.on_event(defines.events.on_player_kicked, function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one was kicked???") end
	local by_player = game.get_player(event.by_player)
	if not by_player then
	---@diagnostic disable-next-line: missing-fields
		by_player = {
			name = "console",
			chat_color = settings.global["bc-default-color"].value --[[@as Color]]
		}
	end
	local message = {
		"player-was-kicked",
		player.name,
		by_player.name,
		event.reason or "unspecified"
	}
	send_message(message, "", by_player.chat_color, "global")
end)
--#endregion