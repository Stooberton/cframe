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

	Entity.Contraption = nil

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

	Entity.Contraption = Contraption

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

local function FloodFill(Entity, Filter, Entities) -- Depth first
	Entities[Entity] = true

	for _, V in pairs(Entity.Constraints) do
		if not Filter[V] then
			Filter[V] = true

			local A = V.Ent1
			local B = V.Ent2
			
			if IsValid(A) then FloodFill(A, Filter, Entities) end
			if IsValid(B) then FloodFill(B, Filter, Entities) end
		end
	end

	return Entities
end

local function TestConnection(Target, Open, Closed, Count) -- Breadth first
	for Entity in pairs(Open) do
		if Entity == Target then return true end

		Count = Count+1
		
		Open[Entity]   = nil
		Closed[Entity] = true
		
		for _, Constraint in pairs(Entity.Constraints) do
			local A = Constraint.Ent1
			local B = Constraint.Ent2

			if IsValid(A) and not Closed[A] then Open[A] = true end
			if IsValid(B) and not Closed[B] then Open[B] = true end
		end
	end

	if next(Open) then TestConnection(Target, Open, Closed, Count) end

	return false, Closed, Count
end

hook.Add("OnEntityCreated", "CFrameCreated", function(Constraint)
	if Constraint:GetClass() == "phys_constraint" then print("On Constraint Created")
		-- We must wait because the Constraint's information is set after the constraint is created
		timer.Simple(0, function()
			if not IsValid(Constraint) then return end
			
			local A = Constraint.Ent1
			local B = Constraint.Ent2

			-- Contraptions consist of multiple entities not one
			if not IsValid(A) or not IsValid(B) then
				print("Invalid entities")
				return
			end

			local Ac = A.Contraption
			local Bc = B.Contraption

			if Ac and Bc then
				if Ac ~= Bc then Merge(Ac, Bc) -- Connecting two existing contraptions, merge the smaller one into the bigger one
				else return end -- Same contraption
			elseif Ac then Append(Ac, B) -- Only contraption Ac exists, add entity B to it
			elseif Bc then Append(Bc, A) -- Only contraption Bc exists, add entity A to it
			else
				-- Neither entity has a contraption, make a new one and add them to it
				local Cont = CreateContraption()

				Append(Cont, A)
				Append(Cont, B)
			end
		end)
	end
end)

hook.Add("EntityRemoved", "CFrameRemoved", function(Constraint)
	if Constraint:GetClass() == "phys_constraint" then  print("On Constraint removed")
		local A = Constraint.Ent1
		local B = Constraint.Ent2

		if not IsValid(A) or not IsValid(B) then return end

		-- From here we will determine if entity A is still connected to entity B by any means
		local Source, Sink
		if #A.Constraints <= #B.Constraints then Source, Sink = A, B
		else Source, Sink = B, A end

		local Open = {}
			for _, V in pairs(Source.Constraints) do
				if V ~= Constraint then
					if IsValid(V.Ent1) then Open[V.Ent1] = true end
					if IsValid(V.Ent2) then Open[V.Ent2] = true end
				end
			end

		if not next(Open) then -- Entity A has no constraints left
			print("        No constraints left on A")
			local Cont  = A.Contraption
			local Count = Cont.Count

			Pop(Cont, A)

			if Count == 2 then
				print("        No constraints left on B")
				Pop(Cont, B)
			end -- If these are the last two entities and A is no longer constrained then B must not be either

			return -- Short circuit, no further proof that the two entities aren't connected is needed
		end

		-- From here we will prove whether or not the two entities are still connected to the same contraption
		print("Test Connection")
		local Connected, Collection, Count = TestConnection(Sink, Open, {[Constraint] = true}, 0)

		if not Connected then -- The two entities are no longer connected and we have created two separate contraptions
			print("Not connected")
			local To   = CreateContraption()
			local From = Source.Contraption

			if Source.Contraption.Count-Count < Count then
				print("Flood Fill", Count, Source.Contraption.Count-Count)
				Collection = FloodFill(Sink, {[Constraint] = true}, {})
			end

			for Ent in pairs(Collection) do
				Pop(From, Ent)
				Append(To, Ent)
			end
		else print("connected") end
	end
end)

hook.Add("OnParent", "CFrame OnParent", function(Child, Parent) print("OnParent")
	
end)

hook.Add("OnUnparent", "CFrame UnParent", function(Child, Parent) print("OnUnparent")

end)

hook.Add("Initialize", "CFrame Init", function()
	local Meta = FindMetaTable("Entity")
	
	Meta.LegacyParent = Meta.SetParent

	function Meta:SetParent(Parent, Attachment)
		local OldParent = self:GetParent()

		self:LegacyParent(Parent, Attachment)

		if IsValid(OldParent) then hook.Run("OnUnParent", self, OldParent) end

		hook.Run("OnParent", self, Parent)
	end

	hook.Remove("Initialize", "CFrame Init")
end)