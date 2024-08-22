
--- Don't run this if the disabled commands doesn't exist
if global.disabledCommands then return log("skipping") end


---@param chat Chat
local function process_message(chat)
  if type(chat.message) == "table" and chat.message[1] == ""
  and type(chat.message[2]) == "table"
  and type(chat.message[2][1]) == "string"
  and chat.message[2][1]--[[@as string]]:find("chat%-localization") then
    chat.process_color = true
    ---Get header color in messages that use chat's header
    local header_color = chat.color or {1,1,1}
    local header = chat.message[2]
    chat.message[2] = {
      "chat-localization.colored-text",
      header,
      header_color[1] or header_color.r,
      header_color[2] or header_color.g,
      header_color[3] or header_color.b,
    }
  end
end

for _,chat in global.GlobalChatLog:from() do
  process_message(chat)
end
for _,ChatLog in pairs(global.ForceChatLog) do
  for _,chat in ChatLog:from() do
    process_message(chat)
  end
end
for _,ChatLog in pairs(global.PlayerChatLog) do
  for _,chat in ChatLog:from() do
    process_message(chat)
  end
end