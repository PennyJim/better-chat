local commands = require("runtime.commands")
local eventData = require("runtime.events")
local events = eventData.events
local eventFilters = eventData.eventFilters

local listener = {
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

local function register_enabled_listeners()
	for event, handler in pairs(events) do
		if not global.disabledListeners[event] then
			script.on_event(event, handler, eventFilters[event])
		end
	end
end
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