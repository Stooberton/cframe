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
		Destroy = {}
	}

-------------------------------------------------- Localization

local Contraptions    = contraption.Contraptions
local Modules         = contraption.Modules
local Filter          = {predicted_viewmodel = true, gmod_hands = true} -- Parent trigger filters
local ConstraintTypes = contraption.ConstraintTypes

-------------------------------------------------- Contraption creation, removal and addition

local function CreateContraption()
	contraption.Count = contraption.Count+1

	local Contraption = {
		IsContraption = true,
		Entities = {
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
	Entity.CFramework = {
		Connections = {},
		IsPhysical = Parent and nil or true
	}
end

local function Pop(Contraption, Entity, Parent)
	if Parent then Contraption.Entities.Parented[Entity] = nil
	else Contraption.Entities.Physical[Entity] = nil end

	Contraption.Entities.Count = Contraption.Entities.Count-1

	for _, V in pairs(Modules.Disconnect) do V(Contraption, Entity, Parent) end

	if Contraption.Entities.Count == 0 then DestroyContraption(Contraption) end

	Entity.CFramework.Contraption = nil
	if not next(Entity.CFramework.Connections) then Entity.CFramework = nil end
end

local function Append(Contraption, Entity, Parent)
	if Parent then Contraption.Entities.Parented[Entity] = true
	else Contraption.Entities.Physical[Entity] = true end

	Contraption.Entities.Count = Contraption.Entities.Count+1

	Entity.CFramework.Contraption = Contraption

	for _, V in pairs(Modules.Connect) do V(Contraption, Entity, Parent) end
end

local function Merge(A, B)
	local Big, Small
		if A.Entities.Count >= B.Entities.Count then Big, Small = A, B
		else Big, Small = B, A end

	for Ent in pairs(Small.Entities.Physical) do
		Pop(Small, Ent)
		Append(Big, Ent)
	end
	
	for Ent in pairs(Small.Entities.Parented) do
		Pop(Small, Ent, true)
		Append(Big, Ent, true)
	end

	return Big
end

-------------------------------------------------- Logic

local function FF(Entity, Filter) -- Depth first
	if not IsValid(Entity) then return Filter end

	Filter[Entity] = true

	for Entity in pairs(Entity.CFramework.Connections) do
		if IsValid(Entity) and not Filter[Entity] then FF(A, Filter) end
	end

	return Filter
end

local function BFS(Start, Goal)
	local Closed = {}
	local Open   = {};	for K in pairs(Start.CFramework.Connections) do Open[K] = true end -- Quick copy
	local Count  = #Open

	while next(Open) do
		local Node = next(Open)

		Open[Node] = nil

		if not IsValid(Node) then continue end
		if Node == Goal then return true end

		Closed[Node] = true
		
		for K in pairs(Node.CFramework.Connections) do
			if not Closed[K] then
				Open[K] = true
				Count = Count+1
			end
		end
	end

	return false, Closed, Count
end

local function SetParented(Entity, Parent)
	Entity.CFramework.IsPhysical = Parent and nil or true

	local Ents = Entity.CFramework.Contraption.Entities

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
	local Ac = A.CFramework and A.CFramework.Contraption or nil
	local Bc = B.CFramework and B.CFramework.Contraption or nil

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

		Initialize(A, IsParent) -- If IsParent, this is NOT a physical change, it's just an 'OnParent'/regular connection
		Initialize(B)

		Append(Contraption, A, IsParent)
		Append(Contraption, B)
	end

	local AConnect = A.CFramework.Connections
	local BConnect = B.CFramework.Connections
	
	AConnect[B] = (AConnect[B] or 0)+1
	BConnect[A] = (BConnect[A] or 0)+1
end

local function OnDisconnect(A, B, IsParent)
	-- Prove whether A is still connected to B or not
	-- If not: A new contraption is created (Assuming A and B are both connected to more than one thing)
	local AFrame = A.CFramework

	local AConnections = AFrame.Connections
	local BConnections = B.CFramework.Connections
	local Contraption  = AFrame.Contraption

	if IsParent then SetParented(A, nil) end -- Entity just became physical since an ent can only have one parent

	if AConnections[B] > 1 then 
		local Num = AConnections[B]-1

		AConnections[B] = Num
		BConnections[A] = Num

		return -- These two entities are still connected, no need for further checking
	else -- These two entities are no longer connected directly
		AConnections[B] = nil
		BConnections[A] = nil

		local SS
			if not next(AConnections) then
				Pop(Contraption, A)
				SS = true
			end

			if not next(BConnections) then
				Pop(Contraption, B)
				SS = true
			end
		if SS then return end -- One or both of the ents has nothing connected


		-- Parented entities with no physical constraint always have only one connection to the contraption
		-- If the thing removed was a parent and A is not physical then the two ents are definitely not connected
		if IsParent and not AFrame.IsPhysical then
			local Collection = FF(A) -- The child probably has less entities connected
			local To         = CreateContraption()
			local From       = Contraption

			for Ent in pairs(Collection) do -- Move all the ents connected to the Child to the new contraption
				Pop(From, Ent)
				Append(To, Ent)
			end

			return -- Short circuit
		end
	end

	
	-- Final test to prove the two entities are no longer connected
	-- Flood filling until we find the other entity
	-- If the other entity is not found, the entities collected during the flood fill are made into a new contraption
	
	local Connected, Collection, Count = BFS(A, B)

	if not Connected then -- The two entities are no longer connected and we have created two separate contraptions
		local To   = CreateContraption()
		local From = Contraption

		if From.Entities.Count - Count < Count then Collection = FF(B, {}) end -- If this side of the split contraption has more entities use the other side instead
		
		for Ent in pairs(Collection) do
			Pop(From, Ent)
			Append(To, Ent)
		end
	end
end

hook.Add("OnEntityCreated", "CFramework Created", function(Constraint)
	if ConstraintTypes[Constraint:GetClass()] then
		-- We must wait because the Constraint's information is set after the constraint is created
		timer.Simple(0, function()
			if not IsValid(Constraint) then return end
			
			local A, B = Constraint.Ent1, Constraint.Ent2

			if not IsValid(A) or not IsValid(B) then return end -- Contraptions consist of multiple entities not one
			if A == B then return end -- We also don't care about constraints attaching an entity to itself, see above

			OnConnect(A, B)
			hook.Run("OnConstraintCreated", Constraint)
		end)
	end
end)

hook.Add("EntityRemoved", "CFramework Removed", function(Constraint)
	if ConstraintTypes[Constraint:GetClass()] then
		local A, B = Constraint.Ent1, Constraint.Ent2

		if not IsValid(A) or not IsValid(B) then return end -- This shouldn't ever run, but just in case
		if A == B then return end -- We don't care about constraints attaching an entity to itself

		OnDisconnect(A, B)
		hook.Run("OnConstraintRemoved", Constraint)
	end
end)

hook.Add("Initialize", "CFramework Init", function() -- We only want to hijack the SetParent function once
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

	hook.Remove("Initialize", "CFramework Init") -- No reason to keep this in memory
end)