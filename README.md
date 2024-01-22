# Better Chatting
### An attempt at improving Factorio's built in chat.

Recommended to be combined with [Twemoji](https://mods.factorio.com/mod/twemoji-in-factorio)

## Emojipack
The main reason I made this mod, is to add support for discord style emotes. eg: `:purple_heart:` -> 💜

This functions by other mods calling `remote.call("emojipack registration", "add")` with the mod name and a dictionary of shortcodes and their tags. I recommend using `[img=<type>.<item>]` rather than `[<type>=<item>]` as it looks significantly nicer in chat.

## Todo List:
- [x] Implement Emojipack Support
- [x] Per-player chat history
	- [x] Fix /whisper and /shout
	- [ ] ~~Add toggleable chat timestamps?~~
- [ ] Add moderation filters
- [ ] Add nicknames
- [ ] more?