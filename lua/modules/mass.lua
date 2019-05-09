local function OnConnect(Contraption, Entity, Parent) -- Add mass to contraption
	local Phys = Entity:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = Contraption.Mass
	local Delta = Phys:GetMass()

	Mass.Total = Mass.Total + Delta

	if Parent then Mass.Parented = Mass.Parented + Delta
			  else Mass.Physical = Mass.Physical + Delta end
end

local function OnDisconnect(Contraption, Entity, Parent) -- Subtract mass from contraption
	local Phys = Entity:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = Contraption.Mass
	local Delta = Phys:GetMass()

	Mass.Total = Mass.Total - Delta

	if Parent then Mass.Parented = Mass.Parented - Delta
			  else Mass.Physical = Mass.Physical - Delta end
end

local function OnCreate(Contraption) -- Initialize the Mass table
	Contraption.Mass = {
		Total    = 0,
		Physical = 0,
		Parented = 0
	}
end

contraption.AddModule("mass", nil, OnConnect, OnDisconnect, OnCreate, nil)


------------------------------------
-- Tracking mass/physicality changes
------------------------------------
hook.Add("Initialize", "CFrame Mass Module", function()
	local Meta = FindMetaTable("PhysObj")
		Meta.LegacyMass = Meta.SetMass

	function Meta:SetMass(NewMass)
		if self:GetEntity().CFramework then
			local CF    = self:GetEntity().CFramework
			local Mass  = CF.Contraption.Mass
			local Delta = NewMass - self:GetMass()

			local NewTotal = Mass.Total + Delta

			if NewTotal > 0 then -- Sanity checking because spawning dupes does some freaky shit

				Mass.Total = NewTotal

				if CF.IsPhysical then Mass.Physical = Mass.Physical + Delta
								 else Mass.Parented = Mass.Parented + Delta end
			end
		end

		self:LegacyMass(NewMass)
	end
end)

hook.Add("OnPhysicalChange", "CFrame Mass Module", function(Entity, IsPhysical)
	local Phys = Entity:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = Entity.CFramework.Contraption.Mass
	local Delta = Phys:GetMass()

	if IsPhysical then
		Mass.Physical = Mass.Physical + Delta
		Mass.Parented = Mass.Parented - Delta
	else
		Mass.Physical = Mass.Physical - Delta
		Mass.Parented = Mass.Parented + Delta
	end
end)

------------------------------------
------------------- Helper functions
------------------------------------

function contraption.GetMass(Var)
	if Var.IsContraption then -- Is a contraption table
		return Var.Mass.Total
	elseif Var.CFramework then -- Is an entity
		return Var.CFramework.Contraption.Mass.Total
	else -- Isn't a contraption or entity attached to one
		return 0
	end
end

function contraption.GetPhysMass(Var)
	if Var.IsContraption then
		return Var.Mass.Physical
	elseif Var.CFramework then
		return Var.CFramework.Contraption.Mass.Physical
	else
		return 0
	end
end

function contraption.GetParentedMass(Var)
	if Var.IsContraption then
		return Var.Mass.Parented
	elseif Var.CFramework then
		return Var.CFramework.Contraption.Mass.Parented
	else
		return 0
	end
end