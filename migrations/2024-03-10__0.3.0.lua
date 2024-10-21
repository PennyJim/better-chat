---@diagnostic disable: inject-field, no-unknown, undefined-field

for _,chat in storage.GlobalChatLog:from() do
  if chat.msg then
    chat.message = {"", chat.header, chat.msg}
    chat.msg = nil
    chat.header = nil
  end
end

for _,ChatLog in pairs(storage.ForceChatLog) do
  for _,chat in ChatLog:from() do
    if chat.msg then
      chat.message = {"", chat.header, chat.msg}
      chat.msg = nil
      chat.header = nil
    end
  end
end

for _,ChatLog in pairs(storage.PlayerChatLog) do
  for _,chat in ChatLog:from() do
    if chat.msg then
      chat.message = {"", chat.header, chat.msg}
      chat.msg = nil
      chat.header = nil
    end
  end
end