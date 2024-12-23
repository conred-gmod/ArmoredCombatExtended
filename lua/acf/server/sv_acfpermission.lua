-- This file defines damage permission with all ACF weaponry


ACF = ACF or {}
ACF.Permissions = {}
local this = ACF.Permissions

--TODO: make player-customizable
this.Selfkill = true

this.Player = {}
this.Modes = {}
this.ModeDescs = {}
this.ModeThinks = {}

--TODO: convar this
local mapDPMDir = "acf/permissions/"
file.CreateDir(mapDPMDir)


local function SaveMapDPM(mode)
	local mapname = string.gsub(game.GetMap(), "[ ^ %a%d-_]", "_")
	file.Write(mapDPMDir .. mapname .. ".txt", mode)
end

local function LoadMapDPM()
	local mapname = string.gsub(game.GetMap(), "[ ^ %a%d-_]", "_")
	return file.Read(mapDPMDir .. mapname .. ".txt", "DATA")
end


concommand.Add( "ACF_SetPermissionMode", function(ply, _, args)
	local validply = IsValid(ply)
	local printmsg = validply and function(hud, msg) ply:PrintMessage(hud, msg) end or msgtoconsole

	if not args[1] then
		local modes = ""
		for k in pairs(this.Modes) do
			modes = modes .. k .. " "
		end
		printmsg(HUD_PRINTCONSOLE,
		" - Set damage permission behaviour mode." ..
		"\n	Available modes: " .. modes)
		return false
	end

	if validply and not ply:IsAdmin() then
		printmsg(HUD_PRINTCONSOLE, "You can't use this because you are not an admin.")
		return false

	else
		local mode = tostring(args[1])
		if not this.Modes[mode] then
			printmsg(HUD_PRINTCONSOLE,
			"Command unsuccessful: " .. mode .. " is not a valid permission mode!" ..
			"\nUse this command without arguments to see all available modes.")
			return false
		end

		local oldmode = table.KeyFromValue(this.Modes, this.DamagePermission)
		this.DamagePermission = this.Modes[mode]

		printmsg(HUD_PRINTCONSOLE, "Command SUCCESSFUL: Current damage permission policy is now " .. mode .. "!")

		hook.Call("ACF_ProtectionModeChanged", GAMEMODE, mode, oldmode)

		return true
	end
end)

concommand.Add( "ACF_SetDefaultPermissionMode", function(ply, _, args)

	local validply = IsValid(ply)
	local printmsg = validply and function(hud, msg) ply:PrintMessage(hud, msg) end or msgtoconsole

	if not args[1] then
		local modes = ""
		for k in pairs(this.Modes) do
			modes = modes .. k .. " "
		end
		printmsg(HUD_PRINTCONSOLE,
		" - Set damage permission behaviour mode." ..
		"\n	Available modes: " .. modes)
		return false
	end

	if validply and not ply:IsAdmin() then
		printmsg(HUD_PRINTCONSOLE, "You can't use this because you are not an admin.")
		return false

	else
		local mode = tostring(args[1])
		if not this.Modes[mode] then
			printmsg(HUD_PRINTCONSOLE,
			"Command unsuccessful: " .. mode .. " is not a valid permission mode!" ..
			"\nUse this command without arguments to see all available modes.")
			return false
		end

		if this.DefaultPermission == mode then return false end

		SaveMapDPM(mode)
		this.DefaultPermission = mode

		printmsg(HUD_PRINTCONSOLE, "Command SUCCESSFUL: Default permission mode for " .. game.GetMap() .. " set to: " .. mode)

		for _, v in pairs(player.GetAll()) do
			if v:IsAdmin() then
				ACE_SendMsg(v, Color(255, 0, 0), "Default permission mode for " .. game.GetMap() .. " has been set to " .. mode .. "!")
			end
		end

		this.ResendPermissionsOnChanged()
		return true
	end
end)


