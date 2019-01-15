-- If an entity is parented but has a constraint other than a nocollide/keepupright, it retains physics (has gravity/mass/collisions)
local function IsPhysical(Ent)
	if Ent:GetParent() then
		for _, V in pairs(Ent.Constraints) do
			if V.Type ~= "NoCollide" and V.Type ~= "KeepUpright" then
				return true
			end
		end

		return false
	else
		return true
	end
end

local function OnConnect(Contraption, Entity)
	local Phys  = IsPhysical(Ent)
	local Mass  = Contraption.Mass
	local Delta = IsValid(Entity:GetPhysicsObject()) and Entity:GetPhysicsObject():GetMass() or 0

	Ent.CF.Physical = Phys

	Mass.Total = Mass.Total + Delta

	if Phys then Mass.Physical = Mass.Physical + Delta
	else Mass.Parented = Mass.Parented + Delta end
end

local function OnDisconnect(Contraption, Entity)
	local Phys  = Entity.CF.IsPhysical
	local Mass  = Contraption.Mass
	local Delta = IsValid(Entity:GetPhysicsObject()) and Entity:GetPhysicsObject():GetMass() or 0

	Mass.Total = Mass.Total - Delta

	if Phys then Mass.Physical = Mass.Physical - Delta
	else Mass.Parented = Mass.Parented - Delta end
end

local function OnCreate(Contraption)
	Contraption.Mass = {
		Total    = 0,
		Physical = 0,
		Parented = 0
	}
end

contraption.AddModule("mass", OnConnect, OnDisconnect, OnCreate, nil)


------------------------------------
-- Tracking mass/physicality changes
------------------------------------
hook.Add("Initialize", "CFrame Mass Module", function()
	local Meta = FindMetaTable("PhysObj")
		Meta.LegacyMass = Meta.SetMass

	function Meta:SetMass(NewMass)
		if self:GetEntity().CF then
			local CF    = self:GetEntity().CF
			local Mass  = CF.Contraption.Mass
			local Delta = NewMass - self:GetMass()

			Mass.Total = Mass.Total + Delta

			if CF.IsPhysical then Mass.Physical = Mass.Physical + Delta
			else Mass.Parented = Mass.Parented + Delta end
		end

		self:LegacyMass(NewMass)
	end
end)

hook.Add("OnConstraintCreated", "CFrame Mass Module", function(Constraint) -- Entity may become "Physical"
	local A, B = Constraint.Ent1, Constraint.Ent2

	if not A.CF.IsPhysical and Constraint.Type ~= "NoCollide" and Constraint.Type ~= "KeepUpright" then
		A.CF.IsPhysical = true

		local Mass  = A.CF.Contraption.Mass
		local Delta = IsValid(A:GetPhysicsObject()) and A:GetPhysicsObject():GetMass() or 0
		
		Mass.Physical = Mass.Physical + Delta
		Mass.Parented = Mass.Parented - Delta		
	end

	if not B.CF.IsPhysical and Constraint.Type ~= "NoCollide" and Constraint.Type ~= "KeepUpright" then
		B.CF.IsPhysical = true

		local Mass  = B.CF.Contraption.Mass
		local Delta = IsValid(B:GetPhysicsObject()) and B:GetPhysicsObject():GetMass() or 0
		
		Mass.Physical = Mass.Physical + Delta
		Mass.Parented = Mass.Parented - Delta		
	end
end)

hook.Add("OnConstraintRemoved", "CFrame Mass Module", function(Constraint) -- Entity may become "Parented"
	local A, B = Constraint.Ent1, Constraint.Ent2

	if A.CF and A.CF.IsPhysical and Constraint.Type ~= "NoCollide" and Constraint.Type ~= "KeepUpright" then
		local Phys = IsPhysical(A)

		if not Phys then
			A.CF.IsPhysical = false

			local Mass  = A.CF.Contraption.Mass
			local Delta = IsValid(A:GetPhysicsObject()) and A:GetPhysicsObject():GetMass() or 0
			
			Mass.Physical = Mass.Physical - Delta
			Mass.Parented = Mass.Parented + Delta
		end
	end

	if B.CF and B.CF.IsPhysical and Constraint.Type ~= "NoCollide" and Constraint.Type ~= "KeepUpright" then
		local Phys = IsPhysical(B)

		if not Phys then
			B.CF.IsPhysical = false

			local Mass  = B.CF.Contraption.Mass
			local Delta = IsValid(B:GetPhysicsObject()) and B:GetPhysicsObject():GetMass() or 0
			
			Mass.Physical = Mass.Physical - Delta
			Mass.Parented = Mass.Parented + Delta
		end
	end
end)

hook.Add("OnParent", "CFrame Mass Module", function(Child, Parent) -- Entity may become "Parented"
	if Child.CF.IsPhysical then
		Child.CF.IsPhysical = false

		local Mass  = Child.CF.Contraption.Mass
		local Delta = IsValid(Child:GetPhysicsObject()) and Child:GetPhysicsObject():GetMass() or 0
		
		Mass.Physical = Mass.Physical - Delta
		Mass.Parented = Mass.Parented + Delta
	end
end)

hook.Add("OnUnparent", "CFrame Mass Module", function(Child, Parent) -- Entity may become "Physical"
	if Child.CF then -- If it's still part of a contraption it must be physical as you cannot have more than one parent
		A.CF.IsPhysical = true

		local Mass  = A.CF.Contraption.Mass
		local Delta = IsValid(A:GetPhysicsObject()) and A:GetPhysicsObject():GetMass() or 0
		
		Mass.Physical = Mass.Physical + Delta
		Mass.Parented = Mass.Parented - Delta
	end
end)