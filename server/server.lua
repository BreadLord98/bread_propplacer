local resourceName = GetCurrentResourceName()

-- webhook (optional)
local function sendWebhook(title, msg)
  if not Config.Webhook or Config.Webhook == "" then return end
  PerformHttpRequest(Config.Webhook, function() end, 'POST',
    json.encode({
      username = "bread_propplacer",
      embeds = {{
        title = title,
        description = msg,
        color = 9364351,
        footer = { text = resourceName.." • "..os.date("%Y-%m-%d %H:%M:%S") }
      }}
    }),
    { ['Content-Type'] = 'application/json' })
end

-- VORP helpers
local function getCore()
  local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
  if ok then return core end
  return nil
end

local function getChar(source)
  local core = getCore(); if not core then return nil end
  local User = core.getUser(source); if not User then return nil end
  return User.getUsedCharacter
end

local function getIdentifier(source)
  for _,v in ipairs(GetPlayerIdentifiers(source)) do
    if v:find("license:") then return v end
  end
  return ("temp:%s"):format(source)
end

local function getPlayerGroup(source)
  local Char = getChar(source)
  if Char and Char.group then return tostring(Char.group):lower() end
  if Char and Char.charIdentifier then
    local row = MySQL.single.await(
      "SELECT `group` FROM characters WHERE identifier=? AND charidentifier=? LIMIT 1",
      { getIdentifier(source), Char.charIdentifier }
    )
    if row and row.group then return tostring(row.group):lower() end
  end
  return nil
end

local function hasAccess(source)
  local g = getPlayerGroup(source) or ""
  return Config.AllowedGroups[g] == true
end

local function isStaff(source)
  local g = getPlayerGroup(source) or ""
  return Config.StaffGroups[g] == true
end

-- DB bootstrap
CreateThread(function()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS bread_props (
      id INT AUTO_INCREMENT PRIMARY KEY,
      model VARCHAR(64) NOT NULL,
      x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
      rx DOUBLE NOT NULL DEFAULT 0, ry DOUBLE NOT NULL DEFAULT 0, rz DOUBLE NOT NULL DEFAULT 0,
      owner_identifier VARCHAR(64) NOT NULL,
      owner_charid INT NOT NULL DEFAULT 0,
      placed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ]])
end)

local function countProps(identifier, charId)
  local r = MySQL.single.await(
    "SELECT COUNT(*) as c FROM bread_props WHERE owner_identifier=? AND owner_charid=?",
    {identifier, charId or 0}
  )
  return (r and r.c) or 0
end

-- access / sync
RegisterNetEvent("bread_propplacer:requestAccess", function()
  local src = source
  TriggerClientEvent("bread_propplacer:accessResult", src, hasAccess(src), isStaff(src))
end)

RegisterNetEvent("bread_propplacer:requestAll", function()
  local src = source
  if not hasAccess(src) then return end
  local list = MySQL.query.await("SELECT * FROM bread_props", {})
  TriggerClientEvent("bread_propplacer:syncAll", src, list or {})
end)

-- save placement
RegisterNetEvent("bread_propplacer:saveProp", function(data)
  local src = source
  if not hasAccess(src) then return end
  local Char = getChar(src); if not Char then return end
  local identifier = getIdentifier(src)
  local charId     = Char.charIdentifier or 0

  if countProps(identifier, charId) >= Config.Limits.maxPerPlayer then
    TriggerClientEvent("bread_propplacer:notify", src, "Limit", "You reached the prop limit.")
    return
  end

  local id = MySQL.insert.await(
    "INSERT INTO bread_props (model,x,y,z,rx,ry,rz,owner_identifier,owner_charid) VALUES (?,?,?,?,?,?,?,?,?)",
    { data.model, data.x, data.y, data.z, data.rx, data.ry, data.rz, identifier, charId }
  )

  if id then
    TriggerClientEvent("bread_propplacer:spawnOne", -1, {
      id=id, model=data.model, x=data.x, y=data.y, z=data.z, rx=data.rx, ry=data.ry, rz=data.rz
    })
    TriggerClientEvent("bread_propplacer:notify", src, "Placed", ("Saved prop #%d"):format(id))
    sendWebhook("Prop Placed",
      ("**%s** placed `%s` at (%.2f, %.2f, %.2f) [id %d]")
        :format(GetPlayerName(src), data.model, data.x, data.y, data.z, id))
  end
end)

-- delete (owner rules + staff override)
RegisterNetEvent("bread_propplacer:deleteProp", function(id)
  local src = source
  if not hasAccess(src) then return end
  if not id then return end

  local Char = getChar(src); if not Char then return end
  local identifier = getIdentifier(src)
  local charId     = Char.charIdentifier or 0

  local where, args = "id = ?", { id }
  if Config.Delete.ownerOnly and not (Config.Delete.staffOverride and isStaff(src)) then
    where, args = where .. " AND owner_identifier=? AND owner_charid=?", { id, identifier, charId }
  end

  local rows = MySQL.update.await(("DELETE FROM bread_props WHERE %s LIMIT 1"):format(where), args)
  if rows and rows > 0 then
    TriggerClientEvent("bread_propplacer:despawnOne", -1, id)
    TriggerClientEvent("bread_propplacer:notify", src, "Deleted", ("Deleted prop #%d"):format(id))
    sendWebhook("Prop Deleted", ("**%s** deleted prop id %d"):format(GetPlayerName(src), id))
  else
    TriggerClientEvent("bread_propplacer:notify", src, "Delete", "No permission or no prop found.")
  end
end)

-- list / reload
RegisterCommand(Config.Commands.reload, function(src)
  if src == 0 or not hasAccess(src) then return end
  local list = MySQL.query.await("SELECT * FROM bread_props", {})
  TriggerClientEvent("bread_propplacer:syncAll", -1, list or {})
  TriggerClientEvent("bread_propplacer:notify", src, "Loaded", "Props reloaded from DB.")
end)

RegisterCommand(Config.Commands.list, function(src)
  if src == 0 or not hasAccess(src) then return end
  local Char = getChar(src); if not Char then return end
  local identifier = getIdentifier(src)
  local charId     = Char.charIdentifier or 0
  local list = MySQL.query.await(
    "SELECT id, model, x,y,z, placed_at FROM bread_props WHERE owner_identifier=? AND owner_charid=? ORDER BY id DESC LIMIT 10",
    {identifier, charId}
  )
  TriggerClientEvent("bread_propplacer:list", src, list or {})
end)

-- legacy feed for non‑NUI list (kept)
RegisterNetEvent("bread_propplacer:menuData", function() end) -- placeholder if others still call it
