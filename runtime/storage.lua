---@type custom_event_handler
local handler = {}
local default_emojipack = require("__better-chat__.runtime.default_shortcodes")

---@class BetterChatStorage
---@field emojipacks table<string,table<string,string[]|string>>
---@field isChatOpen {[integer]: boolean, check:fun(this, integer):boolean}
---@field disabledListeners table<defines.events, string[]>
---@field disabledCommands table<string, string[]>
---@field lastWhispered table<int,int?>
storage = {}

local function setup_storage()
	storage.emojipacks = storage.emojipacks or {
		[script.mod_name] = default_emojipack
	}
	storage.isChatOpen = storage.isChatOpen or setmetatable({}, metatables["bc-chatOpen"])
	storage.disabledListeners = storage.disabledListeners or {}
	storage.disabledCommands = storage.disabledCommands or {}
  storage.lastWhispered = storage.lastWhispered or {}
end

handler.on_init = setup_storage
handler.on_configuration_changed = setup_storage

return handler