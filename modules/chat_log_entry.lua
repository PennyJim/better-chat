local module = {module_type = "chat_log_entry", handlers = {} --[[@as GuiModuleEventHandlers]]}

---@class WindowState.my_module : modules.WindowState
-- Where custom fields would go

---WindowState.my_module
---@param state table
module.setup_state = function(state)
	-- Setup your own fields here or restore
	-- elements after the window was recreated
end

local handler_names = {
	-- A generic place to make sure handler names match
	-- in both handler definitons and in the build_func
	my_handler = "my_module.my_handler" -- Standardly prepended with module name to avoid naming collisions
}

---@alias (partial) modules.types
---| "chat_log_entry"

---@class ChatLogEntryParams : modules.ModuleDef
---@field module_type "chat_log_entry"
---@field name string
-- where LuaLS parameter definitons go
---@field chat Chat
---@type ModuleParameterDict
module.parameters = {
	-- Where gui-modules parameter definitons go
	chat = {is_optional = false, type = {"table"}},
	name = {is_optional = true, type = {"string"}},
}

---Creates the frame for a window with an exit button
---@param params ChatLogEntryParams
---@return flib.GuiElemDef
function module.build_func(params)
	local chat = params.chat
	return {
		type = "frame", name = params.name,
		children = {
			{
				type = "label",
				caption = format_time(chat.tick)
			},
			{
				type = "label",
				caption = "|"
			},
			{
				type = "label",
				caption = chat.message,
				style_mods = {font_color = chat.color}
			}
		}
	}
end

-- How to define handlers
---@param state WindowState.my_module
module.handlers[handler_names.my_handler] = function (state, elem, OriginalEvent)
	-- Do stuff
end

return module --[[@as modules.GuiModuleDef]]