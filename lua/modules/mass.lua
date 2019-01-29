local function OnConnect(Contraption, Entity) -- Add mass to contraption
	local Mass  = Contraption.Mass
	local Delta = IsValid(Entity:GetPhysicsObject()) and Entity:GetPhysicsObject():GetMass() or 0

	Mass.Total = Mass.Total + Delta

	if Entity.CFramework.IsPhysical then Mass.Physical = Mass.Physical + Delta
									else Mass.Parented = Mass.Parented + Delta end
end

local function OnDisconnect(Contraption, Entity) -- Subtract mass from contraption
	local Mass  = Contraption.Mass
	local Delta = IsValid(Entity:GetPhysicsObject()) and Entity:GetPhysicsObject():GetMass() or 0

	Mass.Total = Mass.Total - Delta

	if Entity.CFramework.IsPhysical then Mass.Physical = Mass.Physical - Delta
									else Mass.Parented = Mass.Parented - Delta end
end

local function OnCreate(Contraption) -- Initialize the Mass table
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
		if self:GetEntity().CFramework then
			local CF    = self:GetEntity().CFramework
			local Mass  = CF.Contraption.Mass
			local Delta = NewMass - self:GetMass()
			
			local NewTotal = Mass.Total + Delta

			if NewTotal <= 0 then return end -- Sanity checking because spawning dupes does some freaky shit

			Mass.Total = NewTotal

			if CF.IsPhysical then Mass.Physical = Mass.Physical + Delta
							 else Mass.Parented = Mass.Parented + Delta end
		end

		self:LegacyMass(NewMass)
	end
end)

hook.Add("OnPhysicalChange", "CFrame Mass Module", function(Entity, IsPhysical)
	local Mass  = self:GetEntity().CFramework.Contraption.Mass
	local Delta = self:GetMass()

	if IsPhysical then
		Mass.Physical = Mass.Physical + Delta
		Mass.Parented = Mass.Parented - Delta
	else
		Mass.Physical = Mass.Physical - Delta
		Mass.Parented = Mass.Parented + Delta
	end
end)