---@diagnostic disable: inject-field, no-unknown, undefined-field
if not storage.GlobalChatLog then return log("Global log doesn't exist. Skipping migration") end

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