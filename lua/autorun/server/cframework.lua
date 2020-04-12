Contraption = {
	Contraptions = {},
	Count = 0
}

local Callbacks   = { Append = {}, Pop = {}, Init = {}, State = {} }
local TimerSimple = timer.Simple

do -- Library -----------------------------------
	do -- Methods
		local ENT = FindMetaTable("Entity")

		function ENT:GetContraption()
			return self.Contraption
		end

		function ENT:AddContraptionCallback(Callback)
			if Callbacks[Callback] then Callback[Callback][self] = true
			else error("AddContraptionCallback: Invalid callback name") end
		end

		function ENT:RemoveContraptionCallback(Callback)
			if Callbacks[Callback][self] then
				Callbacks[Callback][self] = nil

				return true
			end

			return false
		end

		function ENT:GetContraptionCallbacks()
			local Out = {}

			for Callback, Table in pairs(Callbacks) do
				if Table[self] then
					Out[Callback] = true
				end
			end

			return Out
		end
	end

	do
		function Contraption.GetAll()
			return Contraption.Contraptions
		end
	end
end

local function FloodFill(Ent, Output) -- Input a table to be used as output
	Output[Ent] = true

	for K in pairs(Ent.Connections) do
		if IsValid(K) and not Output[K] then
			FloodFill(K, Output)
		end
	end
end

--[[ Search if entity Source is connected indirectly to entity Sink
	Breadth-first search in the assumption that most contraptions are made primarily of
	small loops and not long chains

	Returns true if connected
	False, a new contraption, and the number in the contraption
--]]
local function Search(Source, Sink)
	local Closed = {}
	local Open   = {}; for K in pairs(Source.Connections) do Open[K] = true end -- Quick copy

	while next(Open) do
		local Node = next(Open)

		Open[Node] = nil

		if not IsValid(Node) then continue end
		if Node == Sink then return true end -- Found the sink

		Closed[Node] = true

		for K in pairs(Node.Connections) do
			if not Closed[K] then
				Open[K] = true
			end
		end
	end

	return false, Closed -- Not connected
end

--

local function NewContraption()
	local C = { Count = 0, Ents  = {} }
		setmetatable(C, Meta)

	Contraption.Contraptions[C] = true
	Contraption.Count = Contraption.Count + 1

	print("New Contraption", C)
	return C
end

local function DeleteContraption(C) print("Delete Contraption", C)
	Contraption.C     = nil
	Contraption.Count = Contraption.Count - 1
end

local function Append(C, A, Parent, State) print("Append", C, A, Parent, State)
	A.Contraption = C
	C.Count   	  = C.Count + 1

	if State ~= nil then C.Ents[A] = State
	elseif Parent then C.Ents[A] = false
	else C.Ents[A] = true end

	print("Set state to asd", C.Ents[A])

	if Callbacks.Append[A] then A:OnContraptionAppend(C) end

	hook.Run("OnContraptionAppend", C, A, Parent)
end

local function Pop(C, A, Merging) print("Pop", C, A)
	local State = C.Ents[A]

	A.Contraption = nil
	C.Ents[A] 	  = nil
	C.Count   	  = C.Count - 1

	if not Merging then A.Connections = nil end -- We will clean up after ourselves, unlike gayry
	if Callbacks.Pop[A] then A:OnContraptionPop(C) end

	hook.Run("OnContraptionPop", C, A)

	if C.Count == 0 then DeleteContraption(C) end

	return State
end

local function Merge(A, B) print("Merge", A, B)
	local CA, CB = A.Contraption, B.Contraption

	if CA.Count < CB.Count then -- Merge CA into CB
		for Ent in pairs(CA.Ents) do
			Append(CB, Ent, nil, Pop(CA, Ent, true))
		end
	else -- Merge CB into CA
		for Ent in pairs(CB.Ents) do
			Append(CA, Ent, nil, Pop(CB, Ent, true))
		end
	end
end

local function Init(A) print("Init", A)
	A.Connections = {}

	if Callbacks.Init[A] then A:OnContraptionInit() end

	hook.Run("OnContraptionInit", A)
end

local function SetState(A, State)
	if A.Contraption.Ents[A] == State then return end -- State didn't change

	A.Contraption.Ents[A] = State

	if Callbacks.State[A] then A:OnContraptionState(State) end

	hook.Run("OnContraptionState", A, State)
end

