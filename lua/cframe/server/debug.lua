local Enabled = CreateConVar("cframe_debug", 0, FCVAR_ARCHIVE, "Enables console debugging of every CFrame hook", 0, 1)
local Hooks = {
    OnContraptionCreated = true,
    OnContraptionDeleted = true,
    OnContraptionConnect = true,
    OnContraptionDisconnect = true,
    OnContraptionAppend = true,
    OnContraptionPop = true,
    OnContraptionInit = true,
    OnContraptionState = true,
    OnContraptionSplit = true,
    OnContraptionMerge = true
}

local function Callback(_, _, Value)
    local Active = tobool(Value)
    local Function = Active and hook.Add or hook.Remove

    for K in pairs(Hooks) do
        Function(K, "CFW Debug", Active and function(...)
            print(K, ...)
        end)
    end
end

hook.Add("Initialize", "CFW Debug", function()
    if Enabled:GetBool() then
        Callback(nil, nil, true)
    end

    hook.Remove("Initialize", "CFW Debug")
end)

cvars.AddChangeCallback("cframe_debug", Callback)
