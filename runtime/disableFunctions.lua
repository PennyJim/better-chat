local event_handler = require("__better-chat__.runtime.custom_event_handler")
local commands = require("__better-chat__.runtime.commands")
local eventData = require("__better-chat__.runtime.events")
local events = eventData.events

---@class handler_within_event_handler : custom_event_handler
local handlers = {events = events, remote_interfaces = {}}

--MARK: Filtering

---WARN: Make sure to restore it in on_load
local disabledListeners = storage.disabledListeners

for i, func in pairs(events--[[@as table<defines.events,fun(event:EventData)>]]) do
	events[i] = function (event)
		if disabledListeners[i] then return end
		return func(event)
	end
end

--MARK: Events

---Marks the listener for the given event as disabled
---@param mod_name string
---@param event defines.events
---@return boolean success
local function disable_event(mod_name, event)
	if not script.active_mods[mod_name] then return false end
	if not events[event] then return false end
	local disabled = storage.disabledListeners[event]
	if disabled then
		disabled[#disabled+1] = mod_name ---FIXME: Can have a mod disable multiple times. Turn it into a lookup instead of array!!
	else
		storage.disabledListeners[event] = {mod_name}
		-- script.on_event(event, nil)
	end
	return true
end

---Unmarks the listener for the given event as disabled
---@param mod_name string
---@param event defines.events
---@return boolean success
local function enable_event(mod_name, event)
	if not script.active_mods[mod_name] then return false end
	if not events[event] then return false end
	local disabled = storage.disabledListeners[event]
	if not disabled then return false end

	local mod_index = nil
	for index, mod in pairs(disabled) do
		if mod == mod_name then
			mod_index = index
			break
		end
	end
	if not mod_index then return false end
	table.remove(disabled, mod_index)

	if #disabled == 0 then
		storage.disabledListeners[event] = nil
		-- script.on_event(event, events[event])
	end
	return true
end

--MARK: Commands

---Marks the handler for the given command as disabled
---@param mod_name string
---@param command string
---@return boolean success
local function disable_command(mod_name, command)
	if not script.active_mods[mod_name] then return false end
	if not commands[command] then return false end
	local disabled = storage.disabledCommands[command]
	if disabled then
		disabled[#disabled+1] = mod_name
	else
		storage.disabledCommands[command] = {mod_name}
	end
	return true
end
---Unmarks the handler for the given command as disabled
---@param mod_name string
---@param command string
---@return boolean success
local function enable_command(mod_name, command)
	if not script.active_mods[mod_name] then return false end
	if not commands[command] then return false end
	local disabled = storage.disabledCommands[command]
	if not disabled then return false end

	local mod_index = nil
	for index, mod in pairs(disabled) do
		if mod == mod_name then
			mod_index = index
			break
		end
	end
	if not mod_index then return false end
	table.remove(disabled, mod_index)

	if #disabled == 0 then
		storage.disabledCommands[command] = nil
	end
	return true
end

handlers.remote_interfaces["better-chat"] = {
	disable_listener = disable_event,
	enable_listener = enable_event,
	disable_command = disable_command,
	enable_command = enable_command,
}

--MARK: Structural

---Register all listeners not in global.disabledListeners
local function on_load()
	eventData.get_remote_events()
	event_handler.finalize_libraries()

	disabledListeners = storage.disabledListeners
end
handlers.on_load = on_load
handlers.on_init = on_load

---@param event ConfigurationChangedData
function handlers.on_configuration_changed(event)
	for mod_name, change in pairs(event.mod_changes) do
		if not change.new_version then
			for event in pairs(storage.disabledListeners) do
				enable_event(mod_name, event)
			end
			for key in pairs(storage.disabledCommands) do
				enable_command(mod_name, key)
			end
		end
	end
end

return handlers