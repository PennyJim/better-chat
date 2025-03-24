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
	--my_handler = "my_module.my_handler" -- Standardly prepended with module name to avoid naming collisions
}

---@param player ChatPlayer
---@param name_override LocalisedString?
---@return LocalisedString
local function print_player(player, name_override)
	local color = player.color
	return {"chat-localization.colored-text",
		name_override or player.name,
		color.r,
		color.g,
		color.b,
	}
end

---@type table<ChatMessageType,LocalisedString|fun(chat:Chat,params:ChatLogEntryParams):LocalisedString>
local badge_switch = {
	global =  function() return {"chat-localization.bc-global-badge"} end,
	command = function() return {"chat-localization.bc-command-badge"} end,

	-- Turn the badge into a tag with a name if setting is enabled.
	force =   function(chat) return {"chat-localization.bc-force-badge"} end,
	player =  function(chat) return {"chat-localization.bc-player-badge"} end,
	surface = function(chat) return {"chat-localization.bc-surface-badge"} end,

	---@param chat Chat.whisper
	whisper = function(chat, params)
		local player_index = params.player.index
		return {"chat-localization.bc-whisper-badge",
			print_player(chat.sender, params.expand_badges and chat.sender.index == player_index {"chat-localization.you"}),
			print_player(chat.recipient, params.expand_badges and chat.recipient.index == player_index {"chat-localization.you"}),
		}
	end
}

---@alias (partial) modules.types
---| "chat_log_entry"

---@class ChatLogEntryParams : modules.ModuleDef
---@field module_type "chat_log_entry"
-- where LuaLS parameter definitons go
---@field chat Chat
---@field player LuaPlayer
---@field expand_badges boolean?
---
---@field name string?
---@type ModuleParameterDict
module.parameters = {
	-- Where gui-modules parameter definitons go
	chat = {is_optional = false, type = {"table"}},
	player = {is_optional = false, type = {"userdata"}},
	expand_badges = {is_optional = true, type = {"boolean"}, default = false},

	name = {is_optional = true, type = {"string"}},
}

---Creates the frame for a window with an exit button
---@param params ChatLogEntryParams
---@return flib.GuiElemDef
function module.build_func(params)
	local chat = params.chat
	local badge = badge_switch[chat.type](chat, params)

	local show_sender = chat.sender and chat.type ~= "whisper"
	local processed_color = "something"

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
				caption = badge
			},
			show_sender and {
				type = "label",
				caption = print_player(chat.sender)
			} or {},
			show_sender and {
				type = "label",
				caption = ":"
			} or {},
			{
				type = "label",
				caption = chat.message,
				tags = {process_color=chat.process_color},
				style_mods = {font_color = chat.color}
			}
		}
	}
end

-- -- How to define handlers
-- ---@param state WindowState.my_module
-- module.handlers[handler_names.my_handler] = function (state, elem, OriginalEvent)
-- 	-- Do stuff
-- end

return module --[[@as modules.GuiModuleDef]]