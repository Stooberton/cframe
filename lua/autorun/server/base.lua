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
		Count = 0,
		Entities = {}
	}

	Contraptions[Contraption] = true

	for _, V in pairs(Modules.Create) do V(Contraption) end

	return Contraption
end

local function Initialize(Entity) Entity.CFramework = { Connections = {} } end

local function Pop(Contraption, Entity)
	Contraption.Entities[Entity] = nil
	Contraption.Count = Contraption.Count-1

	for _, V in pairs(Modules.Disconnect) do V(Contraption, Entity) end

	if Contraption.Count == 0 then
		Contraptions[Contraption] = nil
		contraption.Count = contraption.Count-1

		for _, V in pairs(Modules.Destroy) do V(Contraption) end
	end

	Entity.CFramework.Contraption = nil
	if not next(Entity.CFramework.Connections) then Entity.CFramework = nil end
end

local function Append(Contraption, Entity)
	Contraption.Entities[Entity] = true
	Contraption.Count = Contraption.Count+1

	Entity.CFramework.Contraption = Contraption

	for _, V in pairs(Modules.Connect) do V(Contraption, Entity) end
end

local function Merge(A, B) print("        Merge")
	if A.Count >= B.Count then
		for Ent in pairs(B.Entities) do
			Pop(B, Ent)
			Append(A, Ent)
		end

		return A
	else
		for Ent in pairs(A.Entities) do
			Pop(A, Ent)
			Append(B, Ent)
		end

		return B
	end
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

local function OnConnect(A, B, IsParent)
	local Ac = A.CFramework and A.CFramework.Contraption or nil
	local Bc = B.CFramework and B.CFramework.Contraption or nil

	if Ac and Bc then
		if IsParent then -- 'A' just became non-physical
			A.CFramework.IsPhysical = nil
			hook.Run("OnPhysicalChange", A)
		end

		if Ac ~= Bc then Merge(Ac, Bc) end -- Connecting two existing contraptions, return the resulting contraption
		-- Otherwise they're the same contraption, do nothing
	elseif Ac then
		Initialize(B)
		
		B.CFramework.IsPhysical = true -- B does not have a contraption, it will always be physical at this point

		if IsParent then -- 'A' just became non-physical
			A.CFramework.IsPhysical = nil
			hook.Run("OnPhysicalChange", A)
		else
			A.CFramework.IsPhysical = true
		end

		Append(Ac, B) -- Only contraption Ac exists, add entity B to it
	elseif Bc
		Initialize(A)

		-- If IsParent, this is NOT a physical change, it's just an 'OnParent'/regular connection
		if not IsParent then A.CFramework.IsPhysical = true end

		Append(Bc, A) -- Only contraption Bc exists, add entity A to it
	else
		Initialize(A)
		Initialize(B)

		-- Neither entity has a contraption, make a new one and add them to it
		-- If IsParent, this is NOT a physical change, it's just an 'OnParent'/regular connection
		if not IsParent then A.CFramework.IsPhysical = true end
		B.CFramework.IsPhysical = true

		local Contraption = CreateContraption()
		Append(Contraption, A)
		Append(Contraption, B)
	end

	local AConnect = A.CFramework.Connections
	local BConnect = B.CFramework.Connections
	
	if AConnect[B] then AConnect[B] = AConnect[B]+1
				   else AConnect[B] = 1 end

	if BConnect[A] then BConnect[A] = BConnect[A]+1
				   else BConnect[A] = 1 end
end

local function OnDisconnect(A, B, IsParent)
	-- Prove whether A is still connected to B or not
	-- If not: A new contraption is created (Assuming A and B are both connected to more than one thing)
	local AFrame = A.CFramework
	local BFrame = B.CFramework
	local AConnections = AFrame.Connections
	local BConnections = BFrame.Connections
	local Contraption  = AFrame.Contraption

	if IsParent then -- Entity just became physical since an ent can only have one parent
		AFrame.IsPhysical = true
		hook.Run("OnPhysicalChange", A, true)
	end 

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

		if From.Count - Count < Count then Collection = FF(B, {}) end -- If this side of the split contraption has more entities use the other side instead
		
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