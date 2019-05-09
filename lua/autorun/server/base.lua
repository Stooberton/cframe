contraption = contraption or {}
	contraption.Count = 0
	contraption.Contraptions = {}
	contraption.ConstraintTypes = {
		phys_lengthconstraint = true,
		phys_constraint = true,
		phys_hinge = true,
		phys_ragdollconstraint = true,
		gmod_winch_controller = true,
		phys_spring = true,
		phys_slideconstraint = true,
		phys_torque = true,
		phys_pulleyconstraint = true,
		phys_ballsocket = true
	}
	contraption.Modules = contraption.Modules or {
		Connect = {},
		Disconnect = {},
		Create = {},
		Destroy = {},
		Initialize = {}
	}

-------------------------------------------------- Localization

local Contraptions    = contraption.Contraptions
local Modules         = contraption.Modules
local Filter          = {predicted_viewmodel = true, gmod_hands = true} -- Parent trigger filters
local ConstraintTypes = contraption.ConstraintTypes

-------------------------------------------------- Contraption Lib
do
	function contraption.GetAll() -- Return a table of all contraptions
		return Contraptions
	end

	function contraption.Get(Entity) -- Return an entity's contraption
		return Entity.CFrame and Entity.CFrame.Contraption or nil
	end

	function contraption.ConstraintTypes() -- Return a table of the constraint types cframe is monitoring
		local Tab = {}; for K in pairs(contraption.ConstraintTypes) do Tab[K] = true end
		return Tab
	end

	function contraption.AddConstraint(Name) -- Add a constraint to be monitored by cframe
		ConstraintTypes[Name] = true
	end

	function contraption.RemoveConstraint(Name)
		ConstraintTypes[Name] = nil
	end

	function contraption.AddModule(Name, Init, Connect, Disconnect, Create, Destroy) -- Adds or modifies a module to cframe
		Modules.Initialize[Name] = Init
		Modules.Connect[Name]    = Connect
		Modules.Disconnect[Name] = Disconnect
		Modules.Create[Name]     = Create
		Modules.Destroy[Name]    = Destroy
	end

	function contraption.RemoveModule(Name) -- Removes/disables a module
		Modules.Initialize[Name] = nil
		Modules.Connect[Name]    = nil
		Modules.Disconnect[Name] = nil
		Modules.Create[Name]     = nil
		Modules.Destroy[Name]    = nil
	end

	function contraption.Module(Name) -- Check if a module exists
		if Modules.Initialize[Name] then return true end
		if Modules.Connect[Name] then return true end
		if Modules.Disconnect[Name] then return true end
		if Modules.Create[Name] then return true end
		if Modules.Destroy[Name] then return true end

		return false
	end
end
-------------------------------------------------- Contraption creation, removal and addition

local function CreateContraption()
	contraption.Count = contraption.Count+1

	local Contraption = {
		IsContraption = true,
		Ents = {
			Count = 0,
			Physical = {},
			Parented = {}
		}
	}

	Contraptions[Contraption] = true

	for _, V in pairs(Modules.Create) do V(Contraption) end

	return Contraption
end

local function DestroyContraption(Contraption)
	Contraptions[Contraption] = nil

	for _, V in pairs(Modules.Destroy) do V(Contraption) end

	for K in pairs(Contraption) do Contraption[K] = nil end -- Just in case... can't rely on module makers to clean up references to a contraption
end

local function Initialize(Entity, Parent)
	Entity.CFrame = {
		Connections = {},
		IsPhysical = Parent and nil or true
	}

	for _, V in pairs(Modules.Initialize) do V(Entity, Parent) end
end

local function Pop(Contraption, Entity, Parent)
	if Parent then Contraption.Ents.Parented[Entity] = nil
			  else Contraption.Ents.Physical[Entity] = nil end

	Contraption.Ents.Count = Contraption.Ents.Count-1

	for _, V in pairs(Modules.Disconnect) do V(Contraption, Entity, Parent) end

	if Contraption.Ents.Count == 0 then DestroyContraption(Contraption) end

	Entity.CFrame.Contraption = nil
	if not next(Entity.CFrame.Connections) then Entity.CFrame = nil end
end

