-- bread_propplacer - CLIENT (tooltip-on-placement)
-- placement + catalog + docked details + center preview + /propselect with outline

local placing, ghost, currentModel = false, nil, nil
local heading, raise = 0.0, 0.0
local hasAccess, isStaff = false, false
local spawned = {} -- id -> entity

-- ================= Utils / notify =================
local function notify(title, msg)
  TriggerEvent("vorp:TipRight", ("~e~%s~q~: %s"):format(title, msg), 3500)
end

-- keep NUI clean
local function forceUIClose()
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({ action = "close" })
  SendNUIMessage({ action = "reticle", show = false })
  SendNUIMessage({ action = "hideHelp" }) -- ensure tooltip hidden
end
CreateThread(function() forceUIClose() end)
AddEventHandler("onClientResourceStart", function(res) if res == GetCurrentResourceName() then forceUIClose() end end)
AddEventHandler("onClientResourceStop",  function(res) if res == GetCurrentResourceName() then forceUIClose() end end)

-- ================= Access / initial sync =================
RegisterNetEvent("bread_propplacer:notify", function(t, m) notify(t, m) end)

RegisterNetEvent("bread_propplacer:accessResult", function(ok, staff)
  hasAccess = ok; isStaff = staff
end)

CreateThread(function()
  TriggerServerEvent("bread_propplacer:requestAccess")
  Wait(800)
  if hasAccess then TriggerServerEvent("bread_propplacer:requestAll") end
end)

-- ================= Spawn helpers =================
local function applyStaticFlags(ent)
  if not ent or not DoesEntityExist(ent) then return end
  FreezeEntityPosition(ent, true)
  SetEntityCanBeDamaged(ent, false)
  SetEntityInvincible(ent, true)
  SetEntityProofs(ent, true, true, true, true, true, true, true, true)
  SetObjectTargettable(ent, false)
  SetEntityDynamic(ent, not Config.StaticProps)
  SetEntityAsMissionEntity(ent, true, true)
end

local function loadModel(mhash)
  if not HasModelLoaded(mhash) then
    RequestModel(mhash)
    while not HasModelLoaded(mhash) do Wait(0) end
  end
end

local function createPlaced(model,x,y,z,rx,ry,rz,id)
  local mh = GetHashKey(model); loadModel(mh)
  local obj = CreateObject(mh, x,y,z, true,true, false)
  SetEntityRotation(obj, rx+0.0, ry+0.0, rz+0.0, 2, true)
  if Config.StaticProps then PlaceObjectOnGroundProperly(obj) end
  applyStaticFlags(obj)
  if id then spawned[id] = obj end
end

RegisterNetEvent("bread_propplacer:spawnOne", function(d)
  createPlaced(d.model, d.x, d.y, d.z, d.rx, d.ry, d.rz, d.id)
end)

-- Hardened despawn
RegisterNetEvent("bread_propplacer:despawnOne", function(id)
  local e = spawned[id]
  if e and DoesEntityExist(e) then
    FreezeEntityPosition(e, false)
    SetEntityCollision(e, false, false)
    for i=1,6 do SetEntityAlpha(e, 180 - i*25, false); Wait(10) end
    if NetworkRequestControlOfEntity then
      local t = GetGameTimer() + 1500
      NetworkRequestControlOfEntity(e)
      while not NetworkHasControlOfEntity(e) and GetGameTimer() < t do
        NetworkRequestControlOfEntity(e); Wait(0)
      end
    end
    SetEntityAsMissionEntity(e, true, true)
    DeleteEntity(e)
  end
  spawned[id] = nil
end)

RegisterNetEvent("bread_propplacer:syncAll", function(list)
  for id,e in pairs(spawned) do if DoesEntityExist(e) then DeleteEntity(e) end end
  spawned = {}
  for _,r in ipairs(list or {}) do
    createPlaced(r.model, r.x, r.y, r.z, r.rx, r.ry, r.rz, r.id)
  end
end)

RegisterNetEvent("bread_propplacer:list", function(list)
  if not list or #list == 0 then notify("Props","No recent props."); return end
  notify("Props","Last 10 in F8.")
  print(("==== %s ==== Last 10 props"):format(GetCurrentResourceName()))
  for _,r in ipairs(list) do
    print(("#%d  %s  (%.2f, %.2f, %.2f)  %s"):format(r.id, r.model, r.x, r.y, r.z, r.placed_at))
  end
end)

