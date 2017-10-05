/*
	Structure:
		id: INTEGER PRIMARY KEY ASC AUTOINCREMENT;
		sid: VARCHAR(22) NOT NULL // STEAM ID
		nick: VARCHAR(64) NOT NULL // Nickname
		registered: DOUBLE UNSIGNED NOT NULL DEFAULT 0 // Time first connected to server
		modified: DOUBLE UNSIGNED NOT NULL DEFAULT 0 // Last modified time
		warns: TINYINT UNSIGNED NOT NULL DEFAULT 0 // Current warning count
		banned BIT NOT NULL DEFAULT 0 // Is banned?
		banend DOUBLE UNSIGNED NOT NULL DEFAULT 0 // Ban end time
		lastwarn: DOUBLE UNSIGNED NOT NULL DEFAULT 0 // Last warning time
		lastban: DOUBLE UNSIGNED NOT NULL DEFAULT 0 // Last banned time
		lastconn: DOUBLE UNSIGNED NOT NULL DEFAULT 0 // Last connected time
		totalwarn: INTEGER UNSIGNED NOT NULL DEFAULT 0 // Total warning count
		totalban: INTEGER UNSIGNED NOT NULL DEFAULT 0 // Total ban count
*/

g_oldsqlstr = g_oldsqlstr or sql.SQLStr

sql.SQLStr = function(str)
	if string.Left(str, 1) == "'" and string.Right(str, 1) == "'" then
		str = string.sub(str, 2, string.len(str) - 1)
	end
	return g_oldsqlstr(str)
end

local isValidSID = function(sid)
	return string.find(string.upper(sid), "^STEAM_%d:%d:%d+$") != nil
end

local isDupePl = function(tbl)
	if !istable(tbl) then
		return false
	end
	
	return true
end

local checkSID = function(sid, pl)
	if isstring(sid) then
		if string.Left(sid, 1) == "'" and string.Right(sid, 1) == "'" then
			sid = string.sub(sid, 2, string.len(sid) - 1)
		end
		
		if string.find(sid, "^%d+$") then
			sid = tonumber(sid)
		end
	end
	
	if sid == -1 then
		error("UNKNOWN ERROR")
	elseif sid == 0 then
		if pl and IsValid(pl) and pl:IsPlayer() then
			pl:PrintMessage(HUD_PRINTTALK, "해당 닉네임의 플레이어를 찾을 수 없습니다.")
		end
		
		error(
			"Player who matched with specified nickname was not found."
		)
	elseif istable(sid) then
		if pl and IsValid(pl) and pl:IsPlayer() then
			pl:PrintMessage(HUD_PRINTTALK, "해당 닉네임의 플레이어가 둘 이상입니다.")
			
			for i, v in pairs(sid) do 
				pl:PrintMessage(HUD_PRINTTALK, v.nick .. "\t\t" .. v.sid)
			end
		end
		
		error(
			"Count of matched players is more than 1."
		)
	end
end

HSWarning.DB = {}

HSWarning.DB.MSG_DUPE = "Duplicated players."
HSWarning.DB.MSG_NO_COL_SPEC = "No column specified."
HSWarning.DB.MSG_KV_NOT_MATCH = "keys and values does not match."
HSWarning.DB.MSG_NO_BOTH_SID_NICK_SET = "No both sid and nick specified."
HSWarning.DB.MSG_NO_TIME_SET = "No time specified."
HSWarning.DB.MSG_SID_FORMAT_NOT_MATCH = "Sid format not matched."
HSWarning.DB.MSG_NO_PLAYER_FROM_SID = "No such player from sid."
HSWarning.DB.MSG_NO_PLAYER_FROM_NICK = "No such player from nick."
HSWarning.DB.MSG_SID_NOT_VALID = "Sid is not valid."
HSWarning.DB.MSG_NO_NICK_SET = "No nick is specified."
HSWarning.DB.MSG_UNKNOWN_ERROR_GETTING_SID = "Unknown error while getting sid info."

HSWarning.DB.TableName = "HSWarning"

HSWarning.DB.WarnThreshold = 3

HSWarning.DB.Init = function()
	if !HSWarning.DB.TableExists() then
		HSLog.d("Init", "No HSWaring table found! Creating... ")
		HSWarning.DB.MakeTable()
		HSLog.d("Init", "DONE!\n")
	else
		HSLog.a("Init", "HSWarning is ready.\n", true)
	end
end

