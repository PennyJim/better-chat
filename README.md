# Better Chatting
### An attempt at improving Factorio's built in chat.

Recommended to be combined with [Twemoji](https://mods.factorio.com/mod/twemoji-in-factorio) or [Fluent Emoji](https://mods.factorio.com/mod/fluent-emoji) (or both)

## Emojipack
The main reason I made this mod, is to add support for discord style emotes. eg: `:purple_heart:` -> 💜

This functions by other mods calling `remote.call("emojipack registration", "add")` with the mod name and a dictionary of shortcodes and their tags. I recommend using `[img=<type>.<item>]` rather than `[<type>=<item>]` as it looks significantly nicer in chat.

## Scripting
To print a permanent message instead of letting Better Chat clear it away, use `remote.call("better-chat", "send", {})`
<br>The arguments are:

- `message` - `LocalisedString` : The contents of the message.
- `type` - `ChatMessageType` : What type of message this is.
- `sender` - `uint?` : The index of the player who the message will be attributed to.
- `color` - `Color?` : The base color of the message.
- `process_color` - `boolean?` : Whether or not the message is faded out by the player's settings. Defaults to `false`.
- `skip_print` - `boolean?` : Whether or not the added message is printed at all. This will also skip any sound. Defaults to `false`.
	- This was intended to be able to preserve the output of commands with less jank.
- `clear` - `boolean?` : Whether or not the chat is cleared before printing the new message. Defaults to `false`.
- `sound` - `defines.print_sound?` : If a sound should be emitted for this message. Defaults to `defines.print_sound.use_player_settings` if clear is `false`. Otherwise defaults to `defines.print_sound.never`.
- `sound_path` - `SoundPath?` : The sound to play. If not given, [UtilitySounds::console\_message](https://lua-api.factorio.com/latest/prototypes/UtilitySounds.html#console_message) will be used instead.
- `volume_modifier` - `float?` : The volume of the sound to play. Must be between 0 and 1 inclusive. Defaults to `1`.

If the `type` is `"global"` there are no additional arguments

If the `type` is `"force"`, `"player"`, or `"surface"`, you add:

- `recipient` - `uint` : Either the player, surface, or force the message is sent to

If the `type` is `"whisper"`, you add:
- `sender` - `uint` : The player that sent the whisper.
	- The difference from base, is that it is now required.
- `recipient` - `uint` : The player that received the whisper.


## Compatibility
For easy compatibility, you can just use this code snippet and turn every `object.print(message, settings)` into `compat_send(object, message, settings)`.
```lua
---@type boolean?
local has_better_chat = nil
local send_types = {
	["LuaGameScript"] = "global",
	["LuaForce"] = "force",
	["LuaPlayer"] = "player",
	["LuaSurface"] = "surface",
}
--- Safely attempts to print via the Better Chatting's interface
---@param recipient LuaGameScript|LuaForce|LuaPlayer|LuaSurface
---@param msg LocalisedString
---@param print_settings PrintSettings?
function compat_send(recipient, msg, print_settings)
	if has_better_chat == nil then
		local better_chat = remote.interfaces["better-chat"]
		has_better_chat = better_chat and better_chat["send"]
	end

	if not has_better_chat then return recipient.print(msg, print_settings) end
	print_settings = print_settings or {}


	local send_type = send_types[recipient.object_name]
	if not send_type then error("Invalid Recipient", 2) end

	---@type int?
	local send_index
	if send_level ~= "global" then
		send_index = recipient.index
		if not send_index then
			error("Invalid Recipient", 2)
		end
	end

	remote.call("better-chat", "send", {
		message = msg,
		type = send_type,
		color = print_settings.color,
		recipient = send_index,

		sound = print_settings.sound,
		sound_path = print_settings.sound_path,
		volume_modifier = print_settings.volume_modifier
	})
end
```


## Todo List:
- [ ] Add nicknames
- [ ] Add admin interface