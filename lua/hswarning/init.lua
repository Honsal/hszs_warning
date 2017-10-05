local isValidSID = function(sid)
	return string.find(string.upper(sid), "^STEAM_%d:%d:%d+$")
end

HSWarning = {}

include("shared.lua")
include("db.lua")

HSWarning.Init = function()
	util.AddNetworkString(HSWarning.NET_ADDWARN)
	util.AddNetworkString(HSWarning.NET_UNBAN)
	util.AddNetworkString(HSWarning.NET_GET_SID)
	util.AddNetworkString(HSWarning.NET_SHOWWARN)
	util.AddNetworkString(HSWarning.NET_SHOWTOTALWARN)
	HSWarning.DB.Init()
end
hook.Add("Initialize", "HSWarning.Init", HSWarning.Init)

HSWarning.ResponseWarn = function(len, pl)
	if !pl:IsAdmin() then
		pl:PrintMessage(HUD_PRINTTALK, "어드민이 아니라서 이 기능을 사용할 수 없습니다.")
		HSLog.d("ResponseWarn", pl:Nick() .. "(" .. pl:SteamID() .. ") 님께서 권한 없는 경고를 시도하셨습니다.")
		ulx.asay(NULL, pl:Nick() .. "(" .. pl:SteamID() .. ") 님께서 권한 없는 경고를 시도하셨습니다.")
		return
	end
	local amount = net.ReadInt(16)
	local target = net.ReadString()
	
	if isValidSID(target) then
		HSWarning.DB.AddWarn(string.upper(target), nil, amount, pl)
	else
		HSWarning.DB.AddWarn(nil, target, amount, pl)
	end
end
net.Receive(HSWarning.NET_ADDWARN, HSWarning.ResponseWarn)

HSWarning.ResponseUnban = function(len, pl)
	if !pl:IsAdmin() then
		pl:PrintMessage(HUD_PRINTTALK, "어드민이 아니라서 이 기능을 사용할 수 없습니다.")
		HSLog.d("ResponseWarn", pl:Nick() .. "(" .. pl:SteamID() .. ") 님께서 권한 없는 언밴을 시도하셨습니다.")
		ulx.asay(NULL, pl:Nick() .. "(" .. pl:SteamID() .. ") 님께서 권한 없는 언밴을 시도하셨습니다.")
		return
	end
	
	local target = net.ReadString()
	
	if isValidSID(target) then
		HSWarning.DB.Unban(string.upper(target), nil, pl)
	else
		HSWarning.DB.Unban(nil, target, pl)
	end
end
net.Receive(HSWarning.NET_UNBAN, HSWarning.ResponseUnban)

HSWarning.ResponseGetSID = function(len, pl)
	local target = net.ReadString()
	
	local players = HSWarning.DB.GetSIDFromNick(target)
	
	if istable(players) then
		for i, v in pairs(players) do
			pl:PrintMessage(HUD_PRINTCONSOLE, v.sid .. "\t\t" .. v.nick)
		end
		pl:PrintMessage(HUD_PRINTTALK, "콘솔에 닉네임과 스팀아이디가 출력되었습니다.")
	elseif isnumber(players) then
		if players == -1 then
			pl:PrintMessage(HUD_PRINTTALK, "스팀아이디 정보를 가져오는 중 치명적인 에러가 발생했습니다.")
		elseif players == 0 then
			pl:PrintMessage(HUD_PRINTTALK, "해당 닉네임을 포함한 유저가 서버에 접속한 기록이 없습니다.")
		end
	elseif isstring(players) then
		pl:PrintMessage(HUD_PRINTTALK, HSWarning.DB.GetNickFromSID(players) .. ": " .. players)
	end
end
net.Receive(HSWarning.NET_GET_SID, HSWarning.ResponseGetSID)

