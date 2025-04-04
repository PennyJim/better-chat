---@type modules.GuiModuleDef
---@diagnostic disable-next-line: missing-fields
local module = {
	module_type = "chat_log_entry",
	handlers = {}
}

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

---@param force LuaForce
---@return LocalisedString
local function print_force(force)
	local color = force.custom_color or force.color
	return {"chat-localization.colored-text",
	force.name,
	color.r,
	color.g,
	color.b,
}
end

---@param surface LuaSurface
---@return LocalisedString
local function print_surface(surface)
	return surface.localised_name or surface.name
end

---@param player ChatPlayer|LuaPlayer
---@param name_override LocalisedString?
---@return LocalisedString
local function print_player(player, name_override)
	---@type Color.0
	local color
	if type(player) == "table" then
		color = player.color
	else
		color = player.chat_color
	end
	return {"chat-localization.colored-text",
		name_override or player.name,
		color.r,
		color.g,
		color.b,
	}
end

---@type table<ChatMessageType,LocalisedString|fun(chat:Chat,params:ChatLogEntryArgs):LocalisedString>
local badge_switch = {
	global =  function() return {"chat-localization.bc-global-badge"} end,
	command = function() return {"chat-localization.bc-command-badge"} end,

	-- Turn the badge into a tag with a name if setting is enabled.
	force =   function(chat, params)
		return params.expand_badges
		and {"chat-localization.bc-expanded-force-badge", print_force(game.forces[chat.recipient_index])}
		or {"chat-localization.bc-force-badge"}
	end,
	player =  function(chat, params)
		return params.expand_badges
		-- It's safe to assume the player exists, because when they are deleted the messages get *wiped*
		and {"chat-localization.bc-expanded-player-badge", print_player(chat.recipient)}
		or {"chat-localization.bc-player-badge"}
	end,
	surface = function(chat, params)
		return params.expand_badges
		and {"chat-localization.bc-expanded-surface-badge", print_surface(game.surfaces[chat.recipient_index])}
		or {"chat-localization.bc-surface-badge"}
	end,

	---@param chat Chat.whisper
	whisper = function(chat, params)
		local player_index = params.player.index
		return {"chat-localization.bc-whisper-badge",
			print_player(chat.sender, not params.expand_badges and chat.sender.index == player_index and {"chat-localization.you"}),
			print_player(chat.recipient, not params.expand_badges and chat.recipient.index == player_index and {"chat-localization.you"}),
		}
	end
}

---@alias (partial) modules.types
---| "chat_log_entry"
---@alias (partial) modules.ModuleElems
---| ChatLogEntryElem
---@class ChatLogEntryElem
---@field module_type "chat_log_entry"
---@field args ChatLogEntryArgs

---@class ChatLogEntryArgs
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
	player = {is_optional = false, type = {"LuaPlayer"}},
	expand_badges = {is_optional = true, type = {"boolean"}, default = false},

	name = {is_optional = true, type = {"string"}},
}

---Creates the frame for a window with an exit button
---@param params ChatLogEntryArgs
function module.build_func(params)
	local chat = params.chat
	local badge = badge_switch[chat.type](chat, params)

	local show_sender = chat.sender and chat.type ~= "whisper"
	local processed_color = "something"

	return {
		args = {type = "frame", name = params.name},
		children = {
			{args={
				type = "label",
				caption = format_time(chat.tick)
			}},
			{args={
				type = "label",
				caption = "|"
			}},
			{args={
				type = "label",
				caption = badge
			}},
			show_sender and {args={
				type = "label",
				caption = print_player(chat.sender)
			}} or nil,
			show_sender and {args={
				type = "label",
				caption = ":"
			}} or nil,
			{
				args={
					type = "label",caption = chat.message,
					tags = {process_color=chat.process_color},
				},
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