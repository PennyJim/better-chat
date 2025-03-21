local ChatHistoryManager = require("__better-chat__.runtime.ChatHistoryManager")
local automation = require("__better-chat__.runtime.levenshtein_automation")
local filter = require("__better-chat__.runtime.filter")
---@class handle_messages : custom_event_handler
local handle_messages = {remote_interfaces = {}}

--MARK: Local functions

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

---Loop through the dictionaries to find the nth
---instance of the given shortcode
---@param given_code string
---@param variation int
---@return string?
local function find_shortcode(given_code, variation)
  -- Define variables outside the loop
  local count = 0
  ---@type string[]|string, int
  local result, new_count
  for _, dictionary in pairs(storage.emojipacks) do
    result = dictionary[given_code]
    if result then

      if type(result) == "string" then
        -- If it's the result
        count = count + 1
        if count == variation then
          return result
        end
      else

        -- If it's an array of results
        new_count = count + #result
        if new_count >= variation then
          return result[variation - count]
        end
        count = new_count
      end
    end
  end
end

---Use the levenshtein algorithm to find the closest
---shortcode to the text given
---@param given_code string
---@return string?
local function Levenshtein_shortcodes(given_code)
  local tree = automation.generate_tree(given_code)
  ---@type string[]|string?, int
  local closest, closest_distance = nil, math.huge
  ---@type Levenshtein.match?
  local match

  for _, dictionary in pairs(storage.emojipacks) do
    for shortcode, replacement in pairs(dictionary) do
      match = automation.match(shortcode, tree)
      if match and match[2] < closest_distance then
        if match[2] == 1 then
          return type(replacement) == "string" and replacement or replacement[1]
        end
        closest = replacement
        closest_distance = match[2]
      end
    end
  end

  return type(closest) == "table" and closest[1] or closest --[[@as string?]]
end

