E2Lib.RegisterExtension("contraption", true, "Enables interaction with Contraption Framework")

--=====================================================================================--
registerType("contraption", "xcr", nil,
	nil,
	nil,
	function(retval)
		if retval == nil then return end
		if not istable(retval) then error("Return value is neither nil nor a table, but a "..type(retval).."!",0) end
	end,
	function(v)
		return not istable(v)
	end
)

-- = operator
registerOperator("ass", "xcr", "xcr", function(self, args)
	local lhs, op2, scope = args[2], args[3], args[4]
	local      rhs = op2[1](self, op2)

	self.Scopes[scope][lhs] = rhs
	self.Scopes[scope].vclk[lhs] = true
	return rhs
end)

local function IsValidContraption(Cont)
	if Cont and cframe.Contraptions[Cont] then
		return true
	else
		return false
	end
end

e2function number operator_is(contraption cont)
	return IsValidContraption(cont) and 1 or 0
end

e2function number operator==(contraption c1, contraption c2)
	return c1 == c2 and 1 or 0
end

e2function number operator!=(contraption c1, contraption c2)
	return c1 ~= c2 and 1 or 0
end

--=====================================================================================--

__e2setcost(5)

e2function number contraption:isValid()
	return IsValidContraption(this) and 1 or 0
end

-- Return an entity's contraption
e2function contraption entity:contraption()
	if not IsValid(this) then return nil end

	return cframe.Get(this)
end

-- Return the E2s own contraption
e2function contraption contraption()
	return cframe.Get(self.entity)
end

-- Return an array of all contraptions
e2function array contraptions()
	local Arr = {}

	for K in pairs(cframe.Contraptions) do Arr[#Arr + 1] = K end

	return Arr
end

e2function number contraption:contains(entity Ent)
	if not IsValidContraption(this) then return 0 end
	if not IsValid(Ent) then return 0 end

	if this.Ents.Physical[Ent] then return 1 end
	if this.Ents.Parented[Ent] then return 1 end

	return 0
end
-- Return an array of all entities in a contraption
e2function array contraption:entities()
	if not IsValidContraption(this) then return {} end

	local Ents  = this.Ents
	local Arr   = {}
	local Count = 0

	for K in pairs(Ents.Physical) do
		Count = Count + 1
		Arr[Count] = K
	end

	if next(Ents.Parented) then
		for K in pairs(Ents.Physical) do
			Count = Count + 1
			Arr[Count] = K
		end
	end

	return Arr
end

-- Return an array of all physical entities in a contraption
e2function array contraption:physicalEntities()
	if not IsValidContraption(this) then return {} end

	local Ents  = this.Ents
	local Arr   = {}
	local Count = 0

	for K in pairs(Ents.Physical) do
		Count = Count + 1
		Arr[Count] = K
	end

	return Arr
end

-- Return an array of all parented entities in a contraption
e2function array contraption:parentedEntities()
	if not IsValidContraption(this) then return {} end
	if not next(Ents.Parented) then return {} end

	local Ents  = this.Ents
	local Arr   = {}
	local Count = 0

	for K in pairs(Ents.Parented) do
		Count = Count + 1
		Arr[Count] = K
	end

	return Arr
end

-- Return the number of entities that make up this contraption
e2function number contraption:count()
	if not IsValidContraption(this) then return 0 end

	return this.Ents.Count
end

e2function number contraption:getMass()
	if not IsValidContraption(this) then return 0 end

	return cframe.GetMass(this)
end

e2function number contraption:getPhysicalMass()
	if not IsValidContraption(this) then return 0 end

	return cframe.GetPhysMass(this)
end

e2function number contraption:getParentedMass()
	if not IsValidContraption(this) then return 0 end

	return cframe.GetParentedMass(this)
end