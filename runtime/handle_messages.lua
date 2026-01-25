local chatlog_manager = require("chatlog_manager")
-- local automation = require("__better-chat__.runtime.levenshtein_automation")
-- local filter = require("__better-chat__.runtime.filter")
---@class handle_messages : event_handler
local handle_messages = {remote_interfaces = {}} --[[@as event_handler]]

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

---@param array table<any,any>|any
---@param tested_type type
---@return boolean
local function is_array(array, tested_type)
	if type(array) ~= "table" then return false end
	---@type uint?
	local last_index
	for index, value in ipairs(array) do
		if type(value) ~= tested_type then
			last_index = nil
			break
		end
		last_index = index
	end
	-- If the size and the last index are equivalent, then we know ipairs didn't miss any indexes
	return last_index and table_size(array) == last_index
end

---@type table<string, string[]|string>
local shortcodes = {}

for emojipack_name, mod_data in pairs(prototypes.mod_data) do
	if mod_data.data_type ~= "bc-shortcodes" then goto continue end

	for shortcode, expansion in pairs(mod_data.data) do
		local expansion_list = shortcodes[shortcode]
		if type(expansion_list) == "string" then
			expansion_list = {expansion_list}
		end

		if type(expansion) == "string" then
			if expansion_list then
				table.insert(expansion_list, expansion)
			else
				shortcodes[shortcode] = expansion
			end

		elseif is_array(expansion, "string") then
			---@cast expansion string[]
			if expansion_list then
				for _, sub_expansion in pairs(expansion) do
					table.insert(expansion_list, sub_expansion)
				end
			else
				shortcodes[shortcode] = expansion
			end

		else
			local mod_history = prototypes.get_history("mod-data", emojipack_name)
			local mod_blame = "\n\t- "..mod_history.created
			for _, mod in pairs(mod_history.changed) do
				mod_blame = mod_blame.."\n\t- "..mod
			end
			error("In emojipack '"..emojipack_name.."' for '"..shortcode.."' expected string or array of strings, got "..serpent.line(expansion)
				.."\n\nMod(s) to blame:"..mod_blame
			)
		end
	end

	::continue::
end

---Loop through the dictionaries to find the nth
---instance of the given shortcode
---@param given_code string
---@param variation int
---@return string?
local function find_shortcode(given_code, variation)
  local result = shortcodes[given_code]
	if not result then return end

	if type(result) == "string" then
		if variation == 1 then
			return result
		end

	else
		return result[variation]
	end
end

---Use the levenshtein algorithm to find the closest
---shortcode to the text given
-- -@param given_code string
-- -@return string?
-- local function Levenshtein_shortcodes(given_code)
--   local tree = automation.generate_tree(given_code)
--   ---@type string[]|string?, int
--   local closest, closest_distance = nil, math.huge
--   ---@type Levenshtein.match?
--   local match

--   for _, dictionary in pairs(storage.emojipacks) do
--     for shortcode, replacement in pairs(dictionary) do
--       match = automation.match(shortcode, tree)
--       if match and match[2] < closest_distance then
--         if match[2] == 1 then
--           return type(replacement) == "string" and replacement or replacement[1]
--         end
--         closest = replacement
--         closest_distance = match[2]
--       end
--     end
--   end

--   return type(closest) == "table" and closest[1] or closest --[[@as string?]]
-- end

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
    -- if not game.is_multiplayer() and variation == 1 then
    --   item = Levenshtein_shortcodes(shortenedcode)
    -- end
    return item or shortcode
	end)
end

--- Converts the given player reference into a standard ChatPlayer if needed
--- Validates the inputs with a verbose message of why it's an invalid reference
---@param player PlayerReference
---@param depth? int
---@return ChatPlayer?
local function convert_player(player, depth)
	if not player then return end
	depth = depth and depth + 1 or 2

	if type(player) == "table" then
		---@cast player ChatPlayer
		if type(player.name) ~= "string" then
			error("Invalid ChatPlayer, name was not a string: "..serpent.line(player.name), depth)
		elseif player.index and type(player.index) ~= "number" then
			error("Invalid ChatPlayer, index was not a number: "..serpent.line(player.index), depth)
		end
		return player

	elseif type(player) == "number" or type(player) == "string" then
		local luaplayer = game.get_player(player)
		if not luaplayer then error("Player did not exist: "..serpent.line(player), depth) end
		player = luaplayer

	elseif type(player) ~= "userdata" then
		error("Expected a PlayerReference (PlayerIdentification or ChatPlayer), was instead given "..serpent.line(player), depth)
	end
	---@cast player LuaPlayer

	local name = player.name
	if player.tag and #player.tag > 0 then
		name = name.." "..player.tag
	end

	return {
		-- name = player.name,
		name = name,
		color = player.chat_color --[[@as Color.0]],
		index = player.index
	}
end

--MARK: public functions

