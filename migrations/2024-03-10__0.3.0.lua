---@diagnostic disable: inject-field, no-unknown, undefined-field

for chat in global.GlobalChatLog:from() do
  if chat.msg then
    chat.message = {"", chat.header, chat.msg}
    chat.msg = nil
    chat.header = nil
  end
end

for _,ChatLog in pairs(global.ForceChatLog) do
  for chat in ChatLog:from() do
    if chat.msg then
      chat.message = {"", chat.header, chat.msg}
      chat.msg = nil
      chat.header = nil
    end
  end
end

for _,ChatLog in pairs(global.PlayerChatLog) do
  for chat in ChatLog:from() do
    if chat.msg then
      chat.message = {"", chat.header, chat.msg}
      chat.msg = nil
      chat.header = nil
    end
  end
end