# Better Chatting
### An attempt at improving Factorio's built in chat.

Recommended to be combined with [Twemoji](https://mods.factorio.com/mod/twemoji-in-factorio) or [Fluent Emoji](https://mods.factorio.com/mod/fluent-emoji) (or both)

## Emojipack
The main reason I made this mod, is to add support for discord style emotes. eg: `:purple_heart:` -> 💜

This functions by other mods calling `remote.call("emojipack registration", "add")` with the mod name and a dictionary of shortcodes and their tags. I recommend using `[img=<type>.<item>]` rather than `[<type>=<item>]` as it looks significantly nicer in chat.

## Scripting
To print a permanent message instead of letting Better Chat clear it away, use `remote.call("better-chat", "send", {})`
The arguments are:
- `message` - `LocalisedString` : The contents of the message.
- `level` - `historyLevel` : Whether the message is intended for `"global"` broadcast, everyone on some `"force"`, everyone on a `"surface"`, or a specific `"player"`.
- `recipient` - `uint` : The id of the recipient force or player (ignored for `"global"` broadcast).
- `color` - `Color?` : The base color of the message.
- `process_color` - `boolean?` : Whether or not the color of the message should be faded out based on user setting.
- `clear` - `boolean?` : Whether or not the chat is cleared before printing the new message. `true` by default.
- `skip_print` - `boolean?` : Whether or not the chat will be immediately printed. This is used for the lua commands to not squash unreplicable normal output. `false` by default.

## Todo List:
- [ ] Add nicknames