concommand.Add( "ACF_ReloadPermissionModes", function(ply)
	local validply = IsValid(ply)
	local printmsg = validply and function(hud, msg) ply:PrintMessage(hud, msg) end or msgtoconsole

	if validply and not ply:IsAdmin() then
		printmsg(HUD_PRINTCONSOLE, "You can't use this because you are not an admin.")
		return false

	else

		local files = file.Find( "acf/server/permissionmodes/*.lua", "LUA" )
		for _, data in pairs( files ) do
			include( "acf/server/permissionmodes/" .. data )
		end


		local mode = table.KeyFromValue(this.Modes, this.DamagePermission)

		if not mode then
			this.DamagePermission = function() end
			hook.Call("ACF_ProtectionModeChanged", GAMEMODE, "default", nil)
			mode = "default"
		end

		printmsg(HUD_PRINTCONSOLE, "Command SUCCESSFUL: Current damage permission policy is now " .. mode .. "!")
		return true
	end
end)



local function tellPlysAboutDPMode(mode, oldmode)
	if mode == oldmode then return end

	for _, v in pairs(player.GetAll()) do
		ACE_SendMsg(v, Color(255,0,0), "Damage protection has been changed to " .. mode .. " mode!")
	end
end
hook.Add("ACF_ProtectionModeChanged", "ACF_TellPlysAboutDPMode", tellPlysAboutDPMode)


function this.RegisterMode(mode, name, desc, default, think, defaultaction)

	this.Modes[name] = mode
	this.ModeDescs[name] = desc
	this.ModeThinks[name] = think or function() end
	this.DefaultCanDamage = defaultaction or false
	print("[ACE | INFO]- Registered damage permission mode \"" .. name .. "\"!")

	local DPM = LoadMapDPM()

	if DPM ~= nil then
		if DPM == name then
			print("[ACE | INFO]- Found default permission mode: " .. DPM)
			print("[ACE | INFO]- Setting permission mode to: " .. name)
			this.DamagePermission = this.Modes[name]
			this.DefaultPermission = name
		end
	else
		if default then
			print("[ACE | WARNING]- Map does not have default permission set, using default")
			print("[ACE | INFO]- Setting permission mode to: " .. name)
			this.DamagePermission = this.Modes[name]
			this.DefaultPermission = name
		end
	end
end

--function this.CanDamage(Type, Entity, Energy, FrArea, Angle, Inflictor, Bone, Gun)
function this.CanDamage(_, Entity, _, _, _, Inflictor, _, _)

	--Disables protection if either CPPI is unexistent or has been disabled via convar.
	local DP = GetConVar("acf_enable_dp"):GetInt()

	if not CPPI or DP == 0 then return true end
	if Entity.DamageOwner then return true end -- This value is normally used by entities meant to be destroyed by everyone.

	local owner = Entity:CPPIGetOwner() --entity to attack. Gets the attacked entity's owner

	if not (IsValid(owner) and owner:IsPlayer()) then

		if IsValid(Entity) and Entity:IsPlayer() then
			owner = Entity
		else
			if this.DefaultCanDamage then return
			else return this.DefaultCanDamage end
		end
	end

	if not (IsValid(Inflictor) and Inflictor:IsPlayer()) then
		if this.DefaultCanDamage then return
		else return this.DefaultCanDamage end
	end

	return this.DamagePermission(owner, Inflictor, Entity)
end
hook.Add("ACF_BulletDamage", "ACF_DamagePermissionCore", this.CanDamage)

function this.thinkWrapper()

	local curmode	= table.KeyFromValue(this.Modes, this.DamagePermission)
	local think	= this.ModeThinks[curmode]
	local nextthink

	if think then
		nextthink = think()
	end

	timer.Simple(nextthink or 0.01, this.thinkWrapper)
end
timer.Simple(0.01, this.thinkWrapper)

function this.GetDamagePermissions(ownerid)
	if not this.Player[ownerid] then
		this.Player[ownerid] = {[ownerid] = true}
	end

	return this.Player[ownerid]
end

function this.AddDamagePermission(owner, attacker)
	local ownerid = owner:SteamID()
	local attackerid = attacker:SteamID()

	local ownerprefs = this.GetDamagePermissions(ownerid)

	ownerprefs[attackerid] = true
end

function this.RemoveDamagePermission(owner, attacker)
	local ownerid = owner:SteamID()
	if not this.Player[ownerid] then return end

	local attackerid = attacker:SteamID()
	this.Player[ownerid][attackerid] = nil
end

function this.ClearDamagePermissions(owner)
	local ownerid = owner:SteamID()
	if not this.Player[ownerid] then return end

	this.Player[ownerid] = nil