HSWarning.ResponseShowWarn = function(len, pl)
	local target = net.ReadString()
	
	if target == "" then
		pl:PrintMessage(HUD_PRINTTALK, "24시간 이내에 받은 경고 횟수: " .. HSWarning.DB.GetWarns(pl:SteamID(), nil, pl) .. "회.")
		return
	end
	
	if pl:IsAdmin() then
		if isValidSID(target) then
			target = string.upper(target)
			pl:PrintMessage(HUD_PRINTTALK, HSWarning.DB.GetNickFromSID(target) .. "님께서 24시간 이내에 받은 경고 횟수: " .. HSWarning.DB.GetWarns(target, nil, pl))
		else
			local players =  HSWarning.DB.GetSIDFromNick(target)
			if istable(players) then
				for i, v in pairs(players) do
					pl:PrintMessage(HUD_PRINTCONSOLE, v.nick .. "님께서 24시간 이내에 받은 경고 횟수: " .. HSWarning.DB.GetWarns(v.sid, nil, pl))
				end
				pl:PrintMessage(HUD_PRINTTALK, "콘솔에 닉네임과 경고 횟수가 출력되었습니다.")
			elseif isnumber(players) then
				if players == -1 then
					pl:PrintMessage(HUD_PRINTTALK, "스팀아이디 정보를 가져오는 중 치명적인 에러가 발생했습니다.")
				elseif players == 0 then
					pl:PrintMessage(HUD_PRINTTALK, "해당 닉네임을 포함한 유저가 서버에 접속한 기록이 없습니다.")
				end
			elseif isstring(players) then
				pl:PrintMessage(HUD_PRINTTALK, HSWarning.DB.GetNickFromSID(players) .. "님께서 24시간 이내에 받은 경고 횟수: " .. HSWarning.DB.GetWarns(players, nil, pl))
			end
		end
		return
	else
		pl:PrintMessage(HUD_PRINTTALK, "어드민이 아니라서 이 기능을 사용할 수 없습니다.")
		HSLog.d("ResponseWarn", pl:Nick() .. "(" .. pl:SteamID() .. ") 님께서 권한 없는 경고 횟수 조회를 시도하셨습니다.")
		ulx.asay(NULL, pl:Nick() .. "(" .. pl:SteamID() .. ") 님께서 권한 없는 경고 횟수 조회를 시도하셨습니다.")
		return
	end
end
net.Receive(HSWarning.NET_SHOWWARN, HSWarning.ResponseShowWarn)

HSWarning.ResponseShowTotalWarn = function(len, pl)
	local target = net.ReadString()
	
	if (target == "") then
		pl:PrintMessage(HUD_PRINTTALK, "총 경고 횟수: " .. HSWarning.DB.GetTotalWarn(pl:SteamID(), nil, pl))
		return
	end
	
	if (isValidSID(target)) then
		target = string.upper(target)
		pl:PrintMessage(HUD_PRINTTALK, HSWarning.DB.GetNickFromSID(target) .. "님께서 받은 총 경고 횟수: " .. HSWarning.DB.GetTotalWarn(target, nil, pl))
	else
		local players = HSWarning.DB.GetSIDFromNick(target)
		if (istable(players)) then
			for i, v in pairs(players) do
				pl:PrintMessage(HUD_PRINTCONSOLE, v.nick .. "님께서 받은 총 경고 횟수: " .. HSWarning.DB.GetTotalWarn(v.sid, nil, pl))
			end
			pl:PrintMessage(HUD_PRINTTALK, "콘솔에 닉네임과 총 경고 횟수가 출력되었습니다.")
		elseif (isnumber(players)) then
			if (players == -1) then
				pl:PrintMessage(HUD_PRINTTALK, "스팀아이디 정보를 가져오는 중 에러가 발생했습니다.")
			elseif (players == 0) then
				pl:PrintMessage(HUD_PRINTTALK, "해당 닉네임을 포함한 유저가 서버에 접속한 기록이 없습니다.")
			end
		elseif (isstring(players)) then
			pl:PrintMessage(HUD_PRINTTALK, HSWarning.DB.GetNickFromSID(players) .. "님께서 받은 총 경고 횟수: " .. HSWarning.DB.GetTotalWarn(players, nil, pl))
		end
	end
end
net.Receive(HSWarning.NET_SHOWTOTALWARN, HSWarning.ResponseShowTotalWarn)

concommand.Add("hswarn", function(pl, cmd, arg)
	if (pl != NULL and (pl:IsPlayer() and !pl:IsAdmin() or true)) then
		return false
	end
	
	local target = string.upper(arg[1])
	
	local cnt = arg[2]
	
	if (target == "STEAM_0") then
		target = arg[1] .. ":" .. arg[3] .. ":" .. arg[5]
		cnt = arg[6]
		HSWarning.DB.AddWarn(target, nil, cnt, pl)
	else
		HSWarning.DB.AddWarn(nil, target, cnt, pl)
	end
	
	-- HSWarning.DB.AddWarn(
end)