-- ================= Placement loop (shows tooltip only while active) =================
local function getForwardPos(distance)
  local ped = PlayerPedId()
  local from = GetEntityCoords(ped)
  local fwd = GetEntityForwardVector(ped)
  return from + (fwd * distance)
end

local function raycastGround(from, to)
  local h = StartShapeTestRay(from.x,from.y,from.z, to.x,to.y,to.z, 1, PlayerPedId(), 0)
  local _, hit, pos = GetShapeTestResult(h)
  if hit == 1 then return pos end
  return nil
end

local gridOn = Config.Grid.enabledByDefault
local function toggleGrid() gridOn = not gridOn; notify("Grid", gridOn and "Snap ON" or "Snap OFF") end

local function ensureGhost(model)
  if ghost and DoesEntityExist(ghost) then return end
  local mh = GetHashKey(model); loadModel(mh)
  local pos = getForwardPos(2.0)
  ghost = CreateObject(mh, pos.x,pos.y,pos.z, false,false,false)
  SetEntityAlpha(ghost, 150, false)
  SetEntityCollision(ghost, false, false)
  SetEntityCompletelyDisableCollision(ghost, false, false)
  SetEntityRotation(ghost, 0.0, 0.0, heading, 2, true)
end

local function destroyGhost() if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end ghost=nil end

local function placementLoop()
  -- show tooltip now
  SendNUIMessage({ action = "showHelp" })

  while placing do
    Wait(0)
    local base = getForwardPos(2.2)
    local pos = vector3(base.x, base.y, base.z + raise)

    if IsControlPressed(0, Config.Keys.fine) then
      if IsControlPressed(0, Config.Keys.up)      then raise = raise + 0.01 end
      if IsControlPressed(0, Config.Keys.down)    then raise = math.max(-2.0, raise - 0.01) end
      if IsControlPressed(0, Config.Keys.rotLeft) then heading = heading - 0.3 end
      if IsControlPressed(0, Config.Keys.rotRight)then heading = heading + 0.3 end
    else
      if IsControlPressed(0, Config.Keys.up)      then raise = raise + 0.05 end
      if IsControlPressed(0, Config.Keys.down)    then raise = math.max(-2.0, raise - 0.05) end
      if IsControlPressed(0, Config.Keys.rotLeft) then heading = heading - 1.5 end
      if IsControlPressed(0, Config.Keys.rotRight)then heading = heading + 1.5 end
    end

    if IsControlPressed(0, Config.Keys.snap) then
      local from = vector3(base.x, base.y, base.z + 2.0)
      local to   = vector3(base.x, base.y, base.z - Config.SnapTraceDistance)
      local hit = raycastGround(from, to)
      if hit then pos = vector3(hit.x, hit.y, hit.z + 0.02) end
    end

    if IsControlJustPressed(0, Config.Grid.toggleKey) then toggleGrid() end
    if gridOn then
      pos = vector3(
        math.floor(pos.x / Config.Grid.size + 0.5) * Config.Grid.size,
        math.floor(pos.y / Config.Grid.size + 0.5) * Config.Grid.size,
        math.floor(pos.z / Config.Grid.size + 0.5) * Config.Grid.size
      )
      heading = math.floor(heading / Config.Grid.angles + 0.5) * Config.Grid.angles
    end

    ensureGhost(currentModel)
    SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z, false, false, false)
    SetEntityRotation(ghost, 0.0, 0.0, heading, 2, true)

    if IsControlJustPressed(0, Config.Keys.confirm) then
      local x,y,z = table.unpack(GetEntityCoords(ghost))
      TriggerServerEvent("bread_propplacer:saveProp", { model=currentModel, x=x,y=y,z=z, rx=0.0, ry=0.0, rz=heading })
      placing=false; destroyGhost(); currentModel=nil
      break
    elseif IsControlJustPressed(0, Config.Keys.cancel) then
      placing=false; notify("Prop","Cancelled."); destroyGhost(); currentModel=nil
      break
    end
  end

  -- hide tooltip
  SendNUIMessage({ action = "hideHelp" })
end

-- ================= Commands: /place /delete =================
RegisterCommand(Config.Commands.place, function(_, args)
  if not hasAccess then return notify("Prop","No access.") end
  local model = args[1]; if not model or model=="" then return notify("Prop","Usage: /"..Config.Commands.place.." <model>") end
  currentModel = model; heading = GetEntityHeading(PlayerPedId()); raise = 0.0; placing = true; placementLoop()
end)

