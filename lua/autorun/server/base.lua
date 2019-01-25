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
--------------------------------------------------

local Contraptions    = contraption.Contraptions
local Modules         = contraption.Modules
local Filter          = {predicted_viewmodel = true, gmod_hands = true} -- Parent trigger filters
local ConstraintTypes = contraption.ConstraintTypes

--------------------------------------------------

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

local function Pop(Contraption, Entity)
	Contraption.Entities[Entity] = nil
	Contraption.Count = Contraption.Count-1

	Entity.CFramework.Contraption = nil
	if not Entity.CFramework.Connections then Entity.CFramework = nil end

	for _, V in pairs(Modules.Disconnect) do V(Contraption, Entity) end

	if Contraption.Count == 0 then
		Contraptions[Contraption] = nil
		contraption.Count = contraption.Count-1

		for _, V in pairs(Modules.Destroy) do V(Contraption) end
	end
end

local function Append(Contraption, Entity)
	Contraption.Entities[Entity] = true
	Contraption.Count = Contraption.Count+1

	if Entity.CFramework then Entity.CFramework.Contraption = Contraption
	else
		Entity.CFramework = {
			Contraption = Contraption,
			Connections = {}
		}
	end

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

local function FloodFill(Entity, Filter) -- Depth first
	if not IsValid(Entity) then return Filter end

	Filter[Entity] = true

	for Entity in pairs(Entity.CFramework.Connections) do
		if IsValid(Entity) and not Filter[Entity] then FloodFill(A, Filter) end
	end

	return Filter
end

local function TestConnection(Target, Open, Closed, Count) -- Breadth first
	for Ent in pairs(Open) do
		if Ent == Target then return true end

		Count       = Count+1
		Open[Ent]   = nil
		Closed[Ent] = true
		
		for ConEnt in pairs(Ent.CFramework.Connections) do
			if IsValid(ConEnt) and not Closed[ConEnt] then Open[ConEnt] = true end
		end
	end

	if next(Open) and TestConnection(Target, Open, Closed, Count) then return true end

	return false, Closed, Count
end

local function OnConnect(A, B)
	local Ac = A.CFramework and A.CFramework.Contraption or nil
	local Bc = B.CFramework and B.CFramework.Contraption or nil

	if Ac and Bc then
		if Ac ~= Bc then Merge(Ac, Bc) end -- Connecting two existing contraptions, return the resulting contraption
		-- Otherwise they're the same contraption, do nothing
	elseif Ac then
		Append(Ac, B) -- Only contraption Ac exists, add entity B to it
	elseif Bc then
		Append(Bc, A) -- Only contraption Bc exists, add entity A to it
	else
		-- Neither entity has a contraption, make a new one and add them to it
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

local function OnDisconnect(A, B)
	-- Proving if A is still connected to the same contraption as B
	local AConnections = A.CFramework.Connections
	local BConnections = B.CFramework.Connections
	local Contraption  = A.CFramework.Contraption

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
		if SS then return end
	end

	local Source, Sink
	if #AConnections <= #BConnections then Source, Sink = A, B
	else Source, Sink = B, A end

	print("FLOOD FILLING")
	-- Flood filling until we find the other entity
	-- If the other entity is not found, the entities collected during the flood fill are made into a new contraption
	local Connected, Collection, Count = TestConnection(Sink, table.Copy(Source.CFramework.Connections), {[Source] = true}, 0)
	if not Connected then -- The two entities are no longer connected and we have created two separate contraptions
		local To   = CreateContraption()
		local From = Contraption

		if From.Count-Count < Count then
			print("Flood Fill Again", Count, From.Count-Count)
			Collection = FloodFill(Sink, {})
		end
		
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

		if not IsValid(A) or not IsValid(B) then return end -- Probably a KeepUpright or something weird, which we don't care about
		if A == B then return end -- We also don't care about constraints attaching an entity to itself

		OnDisconnect(A, B)
		hook.Run("OnConstraintRemoved", Constraint)
	end
end)

hook.Add("Initialize", "CFramework Init", function()
	local Meta = FindMetaTable("Entity")

	Meta.LegacyParent = Meta.SetParent

	function Meta:SetParent(Parent, Attachment)
		local OldParent = self:GetParent()

		if IsValid(OldParent) and not Filter[OldParent:GetClass()] and not Filter[self:GetClass()] then
			OnDisconnect(self, OldParent)
			hook.Run("OnUnparent", self, OldParent)
		end
		
		self:LegacyParent(Parent, Attachment)

		if IsValid(Parent) and not Filter[Parent:GetClass()] and not Filter[self:GetClass()] then
			OnConnect(self, Parent)
			hook.Run("OnParent", self, Parent)
		end
	end

	hook.Remove("Initialize", "CFramework Init")
end)