HSWarning.DB.Remove = function()
	sql.Query("DROP TABLE HSWarning")
end

HSWarning.DB.TableExists = function()
	return sql.TableExists(HSWarning.DB.TableName)
end

HSWarning.DB.MakeTable = function() 
	sql.Query("CREATE TABLE IF NOT EXISTS " .. HSWarning.DB.TableName .. " (id INTEGER PRIMARY KEY ASC AUTOINCREMENT, sid VARCHAR(22) NOT NULL, nick VARCHAR(64) NOT NULL, registered DOUBLE UNSIGNED NOT NULL DEFAULT 0, modified DOUBLE UNSIGNED NOT NULL DEFAULT 0, warns TINYINT UNSIGNED NOT NULL DEFAULT 0, banned BIT NOT NULL DEFAULT 0, banend DOUBLE UNSIGNED NOT NULL DEFAULT 0, lastwarn DOUBLE UNSIGNED NOT NULL DEFAULT 0, lastban DOUBLE UNSIGNED NOT NULL DEFAULT 0, lastconn DOUBLE UNSIGNED NOT NULL DEFAULT 0, totalwarn INTEGER UNSIGNED NOT NULL DEFAULT 0, totalban INTEGER UNSIGNED NOT NULL DEFAULT 0)")
end

HSWarning.DB.PlayerExists = function(sid, nick)
	if !HSWarning.DB.TableExists() then
		return false
	end
	
	if sid then
		sid = sql.SQLStr(sid)
	end
	
	if nick then
		nick = sql.SQLStr(nick)
		nick = string.sub(nick, 2, string.len(nick) - 1)
	end
	
	local exists = false
	if sid != nil then

		local t = sql.Query("SELECT sid FROM " .. HSWarning.DB.TableName .. " WHERE sid = " .. sid)
		if t and table.Count(t) >= 1 then
			exists = true
		else
			exists = false
		end
	else
		local t = sql.Query("SELECT nick FROM " .. HSWarning.DB.TableName .. " WHERE nick LIKE '%" .. nick .. "%'")
		if t and table.Count(t) >= 1 then
			exists = true
		else
			exists = false
		end
	end	
	
	return exists
end

HSWarning.DB.InitPlayer = function(pl)
	local sid = sql.SQLStr(string.upper(pl:SteamID()))
	local nick = sql.SQLStr(pl:Nick())
	local registtime = sql.SQLStr(tostring(os.time()))
	if !HSWarning.DB.PlayerExists(sid) then
		local registered = HSWarning.DB.SQLInsert({"'sid'", "'nick'", "'registered'"}, {sid, nick, registtime})
		if registered then
			HSLog.a(nick .. "(" .. sid .. ")님의 정보가 경고 모듈에 등록되었습니다. 환영합니다.", true)
		end
	else
		local connected = HSWarning.DB.SQLUpdate({"lastconn", "nick"}, {registtime, nick}, "sid = " .. sid)
		local banend = HSWarning.DB.GetBanEndTime(sid)
		registtime = string.sub(registtime, 2, string.len(registtime) - 1)
		if banend > 0 and banend < tonumber(registtime) then
			HSWarning.DB.Unban(sid)
		end
		
		local lastwarn = HSWarning.DB.GetLastWarn(sid)
		if lastwarn > 0 and lastwarn + 86400 <= tonumber(registtime) then
			HSWarning.DB.SQLUpdate({ "warns" }, { 0 }, "sid = " .. sid)
			--HSWarning.DB.AddWarn(sid, nil, -HSWarning.DB.GetWarns(sid), NULL)
		end
	end
end
hook.Add("PlayerInitialSpawn", "HSWarning.DB.InitPlayer", HSWarning.DB.InitPlayer)

HSWarning.DB.NameCheckInit = function()
	HSWarning.DB.NameCheck = function(pl, old, new)
		local sid = sql.SQLStr(string.upper(pl:SteamID()))
		new = sql.SQLStr(new)
		HSWarning.DB.SQLUpdate({"nick"}, {new}, "sid = " .. sid)
		HSLog.d("NameCheck", "Name changed, old: " .. old .. ", new: " .. new)
	end
	hook.Add(ULib.HOOK_PLAYER_NAME_CHANGED, "HSWarning.DB.NameCheck", HSWarning.DB.NameCheck)
end
hook.Add("InitPostEntity", "HSWarning.DB.NameCheckInit", HSWarning.DB.NameCheckInit)

