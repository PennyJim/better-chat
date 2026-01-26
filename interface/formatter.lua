---@class chat_formatter
local formatter = {}

---@class ChatFormatSettngs
---@field brighten_percent float
---@field show_time boolean

---returns the player settings related to chat display
---@param player_settings LuaCustomTable<string,ModSetting>
---@return ChatFormatSettngs
function formatter.fetch_settings(player_settings)
	return {
		brighten_percent = player_settings["bc-color-fade"].value--[[@as float]],
		show_time = player_settings["bc-show-timestamp"].value--[[@as boolean]],
	}
end

---Processes a color according to player settings
---@param print_settings ChatFormatSettngs
---@param color Color
---@return Color
function formatter.process_color(print_settings, color)
	local new_color = {
		color[1] or color.r,
		color[2] or color.g,
		color[3] or color.b
	}
	--Brighten
	local brighten_inverse = 1/(1-print_settings.brighten_percent)
	new_color[1] = new_color[1]/brighten_inverse+print_settings.brighten_percent
	new_color[2] = new_color[2]/brighten_inverse+print_settings.brighten_percent
	new_color[3] = new_color[3]/brighten_inverse+print_settings.brighten_percent


	return new_color
end

---Formats the given tick in D+:HH:MM:SS
---@param tick int
---@return string
function formatter.time(tick)
	---@type int, int, int, int
	local seconds, minutes, hours, days
	seconds = tick / 60
	minutes, seconds = math.floor(seconds / 60), seconds % 60
	hours, minutes = math.floor(minutes / 60), minutes % 60
	days, hours = math.floor(hours / 24), hours % 24

	if days > 0 then
		return string.format("%d:%02d:%02d.%02d", days, hours, minutes, seconds)
	elseif hours > 0 then
		return string.format("%d:%02d.%02d", hours, minutes, seconds)
	else
		return string.format("%d.%02d", minutes, seconds)
	end
end

---Wraps the given LocalisedString or string in a LocalisedString
---that colors the text. Mostly just a shorthand to avoid
---turning the color objects into the argument array all the time
---@param string LocalisedString
---@param color Color
---@param suffix? LocalisedString
---@return LocalisedString
function formatter.color(string, color, suffix)
	return {"",
		"[color="
			..(color[1] or color.r)..","
			..(color[2] or color.g)..","
			..(color[3] or color.b)
		.."]",
		string,
		"[/color]",
		suffix,
	}
end

---@param player ChatPlayer
---@param suffix? LocalisedString
function formatter.chat_player(player, suffix)
	return formatter.color(player.name, player.color, suffix)
end

---@param player ChatPlayer|LuaPlayer
---@param suffix? LocalisedString
function formatter.player(player, suffix)
	if type(player) == "userdata" then
		return formatter.color(player.name, player.chat_color, suffix)
	else
		return formatter.color(player.name, player.chat_color, suffix)
	end
end

return formatter