local icon_types = {"virtual-signal","item","fluid","entity","recipe","technology","space-location","achievement","item-group","tile"}
---Turns the message into a chat message
---@param sender LuaPlayer|ChatPlayer
---@param type PrintLevel
---@param text string
---@return string
function handle_messages.process_message(sender, type, text)
	--Process Item codes with images
	local message = replace_shortcodes(text)

	--- Toggle based icon settings
	---@type LuaCustomTable<string,ModSetting>
	local player_settings
	if type(sender) == "userdata" then
		player_settings = settings.get_player_settings(sender)
	else
		player_settings = settings.player_default
	end

	---Planet is special and has its own tag besides space-location
	if(player_settings["bc-space-location-icon"].value) then
		message = replace_all(message, "%[planet=[^%s,%]]+]", function (match)
			return "[img=space-location."..match:sub(9)
		end)
	end

	for _,icon in pairs(icon_types) do
		if(player_settings["bc-"..icon.."-icon"].value) then
			message = replace_all(message, "%["..icon:gsub("%-", "%%-").."=[^%s,%]]+]", function (match)
				return "[img="..icon.."."..match:sub(3+#icon)
			end)
		end
	end

	-- Use event to filter
	-- message = filter.chat(sender, type, text, message)

	return message
end

--MARK: Validation

---@type table<ChatMessageType, fun(recipient:ForceID|SurfaceIdentification|PlayerReference,message:ChatParams):ChatPlayer|uint?>
local type_validation = {
	---@return nil recipient
	global = function (recipient, message)
		if recipient then
			log("Recipient was given for a global message?\n"..serpent.block(message))
		end
	end,
	---@return nil recipient
	command = function (recipient, message)
		if recipient then
			log("Recipient was given for a command? Sender should be used to assign a command to a user.\n"..serpent.block(message))
		end
	end,
	---@param recipient ForceID
	---@return uint recipient
	force = function (recipient)
		if type(recipient) == "userdata" then
			if recipient.object_name == "LuaForce" then
				return recipient.index
			end

		elseif type(recipient) == "string" or type(recipient) == "number" then
			local force = game.forces[recipient]
			if force then return force.index end
			error("Given force did not exist: "..recipient, 2)
		end

		error("Expected a ForceID, got "..serpent.line(recipient), 2)
	end,
	---@param recipient SurfaceIdentification
	---@return uint recipient
	surface = function (recipient)
		if type(recipient) == "userdata" then
			if recipient.object_name == "LuaSurface" then
				return recipient.index
			end

		elseif type(recipient) == "string" or type(recipient) == "number" then
			local surface = game.get_surface(recipient)
			if surface then return surface.index end
			error("Given surface did not exist: "..recipient, 2)
		end

		error("Expected a SurfaceIdentification, got "..serpent.line(recipient), 2)
	end,
	---@param recipient PlayerReference
	---@return PlayerReference recipient
	player = function (recipient)
		local player = convert_player(recipient, 2)
		if not player then
			error("A recipient player is required", 2)
		end
		if player.index then return player end
		error("A ChatPlayer missing an index cannot be a recipient: "..serpent.line(player), 2)
	end,
}

---Processes messsage and saves it to history
---@param message ChatParams
---@return string? Error
function handle_messages.send_message(message)
	local message_type = message.type
	message.sender = convert_player(message.sender)

	if not message_type or not type_validation[message_type] then
		error("Invalid message type: "..serpent.line(message_type))
	end
	message.recipient = type_validation[message_type](message.recipient, message)
	---@cast message ChatParamsValidated

	chatlog_manager.add_message(message)
end


---@deprecated There is a new format with a message 'type' instead of level
---@class messageParams.base
---@field message LocalisedString
---@field send_level "global"
---@field color? Color
---@field process_color? boolean
---@field skip_print? boolean
---@field clear? boolean
---@field sound? defines.print_sound
---@field sound_path? SoundPath
---@field volume_modifier? float

---@class messageParams.recipient : messageParams.base
---@field send_level "force"|"player"|"surface"
---@field recipient integer

---@alias messageParams messageParams.base|messageParams.recipient

---@param params messageParams|ChatParams
---@return ChatParams
local function convert_params(params)
	if params.type then return params --[[@as ChatParams]] end
	params.type = params.send_level
	params.send_level = nil

	params.clear = not params.clear

	---@cast params -messageParams
	return params
end


---A compatibility layer for the old format of the remote interface
---@see handle_messages.send_message
---@param message LocalisedString|messageParams
---@param color Color?
---@param send_level PrintLevel?
---@param recipient integer?
---@param clear boolean? Whether or not the chat is cleared, `true` by default
local function compatibility_send(message, color, send_level, recipient, clear)
	if type(message) == "table" and message[1] then
		---@cast message LocalisedString
		return handle_messages.send_message({
			message = message,
			color = color,
			type = send_level or "global",
			recipient = recipient,
			clear = clear,
		})

	else
		---@cast message messageParams
		return handle_messages.send_message(convert_params(message))
	end
end
handle_messages.remote_interfaces["better-chat"] = {
	send = compatibility_send,
}

---Send a force-level message and bcc every force
---that considers this force friendly
---Why not the other way round? Dunno. It's how base game does it :)
---@param message ChatParams.force
function handle_messages.broadcast_friendly(message)
  if message.type ~= "force" then error("This should *only* be for force level communications") end
  local force_index = message.recipient--[[@as int]]

	for _, other_force in pairs(game.forces) do
		if other_force.is_friend(force_index) then
      message.recipient = other_force.index
			handle_messages.send_message(message)
		end
	end
end

handle_messages.clear = chatlog_manager.clear

---Wraps the given LocalisedString or string in a LocalisedString
---that colors the text. Mostly just a shorthand to avoid
---turning the color objects into the argument array all the time
---@param string LocalisedString
---@param color Color
---@return LocalisedString
function handle_messages.color(string, color)
	return {"",
		"[color="
			..color[1] or color.r
			..color[2] or color.g
			..color[3] or color.b
		.."]",
			string,
		"[/color]"
	}
end

-- TODO: Add Nicknames?


return handle_messages