HSWarning.DB.crNameCheck = coroutine.create(function()
	while(!HSWarning.DB.StopNameChecking) do
		coroutine.yield()
		for _, pl in pairs(player.GetAll()) do
			coroutine.yield()
			if (pl:IsBot()) then
				continue
			end
			local sid = sql.SQLStr(string.upper(pl:SteamID()))
			local old = HSWarning.DB.SQLQuery({"nick"}, "sid = " .. sid)
			if !old or !old[1] then
				continue
			elseif !old[1]["nick"] then
				old = "알 수 없음"
			end
			
			if istable(old) then
				old = old[1]["nick"]
			end
			local new = pl:Nick()
			
			if old == new then
				continue
			end
			
			new = sql.SQLStr(new)
			
			HSWarning.DB.SQLUpdate({"nick"}, {new}, "sid = " .. sid)
			HSLog.d("NameCheck", "Name changed, old: " .. old .. ", new: " .. new)
		end
	end
end)

local nextNameCheck = 0
HSWarning.DB.NameCheckDelay = function()
	coroutine.resume(HSWarning.DB.crNameCheck)
	-- local curtime = CurTime()
	-- if nextNameCheck <= curtime then
		-- for _, pl in pairs(player.GetAll()) do
			-- local sid = sql.SQLStr(string.upper(pl:SteamID()))
			-- local old = HSWarning.DB.SQLQuery({"nick"}, "sid = " .. sid)
			-- if !old or !old[1] then
				-- continue
			-- elseif !old[1]["nick"] then
				-- old = "알 수 없음"
			-- end
			-- if istable(old) then
				-- old = old[1]["nick"]
			-- end
			-- local new = pl:Nick()
			
			-- if old == new then
				-- continue
			-- end
			
			-- new = sql.SQLStr(new)
			
			-- HSWarning.DB.SQLUpdate({"nick"}, {new}, "sid = " .. sid)
			-- HSLog.d("NameCheck", "Name changed, old: " .. old .. ", new: " .. new)
		-- end
		-- nextNameCheck = curtime + 60
	-- end
end
hook.Add("Think", "HSWarning.DB.NameCheckDelay", HSWarning.DB.NameCheckDelay)

HSWarning.DB.SQLQuery = function(col, where)
	if !col or table.Count(col) == 0 then
		HSLog.e("SQLQuery", HSWarning.DB.MSG_NO_COL_SPEC)
		return false
	end
	
	local query = sql.Query("SELECT " .. (istable(col) and table.concat(col, ", ") or col) .. " FROM " .. HSWarning.DB.TableName .. (where and " WHERE " .. where or ""))
	
	return query
end

HSWarning.DB.SQLInsert = function(keys, values)
	if table.Count(keys) != table.Count(values) then
		HSLog.e("SQLInsert", HSWarning.DB.MSG_KV_NOT_MATCH)
		HSLog.e("SQLInsert", "Keys: ")
		for _, v in pairs(keys) do
			HSLog.e("SQLInsert", "\t" .. v)
		end
		
		HSLog.e("SQLInsert", "Values: ")
		for _, v in pairs(values) do
			HSLog.e("SQLInsert", "\t" .. values)
		end
		
		return false
	end
	
	local keyStr = table.concat(keys, ", ")
	local valueStr = table.concat(values, ", ")
	
	sql.Query("INSERT INTO " .. HSWarning.DB.TableName .. "(" .. keyStr .. ", modified) VALUES (" .. valueStr .. ", " .. tostring(os.time()) .. ")")
	HSLog.d("SQLInsert", "Query successed: keys [" .. keyStr .. "], values [" .. valueStr.. "]")
	return true
end

HSWarning.DB.SQLUpdate = function(keys, values, where)
	if table.Count(keys) != table.Count(values) then
		HSLog.e("SQLUpdate", HSWarning.DB.MSG_KV_NOT_MATCH)
		HSLog.e("SQLUpdate", "Keys: ")
		for _, v in pairs(keys) do
			HSLog.e("SQLUpdate", "\t" .. v)
		end
		
		HSLog.e("SQLUpdate", "Values: ")
		for _, v in pairs(values) do
			HSLog.e("SQLUpdate", "\t" .. values)
		end
		
		return false
	end
	
	local setstr = " SET "
	for i = 1, table.Count(keys) do
		if i == 1 then
			setstr = setstr .. keys[i] .. " = " .. values[i]
		else
			setstr = setstr .. ", " .. keys[i] .. " = " .. values[i]
		end
	end
	
	setstr = setstr .. ", modified = " .. os.time()
	
	if where then
		where = " WHERE " .. where
	end
	
	sql.Query("UPDATE " .. HSWarning.DB.TableName .. setstr .. (where and where or ""))
	HSLog.d("SQLUpdate", "Query successed: keys [" .. table.concat(keys, ", ") .. "], values [" .. table.concat(values, ", ") .. "]")
	return true
