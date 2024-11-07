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
- `level` - `historyLevel` : Whether the message is intended for `"global"` broadcast, a `"force"` level message, or a `"player"` specific message.
- `recipient` - `uint` : The id of the recipient force or player (ignored for `"global"` broadcast).
- `color` - `Color?` : The base color of the message.
- `process_color` - `boolean?` : Whether or not the color of the message should be faded out based on user setting.
- `clear` - `boolean?` : Whether or not the chat is cleared before printing the new message. `true` by default.

## Todo List:
- [x] Use *Proper* migrations
- [x] Add toggleable chat timestamps?
  - They will be in hh:mm:ss format
  - Start using game.ticks_played instead of game.tick?
- [ ] Add moderation filters
- [ ] Add nicknames