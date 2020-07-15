-- Builds "families"
-- Ancestor: root of a parent chain, the physical entity all children are parented to
-- Family: All children (and their children) of an ancestor

do -- Add to the contraption library ------------
	function Contraption.GetParentedEnts(C)
		local Out = {}

		if C.Families then -- If there are any parented ents on this contraption
			for Family in pairs(C.Families) do -- Go through every family
				for E in pairs(Family) do -- and every ent on that family
					if not E.CFW.Physical then -- and if it isnt physical
						Out[E] = true -- Add to our list
					end
				end
			end
		end

		return Out
	end

	function Contraption.GetPhysicalEnts(C)
		local Out = {}

		for Ent in pairs(C.Ents) do -- Go through every entity on a contraption
			if Ent.CFW.Physical then -- and if it's physical
				Out[Ent] = true -- Add to our list
			end
		end
	end
end

hook.Add("OnContraptionConnect", "Families", function(A, B, Parent)
	if not Parent then return end -- Only care about parent actions

	local Ancestor = B:GetAncestor()
	local Family   = A:GetFamily()
	local AncFam   = Ancestor:GetFamily()

	if Family and AncFam then -- Merge
		print("merge families")
		if #Family > #AncFam then
			for Ent in pairs(AncFam) do
				AncFam[Ent] = nil
				Family[Ent] = true

				Ent.CFW.Ancestor = Ancestor
			end

			Family[A] = true

			Ancestor.CFW.Contraption.Families[AncFam] = nil
			Ancestor.CFW.Family = Family
		else
			for Ent in pairs(Family) do
				AncFam[Ent] = true
				Family[Ent] = nil

				Ent.CFW.Ancestor = Ancestor
			end

			AncFam[A] = true

			A.CFW.Contraption.Families[Family] = nil
		end
	elseif Family then -- Transfer
		print("Transfer family")
		for Ent in pairs(Family) do
			Ent.CFW.Ancestor = Ancestor
		end

		Ancestor.CFW.Family = Family
		Family[A]           = true

	elseif AncFam then -- Append
		AncFam[A] = true
	else -- New
		print("New family")
		local F = {[A] = true}

		Ancestor.CFW.Family = F
		Ancestor.CFW.Contraption.Families = Ancestor.CFW.Contraption.Families or {}

		Ancestor.CFW.Contraption.Families[F] = true
	end

	A.CFW.Ancestor = Ancestor
	A.CFW.Family   = nil
end)

hook.Add("OnContraptionDisconnect", "Families", function(A, _, Parent)
	if not Parent then return end -- Only care about parent actions

	local Ancestor = A:GetAncestor()
	local Family   = Ancestor:GetFamily()

	Family[A] = nil -- Remove A from the family

	if next(Family) then -- Still something in the family
		local AncFam   = Ancestor:GetFamily()
		local Children = {}; A:GetAllChildren(Children) -- Outputs to Children

		if next(Children) then -- Transfer A's family and remove from Ancestor's
			print("Inherit")
			Children[A] = nil -- A is not a child (GetAllChildren includes it)

			for Ent in pairs(Children) do -- Remove from Ancestor's family
				AncFam[Ent]      = nil
				Ent.CFW.Ancestor = A
			end

			A.CFW.Family = Children
			A.CFW.Contraption.Families[Children] = true

			if not next(AncFam) then -- Ancestor's family is now empty
				Ancestor.CFW.Contraption.Families[AncFam] = nil
				Ancestor.CFW.Family = nil
			end
		end
	else
		Ancestor.CFW.Family = nil
		Ancestor.CFW.Contraption.Families[Family] = nil
	end
end)

hook.Add("OnContraptionSplit", "Families", function(Old, New) -- Transfer families that have been split off
	if Old.Families then -- If there are any families
		New.Families = New.Families or {}

		for Family in pairs(Old.Families) do -- Go over each one
			if New.Ents[next(Family):GetAncestor()] then -- If the ancestor is in the new contraption
				Old.Families[Family] = nil
				New.Families[Family] = true -- Transfer family to the new one
			end
		end
	end
end)

hook.Add("OnContraptionMerge", "Families", function(Kept, Removed) -- Transfer families from Removed to Kept
	if Removed.Families then
		Kept.Families = Kept.Families or {}

		for Family in pairs(Removed.Families) do
			Removed.Families[Family] = nil
			Kept.Families[Family]    = true
		end

		Removed.Families = nil -- Removed is getting deleted anyways, but just in case
	end
end)

hook.Add("Initialize", "CFW Families", function()
	local ENT = FindMetaTable("Entity")

	function ENT:GetAncestor()
		if self.CFW then
			return self.CFW.Ancestor or self
		else
			return self
		end
	end

	function ENT:GetFamily()
		return self.CFW and self.CFW.Family or nil
	end

	function ENT:GetAllChildren(Output)
		if Output then
			Output[self] = true
		else
			Output = {}
		end

		for _, V in pairs(self:GetChildren()) do
			V:GetAllChildren(Output)
		end

		return Output
	end

	hook.Remove("Initialize", "CFW Families")
end)