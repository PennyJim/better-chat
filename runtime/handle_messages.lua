local ChatHistoryManager = require("__better-chat__.runtime.ChatHistoryManager")

---Replaces all instances of a pattern with the output of the provided function
---@param text string
---@param pattern string
---@param replaceFun fun(match:string):string
---@return string
local function replace_all(text, pattern, replaceFun)
	local output = text
	for match in text:gmatch(pattern) do
		local front, back = output:find(match, 1, true)
		local firsthalf = output:sub(1, front-1)
		local secondHalf = output:sub(back+1)
		output = firsthalf..replaceFun(match)..secondHalf
	end
	return output
end

---Replaces `:<shortcodes>:` into their emoji
---@param text string
---@return string
local function replace_shortcodes(text)
	--- FIXME: Only replaces the first shortcode..
	return replace_all(text, "%:%S+%:", function (shortcode)
		local item = nil
		for _, dictionary in pairs(global.emojipacks) do
			item = dictionary[shortcode:sub(2,-2)] or item
		end
		return item or shortcode
	end)
end

---Turns the message into a chat message
---@param sender LuaPlayer
---@param text string
---@return string
local function process_message(sender, text)
	--Process Item codes with images
	local message = replace_shortcodes(text)

	--- Toggle based icon settings
	local player_settings = settings.get_player_settings(sender)
	local icons = {"item","entity","technology","recipe","item-group","fluid","tile","virtual-signal","achievement"}

	for _,icon in pairs(icons) do
		if(player_settings["bc-"..icon.."-icon"].value) then
			message = replace_all(message, "%["..icon:gsub("%-", "%%-").."=%S+]", function (match)
				return "[img="..icon.."."..match:sub(3+#icon)
			end)
		end
	end
	return message
end

---Processes messsage, saves it to history, then sends latest x messages
---@param message LocalisedString
---@param color Color?
---@param send_level historyLevel
---@param recipient integer?
---@param clear boolean? Whether or not the chat is cleared, `true` by default
---@return string? Error
local function send_message(message, color, send_level, recipient, clear)
	local error = nil
	-- if type(message) ~= "table" then
	-- 	return "Message needs to be a table"
	-- end

	if send_level ~= "force" and
		send_level ~= "global" and
		send_level ~= "player" then
			error = "Invalid send level"
	elseif send_level ~= "global" and type(recipient) ~= "number" then
		error = "Invalid recipient. Must be an index"
	elseif send_level == "force" and not game.forces[recipient] then
		error = "Invalid force"
	elseif send_level == "player" and not game.players[recipient] then
		error = "Invalid player"
	end

	if error then
		log(error)
		return error
	end

	ChatHistoryManager.add_message{
		message = message,
		color = color,
		level = send_level,
		chat_index = recipient
	}

	--Clear chat if `clear` is true or nil
	if clear ~= false then
		ChatHistoryManager.print_chat(send_level, recipient)

	else -- FIXME: use the internal print function rather than this hacked together one
		---@type LuaGameScript|LuaForce|LuaPlayer
		local printer
		if send_level == "global" then
			printer = game
		elseif send_level == "force" then
			---@cast recipient -?
			printer = game.forces[recipient]
		else
			---@cast recipient -?
			printer = game.players[recipient]
		end
		printer.print(message, {
			color = color,
			skip = defines.print_skip.never
		})
	end
end

---Turns the arguments into a LocalizedString
---@param header string
---@param player string
---@param message string
---@return LocalisedString message
local function msg(header, player, message)
	return {"", {"chat-localization."..header, player}, message}
end

-- TODO: Add Nicknames?


return {
	send_message = send_message,
	process_message = process_message,
	msg = msg,
}