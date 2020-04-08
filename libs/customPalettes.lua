-------------------------------------------------------------------------------------
-- Custom Mech Palette Library
-- v0.4
-- https://github.com/KnightMiner/ITB-KnightUtils/blob/master/libs/customPalettes.lua
-------------------------------------------------------------------------------------
-- Contains helpers to make custom mech palettes
-------------------------------------------------------------------------------------

-- Current library version, so we can ensure the latest library version is used
local VERSION = "0.4"

-- if we have a global that is newer than or the same version as us, use that
-- if our version is newer or its not yet loaded, load the library
if CUSTOM_PALETTES == nil or not modApi:isVersion(VERSION, CUSTOM_PALETTES.version) then
  -- if we have an older version, update that table with the latest functions
  -- ensures older copies of the library use the latest logic for everything
  local palettes = CUSTOM_PALETTES or {}
  CUSTOM_PALETTES = palettes

  -- ensure we have needed properties
  palettes.version = VERSION
  -- format: map ID -> {name, colors, index}
  palettes.map = palettes.map or {}
    -- format: index -> map ID
  palettes.indexMap = palettes.indexMap or {}

  ----------------------
  -- Helper functions --
  ----------------------

  --- Path to animations that use palettes
  local palettePath = "units/player"

  --[[--
    Checks if the given animation object uses palettes

    @param anim  Animation object
    @return true if the animation uses palettes
  ]]
  local function usesPalettes(anim)
    return anim:GetImage():sub(1, #palettePath) == palettePath
  end

  --[[--
    Updates all animation objects to the updated color count. Needs to be called every time a palette is added.
    Needed since increasing the palette count increases the generated images in an animation

    @param added  number of palettes added
  ]]
  local function updateAnimations(added)
    -- determine the old index we need to update
    local count = GetColorCount()
    local update = count - added

    -- update base objects, mostly needed for MechIcon as it does not use a units/player image path
    ANIMS.MechColors = count
    ANIMS.MechUnit.Height = count
    ANIMS.MechIcon.Height = count

    -- update other objects that use MechUnit
    for name, anim in pairs(ANIMS) do
      -- images loaded in units/player generate a vertical frame for each unit
      if type(anim) == "table" and anim.Height ~= nil and anim.Height >= update and anim.Height < count and usesPalettes(anim) then
        anim.Height = count
      end
    end
  end

  --[[--
    Checks that our library handles mech palettes

    @return true if this library handles palettes, false otherwise
  ]]
  local function handlesPalettes()
    return GetColorCount == palettes.getCount and GetColorMap == palettes.getColorMap
  end

  --[[--
    Gets the given key from a palette if the palette exists

    @param id       Palette ID
    @param key      Key to fetch
    @param fallback Optional fallback to use if the map exists, but the key does not
    @return Value of the key, or nil if the map does not exist
  ]]
  local function getIfPresent(id, key, fallback)
    -- IDs loaded from vanilla or libraries besids FURL are numerically indexed
    assert(type(id) == "string", "ID must be a string")
    assert(type(key) == "string", "Key must be a string")
    -- fetch the palette if it exists
    local palette = palettes.map[id]
    if palette == nil then
      return nil
    end
    -- fallback to ID for the name
    return palette[key] or fallback
  end

  -------------
  -- Getters --
  -------------

  --[[--
    Gets the colormap ID based on the given map index.

    @param index  Vanilla colormap index
    @return  Colormap ID for the given index
  ]]
  function palettes.getMapID(index)
    assert(type(index) == "number", "Index must be a number")
    return palettes.indexMap[index]
  end

  --[[--
    Gets the colormap ID based on the given image offset.
    Used since there is a difference between the image offset of a pawn and the colors index in vanilla

    @param offset  ImageOffset from the pawn properties
    @return  Colormap ID for the given image offset
  ]]
  function palettes.getOffsetID(offset)
    assert(type(offset) == "number", "Offset must be a number")
    return palettes.indexMap[offset+1]
  end

  --[[--
    Gets the name for the given palette

    @param id  Palette ID
    @return  Palettes name, or nil if the ID does not exist
  ]]
  function palettes.getMapName(id)
    return getIfPresent(id, "name", id)
  end

  --[[--
    Gets the image offset for the given map ID

    @param id  Map ID
    @return  Image offset for the given map, or nil if the ID does not exist
  ]]
  function palettes.getOffset(id)
    local index = getIfPresent(id, "index")
    if index == nil then
      return nil
    end
    return index - 1
  end

  -- Vanilla overrides
  --
  -- These two functions are equivelent to the vanilla GetColorMap and GetColorCount respectively
  -- Difference is they are called through this library, and they may be outdated if another
  -- library (such as FURL) overrides the functions
  -- Calling palettes.migrateHooks() will migrate either vanilla or another library to this library,
  -- then ensure this library's functions are used

  --[[--
    Gets the colormap for the given index

    @param id  Colormap numeric index. Vanilla are 1-9
    @return  Colormap at the given index
  ]]
  function palettes.getColorMap(index)
    assert(type(index) == "number", "Index must be a number")
    -- convert the index to an ID, then fetch the coorsponding map
    local id = palettes.getMapID(index)
    if id ~= nil then
      return getIfPresent(id, "colors")
    end
    return nil
  end

  --[[--
    Gets the number of palettes loaded

    @return  Number of palettes currently loaded
  ]]
  function palettes.getCount()
    return #palettes.indexMap
  end

  -----------------------
  -- Library functions --
  -----------------------

  --- Human readible names for all vanilla maps, will return nil for non-vanilla
  local vanillaMapNames = {
    "Archive Olive",
    "Rust Orange",
    "Pinnacle Dark Blue",
    "Detrius Yellow",
    "Archive Shivan",
    "Rust Red",
    "Pinnacle Ice Blue",
    "Detrius Tan",
    "Vek Purple"
  }
  --- Internal names for each of the palettes, used for modders
  local vanillaIDs = {
    "RiftWalkers",
    "RustingHulks",
    "ZenithGuard",
    "Blitzkrieg",
    "SteelJudoka",
    "FlameBehemoths",
    "FrozenTitans",
    "HazardousMechs",
    "SecretSquad"
  }

  --[[--
    Migrates missing palettes and overrides the vanilla functions
  ]]
  function palettes.migrateHooks()
    -- if one of the two vanilla palette functions is not ours, run migrations
    -- uses the global to ensure we migrate to the latest library version
    if GetColorCount ~= palettes.getCount or GetColorMap ~= palettes.getColorMap then
      -- first, clone any palettes we are missing into our array

      local totalPalettes = GetColorCount()
      if totalPalettes > palettes.getCount() then
        -- first, create a map from indexes to FURL names
        local furlIDs = {}
        if type(FURL_COLORS) == "table" then
          for name, index in pairs(FURL_COLORS) do
            -- FURL stores imageOffset instead of palette index
            furlIDs[index+1] = name
          end
        end

        -- migrate any palettes we are missing
        for index = palettes.getCount()+1, totalPalettes do
          -- first, ensure there is a color map there
          local colors = GetColorMap(index)
          if colors == nil then
            break
          end

          -- use the name from FURL as the ID if present, or fallback to index (vanilla palettes)
          local id = vanillaIDs[index] or furlIDs[index] or tostring(index)
          -- create the palette data
          palettes.map[id] = {
            name = vanillaMapNames[i],
            colors = colors,
            index = index
          }
          -- add the index to the index map, this map may change later
          palettes.indexMap[index] = id
        end
      end

      -- override the vanilla functions with our copies
      GetColorMap = palettes.getColorMap
      GetColorCount = palettes.getCount
    end
  end

  --- List of all key names for indexes in the vanilla palettes structure
  local PALETTE_KEYS = {
    "PlateHighlight",
    "PlateLight",
    "PlateMid",
    "PlateDark",
    "PlateOutline",
    "PlateShadow",
    "BodyColor",
    "BodyHighlight"
  }

  --[[--
    Adds a new palette to the game

    @param ...  Varargs table parameters for palette data. Contains all the colors from PALETTE_KEYS, plus:
           ID: Unique ID for this palette
           Name: Human readible name, if unset defaults to ID
  ]]
  function palettes.addPalette(...)
    -- ensure this library is in charge of palettes
    palettes.migrateHooks()

    -- allow passing in multiple palettes at once, more efficient for animation reloading
    local datas = {...}
    local added = #datas
    for _, data in ipairs(datas) do
      -- validations
      assert(type(data) == "table", "Palette data must be a table")
      assert(type(data.ID) == "string", "Invalid palette, missing string ID")
      assert(data.Name == nil or type(data.Name) == "string", "Name must be a string")

      -- if two mods add a palette with the same ID, ignore
      -- allows mods to "share" a palette
      if palettes.map[data.ID] ~= nil then
        added = added - 1
      else
        -- construct each of the pieces of the color
        local colors = {}
        for i, key in ipairs(PALETTE_KEYS) do
          if type(data[key]) ~= "table" then
            error("Invalid palette, missing key " .. key)
          end
          assert(#data[key] == 3, "Color must contain three integers")
          colors[i] = GL_Color(unpack(data[key]))
        end

        -- create the palette
        local index = palettes.getCount() + 1
        palettes.map[data.ID] = {
          name = data.Name,
          colors = colors,
          index = index
        }
        palettes.indexMap[index] = data.ID
      end
    end

    -- reload animations to update the color count
    -- only need to reload once for all the palettes
    updateAnimations(added)
  end
end

-- take control of the vanilla functions
CUSTOM_PALETTES.migrateHooks()

-- return library, in general the global should not be used outside this script
return CUSTOM_PALETTES
