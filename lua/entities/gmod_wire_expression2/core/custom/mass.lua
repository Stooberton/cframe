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

__e2setcost(1)

e2function number entity:isPhysical()
	if this.CF then
		return this.CF.IsPhysical and 1 or 0
	else
		return IsPhysical(Ent) and 1 or 0
	end
end