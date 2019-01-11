contraption = {
	Count = 0,
	Contraptions = {}
}
local Contraptions = contraption.Contraptions
local Filter = {predicted_viewmodel = true, gmod_hands = true} -- Parent trigger filters

local function CreateContraption()
	contraption.Count = contraption.Count+1

	local Cont = {
		IsContraption = true,
		Count = 0,
		Entities = {}
	}

	print("    Create Contraption", Cont)
	Contraptions[Cont] = true
	hook.Run("OnContraptionCreated", Cont)
	return Cont
end

local function Pop(Contraption, Entity) print("        Pop", Contraption, Entity)
	Contraption.Entities[Entity] = nil
	Contraption.Count = Contraption.Count-1
		print(Contraption.Count)

	Entity.CFramework.Contraption = nil
	if not Entity.CFramework.Connections then Entity.CFramework = nil end

	hook.Run("OnContraptionPopped", Contraption, Entity)

	if Contraption.Count == 0 then print("    Contraption Removed")
		Contraptions[Contraption] = nil
		contraption.Count = contraption.Count-1

		hook.Run("OnContraptionRemoved", Contraption)
	end
end

local function Append(Contraption, Entity) print("        Append", Contraption, Entity)
	Contraption.Entities[Entity] = true
	Contraption.Count = Contraption.Count+1

	if Entity.CFramework then Entity.CFramework.Contraption = Contraption
	else
		Entity.CFramework = {
			Contraption = Contraption,
			Connections = {}
		}
	end

	hook.Run("OnContraptionAppended", Contraption, Entity)
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

local function OnConnect(A, B) print("OnConnect", A, B)
	local Ac = A.CFramework and A.CFramework.Contraption or nil
	local Bc = B.CFramework and B.CFramework.Contraption or nil

	if Ac and Bc then
		if Ac ~= Bc then Merge(Ac, Bc) -- Connecting two existing contraptions
		else
			local AConnect = A.CFramework.Connections
			local BConnect = B.CFramework.Connections

			AConnect[B] = AConnect[B] and AConnect[B]+1 or 1
			BConnect[A] = BConnect[A] and BConnect[A]+1 or 1

			return
		end
	elseif Ac then Append(Ac, B) -- Only contraption Ac exists, add entity B to it
	elseif Bc then Append(Bc, A) -- Only contraption Bc exists, add entity A to it
	else
		-- Neither entity has a contraption, make a new one and add them to it
		local Cont = CreateContraption()

		Append(Cont, A)
		Append(Cont, B)
	end

	A.CFramework.Connections[B] = 1
	B.CFramework.Connections[A] = 1
end

local function OnDisconnect(A, B) print("OnDisconnect", A, B)
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
		if SS then print("Not connected, short circuit") return end
	end


	local Source, Sink
	if #AConnections <= #BConnections then Source, Sink = A, B
	else Source, Sink = B, A end

	-- Flood filling until we find the other entity
	-- If the other entity is not found, the entities collected during the flood fill are made into a new contraption
	local Connected, Collection, Count = TestConnection(Sink, table.Copy(Source.CFramework.Connections), {[Source] = true}, 0)
	if not Connected then -- The two entities are no longer connected and we have created two separate contraptions
		print("Not connected")
		local To   = CreateContraption()
		local From = Contraption

		if From.Count-Count < Count then
			print("Flood Fill", Count, From.Count-Count)
			Collection = FloodFill(Sink, {})
		end
		
		for Ent in pairs(Collection) do
			Pop(From, Ent)
			Append(To, Ent)
		end
	else
		print("Connected")
	end
end


hook.Add("OnEntityCreated", "CFramework Created", function(Constraint)
	if Constraint:GetClass() == "phys_constraint" then print("On Constraint Created")
		-- We must wait because the Constraint's information is set after the constraint is created
		timer.Simple(0, function()
			if not IsValid(Constraint) then return end
			
			local A, B = Constraint.Ent1, Constraint.Ent2

			-- Contraptions consist of multiple entities not one
			if not IsValid(A) or not IsValid(B) then
				print("Invalid entities")
				return
			end

			OnConnect(A, B)
		end)
	end
end)
hook.Add("EntityRemoved", "CFramework Removed", function(Constraint)
	if Constraint:GetClass() == "phys_constraint" then  print("On Constraint removed")
		local A, B = Constraint.Ent1, Constraint.Ent2

		if not IsValid(A) or not IsValid(B) then return end

		OnDisconnect(A, B)
	end
end)
hook.Add("OnParent", "CFramework OnParent", function(Child, Parent) if IsValid(Child) and not Filter[Child:GetClass()] then OnConnect(Child, Parent) end end)
hook.Add("OnUnparent", "CFramework UnParent", function(Child, Parent) if IsValid(Child) and not Filter[Child:GetClass()] then OnDisconnect(Child, Parent) end end)
hook.Add("Initialize", "CFramework Init", function()
	local Meta = FindMetaTable("Entity")

	Meta.LegacyParent = Meta.SetParent

	function Meta:SetParent(Parent, Attachment)
		local OldParent = self:GetParent()

		if IsValid(OldParent) then hook.Run("OnUnparent", self, OldParent) end
		
		self:LegacyParent(Parent, Attachment)

		if IsValid(Parent)then hook.Run("OnParent", self, Parent) end
	end

	hook.Remove("Initialize", "CFramework Init")
end)