end

HSWarning.DB.SetBan = function(sid, nick, time, pl)	
	if sid then
		sid = sql.SQLStr(sid)
	end
	
	if nick then
		nick = sql.SQLStr(nick)
		sid = HSWarning.DB.GetSIDFromNick(nick)
		
		checkSID(sid, pl)
		
		sid = sql.SQLStr(sid)
	end
	
	if !sid then
		error("Unknown Error")
	end
		
	local totalban = HSWarning.DB.GetTotalBan(sid)
	
	local ostime = os.time()
	
	ulx.banid((IsValid(pl) and pl:IsPlayer() and pl:IsAdmin()) and pl or NULL, string.sub(sid, 2, string.len(sid) - 1), time / 60, (time == 86400 and "TOOK TOO MANY WARNINGS." or "TOOK TOO MANY WARNINGS (added " .. ((time - 86400) / 60 / 60) .. " hours)"))
	
	HSWarning.DB.SQLUpdate({"banned", "banend", "lastban", "totalban"}, {"1", sql.SQLStr(ostime), tostring(ostime + time), totalban + 1}, "sid = " .. sid)
end

HSWarning.DB.Unban = function(sid, nick, pl)
	if sid then
		sid = sql.SQLStr(sid)
	end
	
	if nick then
		nick = sql.SQLStr(nick)
		sid = HSWarning.DB.GetSIDFromNick(nick)
		
		checkSID(sid, pl)
		
		sid = sql.SQLStr(sid)
	end
	
	if !sid then
		error("Unknown Error")
	end
	
	HSWarning.DB.SQLUpdate({"banned", "banend"}, {"0", "0"}, "sid = " .. sid)

	nick = HSWarning.DB.GetNickFromSID(sid)
	
	ulx.unban(NULL, string.sub(sid, 2, string.len(sid) - 1))
	
	HSLog.a((IsValid(pl) and pl:IsPlayer() and pl:IsAdmin() and pl:Nick() .. "님께서 " or "") .. nick .. "님을 언밴 처리하였습니다.")
end

HSWarning.DB.GetTotalBan = function(sid, nick, pl)
	if sid then
		sid = sql.SQLStr(sid)
	end
	
	if nick then
		nick = sql.SQLStr(nick)
		sid = HSWarning.DB.GetSIDFromNick(nick, pl)
		
		checkSID(sid, pl)
		
		sid = sql.SQLStr(sid)
	end
	
	if !sid then
		error("Unknown Error")
	end
	
	local totalban = HSWarning.DB.SQLQuery({"totalban"}, "sid = " .. sid)
	return tonumber(totalban[1].totalban)
end

HSWarning.DB.GetBanEndTime = function(sid, nick, pl)
	if sid then
		sid = sql.SQLStr(sid)
	end
	
	if nick then
		nick = sql.SQLStr(nick)
		sid = HSWarning.DB.GetSIDFromNick(nick)
		
		checkSID(sid, pl)
		
		sid = sql.SQLStr(sid)
	end
	
	if !sid then
		error("Unknown Error")
	end
	
	local banend = HSWarning.DB.SQLQuery({"banend"}, "sid = " .. sid)
	return tonumber(banend[1].banend)
end

