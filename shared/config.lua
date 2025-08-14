Config = {}

    -- Who can place props?
    Config.AllowedGroups = { admin=true, staff=true, owner=true, developer=true }
    Config.StaffGroups   = { admin=true, staff=true }

    -- Deletion behavior
    Config.Delete = { ownerOnly=true, staffOverride=true }

    -- UI mode: "nui" (full catalog, text-only) | "menu" (old) | "list"
    Config.PropUI = "nui"

    -- Static props (frozen/invincible)
    Config.StaticProps = true

    -- Webhook (optional)
    Config.Webhook = "https://discordapp.com/api/webhooks/1404253004676464660/w53z9uWGoObNp6LFnmtySyqm-fKjQkRKpgnfh0cKkAWB66-NQu1TBEf2EZmVJon5yIvD"

    -- Commands
    Config.Commands = {
      place   = "prop",        -- /prop <model>
      delete  = "delprop",     -- delete targeted prop (owner/staff rules)
      reload  = "loadprops",   -- reload all from DB
      list    = "myprops",     -- last 10 (F8)
      menu    = "props",       -- open UI (respects PropUI)
      catalog = "propcatalog", -- open NUI catalog directly
      select  = "propselect"   -- new: selection mode
    }

    -- Controls (placement)
    Config.Keys = {
      confirm   = 0x760A9C6F,  -- G
      cancel    = 0x8AAA0AD4,  -- H
      up        = 0x446258B6,  -- PgUp
      down      = 0x3C3DD371,  -- PgDn
      rotLeft   = 0xE17F9DFE,  -- Q
      rotRight  = 0xCEFD9220,  -- E
      snap      = 0x05CA7C52,  -- LSHIFT
      fine      = 0x6319DB71,  -- LCTRL
    }

    Config.Select = {
      maxDistance = 10.0,    -- how far the ray can scan
      lineRGBA    = {230,210,150,200}, -- line color
      hoverAlpha  = 180      -- transparency when highlighting
    }
    

    -- Grid snapping
    Config.Grid = {
      enabledByDefault = false,
      size   = 0.25,          -- meters
      angles = 15,            -- degrees
      toggleKey = 0x4CC0E2FE  -- DELETE toggles grid on/off while placing / editing
    }

    Config.SnapTraceDistance = 15.0
    Config.Limits = { maxPerPlayer = 300 }


    -- Friendly display names used by:
    -- 1) Catalog UI, 2) /fetchprop output (preferred over catalog.json label)
    Config.ModelLabels = {
      p_barrel02x      = "Barrel",
      p_crate03x       = "Crate",
      p_cs_lantern04x  = "Lantern",
      p_table05x       = "Table",
    }