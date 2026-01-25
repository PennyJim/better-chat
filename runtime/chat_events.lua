local handled_commands = require("chat_commands")
local handle_messages = require("handle_messages")
local send_message = handle_messages.send_message
local color = handle_messages.color

---@type event_handler.events
local handled_events = {}
---@type event_handler
local event_handler = {events = {}, remote_interfaces = {}}

--MARK: Remote events

---@alias command_definition table<string,fun(player?:LuaPlayer|ChatPlayer,event:EventData.on_console_command)>
---@type {[string]:fun(events:event_handler.events, commands:command_definition)}
local remote_event_handlers = {
	-- ["pvp"] = require("remote_events.pvp")
}
local function get_remote_events()
	local interfaces = remote.interfaces
	for remote_interface, func in pairs(remote_event_handlers) do
		if interfaces[remote_interface] then
			func(handled_events, handled_commands)
		end
	end
end

--MARK: Basic events

---@type ChatPlayer
local server_player = {
	name = "<Server>",
	color = {r=1,g=1,b=1,a=1},
}

handled_events[defines.events.on_console_chat] = function (event)
	local player_index = event.player_index
	local send_level = settings.global["bc-normal-chat-type"].value --[[@as PrintLevel]]

	---@type ChatPlayer|LuaPlayer?
	local player
	if player_index then
		player = game.get_player(player_index)
	else
		send_level = "global"
		player = server_player
	end

	if not player then return end
	local recipient = send_level == "force" and player.force_index
		or send_level == "player" and player_index
		or send_level == "surface" and player.surface_index
		or nil

	local message = handle_messages.process_message(player, send_level, event.message)
	send_message{
		sender = player,
		message = message,
		color = player.chat_color,
		process_color = true,
		type = send_level,
		recipient = recipient,
	}
end

---@param event EventData.on_console_command
handled_events[defines.events.on_console_command] = function (event)
	local player_index = event.player_index
	local player = player_index and game.get_player(player_index) or server_player

	local handler = handled_commands[event.command] or function () log(event.command..": Not implemented in Better Chatting") end
	local enabled = not storage.disabled_command_handlers[event.command]
	if handler and enabled then handler(player, event) end
end

--MARK: Disabling Interface

---@type table<string,function>
local interface = {}
event_handler.remote_interfaces["better-chat"] = interface

---@param mod_name string
---@param event LuaEventType
---@return boolean success
function interface.disable_event(mod_name, event)
	if not script.active_mods[mod_name] then return false end
	event = script.get_event_id(event)
	if not handled_events[event] then return false end
	local disabled = storage.disabled_handlers[event]

	if not disabled then
		disabled = {[mod_name]=true}
		storage.disabled_handlers[event] = disabled
	else
		disabled[mod_name] = true
	end
	return true
end

---@param mod_name string
---@param event LuaEventType
---@return boolean success
function interface.enable_event(mod_name, event)
	if not script.active_mods[mod_name] then return false end
	event = script.get_event_id(event)
	if not handled_events[event] then return false end

	local disabled = storage.disabled_handlers[event]
	if not disabled then return true end

	disabled[mod_name] = nil
	if not next(disabled) then
		storage.disabled_handlers[event] = nil
	end
	return true
end

---@param mod_name string
---@param command string
---@return boolean success
function interface.disable_command(mod_name, command)
	if not script.active_mods[mod_name] then return false end
	if not handled_events[command] then return false end
	local disabled = storage.disabled_command_handlers[command]

	if not disabled then
		disabled = {[mod_name]=true}
		storage.disabled_command_handlers[command] = disabled
	else
		disabled[mod_name] = true
	end
	return true
end

---@param mod_name string
---@param command string
---@return boolean success
function interface.enable_command(mod_name, command)
	if not script.active_mods[mod_name] then return false end
	if not handled_events[command] then return false end

	local disabled = storage.disabled_command_handlers[command]
	if not disabled then return true end

	disabled[mod_name] = nil
	if not next(disabled) then
		storage.disabled_command_handlers[command] = nil
	end
	return true
end

--MARK: Structural

local filtered_events = event_handler.events
local disabled_handlers = storage.disabled_handlers

local function filter_events()
	for event_id, handler in pairs(handled_events--[[@as table<defines.events,function>]]) do
		filtered_events[event_id] = function (event)
			if disabled_handlers[event_id] then return end
			return handler(event)
		end
	end
end

function event_handler.on_load()
	get_remote_events()
	filter_events()
	event_handler_lib.finalize_libraries()
	disabled_handlers = storage.disabled_handlers
end

---@class ModDisables
---The mods that have marked this as disabled
---@field [string] true

function event_handler.on_init()
	---@type table<defines.events,table<string,true>?>
	storage.disabled_handlers = {}
	---@type table<string,table<string,true>?>
	storage.disabled_command_handlers = {}

	--- A mapping from player to the last player to message them
	---@type table<uint,string>
	storage.last_whispered = {}

	event_handler.on_load()
end

function event_handler.on_configuration_changed(event)
	for mod_name, change in pairs(event.mod_changes) do
		if not change.new_version then
			for event_id in pairs(storage.disabled_handlers) do
				interface.enable_event(mod_name, event_id)
			end
			for command in pairs(storage.disabled_command_handlers) do
				interface.enable_command(mod_name, command)
			end
		end
	end
end

return event_handler