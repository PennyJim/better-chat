---@diagnostic disable: inject-field
local ChatHistoryManager = require "__better-chat__.runtime.ChatHistoryManager"

-- TODO: Make this *actual* migrations goddamn
-- HACK: This works, but also it is not the right way
-- FIXME: Just to get as much attention on this issue as I can

---@param stuff_changed ConfigurationChangedData
---@param metatables table[]
return function (stuff_changed, metatables)
	if stuff_changed.mod_changes[script.mod_name] then
		local old_version = stuff_changed.mod_changes[script.mod_name].old_version

		if not old_version then return
		elseif old_version == "0.1.0" then goto v0_1_0
		elseif old_version == "0.2.0" then goto v0_2_0
		elseif old_version == "0.2.1" then goto v0_2_1
		elseif old_version == "0.2.2" then goto v0_2_2
		elseif old_version == "0.2.3" then goto v0_2_3
		elseif old_version == "0.2.4" then goto v0_2_4
		elseif old_version == "0.2.5" then goto v0_2_5
		elseif old_version == "0.2.6" then goto v0_2_6
		elseif old_version == "0.2.7" then goto v0_2_7
		elseif old_version == "0.2.8" then goto v0_2_8
		elseif old_version == "0.3.0" then goto v0_3_0
		elseif old_version == "0.3.1" then goto v0_3_1
		else
			game.print("Better Chat migrating from invalid version. Continue at your own risk")
			return
		end

		::v0_1_0::
		do -- block reduce oldHistory's scope
			local oldHistory = global.chatHistory
			global.chatHistory = nil;

			--Replicate ChatHistoryManager.init
			global.GlobalChatLog = ChatHistoryManager.__newChatLog()
			global.ForceChatLog = {}
			for _,force in pairs(game.forces) do
				global.ForceChatLog[force.index] = ChatHistoryManager.__newChatLog();
			end
			global.PlayerChatLog = {}
			for _,player in pairs(game.players) do
				local player_index = player.index
				global.PlayerChatLog[player_index] = ChatHistoryManager.__newChatLog();
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
		end
		-- Don't need to convert chatlogs as it 
		--  made them using the internal command
		goto v0_2_8

		::v0_2_0::
		::v0_2_1::
		::v0_2_2::
		do --block to redue linkedListMigration's scope
			local function linkedListMigration(list)
				local log = ChatHistoryManager.__newChatLog()
				local array = log.chat_array

				local link = list.first_chat
				while link do
					array[#array+1] = link.value
					link = link.next
				end
				log.size = #array
				log.last_index = #array

				return log
			end

			global.GlobalChatLog = linkedListMigration(global.GlobalChatLog)
			for force_index in pairs(global.ForceChatLog) do
				global.ForceChatLog[force_index] = linkedListMigration(global.ForceChatLog[force_index])
			end
			for player_index in pairs(global.PlayerChatLog) do
				global.PlayerChatLog[player_index] = linkedListMigration(global.PlayerChatLog[player_index])
			end
		end

		::v0_2_3::
		::v0_2_4::
		::v0_2_5::
		::v0_2_6::
		::v0_2_7::
		do --reduce Chat Migration's scope
			for chat in global.GlobalChatLog:from() do
				chat.tick = game.tick
			end
			for _,ChatLog in pairs(global.ForceChatLog) do
				for chat in ChatLog:from() do
					chat.tick = game.tick
				end
			end
			for _,ChatLog in pairs(global.PlayerChatLog) do
				for chat in ChatLog:from() do
					chat.tick = game.tick
				end
			end
		end
		::v0_2_8::
		do --reduce message migration's scope
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
		end

		::v0_3_0::
		do
			global.isChatOpen = setmetatable({}, metatables[1])
		end
		::v0_3_1::
		do
			global.disabledCommands = {}
			global.disabledListeners = {}
		end
	end
end