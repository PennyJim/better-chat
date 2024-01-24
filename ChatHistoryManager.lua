---@class Chat
---@field msg string
---@field header LocalisedString
---@field color hsvColor?

---@class ChatLog
---@field chat_array Chat[]
---@field size integer
---@field top_index integer
---@field last_index integer
local ChatLog = {
	---Add a new element in the linked list
	---@param self ChatLog
	---@param chat Chat
	---@param sizeLimit integer?
	add = function(self, chat, sizeLimit)
		self.size = self.size + 1
		self.last_index = self.last_index + 1
		self.chat_array[self.last_index] = chat
		if sizeLimit then self:trim(sizeLimit) end
	end,
	---Trim elements from linked list until its equal to limit
	---@param self ChatLog
	---@param sizeLimit integer
	trim = function(self, sizeLimit)
		for i = self.top_index, self.last_index-sizeLimit, 1 do
			self.top_index = i + 1
			self.chat_array[i] = nil
		end
	end,
	---Return an iterator for every element in linked list
	---@param self ChatLog
	---@param first_index integer?
	---@return fun():Chat?
	from = function(self, first_index)
		local chat_array = self.chat_array
		local i = first_index or self.top_index
		i = i-1
		return function()
			i = 1 + i
			return chat_array[i]
		end
	end
}

local chatMetatable = {__index=ChatLog}
script.register_metatable("bc-chatlog", chatMetatable)
---Creates a new ChatLog
---@param oldLog ChatLog?
---@param log_type "force"|"player"?
---@return ChatLog
local function newChatLog(oldLog, log_type)
	local newLog = setmetatable({
		size = 0,
		top_index = 1,
		last_index = 0,
		chat_array = {}
	}, chatMetatable)
	if not oldLog then return newLog end

	for chat in oldLog:from() do
		newLog:add(chat)
	end
	if (log_type=="force") then
		newLog:trim(settings.global["bc-force-chat-history"].value--[[@as integer]])
	else
		newLog:trim(settings.player["bc-player-chat-history"].value--[[@as integer]])
	end
	return newLog
end

---@class hsvColor
---@field h float
---@field s float
---@field v float
-- HSV conversion taken from
-- https://stackoverflow.com/questions/13806483/increase-or-decrease-color-saturation

---Converts an rgb color to hsv
---@param rgb Color
---@return hsvColor
-- local function rgb_to_hsv(rgb)
-- 	local hsv = {h=0,s=0,v=0}
-- 	local min = math.min(rgb.r,rgb.g,rgb.b)
-- 	local max = math.max(rgb.r,rgb.g,rgb.b)

-- 	hsv.v = max
-- 	local delta = max - min
-- 	if max ~= 0 then
-- 		hsv.s = delta / max
-- 	else
-- 		hsv.s = 0
-- 		hsv.h = -1
-- 		return hsv
-- 	end
-- 	if rgb.r >= max then
-- 		hsv.h = (rgb.g-rgb.b)/delta
-- 	elseif rgb.g >= max then
-- 		hsv.h = (rgb.b-rgb.r)/delta
-- 	else
-- 		hsv.h = (rgb.r-rgb.g)/delta
-- 	end
-- 	hsv.h = hsv.h * 60 -- Change to 0.1666666666?
-- 	if hsv.h < 0 then hsv.h = hsv.h + 360 end
-- 	if hsv.h ~= hsv.h then hsv.h = 0 end
-- 	return hsv
-- end
local function rgb_to_hsv(rgb)
  local hsv = { h=0, s=0, v=0 }
  local cmax = math.max(rgb.r,rgb.g,rgb.b)
  local cmin = math.min(rgb.r,rgb.g,rgb.b)
  local cdelta = cmax - cmin
  -- calculate hue
  hsv.h = 0
  if (cmax == rgb.r) then
    hsv.h = math.fmod((rgb.g-rgb.b)/cdelta, 6)*60
  elseif (cmax == rgb.g) then
    hsv.h = 120 + ((rgb.b-rgb.r)/cdelta)*60
  else
    hsv.h = 240 + ((rgb.r-rgb.g)/cdelta)*60
  end
  -- calculate saturation
  hsv.s = 0
  if (cmax > 0) then
    hsv.s = cdelta / cmax
  end
  -- calculate value
  hsv.v = cmax
  -- return
  return hsv
