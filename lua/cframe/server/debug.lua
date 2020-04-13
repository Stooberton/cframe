hook.Add("OnContraptionCreated", "CFW Debug", "CFW Debug", function(C)
    print("OnContraptionCreated", C)
end)

hook.Add("OnContraptionDeleted", "CFW Debug", function(C)
    print("OnContraptionDeleted", C)
end)

hook.Add("OnContraptionConnect", "CFW Debug", function(C, A, B, Parent)
    print("OnContraptionConnect", C, A, B, Parent)
end)

hook.Add("OnContraptionDisconnect", "CFW Debug", function(C, A, B, Parent)
    print("OnContraptionDisconnect", C, A, B, Parent)
end)

hook.Add("OnContraptionAppend", "CFW Debug", function(C, A)
    print("OnContraptionAppend", C, A)
end)

hook.Add("OnContraptionPop", "CFW Debug", function(C, A)
    print("OnContraptionPop", C, A)
end)

hook.Add("OnContraptionInit", "CFW Debug", function(A)
    print("OnContraptionInit", A)
end)

hook.Add("OnContraptionState", "CFW Debug", function(A, State)
    print("OnContraptionState", A, State)
end)

hook.Add("OnContraptionSplit", "CFW Debug", function(Old, New)
    print("OnContraptionSplit", Old, New)
end)

hook.Add("OnContraptionMerge", "CFW Debug", function(Kept, Removed)
    print("OnContraptionMerge", Kept, Removed)
end)