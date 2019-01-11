contraption = {
	Count = 0,
	Contraptions = {}
}
local Contraptions = contraption.Contraptions


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
	for Entity in pairs(Open) do
		if Entity == Target then return true end

		Count = Count+1
		
		Open[Entity]   = nil
		Closed[Entity] = true
		
		for ConEnt in pairs(Entity.CFramework.Connections) do
			if IsValid(ConEnt) and not Closed[Entity] then Open[Entity] = true end
		end
	end

	if next(Open) then TestConnection(Target, Open, Closed, Count) end

	return false, Closed, Count
end

local function OnConnect(A, B)
	local Ac = A.CFramework.Contraption
	local Bc = B.CFramework.Contraption

	if Ac and Bc then
		if Ac ~= Bc then Merge(Ac, Bc) -- Connecting two existing contraptions
		else
			local AConnect = A.CFramework.Connections
			local BConnect = B.CFramework.Connections

			AConnect[B] = AConnect[B]+1
			BConnect[A] = BConnect[A]+1

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

local function OnDisconnect(A, B)
	-- Proving if A is still connected to the same contraption as B
	local AConnections = A.CFramework.Connections
	local BConnections = B.CFramework.Connections

	if AConnections[B] > 1 then 
		local Num = AConnections[B]-1

		AConnections[B] = Num
		BConnections[A] = Num

		return -- These two entities are still connected, no need for further checking
	else -- These two entities are no longer connected directly
		AConnections[B] = nil
		BConnections[A] = nil

		local Cont = A.CFramework.Contraption
		Pop(Cont, A)
		Pop(Cont, B)
	end


	local Source, Sink
	if #AConnections <= #BConnections then Source, Sink = A, B
	else Source, Sink = B, A end

	-- Flood filling until we find the other entity
	-- If the other entity is not found, the entities collected during the flood fill are made into a new contraption
	print("Test Connection")
	local Connected, Collection, Count = TestConnection(Sink, table.Copy(Source.Connections), {}, 0)

	if not Connected then -- The two entities are no longer connected and we have created two separate contraptions
		print("Not connected")
		local To   = CreateContraption()
		local From = Source.CFramework.Contraption

		if From.Count-Count < Count then
			print("Flood Fill", Count, From.Count-Count)
			Collection = FloodFill(Sink, {})
		end
		
		for Ent in pairs(Collection) do
			Pop(From, Ent)
			Append(To, Ent)
		end
	else print("connected") end
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

hook.Add("OnParent", "CFramework OnParent", function(Child, Parent) if IsValid(Child) then OnConnect(Child, Parent) end end)
hook.Add("OnUnparent", "CFramework UnParent", function(Child, Parent) if IsValid(Child) then OnDisconnect(Child, Parent) end end)
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