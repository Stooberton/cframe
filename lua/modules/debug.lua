local function OnConnect(Contraption, Entity) print("OnConnect", Contraption, Entity) end
local function OnDisconnect(Contraption, Entity) print("OnDisconnect", Contraption, Entity) end
local function OnCreate(Contraption) print("OnCreate", Contraption) end
local function OnDestroy(Contraption) print("OnDestroy", Contraption) end

contraption.AddModule("debug", OnConnect, OnDisconnect, OnCreate, OnDestroy)