HSWarning.DB.LastWarnTime = 0
HSWarning.DB.AddWarn = function(sid, nick, amount, pl)
	if HSWarning.DB.LastWarnTime + 1.5 <= CurTime() then
		if !(pl == NULL or pl:IsAdmin()) then
			return
		end

		if sid then
			sid = sql.SQLStr(sid)
		end
		
		if nick then
			nick = sql.SQLStr(nick)
			sid = HSWarning.DB.GetSIDFromNick(nick)
			
			checkSID(sid, pl)
			
			sid = sql.SQLStr(sid)
		end
		
		if !sid then
			error("Unknown Error")
		end
		
		local ostime = os.time()
		
		HSWarning.DB.SQLUpdate({"warns", "lastwarn", "totalwarn"}, {HSWarning.DB.GetWarns(sid, nil, pl) + amount, sql.SQLStr(tostring(ostime)), HSWarning.DB.GetTotalWarn(sid, nil, pl) + amount}, "sid = " .. sid)
		
		if HSWarning.DB.GetWarns(sid) >= HSWarning.DB.WarnThreshold then
			local totalwarn = HSWarning.DB.GetTotalWarn(sid)
			
			if (totalwarn <= 10) then
				HSWarning.DB.SetBan(sid, nil, 86400, pl)
			else 
				local add = (totalwarn - 10) * 6 * 60 * 60
				HSWarning.DB.SetBan(sid, nil, 86400 + add, pl)
			end
		end
		
		nick = HSWarning.DB.GetNickFromSID(sid)
		HSLog.a((IsValid(pl) and pl:IsPlayer() and pl:IsAdmin() and pl:Nick() .. "님께서 " or "") .. nick .. "님께 경고 " .. tostring(amount) .. "회를 부여하여")
		HSLog.a(nick .. "님의 경고 횟수가 " .. tostring(HSWarning.DB.GetWarns(sid)) .. "회가 되었습니다.")
		HSWarning.DB.LastWarnTime = CurTime()
	else
		HSLog.a("다음 경고까지 " .. tostring((HSWarning.DB.LastWarnTime + 1.5) - CurTime()) .. " 초 기다려야 합니다.")
	end
end

HSWarning.DB.GetWarns = function(sid, nick, pl)
	if sid then
		sid = sql.SQLStr(sid)
	end
	
	if nick then
		nick = sql.SQLStr(nick)
		sid = HSWarning.DB.GetSIDFromNick(nick)
		
		checkSID(sid, pl)
		
		sid = sql.SQLStr(sid)
	end
	
	if !sid then
		error("Unknown Error")
	end
	
	local warns = HSWarning.DB.SQLQuery({"warns"}, "sid = " .. sid)
	return tonumber(warns[1].warns)
end

HSWarning.DB.GetLastWarn = function(sid, nick)
	if sid then
		sid = sql.SQLStr(sid)
	end
	
	if nick then
		nick = sql.SQLStr(nick)
		sid = HSWarning.DB.GetSIDFromNick(nick)
		
		checkSID(sid, pl)
		
		sid = sql.SQLStr(sid)
	end
	
	if !sid then
		error("Unknown Error")
	end
	
	local lastwarn = HSWarning.DB.SQLQuery({"lastwarn"}, "sid = " .. sid)
	return tonumber(lastwarn[1].lastwarn)
end

HSWarning.DB.GetTotalWarn = function(sid, nick)
	if sid then
		sid = sql.SQLStr(sid)
	end
	
	if nick then
		nick = sql.SQLStr(nick)
		sid = HSWarning.DB.GetSIDFromNick(nick)
		
		checkSID(sid, pl)
		
		sid = sql.SQLStr(sid)
	end
	
	if !sid then
		error("Unknown Error")
	end

	local totalwarn = HSWarning.DB.SQLQuery({"totalwarn"}, "sid = " .. sid)
	return tonumber(totalwarn[1].totalwarn)
end

/*
	RETURN:
		STRING: nick
		FALSE: NO MATCHED DATA
*/
HSWarning.DB.GetNickFromSID = function(sid)
	sid = sql.SQLStr(sid)
	
	local nick = HSWarning.DB.SQLQuery({"nick"}, "sid = " .. sid)
	if istable(nick) then
		return nick[1].nick
	else
		return false
	end
end

/*
	RETURN:
		-1: UNKNOWN ERROR
		0: NOT FOUND
		STRING: SID
		TABLE: TABLE OF {NICK, SID}
*/
HSWarning.DB.GetSIDFromNick = function(nick)
	nick = sql.SQLStr(nick)
	
	nick = string.sub(nick, 2, string.len(nick) - 1)
	
	local players = HSWarning.DB.SQLQuery({"nick", "sid"}, "nick LIKE '%" .. nick .. "%'")
	
	if !players or (!istable(players) and !isstring(players)) or table.Count(players) == 0 then
		return 0
	elseif table.Count(players) == 1 then
		return players[1].sid
	elseif table.Count(players) > 1 then
		local returnTable = {}
		for i, v in pairs(players) do
			table.insert(returnTable, {nick = v.nick, sid = v.sid})
		end
		
		return returnTable
	else
		return -1
	end
end	