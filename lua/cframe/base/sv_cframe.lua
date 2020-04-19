Contraption = { Contraptions = {}, Count = 0 }

local function FloodFill(Ent, Output) -- Input a table to be used as output
	Output[Ent] = true

	for K in pairs(Ent.CFW.Connections) do
		if IsValid(K) and not Output[K] then
			FloodFill(K, Output)
		end
	end
end

local function Search(Source, Sink)
	local Closed = {}
	local Open   = {}; for K in pairs(Source.CFW.Connections) do Open[K] = true end -- Quick copy

	while next(Open) do
		local Node = next(Open)

		Open[Node] = nil

		if not IsValid(Node) then continue end
		if Node == Sink then return true end -- Found the sink

		Closed[Node] = true

		for K in pairs(Node.CFW.Connections) do
			if not Closed[K] then
				Open[K] = true
			end
		end
	end

	return false, Closed -- Not connected
end

do -- Library -----------------------------------
	do -- Methods
		local ENT = FindMetaTable("Entity")

		function ENT:GetContraption()
			return self.CFW and self.CFW.Contraption or nil
		end
	end

	do
		function Contraption.GetAll()
			return Contraption.Contraptions
		end
	end
end

-- Main -----------------------------------------

local function NewContraption()
	local C = { Count = 0, Ents  = {}, IsContraption = true }

	Contraption.Contraptions[C] = true
	Contraption.Count = Contraption.Count + 1

	hook.Run("OnContraptionCreate", C)
	return C
end

local function DeleteContraption(C)
	Contraption.C     = nil
	Contraption.Count = Contraption.Count - 1

	hook.Run("OnContraptionDelete", C)
end

local function Init(A)
	A.CFW = {
		Physical    = true,
		Contraption = false,
		Connections = {},
	}

	if A.OnContraptionInit then A:OnContraptionInit() end

	hook.Run("OnContraptionInit", A)
end

local function SetState(A, State)
	if A.CFW.Physical == State then return end -- State didn't change

	A.CFW.Physical = State

	if A.OnContraptionState then A:OnContraptionState(State) end

	hook.Run("OnContraptionState", A, State)
end

local function Append(C, A)
	print("Append", C, A)
	A.CFW.Contraption = C
	C.Ents[A]		  = true
	C.Count   	  	  = C.Count + 1

	if A.OnContraptionAppend then A:OnContraptionAppend(C) end
	hook.Run("OnContraptionAppend", C, A)
end

local function Pop(C, A) print("Pop", C, A)
	C.Ents[A] = nil
	C.Count   = C.Count - 1

	print(C.Count)

	if A.OnContraptionPop then A:OnContraptionPop(C) end
	hook.Run("OnContraptionPop", C, A)

	A.CFW = nil

	if C.Count == 0 then DeleteContraption(C) end -- Delete the contraption if this was the last entity in it

	return
end

local function Merge(A, B)
	hook.Run("OnContraptionMerge", A, B)

	A.Count = A.Count + B.Count

	for Ent in pairs(B.Ents) do
		A.Ents[Ent] = true
		B.Ents[Ent] = nil

		Ent.CFW.Contraption = A

		if Ent.OnContraptionTransfer then Ent:OnContraptionTransfer(A, B) end
	end

	DeleteContraption(B)
end

local function Split(C, Ents)
	local NewC  = NewContraption()
	local Count = 0

	for Ent in pairs(Ents) do
		NewC.Ents[Ent] = true
		C.Ents[Ent]    = nil

		Ent.CFW.Contraption = NewC
		Count = Count + 1

		if Ent.OnContraptionTransfer then Ent:OnContraptionTransfer(NewC, C) end
	end

	C.Count    = C.Count - Count
	NewC.Count = Count

	hook.Run("OnContraptionSplit", C, NewC)
	return NewC
end
--[[
	Results in:
		Append (Adding new entity to a contraption)
		Merge (Combinging two different contraptions)
		Creation and two Appends (Making a new contraption and adding the two ents to it)
	
		Any result may also trigger a physical state change
--]]
local function Connect(A, B, Parent)
	if not A.CFW then Init(A) end
	if not B.CFW then Init(B) end

	local AC, BC     = A.CFW.Contraption, B.CFW.Contraption
	local ACon, BCon = A.CFW.Connections, B.CFW.Connections

	if ACon[B] then -- Already connected to eachother
		SetState(A, true) -- 2+ connections... Must be physical
	elseif Parent then
		if next(ACon) then -- Connected to something already
			SetState(A, false) -- Trigger a state change
		else
			A.CFW.Physical = false -- Not a state change
		end
	end

	if AC and BC then print("Two Contraptions")
		if AC ~= BC then -- Two different contraptions. Merge them
			if AC.Count > BC.Count then
				Merge(AC, BC)
			else
				Merge(BC, AC)
			end
		end
	elseif AC then print("A contraption")

		Append(AC, B)
	elseif BC then print("B contraption")
		Append(BC, A)
	else print("New contraption")
		local C = NewContraption()

		Append(C, A)
		Append(C, B)
	end

	ACon[B] = (ACon[B] or 0) + 1
	BCon[A] = (BCon[A] or 0) + 1

	if A.OnContraptionConnect then A:OnContraptionConnect(B, Parent) end
	hook.Run("OnContraptionConnect", A, B, Parent)