end

---Converts an gsv color to rgb
---@param hsv hsvColor
---@return Color
local function hsv_to_rgb(hsv)
	if hsv.s == 0 then return {0,0,0} end
	local h = hsv.h / 60
	local i = math.floor(h) --Change to * 5?
	local f = h - i
	local p = hsv.v * (1 - hsv.s)
	local q = hsv.v * (1 - hsv.s * f)
	local t = hsv.v * (1 - hsv.s * (1 - f))
	if i == 0 then
		return {r=hsv.v,g=t,b=p}
	elseif i == 1 then
		return {r=q,g=hsv.v,b=p}
	elseif i == 2 then
		return {r=p,g=hsv.v,b=t}
	elseif i == 3 then
		return {r=p,g=q,b=hsv.v}
	elseif i == 4 then
		return {r=t,g=p,b=hsv.v}
	else
		return {r=hsv.v,g=p,b=q}
	end
end

---@class ChatLogManager
local manager = {}

--#region Player and force management
---Adds a new chatlog for force_index if it didn't exist before
---@param force_index integer
manager.add_force = function(force_index)
	if global.ForceChatLog[force_index] then return end
	global.ForceChatLog[force_index] = newChatLog(
		global.GlobalChatLog
	)
end
---Adds a new chatlog for player_index if it didn't exist before
---@param player_index integer
manager.add_player = function(player_index)
	if not global.PlayerChatLog[player_index] then
		global.PlayerChatLog[player_index] = newChatLog(
			global.ForceChatLog[game.get_player(player_index).force_index]
		)
	end
	if not global.PlayerColors[player_index] then
		global.PlayerColors[player_index] = {
			["bc-default-color"]=nil,
			["bc-error-color"]=nil,
			["bc-warn-color"]=nil,
			["bc-debug-color"]=nil,
		}
		manager.update_colors(player_index)
	end
end
---Removes a chatlog for deleted force
---@param force_index integer
manager.remove_force = function(force_index)
	global.ForceChatLog[force_index] = nil
end
---Removes a chatlog for removed player
---@param player_index integer
manager.remove_player = function(player_index)
	global.PlayerChatLog[player_index] = nil
end
--#endregion

---@class addMessageParams
---@field message string
---@field header LocalisedString
---@field color Color?
---@field level historyLevel
---@field chat_index integer?
---Adds a message to chat history
---@param messageParams addMessageParams
manager.add_message = function(messageParams)
	local color = messageParams.color
---@diagnostic disable-next-line: cast-local-type
	if color then color = rgb_to_hsv(color) end
	---@type Chat
	local newChat = {
		msg = messageParams.message,
		color = color,
		header = messageParams.header
	}

	if messageParams.level =="global" then
		-- Add message to global chat, every force, and every player
		global.GlobalChatLog:add(newChat, settings.global["bc-global-chat-history"].value--[[@as integer]])

		local force_chat_history = settings.global["bc-force-chat-history"].value--[[@as integer]]
		for _,force in pairs(game.forces) do
			global.ForceChatLog[force.index]:add(newChat, force_chat_history)
		end

		for _, player in pairs(game.players) do
			local player_index = player.index
			local player_chat_history = settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as integer]]
			global.PlayerChatLog[player_index]:add(newChat, player_chat_history)
		end
	elseif messageParams.level == "force" then
		-- Add message to the force and players in the force
		global.ForceChatLog[messageParams.chat_index]
			:add(newChat, settings.global["bc-force-chat-history"].value--[[@as integer]])

		for _,player in pairs(game.forces[messageParams.chat_index].players) do
			local player_index = player.index
			local player_chat_history = settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as integer]]
			global.PlayerChatLog[player_index]:add(newChat, player_chat_history)
		end
	elseif messageParams.level == "player" then
		-- Add message to the player
		global.PlayerChatLog[messageParams.chat_index]
			:add(newChat, settings.get_player_settings(messageParams.chat_index)["bc-player-chat-history"].value--[[@as integer]])
	else
		log({"", {"bc-invalid-chat-level"}, serpent.line(messageParams), "\n"})
	end
end

---@class ColorSettings
---@field new_saturation float
---@field new_brightness float
---@field default_color hsvColor
---@field error_color hsvColor
---@field warn_color hsvColor
---@field debug_color hsvColor