local function Append(Contraption, Entity, Parent)
	if Parent then Contraption.Ents.Parented[Entity] = true
			  else Contraption.Ents.Physical[Entity] = true end

	Contraption.Ents.Count = Contraption.Ents.Count+1

	Entity.CFrame.Contraption = Contraption

	for _, V in pairs(Modules.Connect) do V(Contraption, Entity, Parent) end
end

local function Merge(A, B)
	local Big, Small

	if A.Ents.Count >= B.Ents.Count then Big, Small = A, B
									else Big, Small = B, A end

	for Ent in pairs(Small.Ents.Physical) do
		Pop(Small, Ent)
		Append(Big, Ent)
	end

	if Contraptions[Small] then -- Entity may have consisted of only physical entities, check if it still exists
		for Ent in pairs(Small.Ents.Parented) do
			Pop(Small, Ent, true)
			Append(Big, Ent, true)
		end
	end

	return Big
end

-------------------------------------------------- Logic

local function FF(Entity, Filter) -- Depth first
	if not IsValid(Entity) then return Filter end

	Filter[Entity] = true

	for Entity in pairs(Entity.CFrame.Connections) do
		if IsValid(Entity) and not Filter[Entity] then FF(A, Filter) end
	end

	return Filter
end

local function BFS(Start, Goal) -- Breadth first
	local Closed = {}
	local Open   = {};	for K in pairs(Start.CFrame.Connections) do Open[K] = true end -- Quick copy
	local Count  = #Open

	while next(Open) do
		local Node = next(Open)

		Open[Node] = nil

		if not IsValid(Node) then continue end
		if Node == Goal then return true end

		Closed[Node] = true

		for K in pairs(Node.CFrame.Connections) do
			if not Closed[K] then
				Open[K] = true
				Count = Count+1
			end
		end
	end

	return false, Closed, Count
end

local function SetParented(Entity, Parent)
	Entity.CFrame.IsPhysical = Parent and nil or true

	local Ents = Entity.CFrame.Contraption.Ents

	if Parent then
		Ents.Parented[Entity] = true
		Ents.Physical[Entity] = nil
	else
		Ents.Parented[Entity] = nil
		Ents.Physical[Entity] = true
	end

	hook.Run("OnPhysicalChange", Entity)
end

local function OnConnect(A, B, IsParent)
	local Ac = A.CFrame and A.CFrame.Contraption or nil
	local Bc = B.CFrame and B.CFrame.Contraption or nil

	if Ac and Bc then
		if IsParent then SetParented(A, true) end -- 'A' just became non-physical

		if Ac ~= Bc then Merge(Ac, Bc) end -- Connecting two existing contraptions, return the resulting contraption
		-- Otherwise they're the same contraption, do nothing
	elseif Ac then
		if IsParent then SetParented(A, true) end-- 'A' just became non-physical

		Initialize(B)
		Append(Ac, B) -- Only contraption Ac exists, add entity B to it
	elseif Bc then
		Initialize(A, IsParent)
		Append(Bc, A, IsParent) -- Only contraption Bc exists, add entity A to it
	else
		-- Neither entity has a contraption, make a new one and add them to it
		local Contraption = CreateContraption()

		Initialize(B)
		Initialize(A, IsParent) -- If IsParent, this is NOT a physical change, it's just an 'OnParent'/regular connection

		Append(Contraption, A, IsParent)
		Append(Contraption, B)
	end

	local AConnect = A.CFrame.Connections
	local BConnect = B.CFrame.Connections

	AConnect[B] = (AConnect[B] or 0)+1
	BConnect[A] = (BConnect[A] or 0)+1
end

