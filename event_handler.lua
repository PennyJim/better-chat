if ... ~= "__better-chat__.runtime.custom_event_handler" then
	return require("__better-chat__.runtime.custom_event_handler")
end
local util = require("util")

---@class custom_event_handler.remote_interfaces : {[string]:{[string]:function}}

---@class custom_event_handler : event_handler
---@field on_script_trigger? table<string,fun(event:EventData.on_script_trigger_effect)>
---@field remote_interfaces? table<string,table<string,function>>
---@field commands? table<string,fun(event:CustomCommandData)>
---@field command_helps? table<string,LocalisedString> If a help message is left unset, it'll default to `{"command-help."..name}`
local tmp = {
	---@deprecated DO NOT USE. Fucking hate this interface
	add_commands = nil,
	---@deprecated DO NOT USE. Fucking hate this interface
	add_remote_interface = nil,
}
---@diagnostic disable-next-line: cast-local-type
tmp = nil
---@param string LocalisedString
local function pack_localized_concat(string)
  ---@cast string -?
  local length = #string
  if length <= 21 then
    return string
  end

  ---@type LocalisedString
  local new_string, index = {""}, 1
  for i = 2, length, 20 do
    index = index + 1
    new_string[index] = {"",
      table.unpack(string--[[@as LocalisedString[] ]], i, i+19)
    }
  end

  return pack_localized_concat(new_string)
end

---@type custom_event_handler[]
local libraries = {}

local setup_ran = false

local register_remote_interfaces = function()
  --Sometimes, in special cases, on_init and on_load can be run at the same time. Only register events once in this case.
  if setup_ran then return end
  setup_ran = true

	---@type table<string,table<string,function[]>>
	local unmerged_interfaces = {}
	---@type table<string,fun(event:CustomCommandData)[]>
	local custom_commands = {}
	---@type table<string,LocalisedString[]>
	local command_helps = {}

  for lib_name, lib in pairs (libraries) do


		if lib.remote_interfaces then
			for name, new in pairs(lib.remote_interfaces) do
				local current = unmerged_interfaces[name]

				if not current then
					current = {}
					unmerged_interfaces[name] = current
				end

				for key, handler in pairs(new) do
					current[key] = current[key] or {}
					current[key][lib_name] = handler
				end
			end
		end


		if lib.commands then
			for name, handler in pairs(lib.commands) do
				custom_commands[name] = custom_commands[name] or {}
				custom_commands[name][lib_name] = handler
			end
		end

		if lib.command_helps then
			for name, help in pairs(lib.command_helps) do
				command_helps[name] = command_helps[name] or {}
				command_helps[name][lib_name] = help
			end
		end

		-- And I guess I have to still support these :(
---@diagnostic disable-next-line: deprecated
		if lib.add_commands then lib.add_commands() end
---@diagnostic disable-next-line: deprecated
		if lib.add_remote_interface then lib.add_remote_interface() end
  end


	for name, interface in pairs(unmerged_interfaces) do
		---@type table<string,function>
		local merged_interface = {}

		for key, handlers in pairs(interface) do

			if not next(handlers, next(handlers)) then
				-- We only have *one* handler. Just pass it directly
				_, merged_interface[key] = next(handlers)
			else
				log("There are multiple handlers for the '"..name.."' inteface: "..key)

				local action = function (...)
					for _, handler in pairs(handlers) do
						local output = {handler(...)}
						if next(output) then
							log("Multi-handler remote interface had a truthy return. Returning early!")
							return table.unpack(output)
						end
					end
				end

				merged_interface[key] = action
			end

		end

		remote.add_interface(name, merged_interface)
	end

	for name, functions in pairs(custom_commands) do
		local helps = command_helps[name] or {{"command-help."..name}}
		---@type LocalisedString
		local help
		if not next(helps, next(helps)) then
			_, help = next(helps)
		else
			help = {""}
			local index = 1
			for _, value in pairs(helps) do
				help[index + 1] = value
				help[index + 2] = "\n"
				index = index + 2
			end
			help[index] = nil
			help = pack_localized_concat(help)
		end

		local action = function (command)
			for _, handler in pairs(functions) do
				handler(command)
			end
		end
		commands.add_command(name, help, action)
	end

end

local register_events = function()
	---@type table<defines.events, function[]>
  local all_events = {}
	---@type table<uint, function[]>
  local on_nth_tick = {}
	---@type table<string, function[]>
	local script_trigger = {}

  for lib_name, lib in pairs (libraries) do

    if lib.events then
      for k, handler in pairs (lib.events--[[@as table<defines.events,function>]]) do
        all_events[k] = all_events[k] or {}
        all_events[k][lib_name] = handler
      end
    end

    if lib.on_nth_tick then
      for n, handler in pairs (lib.on_nth_tick) do
        on_nth_tick[n] = on_nth_tick[n] or {}
        on_nth_tick[n][lib_name] = handler
      end
    end

		if lib.on_script_trigger then
			for e, handler in pairs (lib.on_script_trigger) do
				script_trigger[e] = script_trigger[e] or {}
				script_trigger[e][lib_name] = handler
			end
		end

  end

	if next(script_trigger) then
		local action = function (event)
			local funcs = script_trigger[event.effect_id]
			if funcs then
				for _, handler in pairs(funcs) do
					handler(event)
				end
			end
		end
		if all_events[defines.events.on_script_trigger_effect] then
			-- We want this to run first please
			table.insert(all_events[defines.events.on_script_trigger_effect], 1, action)
		else
			all_events[defines.events.on_script_trigger_effect] = {action}
		end
	end

  for event, handlers in pairs (all_events) do
    local action = function(event)
      for k, handler in pairs (handlers) do
        handler(event)
      end
    end
    script.on_event(event, action)
  end

  for n, handlers in pairs (on_nth_tick) do
    local action = function(event)
      for k, handler in pairs (handlers) do
        handler(event)
      end
    end
    script.on_nth_tick(n, action)
  end

end

script.on_init(function()
  register_remote_interfaces()
  register_events()
  for k, lib in pairs (libraries) do
    if lib.on_init then
      lib.on_init()
    end
  end
end)

script.on_load(function()
  register_remote_interfaces()
  register_events()
  for k, lib in pairs (libraries) do
    if lib.on_load then
      lib.on_load()
    end
  end
end)

script.on_configuration_changed(function(data)
  for k, lib in pairs (libraries) do
    if lib.on_configuration_changed then
      lib.on_configuration_changed(data)
    end
  end
end)

---@class custom_event_handler_lib : event_handler_lib
local handler = {}

---@param lib custom_event_handler|event_handler
handler.add_lib = function(lib)
  for k, current in pairs (libraries) do
    if current == lib then
      error("Trying to register same lib twice")
    end
  end
  table.insert(libraries, lib)
end

---@param libs (custom_event_handler|event_handler)[]
handler.add_libraries = function(libs)
  for k, lib in pairs (libs) do
    handler.add_lib(lib)
  end
end

--- Can be ran multiple times. Allows re-registering after adding event listeners
handler.finalize_libraries = function()
	register_events()
end

return handler