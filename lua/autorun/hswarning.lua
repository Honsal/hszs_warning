if SERVER then
	include("hswarning/init.lua")
	AddCSLuaFile("hswarning/cl_init.lua")
	AddCSLuaFile("hswarning/shared.lua")
end

if CLIENT then
	include("hswarning/cl_init.lua")
end