local function OnDisconnect(A, B, IsParent)
	-- Prove whether A is still connected to B or not
	-- If not: A new contraption is created (Assuming A and B are both connected to more than one thing)
	local AFrame = A.CFrame

	local AConnections = AFrame.Connections
	local BConnections = B.CFrame.Connections
	local Contraption  = AFrame.Contraption

	if IsParent then SetParented(A, nil) end -- Entity just became physical since an ent can only have one parent

	-- Check if the two entities are directly connected
	if AConnections[B] > 1 then
		local Num = AConnections[B]-1

		AConnections[B] = Num
		BConnections[A] = Num

		return -- These two Ents are still connected, no need for further checking
	end


	AConnections[B] = nil
	BConnections[A] = nil

	-- Check if the two entities are connected to anything at all
	local SC
		if not next(AConnections) then
			Pop(Contraption, A)
			SC = true
		end

		if not next(BConnections) then
			Pop(Contraption, B)
			SC = true
		end
	if SC then return end -- One or both of the ents has nothing connected, no further checking needed


	-- Handle parents with children
	-- Parented Ents with no physical constraint always have only one connection to the contraption
	-- If the thing removed was a parent and A is not physical then the two ents are definitely not connected
	if IsParent and not AFrame.IsPhysical then
		local Collection = FF(A) -- The child probably has less Ents connected
		local To         = CreateContraption()
		local From       = Contraption

		for Ent in pairs(Collection) do -- Move all the ents connected to the Child to the new contraption
			Pop(From, Ent)
			Append(To, Ent)
		end

		return -- Short circuit
	end

	-- Final test to prove the two Ents are no longer connected
	-- Flood filling until we find the other entity
	-- If the other entity is not found, the Ents collected during the flood fill are made into a new contraption
	local Connected, Collection, Count = BFS(A, B)

	if not Connected then -- The two Ents are no longer connected and we have created two separate contraptions
		local To   = CreateContraption()
		local From = Contraption

		if From.Ents.Count - Count < Count then Collection = FF(B, {}) end -- If this side of the split contraption has more Ents use the other side instead

		for Ent in pairs(Collection) do
			Pop(From, Ent)
			Append(To, Ent)
		end
	end
end

-------------------------------------------------- Hooks

hook.Add("OnEntityCreated", "CFrame Created", function(Constraint)
	if ConstraintTypes[Constraint:GetClass()] then
		-- We must wait because the Constraint's information is set after the constraint is created
		-- Setting information when it's created will be removed by SetTable called on the constraint immediately after it's made
		timer.Simple(0, function() print("Timer")
			if not IsValid(Constraint) then return end

			Constraint.Initialized = true -- Required check on EntityRemoved to handle constraints created and deleted in the same tick

			local A, B = Constraint.Ent1, Constraint.Ent2

			if not IsValid(A) or not IsValid(B) then return end -- Contraptions consist of multiple Ents not one
			if A == B then return end -- We also don't care about constraints attaching an entity to itself, see above

			OnConnect(A, B)
			hook.Run("OnConstraintCreated", Constraint)
		end)
	end
end)

hook.Add("EntityRemoved", "CFrame Removed", function(Constraint)
	if Constraint.Initialized then
		local A, B = Constraint.Ent1, Constraint.Ent2

		if not IsValid(A) or not IsValid(B) then return end -- This shouldn't ever run, but just in case
		if A == B then return end -- We don't care about constraints attaching an entity to itself

		OnDisconnect(A, B)
		hook.Run("OnConstraintRemoved", Constraint)
	end
end)

hook.Add("Initialize", "CFrame Init", function() -- We only want to hijack the SetParent function once
	local Meta = FindMetaTable("Entity")

	Meta.LegacyParent = Meta.SetParent

	function Meta:SetParent(Parent, Attachment)
		local OldParent = self:GetParent()

		if IsValid(OldParent) and not Filter[OldParent:GetClass()] and not Filter[self:GetClass()] then -- It's only an 'Unparent' if there was a previous parent
			OnDisconnect(self, OldParent, true)
			hook.Run("OnUnparent", self, OldParent)
		end

		self:LegacyParent(Parent, Attachment)

		if IsValid(Parent) and not Filter[Parent:GetClass()] and not Filter[self:GetClass()] then
			OnConnect(self, Parent, true)
			hook.Run("OnParent", self, Parent)
		end
	end

	hook.Remove("Initialize", "CFrame Init") -- No reason to keep this in memory
end)

-------------------------------------------------- Load Modules

for K, V in pairs(file.Find("modules/*", "LUA")) do
	if string.Left(V, 2) ~= "cl" then
		Msg("Mounting " .. V .. " module\n")
		include("modules/" .. V)
	else
		Msg("Sending " .. V .. " module\n")
		AddCSLuaFile("modules/" .. V)
	end
end