
--[[
	Files are sent to client/server/shared realm as determined by folder name (server, client, shared)
	realm destination inherits through sub-folders
	Files are sent by one of the following prefixes if not in a realm-specific folder:
		sv_: server
		cl_: client
		sh_: shared (default if no prefix)
		sk_: skipped/ignored (client only)

	----------------------------------------------------------------------
	--	IMPORTANT NOTE: file.Find returns files in ALPHABETICAL ORDER	--
	--		All FOLDERS and FILES are loaded in ALPHABETICAL ORDER		--
	----------------------------------------------------------------------
]]--
MsgN("===========[ Loading Contraption Framework ]============\n|")

if SERVER then
	local Realms = {client = "client", server = "server", shared = "shared"}
	local function Load(Path, Realm)
		local Files, Directories = file.Find(Path .. "/*", "LUA")

		if Realm then -- If a directory specifies which realm then load in that realm and persist through sub-directories
			for _, File in ipairs(Files) do
				File = Path .. "/" .. File

				if Realm == "client" then
					MsgN("| cl/" .. File)
					AddCSLuaFile(File)
				elseif Realm == "server" then
					MsgN("| sv/" .. File)
					include(File)
				else -- Shared
					MsgN("| sh/" .. File)
					include(File)
					AddCSLuaFile(File)
				end
			end
		else
			for _, File in ipairs(Files) do
				local Sub = string.sub(File, 1, 3)

				File = Path .. "/" .. File

				if Sub == "cl_" then
					MsgN("| cl/" .. File)
					AddCSLuaFile(File)
				elseif Sub == "sv_" then
					MsgN("| sv/" .. File)
					include(File)
				else -- Shared
					MsgN("| sh/" .. File)
					include(File)
					AddCSLuaFile(File)
				end
			end
		end

		for _, Directory in ipairs(Directories) do
			local Sub = string.sub(Directory, 1, 6)

			Realm = Realms[Sub] or Realm or nil

			Load(Path .. "/" .. Directory, Realm)
		end
	end

	Load("cframe")
	Load = nil

elseif CLIENT then
	local function Load(Path)
		local Files, Directories = file.Find(Path .. "/*", "LUA")

		for _, File in ipairs(Files) do
			local Sub = string.sub(File, 1, 3)

			if Sub == "sk_" then continue end

			File = Path .. "/" .. File
			MsgN("| cl/" .. File)
			include(File)
		end

		for _, Directory in ipairs(Directories) do Load(Path .. "/" .. Directory) end
	end

	Load("cframe")
	Load = nil
end

MsgN("|\n=======[ Finished loading Contraption Framework ]=======")