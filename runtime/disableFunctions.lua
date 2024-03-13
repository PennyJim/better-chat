local commands = require("__better-chat__.runtime.commands")
local eventData = require("__better-chat__.runtime.events")
local events = eventData.events
local eventFilters = eventData.eventFilters

local listener = {
	---Marks the listener for the given event as disabled
	---@param mod_name string
	---@param event defines.events
	---@return boolean success
	disable = function (mod_name, event)
		if not script.active_mods[mod_name] then return false end
		if not events[event] then return false end
		local disabled = global.disabledListeners[event]
		if disabled then
			disabled[#disabled+1] = mod_name
		else
			global.disabledListeners[event] = {mod_name}
			script.on_event(event, nil)
		end
		return true
	end,
	---Unmarks the listener for the given event as disabled
	---@param mod_name string
	---@param event defines.events
	---@return boolean success
	enable = function (mod_name, event)
		if not script.active_mods[mod_name] then return false end
		if not events[event] then return false end
		local disabled = global.disabledListeners[event]
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
			global.disabledListeners[event] = nil
			script.on_event(event, events[event], eventFilters[event])
		end
		return true
	end
}
local command = {
	---Marks the handler for the given command as disabled
	---@param mod_name string
	---@param command string
	---@return boolean success
	disable = function (mod_name, command)
		if not script.active_mods[mod_name] then return false end
		if not commands[command] then return false end
		local disabled = global.disabledCommands[command]
		if disabled then
			disabled[#disabled+1] = mod_name
		else
			global.disabledCommands[command] = {mod_name}
		end
		return true
	end,
	---Unmarks the handler for the given command as disabled
	---@param mod_name string
	---@param command string
	---@return boolean success
	enable = function (mod_name, command)
		if not script.active_mods[mod_name] then return false end
		if not commands[command] then return false end
		local disabled = global.disabledCommands[command]
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
			global.disabledListeners[command] = nil
		end
		return true
	end
}

---Register all listeners not in global.disabledListeners
local function register_enabled_listeners()
	for event, handler in pairs(events) do
		if not global.disabledListeners or not global.disabledListeners[event] then
			script.on_event(event, handler, eventFilters[event])
		end
	end
end
---Re-enable all Listeners that are in global.disabledListeners from disabled mods
---@param changes {[string]: ModChangeData}
local function reenable(changes)
	for mod_name, change in pairs(changes) do
		if not change.new_version then
			for event in pairs(global.disabledListeners) do
				listener.enable(mod_name, event)
			end
			for key in pairs(global.disabledCommands) do
				command.enable(mod_name, key)
			end
		end
	end
end
return {
	listener = listener,
	command = command,
	register_enabled_listeners = register_enabled_listeners,
	reenable = reenable,
}