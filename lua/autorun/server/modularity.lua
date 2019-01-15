contraption = contraption or {Modules = {}}

local Modules = contraption.Modules

-- Adds or modifies a module to contraption framework
function contraption.AddModule(Name, Connect, Disconnect, Create, Destroy)
	Modules.Connect[Name]    = Connect
	Modules.Disconnect[Name] = Disconnect
	Modules.Create[Name]     = Create
	Modules.Destroy[Name]    = Destroy
end

-- Removes/disables a module
function contraption.RemoveModule(Name)
	Modules.Connect[Name]    = nil
	Modules.Disconnect[Name] = nil
	Modules.Create[Name]     = nil
	Modules.Destroy[Name]    = nil
end

-- Check if a module exists
function contraption.Module(Name)
	if Modules.Connect[Name] then return true end
	if Modules.Disconnect[Name] then return true end
	if Modules.Create[Name] then return true end
	if Modules.Destroy[Name] then return true end

	return false
end

-- Return a table of all modules
function contraption.Modules()
	return Modules
end


for K, V in pairs(file.Find("modules/*", "LUA")) do
	if string.Left(V, 2) ~= "cl" then
		Msg("Mounting " .. V .. " module\n")
		include("modules/" .. V)
	else
		Msg("Sending " .. V .. " module\n")
		AddCSLuaFile("modules/" .. V)
	end
end