---Replaces `:<shortcodes>:` into their emoji
---@param text string
---@return string
local function replace_shortcodes(text)
	return replace_all(text, ":[^%s:]+:", function (shortcode)
		local shortenedcode = shortcode:sub(2,-2)
    ---@type int|string?
    local variation = shortenedcode:match("~%d+$")

    if variation then
      ---@cast variation string
      shortenedcode = shortenedcode:sub(1, -1-#variation)
      variation = tonumber(variation:sub(2)) --[[@as int]] + 1
    else
      variation = 1
    end

    local item = find_shortcode(shortenedcode, variation)
    if item then
      return item
    end

    -- Wasn't found, let's try a code that's levenshteinly close
    -- unlesss a variation is specified or on a server
    -- It is not optimized enough for that :P
    if not game.is_multiplayer() and variation == 1 then
      item = Levenshtein_shortcodes(shortenedcode)
    end
    return item or shortcode
	end)
end

--MARK: public functions

---Turns the message into a chat message
---@param sender LuaPlayer
---@param send_level historyLevel
---@param text string
---@return string
function handle_messages.process_message(sender, send_level, text)
	--Process Item codes with images
	local message = replace_shortcodes(text)

	--- Toggle based icon settings
	local player_settings = settings.get_player_settings(sender)
	local icons = {"virtual-signal","item","fluid","entity","recipe","technology","space-location","achievement","item-group","tile"}

	---Planet is special and has its own tag besides space-location
	if(player_settings["bc-space-location-icon"].value) then
		message = replace_all(message, "%[planet=[^%s,%]]+]", function (match)
			return "[img=space-location."..match:sub(9)
		end)
	end

	for _,icon in pairs(icons) do
		if(player_settings["bc-"..icon.."-icon"].value) then
			message = replace_all(message, "%["..icon:gsub("%-", "%%-").."=[^%s,%]]+]", function (match)
				return "[img="..icon.."."..match:sub(3+#icon)
			end)
		end
	end

	-- Use event to filter
	message = filter.chat(sender, send_level, text, message)

	return message
end

---@class messageParams.base
---The contents of the message.
---@field message LocalisedString
---Whether the message is intended for `"global"` broadcast, everyone on some `"force"`, everyone on a `"surface"`, or a specific `"player"`.
---@field send_level historyLevel
---The base color of the message.
---@field color? Color
---Whether or not the message is faded out by the player's settings. Defaults to `false`.
---@field process_color? boolean
---Whether or not the added chat is printed at all. This will also skip any sound. Defaults to `false`.
---@field skip_print? boolean
---Whether or not the chat is cleared before printing the new message. Defaults to `true`.
---@field clear? boolean
---If a sound should be emitted for this message. Defaults to `defines.print_sound.use_player_settings` if clear is `false`. Otherwise defaults to `defines.print_sound.never`.
---@field sound? defines.print_sound
---The sound to play. If not given, [UtilitySounds::console\_message](https://lua-api.factorio.com/latest/prototypes/UtilitySounds.html#console_message) will be used instead.
---@field sound_path? SoundPath
---The volume of the sound to play. Must be between 0 and 1 inclusive. Defaults to `1`.
---@field volume_modifier? float

---@class messageParams.global : messageParams.base
---@field send_level "global"
---@field recipient nil

---@class messageParams.recipient : messageParams.base
---@field send_level "force"|"player"|"surface"
---Either the player, surface, or force that recieves it if the send_level was not global
---@field recipient integer

---@alias messageParams messageParams.global|messageParams.recipient

local valid_send_levels = {
	global = true,
	force = true,
	surface = true,
	player = true,
}

---Processes messsage, saves it to history, then sends latest x messages
---@param message messageParams
---@return string? Error
function handle_messages.send_message(message)
	local error = nil
	local send_level = message.send_level
	local recipient = message.recipient --[[@as int]]

	if not valid_send_levels[send_level] then
		error = "Invalid send level"
	elseif send_level ~= "global" and type(recipient) ~= "number" then
		error = "Invalid recipient. Must be an index"
	elseif send_level == "force" and not game.forces[recipient] then
		error = "Invalid force"
	elseif send_level == "surface" and not game.get_surface(recipient) then
		error = "Invalid surface"
	elseif send_level == "player" and not game.get_player(recipient) then
		error = "Invalid player"
	end

	if error then
		log(error)
		return error
	end

	local msg = message.message
	local color = message.color
	local process_color = message.process_color
	local skip_print = message.skip_print
	local clear = message.clear ~= false
	local sound = message.sound
	if not sound and not clear then
		sound = defines.print_sound.use_player_settings
	end
	local sound_path = message.sound_path
	local volume_modifier = message.volume_modifier

	ChatHistoryManager.add_message{
		message = msg,
		color = color,
		process_color = process_color,
		level = send_level,
		chat_index = recipient
	}

	if skip_print then return end

	--Clear chat if `clear` is true or nil
	if clear then
		ChatHistoryManager.print_chat(send_level, recipient, sound, sound_path, volume_modifier)
	else
		ChatHistoryManager.print_latest(send_level, recipient, sound, sound_path, volume_modifier)
	end
end
--- Because the printer needs it and this file requires the printer
send_message = handle_messages.send_message

---A compatibility layer for the old format of the remote interface
---@see handle_messages.send_message
---@param message LocalisedString|messageParams
---@param color Color?
---@param send_level historyLevel?
---@param recipient integer?
---@param clear boolean? Whether or not the chat is cleared, `true` by default
local function compatibility_send(message, color, send_level, recipient, clear)
	if type(message) == "table" and message[1] then
		---@cast message LocalisedString
		return handle_messages.send_message{
			message = message,
			color = color,
			send_level = send_level or "global",
			recipient = recipient,
			clear = clear,
		}

	else
		---@cast message messageParams
		return handle_messages.send_message(message)
	end
end
handle_messages.remote_interfaces["better-chat"] = {
	send = compatibility_send,
}

---Send a force-leve message and bcc every force
---that considers this force friendly
---Why not the other way round? Dunno. It's how base game does it :)
---@param message messageParams.recipient
function handle_messages.broadcast_friendly(message)
  if message.send_level ~= "force" then error("This should *only* be for force level communications") end
  local force_index = message.recipient--[[@as int]]

	for _, other_force in pairs(game.forces) do
		if other_force.is_friend(force_index) then
      message.recipient = other_force.index
			handle_messages.send_message(message)
		end
	end
end

---Turns the arguments into a LocalizedString
---@param header string
---@param player LuaPlayer
---@param message string
---@return LocalisedString message
function handle_messages.msg(header, player, message)
	local name = player.name
	if player.tag and #player.tag > 0 then
		name = name.." "..player.tag
	end
	local color = player.chat_color
	return {
		"",
		{
			"chat-localization.colored-text",
			{
				"chat-localization."..header,
				name
			},
			color[1] or color.r,
			color[2] or color.g,
			color[3] or color.b,
		},
		message
	}
end

---Reprints the chat to clear ephemeral messages
---@param player_index int
function handle_messages.clear_ephemeral(player_index)
  ChatHistoryManager.print_chat("player", player_index)
end

handle_messages.clear = ChatHistoryManager.clear

---Wraps the given LocalisedString or string in a LocalisedString
---that colors the text. Mostly just a shorthand to avoid
---turning the color objects into the argument array all the time
---@param string LocalisedString
---@param color Color
---@return LocalisedString
function handle_messages.color(string, color)
	return {
		"chat-localization.colored-text",
		string,
		color[1] or color.r,
		color[2] or color.g,
		color[3] or color.b,
	}
end

-- TODO: Add Nicknames?


return handle_messages