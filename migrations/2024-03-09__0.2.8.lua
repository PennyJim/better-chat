for _,chat in global.GlobalChatLog:from() do
  chat.tick = chat.tick or game.tick
end
for _,ChatLog in pairs(global.ForceChatLog) do
  for _,chat in ChatLog:from() do
    chat.tick = chat.tick or game.tick
  end
end
for _,ChatLog in pairs(global.PlayerChatLog) do
  for _,chat in ChatLog:from() do
    chat.tick = chat.tick or game.tick
  end
end