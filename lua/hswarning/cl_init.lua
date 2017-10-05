
HSWarning = {}

include("shared.lua")

HSWarning.ChatHook = function(pl, text, teamchat, isdead)
	if pl != LocalPlayer() then
		if HSWarning.IsWarningCommand(text) then
			return true
		end
	end
	
	if HSWarning.IsWarningCommand(text) then	
		local command, args = HSWarning.ExtractCommandArgs(text)
		
		args = args
		
		if string.len(command) == 0 then
			chat.AddText(COLOR_GREEN, "경고 모듈 명령어:")
			if pl:IsAdmin() then 
				chat.AddText(COLOR_GREEN, "\t!warn add|a")
				chat.AddText(COLOR_GREEN, "\t!warn unban|u")
			end
			chat.AddText(COLOR_GREEN, "\t!warn sid")
			chat.AddText(COLOR_GREEN, "\t!warn show|s")
			chat.AddText(COLOR_GREEN, "\t!warn showtotal|st")
			return true
		end
		
		if command == "add" or command == "a" then
			if string.len(args) == 0 then
				chat.AddText(COLOR_GREEN, "경고 주기: !warn add ID_OR_SID 횟수")
			else
				local exploded = string.Explode(" ", args)
				local count = 0
				for i, v in pairs(exploded) do
					if string.find(v, "^%-?%d+$") then
						table.remove(exploded, i)
						count = tonumber(v)
						break
					end
				end
				
				local target = table.concat(exploded, " ")
				if !string.find(count, "^%-?%d+$") then
					chat.AddText(COLOR_RED, "경고는 정수로만 줄 수 있습니다.")
				end
				HSWarning.RequestWarn(tonumber(count), target)
			end
			
			return true
		end
		
		if command == "unban" or command == "u" then
			if string.len(args) == 0 then
				chat.AddText(COLOR_GREEN, "언밴(경고 초기화): !warn unban NICK_OR_SID")
			else
				HSWarning.RequestUnban(args)
			end
			
			return true
		end
		
		if command == "sid" then
			if string.len(args) == 0 then
				chat.AddText(COLOR_GREEN, "SID 보기(콘솔에 출력):")
					chat.AddText(COLOR_GREEN, "\t특정 닉네임을 포함한 SID 검색: 닉네임의 일부분 입력")
						chat.AddText(COLOR_GREEN, "\t\t(ex: !warn sid KOR => [KOR]혼살, [KOR]뚜벅이, ...)")
					chat.AddText(COLOR_GREEN, "\t현재 접속중인 플레이어의 SID 보기: #ALL#(ex: !warn sid #all# or !warn sid #ALL#")
			else
				HSWarning.RequestSID(args)
			end
			
			return true
		end
		
		if command == "show" or command == "s" then
			chat.AddText(COLOR_GREEN, "타인의 경고 횟수를 보려면 !warn show NICK")
			HSWarning.RequestShowWarn(args)
			return true
		end
		
		if  (command == "showtotal" or command == "st") then
			HSWarning.RequestShowTotalWarn(args)
		end
	end
end
hook.Add("OnPlayerChat", "HSWarning.ChatHook", HSWarning.ChatHook)

HSWarning.IsWarningCommand = function(text) 
	return string.Left(text, 5) == "!warn"
end

HSWarning.ExtractCommandArgs = function(text)
	if string.len(text) <= 5 then
		return "", ""
	end
	local exploded = string.Explode(" ", text)
	table.remove(exploded, 1)
	local command = string.lower(exploded[1])
	table.remove(exploded, 1)
	local args = string.lower(table.concat(exploded, " "))
	
	return command, args
end

HSWarning.RequestWarn = function(count, target)
	net.Start(HSWarning.NET_ADDWARN)
		net.WriteInt(count, 16)
		net.WriteString(string.lower(target))
	net.SendToServer()
end

HSWarning.RequestSID = function(text)
	if string.lower(text) == "#all#" then
		for i, v in pairs(player.GetAll()) do 
			chat.AddText(COLOR_DARKGREEN, i .. ": " .. v:Nick() .. "\t\t" .. v:SteamID() .. "\n\n")
		end
		return
	end
	
	net.Start(HSWarning.NET_GET_SID)
		net.WriteString(string.lower(text))
	net.SendToServer()
end

HSWarning.RequestShowWarn = function(target)
	net.Start(HSWarning.NET_SHOWWARN)
		net.WriteString(target)
	net.SendToServer()
end

HSWarning.RequestShowTotalWarn = function(target)
	net.Start(HSWarning.NET_SHOWTOTALWARN)
		net.WriteString(target)
	net.SendToServer()
end

HSWarning.RequestUnban = function(target)
	net.Start(HSWarning.NET_UNBAN)
		net.WriteString(target)
	net.SendToServer()
end