end

--[[ Whenever a connection is removed between two entities
	Resuilts in:
		Split (A new contraption is split off of the original)
		Pop (An entity is removed from a contraption)
		Nothing (Entities are still connected)
--]]
local function Disconnect(A, B, Parent) print("Disconnect")
	if A.OnContraptionDisconnect then A.OnContraptionDisconnect(B, Parent) end
	hook.Run("OnContraptionDisconnect", A, B, Parent)

	local N = A.CFW.Connections[B] - 1

	if N > 0 then
		A.CFW.Connections[B] = N
		B.CFW.Connections[A] = N

		if Parent then -- Was parented, is now physical
			SetState(A, true)
		elseif N == 1 and A:GetParent() then -- A is still parented but all constraints have been removed, making it not physical 
			SetState(A, false)
		end

		return -- Still directly connected
	else -- Not directly connected... Check if indirectly connected
		A.CFW.Connections[B] = nil
		B.CFW.Connections[A] = nil

		-- Check if the two entities are connected to anything at all
		local C = A.CFW.Contraption
		local ShortCircuit

		if not next(A.CFW.Connections) then
			Pop(C, A)
			ShortCircuit = true
		end

		if not next(B.CFW.Connections) then
			Pop(C, B)
			ShortCircuit = true
		end

		if ShortCircuit then return end

		-- At this point: Both entities are not directly connected and are connected to other entities

		--[[ Handle parents with children
			A (the child) is connected to something, but not its former parent.
			This means it must have children. Split children into a new contraption.
		--]]
		if Parent then -- Unparent scenario
			local Subtree = {}; FloodFill(A, Subtree) -- Subtree gets populated by FloodFill

			SetState(A, true) -- A is now physical

			Split(A.CFW.Contraption, Subtree)
		else -- Constraint removed scenario
			-- A cannot be parented during this scenario, so A is already physical

			local Connected, Subtree = Search(A, B)

			if not Connected then
				Split(A.CFW.Contraption, Subtree)
			end
		end
	end
end

do -- Hooks -------------------------------------
	local TimerSimple     = timer.Simple
	local ConstraintTypes = { -- Note: no-collide is missing because no-collide is not a constraint
		phys_lengthconstraint = true, phys_constraint = true, phys_hinge = true, phys_ragdollconstraint = true,
		gmod_winch_controller = true, phys_spring = true, phys_slideconstraint = true, phys_torque = true,
		phys_pulleyconstraint = true, phys_ballsocket = true
	}
	hook.Add("OnEntityCreated", "Contraption Framework", function(Ent)
		if ConstraintTypes[Ent:GetClass()] then
			TimerSimple(0, function()
				if not IsValid(Ent) then return end

				local A, B = Ent.Ent1, Ent.Ent2

				if not IsValid(A) or not IsValid(B) then return end -- Contraptions consist of multiple ents, not one
				if A == B then return end

				Ent.CFWInit = true -- Required to prevent errors when a constraint is created and removed in the same tick
				Connect(A, B)
			end)
		end
	end)

	hook.Add("EntityRemoved", "Contraption Framework", function(Ent)
		if Ent.CFWInit then
			local A, B = Ent.Ent1, Ent.Ent2

			if not IsValid(A) or not IsValid(B) then return end

			Disconnect(A, B)
		end
	end)

	hook.Add("Initialize", "Contraption Framework", function() -- Detouring SetParent
		local ENT = FindMetaTable("Entity")
		local P   = ENT.SetParent

		local ParentFilter = {predicted_viewmodel = true, gmod_hands = true}

		function ENT:SetParent(Parent, Attachment, ...)
			local OldParent = self:GetParent()
			local Bad		= ParentFilter[self:GetClass()]

			if not Bad and IsValid(OldParent) and not ParentFilter[OldParent:GetClass()] then -- Not bad at all...
				Disconnect(self, OldParent, true)
			end

			P(self, Parent, Attachment, ...)

			if not Bad and IsValid(Parent) and not ParentFilter[Parent:GetClass()] then
				Connect(self, Parent, true)
			end
		end

		hook.Remove("Initialize", "Contraption Framework") -- Not wasting memory like a good boy
	end)
end