---@alias historyLevel "global"|"force"|"player"
local migrate = require("__better-chat__.runtime_migrations")
local ChatHistoryManager = require("__better-chat__.runtime.ChatHistoryManager")
local send_message = require("__better-chat__.runtime.handle_messages").send_message
local disableFunctions = require("__better-chat__.runtime.disableFunctions")


---Clean emojipacks of unloaded mods
---@param changes {[string]: ModChangeData}
local function clean_emojipacks(changes)
	local defunct_mods = {}
	for mod_name in pairs(changes) do
		if not changes[mod_name].new_version then
			global.emojipacks[mod_name] = nil
		end
	end
end

script.on_event("bc-toggle-chat", function (event)
	global.isChatOpen[event.player_index] = not global.isChatOpen:check(event.player_index)
	ChatHistoryManager.print_chat("player", event.player_index)
	-- log("Toggle Chat")
end)
script.on_event("bc-exit-chat", function (event)
	global.isChatOpen[event.player_index] = nil
	ChatHistoryManager.print_chat("player", event.player_index)
	-- log("Exit Chat")
end)

--#region Setup
local isOpenDirty = false
local chatOpenMeta = {
	__index = {
		check = function (self, player_index)
			if isOpenDirty then
				self = {}
				isOpenDirty = false
			end
			return self[player_index]
		end
	}
}
script.register_metatable("bc-chatOpen",chatOpenMeta)

script.on_init(function ()
	global.emojipacks = {} --[[@as {[string]:{[string]:string}} ]]
	global.isChatOpen = setmetatable({}, chatOpenMeta) --[[@as {[integer]: boolean, check:fun(this, integer)}]]
	global.disabledListeners = {} --[[@as {[defines.events]: string[]}]]
	global.disabledCommands = {} --[[@as {[string]: string[]}]]
	disableFunctions.register_enabled_listeners()
	ChatHistoryManager.init()
end)
script.on_load(function ()
	global.isChatOpen = global.isChatOpen or setmetatable({}, chatOpenMeta)
	global.disabledCommands = global.disabledCommands or {}
	global.disabledListeners = global.disabledListeners or {}
	disableFunctions.register_enabled_listeners()
	-- FIXME: Currently, singleplayer can load out of sync
	-- script.on_nth_tick(1, function (p1)
	-- 	if not game.is_multiplayer() then
	-- 		isOpenDirty = true
	-- 	end
	-- 	script.on_nth_tick(p1.nth_tick, nil)
	-- end)
end)
script.on_configuration_changed(function (change)
	migrate(change)
	clean_emojipacks(change.mod_changes)
	disableFunctions.reenable(change.mod_changes)
end)
script.on_event(defines.events.on_runtime_mod_setting_changed, function (event)
	local setting_type = event.setting_type --[[@as "runtime-per-user"|"runtime-global"]]
	if event.setting == "bc-global-chat-history" then
		local new_setting = settings.global[event.setting].value
		send_message({"chat-localization.bc-global-history-changed", new_setting}, nil, "global")
		ChatHistoryManager.print_chat("global")
	elseif event.setting == "bc-force-chat-history" then
		local new_setting = settings.global[event.setting].value
		send_message({"chat-localization.bc-force-history-changed", new_setting}, nil, "global")
		ChatHistoryManager.print_chat("global")
	elseif event.setting == "bc-player-chat-history" then
		if not event.player_index then return log("Who changed their setting???") end
		local new_setting = settings.get_player_settings(event.player_index)[event.setting].value
		send_message({"chat-localization.bc-player-history-changed", new_setting}, nil, "player", event.player_index)
		ChatHistoryManager.print_chat("player", event.player_index)
	elseif setting_type == "runtime-per-user" and (
		event.setting == "bc-color-fade" or
		event.setting == "bc-default-color" or
		event.setting == "bc-error-color" or
		event.setting == "bc-warn-color" or
		event.setting == "bc-debug-color"
	) then
		if not event.player_index then return log("Who changed their setting???") end
		ChatHistoryManager.print_chat("player", event.player_index)
	end
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
--#endregion

--#region Symbol Exporting for other mods
remote.add_interface("better-chat", {
	send = send_message,
	disable_listener = disableFunctions.listener.disable,
	enable_listener = disableFunctions.listener.enable,
	disable_command = disableFunctions.command.disable,
	enable_command = disableFunctions.command.enable,
	-- [ ] debug(LocalisedString, isEphemeral)
	-- [ ] print(LocalisedString, color)
	-- [ ] warn(LocalisedString, isEphemeral)
	-- [ ] error(LocalisedString, isEphemeral)
	-- [ ] clear(player_index)
})
remote.add_interface("emojipack registration", {
	add = function (mod_name, shortcode_dictionary)
		if not script.active_mods[mod_name] then return end
		global.emojipacks = global.emojipacks or {}

		global.emojipacks[mod_name] = shortcode_dictionary
	end
})
--#endregion