RegisterCommand(Config.Commands.delete, function()
  if not hasAccess then return notify("Prop","No access.") end
  local ped = PlayerPedId()
  local from = GetEntityCoords(ped)
  local to   = from + (GetEntityForwardVector(ped) * 6.0)
  local h = StartShapeTestRay(from.x,from.y,from.z+0.5, to.x,to.y,to.z, 16, ped, 0)
  local _,hit,_,_,ent = GetShapeTestResult(h)
  if hit==1 and ent~=0 and DoesEntityExist(ent) then
    local ex,ey,ez = table.unpack(GetEntityCoords(ent))
    local bestId, bestDist = nil, 1.2
    for id,obj in pairs(spawned) do
      if DoesEntityExist(obj) then
        local ox,oy,oz = table.unpack(GetEntityCoords(obj))
        local d = #(vector3(ex,ey,ez) - vector3(ox,oy,oz))
        if d < bestDist then bestDist=d; bestId=id end
      end
    end
    if bestId then TriggerServerEvent("bread_propplacer:deleteProp", bestId) else notify("Prop","No targeted prop.") end
  else
    notify("Prop","No targeted prop.")
  end
end)

-- ================= Catalog (NUI) =================
local function openCatalog()
  if not hasAccess then return notify("Prop","No access.") end
  SetNuiFocus(true, true)
  local raw = LoadResourceFile(GetCurrentResourceName(), "shared/catalog.json")
  local items = {}
  if raw then
    local ok, data = pcall(json.decode, raw)
    if ok and type(data)=="table" then
      for _,e in ipairs(data) do
        local label = (Config.ModelLabels and Config.ModelLabels[e.model]) or e.label or e.model
        items[#items+1] = { model=e.model, label=label, tags=e.tags or {} }
      end
    end
  end
  if Config.ModelLabels then
    for model, label in pairs(Config.ModelLabels) do
      local found=false
      for _,it in ipairs(items) do if it.model==model then found=true break end end
      if not found then items[#items+1] = { model=model, label=label, tags={} } end
    end
  end
  table.sort(items, function(a,b) return (a.label or a.model) < (b.label or b.model) end)
  SendNUIMessage({ action="open", items=items })
end

local function closeCatalog()
  SetNuiFocus(false, false)
  SendNUIMessage({ action="close" })
end

RegisterCommand(Config.Commands.catalog, function() openCatalog() end)
RegisterCommand(Config.Commands.menu, function()
  if Config.PropUI == "nui" then openCatalog() else notify("Props", 'NUI disabled (set PropUI="nui").') end
end)

RegisterNUICallback("catalog_close", function(_, cb) closeCatalog(); cb({ok=true}) end)
RegisterNUICallback("catalog_pick", function(data, cb)
  closeCatalog()
  local model = data and data.model
  if model and model ~= "" then
    currentModel = model
    heading = GetEntityHeading(PlayerPedId())
    raise = 0.0
    placing = true
    placementLoop()
  else
    notify("Catalog","Invalid selection.")
  end
  cb({ok=true})
end)

-- ================= Catalog Preview (center screen) =================
local previewEnt, previewModel, previewTick = nil, nil, 0.0
local previewThreadRunning = false

local function _previewDelete()
  if previewEnt and DoesEntityExist(previewEnt) then
    SetEntityAsMissionEntity(previewEnt, true, true)
    DeleteEntity(previewEnt)
  end
  previewEnt, previewModel, previewTick = nil, nil, 0.0
end

local function _previewEnsure(modelName)
  if previewEnt and DoesEntityExist(previewEnt) and previewModel == modelName then return true end
  _previewDelete()
  local h = GetHashKey(modelName)
  if not HasModelLoaded(h) then
    RequestModel(h)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
  end
  if not HasModelLoaded(h) then return false end

  local cam = GetGameplayCamCoord()
  local rot = GetGameplayCamRot(2)
  local pitch = math.rad(rot.x); local yaw = math.rad(rot.z)
  local cp = math.cos(pitch)
  local dir = vector3(-math.sin(yaw)*cp, math.cos(yaw)*cp, math.sin(pitch))
  local dist = 3.0
  local pos = cam + (dir * dist)

  previewEnt = CreateObject(h, pos.x, pos.y, pos.z, false, false, false)
  SetEntityAsMissionEntity(previewEnt, true, true)
  SetEntityCollision(previewEnt, false, false)
  SetEntityCompletelyDisableCollision(previewEnt, true, true)
  SetEntityAlpha(previewEnt, 210, false)
  FreezeEntityPosition(previewEnt, true)
  SetEntityRotation(previewEnt, 0.0, 0.0, GetEntityHeading(PlayerPedId()), 2, true)

  previewModel = modelName
  return true
end

local function _previewUpdatePosition()
  if not previewEnt or not DoesEntityExist(previewEnt) then return end
  local cam = GetGameplayCamCoord()
  local rot = GetGameplayCamRot(2)
  local pitch = math.rad(rot.x); local yaw = math.rad(rot.z)
  local cp = math.cos(pitch)
  local dir = vector3(-math.sin(yaw)*cp, math.cos(yaw)*cp, math.sin(pitch))
  local dist = 3.0
  local pos = cam + (dir * dist)

  previewTick = (previewTick + 0.6) % 360.0
  SetEntityCoordsNoOffset(previewEnt, pos.x, pos.y, pos.z, false, false, false)
  SetEntityRotation(previewEnt, 0.0, 0.0, previewTick, 2, true)
end

RegisterNUICallback("catalog_preview_start", function(data, cb)
  local model = data and data.model
  if not model or model == "" then cb({ok=false}); return end
  if not _previewEnsure(model) then notify("Preview","Failed to load model."); cb({ok=false}); return end
  if not previewThreadRunning then
    previewThreadRunning = true
    CreateThread(function()
      while previewThreadRunning and previewEnt and DoesEntityExist(previewEnt) do
        Wait(0)
        _previewUpdatePosition()
      end
    end)
  end
  cb({ok=true})
end)

RegisterNUICallback("catalog_preview_stop", function(_, cb)
  previewThreadRunning = false
  _previewDelete()
  cb({ok=true})
end)

-- ================= /propselect (reticle + outline) =================
local selecting = false
local hoverId, hoverEnt = nil, nil

local HAS_OUTLINE = (type(SetEntityDrawOutline) == "function") and (type(SetEntityDrawOutlineColor) == "function")
local OUTLINE_COL = { r = 224, g = 179, b = 111, a = 255 }

local function clearHover()
  if hoverEnt and DoesEntityExist(hoverEnt) then
    if HAS_OUTLINE then SetEntityDrawOutline(hoverEnt, false) end
    ResetEntityAlpha(hoverEnt)
    SetEntityCollision(hoverEnt, true, true)
  end
  hoverId, hoverEnt = nil, nil
end

local function highlight(ent, on)
  if not ent or not DoesEntityExist(ent) then return end
  if on then
    if HAS_OUTLINE then
      SetEntityDrawOutlineColor(OUTLINE_COL.r, OUTLINE_COL.g, OUTLINE_COL.b, OUTLINE_COL.a)
      SetEntityDrawOutline(ent, true)
    else
      SetEntityAlpha(ent, (Config.Select and Config.Select.hoverAlpha) or 180, false)
      SetEntityCollision(ent, false, false)
    end
  else
    if HAS_OUTLINE then SetEntityDrawOutline(ent, false) end
    ResetEntityAlpha(ent)
    SetEntityCollision(ent, true, true)
  end
end

-- bbox fallback for older builds
local function _bboxCorners(ent)
  if not ent or not DoesEntityExist(ent) then return nil end
  local mn, mx = GetModelDimensions(GetEntityModel(ent))
  if not mn or not mx then mn = vector3(-0.5,-0.5,-0.5); mx = vector3(0.5,0.5,0.5) end
  local corners = {}
  for xi=0,1 do
    for yi=0,1 do
      for zi=0,1 do
        local off = vector3((xi==0) and mn.x or mx.x, (yi==0) and mn.y or mx.y, (zi==0) and mn.z or mx.z)
        corners[#corners+1] = GetOffsetFromEntityInWorldCoords(ent, off.x, off.y, off.z)
      end
    end
  end
  return corners
end
local function _drawBoxLines(c, r,g,b,a)
  local function L(i,j) local A,B=c[i],c[j]; DrawLine(A.x,A.y,A.z, B.x,B.y,B.z, r,g,b,a) end
  if not c or #c < 8 then return end
  L(1,2); L(2,4); L(4,3); L(3,1)
  L(5,6); L(6,8); L(8,7); L(7,5)
  L(1,5); L(2,6); L(3,7); L(4,8)
end

local function camRay(maxDist)
  local cam = GetGameplayCamCoord()
  local rot = GetGameplayCamRot(2)
  local pitch = math.rad(rot.x); local yaw = math.rad(rot.z)
  local cp = math.cos(pitch)
  local dir = vector3(-math.sin(yaw)*cp, math.cos(yaw)*cp, math.sin(pitch))
  local to  = cam + (dir * (maxDist or 10.0))
  local h = StartShapeTestRay(cam.x,cam.y,cam.z, to.x,to.y,to.z, 16, PlayerPedId(), 0)
  local _, hit, endPos, _, ent = GetShapeTestResult(h)
  return hit == 1, endPos, ent
end

RegisterCommand((Config.Commands and Config.Commands.select) or "propselect", function()
  if not hasAccess then return notify("Prop","No access.") end
  selecting = not selecting
  if not selecting then
    clearHover()
    SendNUIMessage({ action = "reticle", show = false })
    notify("Select","Exited prop select.")
    return
  end

  SendNUIMessage({ action = "reticle", show = true, hit = false, text = "Aim at a placed prop." })
  notify("Select","G: Delete  •  H: Exit")

  CreateThread(function()
    while selecting do
      Wait(0)
      local hit, _, ent = camRay((Config.Select and Config.Select.maxDistance) or 10.0)

      local idUnder = nil
      if hit and ent ~= 0 and DoesEntityExist(ent) then
        for id,obj in pairs(spawned) do if obj == ent then idUnder = id break end end
        if not idUnder then
          local ex,ey,ez = table.unpack(GetEntityCoords(ent))
          local bestId, bestDist = nil, 0.25
          for id,obj in pairs(spawned) do
            if DoesEntityExist(obj) then
              local ox,oy,oz = table.unpack(GetEntityCoords(obj))
              local d = #(vector3(ex,ey,ez) - vector3(ox,oy,oz))
              if d < bestDist then bestDist=d; bestId=id end
            end
          end
          idUnder = bestId
        end
      end

      if idUnder and spawned[idUnder] then
        local newEnt = spawned[idUnder]
        if newEnt ~= hoverEnt then
          if hoverEnt then highlight(hoverEnt, false) end
          hoverId, hoverEnt = idUnder, newEnt
          highlight(hoverEnt, true)
        end
        SendNUIMessage({ action = "reticle", show = true, hit = true, text = "Target locked." })
      else
        if hoverEnt then highlight(hoverEnt, false) end
        hoverId, hoverEnt = nil, nil
        SendNUIMessage({ action = "reticle", show = true, hit = false, text = "Aim at a placed prop." })
      end

      if not HAS_OUTLINE and hoverEnt and DoesEntityExist(hoverEnt) then
        local c = _bboxCorners(hoverEnt)
        _drawBoxLines(c, 224,179,111, 220)
      end

      if hoverId and IsControlJustPressed(0, Config.Keys.confirm) then
        local entToNuke = hoverEnt
        if entToNuke and DoesEntityExist(entToNuke) then
          FreezeEntityPosition(entToNuke, false)
          SetEntityCollision(entToNuke, false, false)
          for i=1,6 do SetEntityAlpha(entToNuke, 180 - i*25, false); Wait(15) end
        end
        TriggerServerEvent("bread_propplacer:deleteProp", hoverId)
        clearHover()
        CreateThread(function()
          Wait(1200)
          if isStaff and entToNuke and DoesEntityExist(entToNuke) then
            if NetworkRequestControlOfEntity then
              local t = GetGameTimer() + 1200
              while not NetworkHasControlOfEntity(entToNuke) and GetGameTimer() < t do
                NetworkRequestControlOfEntity(entToNuke); Wait(0)
              end
            end
            SetEntityAsMissionEntity(entToNuke, true, true)
            DeleteEntity(entToNuke)
          end
        end)
      end

      if IsControlJustPressed(0, Config.Keys.cancel) then
        selecting = false
        break
      end
    end
    clearHover()
    SendNUIMessage({ action = "reticle", show = false })
    notify("Select","Exited prop select.")
  end)
end)
