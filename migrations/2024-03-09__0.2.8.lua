for _,chat in storage.GlobalChatLog:from() do
  chat.tick = chat.tick or game.tick
end
for _,ChatLog in pairs(storage.ForceChatLog) do
  for _,chat in ChatLog:from() do
    chat.tick = chat.tick or game.tick
  end
end
for _,ChatLog in pairs(storage.PlayerChatLog) do
  for _,chat in ChatLog:from() do
    chat.tick = chat.tick or game.tick
  end
end