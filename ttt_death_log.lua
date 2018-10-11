-- Must test on real server... inflictor is almost always "player". What the fuck.

if SERVER then
	util.AddNetworkString("chatMessage")

	local playerMeta = FindMetaTable("Player")
	function playerMeta:AddChatText(...)
		net.Start("chatMessage") net.WriteTable({...}) net.Send(self)
	end

	function AddChatText(...)
		net.Start("chatMessage") net.WriteTable({...}) net.Broadcast()
	end

	function AddChatTextSelected(players, ...)
		for k, v in pairs (player.GetAll()) do
			net.Start("chatMessage") net.WriteTable({...}) net.Send(players)
		end
	end

	function AddChatTextOmit(players, ...)
		for k, v in pairs (player.GetAll()) do
			if v:IsPlayer() and IsValid(v) then
				net.Start("chatMessage") net.WriteTable({...}) net.SendOmit(v)
			end
		end
	end
	
	ROLE_INNOCENT  = 0
	ROLE_TRAITOR   = 1
	ROLE_DETECTIVE = 2
	roles = {[ROLE_TRAITOR] = {'traitor', Color(255, 0, 0, 255)}, [ROLE_DETECTIVE] = {'detective', Color(0, 0, 255, 255)}, [ROLE_INNOCENT] = {'innocent', Color(0, 255, 0, 255)}} -- Defining the reference table with roles and their name and color.
	logs = {}
	orange = Color(255, 125, 0, 255)
	teal = Color(0, 125, 255)
	white = Color(255, 255, 255, 255)
	authedRanks = {"admin", "superadmin", "owner"} -- This isn't case sensitive. Just make sure to put the usergroup ID and not the usergroup display name

	for k, v in pairs (authedRanks) do
		authedRanks[k] = string.lower(v)
	end

	local playerMeta = FindMetaTable("Player")
	function playerMeta:GetUserGroup()
		return self:GetNWString("UserGroup")
	end

	function GetTeamColor(player) -- This gets the team color by grabbing their team enum, and looking in the key with the same value as the enum, then grabbing the second value in that key.
		if !player:IsPlayer() then
			return Color(125, 125, 125)
		end
		return roles[player:GetRole()][2]
	end

	function GetTeamString(player) -- This gets the team name by grabbing their team enum, and looking in the key with the same value as the enum, then grabbing the first value in that key.
		if !player:IsPlayer() then
			return "none"
		end
		return roles[player:GetRole()][1]
	end

	function PrintLog(victim, killer, entity) -- Adds a log into the table, it has the table that we'll unpack into varargs for the chat message
		if stopLogging then return end;
		if victim == killer or victim == entity or !killer:IsPlayer() then return end;

		if (victim:GetRole() == ROLE_TRAITOR and killer:GetRole() == ROLE_TRAITOR) or (victim:GetRole() != ROLE_TRAITOR and killer:GetRole() != ROLE_TRAITOR) then
			if entity:IsPlayer() then
				logs[#logs + 1] = {teal, '[Kuro Log]', orange, white, killer:GetName(), orange, "[", GetTeamColor(killer), GetTeamString(killer), orange, "] has killed ", white, victim:GetName(), orange, "[", GetTeamColor(victim), GetTeamString(victim), orange, "] with ", white, entity:GetActiveWeapon():GetClass(), orange, "."}
			else
				logs[#logs + 1] = {teal, '[Kuro Log]', orange, white, killer:GetName(), orange, "[", GetTeamColor(killer), GetTeamString(killer), orange, "] has killed ", white, victim:GetName(), orange, "[", GetTeamColor(victim), GetTeamString(victim), orange, "] with ", white, entity:GetClass(), orange, "."}
			end
		end
	end

	function BroadcastKiller(victim, entity, killer) -- This one tells the victim who killed him/her
		if victim != killer and killer:IsPlayer() and entity:IsPlayer() then -- If the victim was killed by another player, with a weapon.
			victim:AddChatText(teal, '[Kuro Deaths]', orange, 'You were killed by ', white, killer:GetName(), orange, '[', GetTeamColor(killer), GetTeamString(killer), orange, '] with weapon: ', white, entity:GetActiveWeapon():GetClass(), orange, '.')
		elseif victim == killer and killer == entity then -- If the victim suicided, or was slain
			victim:AddChatText(teal, '[Kuro Deaths]', orange, 'You committed suicide or were slain.') -- No way to check this without adding a decent amount of code in other files
		elseif entity:GetClass() == 'worldspawn' and killer:GetClass() == 'worldspawn' then -- If the victim died of fall damage
			victim:AddChatText(teal, '[Kuro Deaths]', orange, 'You fell to your death.')
		elseif entity:GetClass() == "entityflame" and killer:GetClass() == "entityflame" then -- If killed by fire
			victim:AddChatText(teal, '[Kuro Deaths]', orange, 'You burnt to death.')
		elseif entity:GetClass() == 'prop_physics' then -- If the entity is a prop
			if killer:GetClass() == 'prop_physics' then -- If the killer is also a prop
				victim:AddChatText(teal, '[Kuro Deaths]', orange, 'You were killed by a prop')
			elseif killer:IsPlayer() then -- If the killer is a player, it's likely that it's an explosive barrel set off by that player.
				if killer != victim then -- If the killer is not also the victim, it means it's not a suicide.
					victim:AddChatText(teal, '[Kuro Deaths]', orange, 'You were killed by a prop triggered by ', white, killer:GetName(), orange, '[', GetTeamColor(killer), GetTeamString(killer), orange, ']. Perhaps an explosive barrel?')
				else -- If the victim is the killer too, then it's an epic fail, and you suicided.
					victim:AddChatText(teal, '[Kuro Deaths]', orange, 'You were killed by a prop triggered by yourself. Perhaps an explosive barrel?')
				end
			end
		else
			victim:AddChatText(teal, '[Kuro Deaths]', orange, 'You were killed by "', white, killer:GetClass(), orange, '" with "', white, entity:GetClass(), orange, '".') -- If none of the above, (unlikely,) then there is no way to determine how did you die.
		end
		PrintLog(victim, killer, entity)
	end
	hook.Add("PlayerDeath", "BroadcastKiller", BroadcastKiller)

	function GetAuthedPlayers()
		local authedPlayers = {}
		for k, v in pairs (player.GetAll()) do
			if table.HasValue(authedRanks, string.lower(v:GetUserGroup())) then
				table.insert(authedPlayers, v)
			end
		end
		if #authedPlayers >= 1 then
			return authedPlayers
		else
			return false
		end
	end

	function SendLogs()
		local authedPlayers = GetAuthedPlayers()
		if !authedPlayers then return end
		for k, v in pairs (authedPlayers) do
			v:AddChatText(Color(255, 255, 0), "---! END ROUND RDM REPORT !---")
			if #logs < 1 then
				v:AddChatText(white, "---! NO RDM IN LAST ROUND !---")
			else
				for k2, v2 in ipairs (logs) do
					v:AddChatText(unpack(v2))
				end
			end
		end
		stopLogging = true
	end
	hook.Add("TTTEndRound", "SendLogs", SendLogs)

	function ClearLogs()
		logs = {}
		stopLogging = false
	end
	hook.Add("TTTBeginRound", "ClearLogs", ClearLogs)
end

if CLIENT then
	net.Receive("chatMessage", function(length, client) chat.AddText(unpack(net.ReadTable())) end)
end