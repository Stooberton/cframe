hook.Add("CFrame Create", "Mass", function(Contraption) -- Initialize the Mass table when a contraption is created
	Contraption.Mass = {
		Total    = 0,
		Physical = 0,
		Parented = 0
	}
end)

hook.Add("CFrame Connect", "Mass", function(Contraption, Entity, Parent) -- Add mass to contraption
	local Phys = Entity:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = Contraption.Mass
	local Delta = Phys:GetMass()

	Mass.Total = Mass.Total + Delta

	if Parent then Mass.Parented = Mass.Parented + Delta
			  else Mass.Physical = Mass.Physical + Delta end
end)

hook.Add("CFrame Disconnect", "Mass", function(Contraption, Entity, Parent) -- Subtract mass from contraption
	local Phys = Entity:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = Contraption.Mass
	local Delta = Phys:GetMass()

	Mass.Total = Mass.Total - Delta

	if Parent then Mass.Parented = Mass.Parented - Delta
			  else Mass.Physical = Mass.Physical - Delta end
end)

------------------------------------
-- Tracking mass/physicality changes
------------------------------------
hook.Add("Initialize", "CFrame Mass Module", function()
	local Meta = FindMetaTable("PhysObj")
		Meta.LegacyMass = Meta.SetMass

	function Meta:SetMass(NewMass)
		if IsValid(self) then
			local CF = cframe.Get(self:GetEntity())

			if CF then
				local Mass  = CF.Mass
				local Delta = NewMass - self:GetMass()

				local NewTotal = Mass.Total + Delta

				if NewTotal > 0 then -- Sanity checking because spawning dupes does some freaky shit

					Mass.Total = NewTotal

					if CF.IsPhysical then Mass.Physical = Mass.Physical + Delta
									 else Mass.Parented = Mass.Parented + Delta end
				end
			end
		end

		self:LegacyMass(NewMass)
	end

	hook.Remove("Initialize", "CFrame Mass Module")
end)

hook.Add("CFrame PhysChange", "CFrame Mass Module", function(Entity, IsPhysical)
	local Phys = Entity:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = Entity.CFWRK.Contraption.Mass
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

function cframe.GetMass(Var)
	if not Var then return 0 end

	if Var.IsContraption then -- Is a contraption table
		return Var.Mass.Total
	elseif Var.CFWRK then -- Is an entity
		return Var.CFWRK.Contraption.Mass.Total
	else -- Isn't a contraption or entity attached to one
		return 0
	end
end

function cframe.GetPhysMass(Var)
	if not Var then return 0 end

	if Var.IsContraption then
		return Var.Mass.Physical
	elseif Var.CFWRK then
		return Var.CFWRK.Contraption.Mass.Physical
	else
		return 0
	end
end

function cframe.GetParentedMass(Var)
	if not Var then return 0 end

	if Var.IsContraption then
		return Var.Mass.Parented
	elseif Var.CFWRK then
		return Var.CFWRK.Contraption.Mass.Parented
	else
		return 0
	end
end