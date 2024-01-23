local ChatHistoryManager = require "ChatHistoryManager"

script.on_configuration_changed(function (stuff_changed)
	if stuff_changed.mod_changes[script.mod_name] then
		local old_version = stuff_changed.mod_changes[script.mod_name].old_version

		if not old_version then return
		elseif old_version == "0.1.0" then goto v0_1_0
		elseif old_version == "0.2.0" then goto v0_2_0
		else
			game.print("Better Chat migrating from invalid version. Continue at your own risk")
			return
		end

		::v0_1_0::
		local oldHistory = global.chatHistory
		global.chatHistory = nil;

		--Replicate ChatHistoryManager.init
		global.GlobalChatLog = ChatHistoryManager.__newChatLog()
		global.ForceChatLog = {}
		for _,force in pairs(game.forces) do
			global.ForceChatLog[force.index] = ChatHistoryManager.__newChatLog();
		end
		global.PlayerChatLog = {}
		for player in pairs(game.players) do
			global.PlayerChatLog[player] = ChatHistoryManager.__newChatLog();
		end

		--Migrate old chat history into new one's global chat
		for _, chat in pairs(oldHistory) do
			ChatHistoryManager.add_message{
				message = chat.msg,
				header = {"chat-localization.bc-empty-header"},
				color = chat.color,
				level = "global"
			}
		end

		::v0_2_0::
	end
end)