end

function this.PermissionsRaw(ownerid, attackerid, value)
	if not ownerid then return end

	local ownerprefs = this.GetDamagePermissions(ownerid) --PrintTable(ownerprefs)

	if attackerid then
		local old = ownerprefs[attackerid] and true or nil
		local new = value and true or nil
		ownerprefs[attackerid] = new
		return old ~= new
	end

	return false
end

local function onDisconnect( ply )
	plyid = ply:SteamID()

	if this.Player[plyid] then
		this.Player[plyid] = nil
	end
end
hook.Add( "PlayerDisconnected", "ACF_PermissionDisconnect", onDisconnect )

local function plyBySID(steamid)
	for _, v in pairs(player.GetAll()) do
		if v:SteamID() == steamid then
			return v
		end
	end

	return false
end




-- -- -- -- -- Client sync -- -- -- -- --

-- All code below modified from the NADMOD client permissions menu, by Nebual
-- http://www.facepunch.com/showthread.php?t=1221183
util.AddNetworkString("ACF_dmgfriends")
util.AddNetworkString("ACF_refreshfeedback")
net.Receive("ACF_dmgfriends", function(_, ply)
	--Msg("\nsv dmgfriends\n")
	if not ply:IsValid() then return end

	local perms = net.ReadTable()
	local ownerid = ply:SteamID()

	ply.HasDisabledPerms = nil

	local changed
	for k, v in pairs(perms) do
		changed = this.PermissionsRaw(ownerid, k, v)
		--Msg(k, " has ", changed and "changed\n" or "not changed\n")

		if ownerid == k and not v then
			ply.HasDisabledPerms = true
		end

		if changed then
			local targ = plyBySID(k)
			if IsValid(targ) then

				local note = v and "given you" or "removed your"
				local MsgNote = v and "given" or "removed"

				ACE_SendNotification(targ, ply:Nick() .. " has " .. note .. " permission to damage their objects with ACE!")
				print("[ACE | INFO]- The user " .. ply:Nick() .. " has " .. MsgNote .. " permissions to damage objects with ACE " .. (v and "to" or "from") .. " " .. ((targ == ply) and "himself" or targ:Nick()))
			end
		end
	end

	net.Start("ACF_refreshfeedback")
		net.WriteBit(true)
	net.Send(ply)

end)




function this.RefreshPlyDPFriends(ply)
	--Msg("\nsv refreshfriends\n")
	if not ply:IsValid() then return end

	local perms = this.GetDamagePermissions(ply:SteamID())

	net.Start("ACF_refreshfriends")
		net.WriteTable(perms)
	net.Send(ply)
end
util.AddNetworkString("ACF_refreshfriends")
net.Receive("ACF_refreshfriends", function(_, ply) this.RefreshPlyDPFriends(ply) end)




function this.SendPermissionsState(ply)

	local modes = this.ModeDescs
	local current = table.KeyFromValue(this.Modes, this.DamagePermission)

	net.Start("ACF_refreshpermissions")
		net.WriteTable(modes)
		net.WriteString(current or this.DefaultPermission)
		net.WriteString(this.DefaultPermission or "")
	net.Send(ply)
end
util.AddNetworkString("ACF_refreshpermissions")
net.Receive("ACF_refreshpermissions", function(_, ply)
	ACE_SendDPStatus()
	this.SendPermissionsState(ply)
end)




function this.ResendPermissionsOnChanged()
	for _, ply in pairs(player.GetAll()) do
		this.SendPermissionsState(ply)
	end
end
hook.Add("ACF_ProtectionModeChanged", "ACF_ResendPermissionsOnChanged", this.ResendPermissionsOnChanged)




-- -- -- -- -- Initial DP mode load -- -- -- -- --

do

	local files = file.Find( "acf/server/permissionmodes/*.lua", "LUA" )
	for _, data in pairs( files ) do
		include( "acf/server/permissionmodes/" .. data )
	end

	local mode = table.KeyFromValue(this.Modes, this.DamagePermission)

	if not mode then
		this.DamagePermission = function() end
		hook.Call("ACF_ProtectionModeChanged", GAMEMODE, "default", nil)
		mode = "default"
	end

end


