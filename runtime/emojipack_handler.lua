---@type custom_event_handler
local handler = {remote_interfaces={}}
local default_emojipack = require("__better-chat__.runtime.default_shortcodes")

---Clean emojipacks of unloaded mods
function handler.on_configuration_changed(data)
	-- Remove emojipacks of unloaded mods
	for mod_name, change in pairs(data.mod_changes) do
		if not change.new_version then
			storage.emojipacks[mod_name] = nil
		end
	end

  --- Update the default emojipack
  storage.emojipacks[script.mod_name] = default_emojipack
end

handler.remote_interfaces["emojipack registration"] = {
	add = function (mod_name, shortcode_dictionary)
		if not script.active_mods[mod_name] then return end
		-- storage.emojipacks = global.emojipacks or {}

		storage.emojipacks[mod_name] = shortcode_dictionary
	end
}