local function Connect(A, B, Parent) print("Connect", A, B, Parent) -- A is the child and B the parent
	if A.Contraption and B.Contraption then print("Both have a contraption")
		if Parent then -- Parent added to an already constrained entity
			SetState(A, false) -- Not physical
		elseif A:GetParent() then -- A is parented and a constraint was added
			SetState(A, true) -- Making it physical
		end

		if A.Contraption ~= B.Contraption then print("Different contraptions") -- Two different contraptions
			Merge(A, B) -- Merge them
		end
	elseif A.Contraption then print("A has a contraption")
		Init(B)

		Append(A.Contraption, B)

		if Parent then -- Parent added to an already constrained entity
			SetState(A, false) -- Not physical
		elseif A:GetParent() then -- A is parented and a constraint was added
			SetState(A, true) -- Making it physical
		end
	elseif B.Contraption then print("B has a contraption")
		Init(A)

		Append(B.Contraption, A, Parent) -- A is added as a parented entity
	else
		local C = NewContraption()

		Init(A)
		Init(B)

		Append(C, A, Parent)
		Append(C, B)
	end

	A.Connections[B] = (A.Connections[B] or 0) + 1
	B.Connections[A] = (B.Connections[A] or 0) + 1
end

local function Disconnect(A, B, Parent) print("Disconnect", A, B, Parent)

	local N = A.Connections[B] - 1

	if N > 0 then
		A.Connections[B] = N
		B.Connections[A] = N

		if Parent then -- Was parented, is now physical
			SetState(A, true)
		elseif N == 1 and A:GetParent() then -- A is still parented but all constraints have been removed, making it not physical 
			SetState(A, false)
		end

		return -- Still directly connected
	else -- Not directly connected... Check if indirectly connected
		A.Connections[B] = nil
		B.Connections[A] = nil

		-- Check if the two entities are connected to anything at all
		local C = A.Contraption
		local ShortCircuit

		if not next(A.Connections) then
			Pop(C, A)
			ShortCircuit = true
		end

		if not next(B.Connections) then
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
			local Subtree = {}; FloodFill(A, Subtree)
			local NewC    = NewContraption()

			for Ent in pairs(Subtree) do -- Move all the children to a new contraption
				Append(NewC, Ent, nil, Pop(C, Ent, true))
			end

			hook.Run("OnContraptionSplit", C, Subtree)

			SetState(A, true) -- A is now physical
		else -- Constraint removed scenario
			-- A cannot be parented during this scenario, so A is already physical

			--[[ Test indirect connectivity
				Breadth-First search to find other entity
				If not connected, the subtree is made into a new contraption
			--]]

			local Connected, Subtree = Search(A, B)

			if not Connected then
				local NewC = NewContraption()

				for Ent in pairs(Subtree) do
					Append(NewC, Ent, nil, Pop(C, Ent, true))
				end
			end
		end
	end
end

do -- Hooks -------------------------------------
	local ConstraintTypes = { -- Note: no-collide is missing because no-collide is not a constraint
		phys_lengthconstraint = true, phys_constraint = true, phys_hinge = true, phys_ragdollconstraint = true,
		gmod_winch_controller = true, phys_spring = true, phys_slideconstraint = true, phys_torque = true,
		phys_pulleyconstraint = true, phys_ballsocket = true
	}
	hook.Add("OnEntityCreated", "Contraption Framework", function(Ent)
		if ConstraintTypes[Ent:GetClass()] then
			TimerSimple(0, function()
				if not IsValid(Ent) then return end

				Ent.CFRAMEINIT = true -- Required check for the EntityRemoved hook to handle ents created and deleted in the same tick

				local A, B = Ent.Ent1, Ent.Ent2

				if not IsValid(A) or not IsValid(B) then return end -- Contraptions consist of multiple ents, not one
				if A == B then return end

				Connect(A, B)
			end)

			hook.Run("OnConstraintCreated", Ent)
		end
	end)

	hook.Add("EntityRemoved", "Contraption Framework", function(Ent)
		if Ent.CFRAMEINIT then
			local A, B = Ent.Ent1, Ent.Ent2

			if not IsValid(A) or not IsValid(B) then return end

			Disconnect(A, B)

			hook.Run("OnConstraintRemoved", Ent)
		end
	end)

	hook.Add("Initialize", "Contraption Framework", function() -- Detouring SetParent
		local ENT = FindMetaTable("Entity")
		local P   = ENT.SetParent

		local ParentFilter = {predicted_viewmodel = true, gmod_hands = true}

		function ENT:SetParent(Parent, Attachment, ...) print("SetParent")
			local OldParent = self:GetParent()
			local Bad		= ParentFilter[self:GetClass()]


			if not Bad and IsValid(OldParent) and not ParentFilter[OldParent:GetClass()] then -- Not bad at all...
				print("Parent disconnect")
				Disconnect(self, OldParent, true)

				hook.Run("OnUnparent", self, OldParent)
			end

			P(self, Parent, Attachment, ...)

			if not Bad and IsValid(Parent) and not ParentFilter[Parent:GetClass()] then print("OnParent")
				print("Parent connect")
				Connect(self, Parent, true)

				hook.Run("OnParent", self, Parent)
			end
		end

		hook.Remove("Initialize", "Contraption Framework") -- Not wasting memory like a good boy
	end)
end