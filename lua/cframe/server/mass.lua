hook.Add("OnContraptionCreate", "Mass", function(C) -- Initialize the Mass table when a contraption is created
	C.Mass = {
		Total    = 0,
		Physical = 0,
		Parented = 0
	}
end)

hook.Add("OnContraptionAppend", "Mass", function(C, A) -- Add mass to contraption
	local Phys = A:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = C.Mass
	local Delta = Phys:GetMass()

	Mass.Total = Mass.Total + Delta

	if A.CFW.Physical then
		Mass.Physical = Mass.Physical + Delta
	else
		Mass.Parented = Mass.Parented + Delta
	end
end)

hook.Add("OnContraptionPop", "Mass", function(C, A) -- Subtract mass from contraption
	local Phys = A:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = C.Mass
	local Delta = Phys:GetMass()

	Mass.Total = Mass.Total - Delta

	if A.CFW.Physical then
		Mass.Physical = Mass.Physical - Delta
	else
		Mass.Parented = Mass.Parented - Delta
	end
end)

hook.Add("OnContraptionMerge", "Mass", function(C, Merged) print("Mass merge")
	local CM, MM = C.Mass, Merged.Mass

	CM.Physical = CM.Physical + MM.Physical
	CM.Parented = CM.Parented + MM.Parented
	CM.Total    = CM.Total + MM.Total
end)

hook.Add("OnContraptionSplit", "Mass", function(Old, New)
	local PhysMass, PareMass, Total = 0, 0, 0

	for Ent in pairs(New.Ents) do
		local Phys = Ent:GetPhysicsObject()

		if IsValid(Phys) then
			local Mass = Phys:GetMass()

			Total = Total + Mass

			if Ent.CFW.Physical then
				PhysMass = PhysMass + Mass
			else
				PareMass = PareMass + Mass
			end
		end
	end

	Old.Mass.Total	  = Old.Mass.Total - Total
	Old.Mass.Physical = Old.Mass.Physical - PhysMass
	Old.Mass.Parented = Old.Mass.Parented - PareMass

	New.Mass.Total    = Total
	New.Mass.Parented = PareMass
	New.Mass.Physical = PhysMass
end)

hook.Add("OnContraptionState", "Mass", function(Entity, Physical)
	local Phys = Entity:GetPhysicsObject()

	if not IsValid(Phys) then return end

	local Mass  = Entity.CFW.Contraption.Mass
	local Delta = Phys:GetMass()

	if Physical then
		Mass.Physical = Mass.Physical + Delta
		Mass.Parented = Mass.Parented - Delta
	else
		Mass.Physical = Mass.Physical - Delta
		Mass.Parented = Mass.Parented + Delta
	end
end)

hook.Add("Initialize", "CFrame Mass Module", function() -- Detour SetMass
	local PHYS    = FindMetaTable("PhysObj")
	local setMass = PHYS.SetMass

	function PHYS:SetMass(NewMass, ...)
		local OldMass = self:GetMass()
		local Ent     = self:GetEntity()

		if hook.Run("OnSetMass", Ent, OldMass, NewMass) ~= false then
			if IsValid(self) and Ent.CFW then
				local Mass    = Ent.CFW.Contraption.Mass
				local Delta   = NewMass - OldMass

				local NewTotal = Mass.Total + Delta

				if NewTotal > 0 then -- Sanity checking because spawning dupes does some freaky shit

					Mass.Total = NewTotal

					if Ent.CFW.Physical then
						Mass.Physical = Mass.Physical + Delta
					else
						Mass.Parented = Mass.Parented + Delta
					end
				end
			end

			setMass(self, NewMass, ...)
		end
	end

	hook.Remove("Initialize", "CFrame Mass Module")
end)

do -- Library -----------------------------------
	function Contraption.GetMass(C)
		return C.Mass.Total
	end

	function Contraption.GetPhysicalMass(C)
		return C.Mass.Physical
	end

	function Contraption.GetParentedMass(C)
		return C.Mass.Parented
	end
end