---returns the player settings related to color
---@param player_index integer
---@return ColorSettings
local function get_color_settings(player_index)
	local player_settings = settings.get_player_settings(player_index)
	return {
		new_saturation = player_settings["bc-color-saturation-override"].value--[[@as float]],
		new_brightness = player_settings["bc-color-brightness-override"].value--[[@as float]],
		default_color = global.PlayerColors[player_index]["bc-default-color"],
		error_color = global.PlayerColors[player_index]["bc-error-color"],
		warn_color = global.PlayerColors[player_index]["bc-warn-color"],
		debug_color = global.PlayerColors[player_index]["bc-debug-color"],
	}
end

---Processes a color according to player settings
---@param color_settings ColorSettings
---@param color hsvColor?
---@return hsvColor
local function process_color(color_settings, color)
	color = color or color_settings.default_color
	local new_color = {
		h = color.h,
		s = color.s,
		v = color.v
	}
	--Brighten
	-- local brighten_inverse = 1/(1-color_settings.brighten_percent)
	-- new_color.r = new_color.r/brighten_inverse+color_settings.brighten_percent
	-- new_color.g = new_color.g/brighten_inverse+color_settings.brighten_percent
	-- new_color.b = new_color.b/brighten_inverse+color_settings.brighten_percent

	--Saturation
	new_color.s = new_color.s*(1-color_settings.new_saturation)+color_settings.new_saturation
	new_color.v = new_color.v*(1-color_settings.new_brightness)+color_settings.new_brightness

	return new_color
end

---Prints the chats to the passed player
---@param player LuaPlayer
local function print_chats(player)
	local player_index = player.index
	--Obtain relevant settings
	local color_settings = get_color_settings(player_index)

	--Go through every chat
	player.clear_console()
	for chat in global.PlayerChatLog[player_index]:from() do
		--Get general message color
		local color = process_color(color_settings, chat.color)

		---@diagnostic disable-next-line: param-type-mismatch
		if type(chat.header[1]) == "string" and chat.header[1]:find("chat%-localization") then
			---Get header color in messages that have a header
			local header_color = hsv_to_rgb(chat.color or color_settings.default_color)
			chat.header[3] = header_color.r
			chat.header[4] = header_color.g
			chat.header[5] = header_color.b
		end

		--Print the message
		player.print({"", chat.header, chat.msg}, {
			color = hsv_to_rgb(color),
			sound = defines.print_sound.never,
			skip = defines.print_skip.never
		})
	end
end

---Print out all messages for a group
---@param chat_level historyLevel
---@param chat_index integer?
manager.print_chat = function(chat_level, chat_index)
	if chat_level == "global" then
		for _, player in pairs(game.players) do
			print_chats(player)
		end
	elseif chat_level == "force" then
		---@cast chat_index integer
		for _, player in pairs(game.forces[chat_index].players) do
			print_chats(player)
		end
	elseif chat_level == "player" then
		---@cast chat_index integer
		local player = game.get_player(chat_index)
		-- TODO: improve this error statement
		if not player then return log("[ERR] Something has gone wrong") end
		print_chats(player)
	else
		log({"invalid-destination"})
	end
end

---Initializes Chat History
manager.init = function()
	global.GlobalChatLog = newChatLog();
	global.ForceChatLog = {} --[[@as ChatLog[] ]]
	for _,force in pairs(game.forces) do
		global.ForceChatLog[force.index] = newChatLog();
	end
	global.PlayerColors = {}
	global.PlayerChatLog = {} --[[@as ChatLog[] ]]
	for _, player in pairs(game.players) do
		local player_index = player.index
		global.PlayerChatLog[player_index] = newChatLog();
	end
end

---Re-saves player color settings as hsv
---@param player_index integer
manager.update_colors = function (player_index)
	local player_settings = settings.get_player_settings(player_index)
	local player_colors = global.PlayerColors[player_index]
	for key,_ in pairs(player_colors) do
		player_colors[key] = rgb_to_hsv(player_settings[key].value --[[@as Color]])
	end
end

---Functions for internal manipulations by runtime_migrations
manager.__newChatLog = newChatLog
manager.__rgb_to_hsv = rgb_to_hsv
manager.__hsv_to_rgb = hsv_to_rgb

return manager