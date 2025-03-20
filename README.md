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
- `level` - `historyLevel` : Whether the message is intended for `"global"` broadcast, everyone on some `"force"`, everyone on a `"surface"`, or a specific `"player"`.
- `recipient` - `uint` : Either the player, surface, or force that recieves it if the send_level was not global.
- `color` - `Color?` : The base color of the message.
- `process_color` - `boolean?` : Whether or not the message is faded out by the player's settings. Defaults to `false`.
- `skip_print` - `boolean?` : Whether or not the added chat is printed at all. This will also skip any sound. Defaults to `false`.
	- This was intended to be able to preserve the output of commands with less jank.
- `clear` - `boolean?` : Whether or not the chat is cleared before printing the new message. Defaults to `true`.
- `sound` - `defines.print_sound?` : If a sound should be emitted for this message. Defaults to `defines.print_sound.use_player_settings` if clear is `false`. Otherwise defaults to `defines.print_sound.never`.
- `sound_path` - `SoundPath?` : The sound to play. If not given, [UtilitySounds::console\_message](https://lua-api.factorio.com/latest/prototypes/UtilitySounds.html#console_message) will be used instead.
- `volume_modifier` - `float?` : The volume of the sound to play. Must be between 0 and 1 inclusive. Defaults to `1`


## Todo List:
- [ ] Add nicknames