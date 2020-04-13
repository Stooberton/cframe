local function GetAllChildren(Ent, Output)
    if Output then
        Output[Ent] = true
    else
        Output = {}
    end

    for K in pairs(Ent:GetChildren()) do
        GetAllChildren(K, Output)
    end

    return Output
end

hook.Add("OnContraptionCreate", "Families", function(C)
    C.Families = {}
end)

hook.Add("OnContraptionConnect", "Families", function(A, B, Parent)
    if not Parent then return end -- Only care about parent actions

    local Ancestor = B.CFW.Ancestor or B
    local Family   = Ancestor.CFW.Family or {}
    local OldFam   = A.CFW.Family

    Family[A] = true -- Add A to the family

    if OldFam then -- Transfer old family, if it exists, to new family
        for Ent in pairs(OldFam) do
            OldFam[Ent] = nil
            Family[Ent] = true

            Ent.CFW.Ancestor = Ancestor
        end

        A.CFW.Family = nil
    end

    Ancestor.CFW.Family = Family -- Asign the family to the ancestor
    A.CFW.Ancestor      = Ancestor -- Update A's ancestor

    A.CFW.Contraption.Families[Family] = true -- Add this family to the contraption
end)

hook.Add("OnContraptionDisconnect", "Families", function(A, B, Parent)
    if not Parent then return end -- Only care about parent actions

    local OldAncestor = A.CFW.Ancestor
    local OldFamily   = OldAncestor.CFW.Family

    OldFamily[A]   = nil -- Remove A from the old family
    A.CFW.Ancestor = nil -- A is the ancestor now

    local Subtree = GetAllChildren(A)

    if next(Subtree) then -- If A has children, move them to A's family
        local NewFamily = {}

        for Ent in pairs(Subtree) do
            OldFamily[Ent] = nil
            NewFamily[Ent] = true

            Ent.CFW.Ancestor = A
        end

        A.CFW.Family = NewFamily

        if not A.CFW.Contraption.Families then
            print("CFW")
            PrintTable(A.CFW)
            print("Contraption")
            PrintTable(A.CFW.Contraption)
        end
        A.CFW.Contraption.Families[NewFamily] = true
    end
end)

hook.Add("OnContraptionSplit", "Families", function(Old, New) -- Transfer families that have been split off
    if Old.Families then
        New.Families = New.Families or {}

        for Family in pairs(Old.Families) do
            Old.Families[Family] = nil
            New.Families[Family] = true
        end
    end
end)

hook.Add("OnContraptionMerge", "Families", function(Kept, Removed) -- Transfer families from Removed to Kept
    if Removed.Families then
        for Family in pairs(Removed.Families) do
            Removed.Families[Family] = nil
            Kept.Families[Family]    = true
        end

        Removed.Families = nil
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

    hook.Remove("Initialize", "CFW Families")
end)