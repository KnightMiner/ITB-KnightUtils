------------------------------------------------------------------------------------
-- Custom Mech Pallet Library
-- v0.2
-- https://github.com/KnightMiner/ITB-KnightUtils/blob/master/libs/customPallets.lua
------------------------------------------------------------------------------------
-- Contains helpers to make custom mech pallets
------------------------------------------------------------------------------------

-- Current library version, so we can ensure the latest library version is used
local VERSION = "0.2"

-- if we have a global that is newer than or the same version as us, use that
-- if our version is newer or its not yet loaded, load the library
if CUSTOM_PALLETS == nil or not modApi:isVersion(VERSION, CUSTOM_PALLETS.version) then
  local pallets = {
    version = VERSION,
    -- format: map ID -> {name, colors, index}
    map = {},
    -- format: index -> map ID
    indexMap = {}
  }

  -- migrate maps from older version
  if type(CUSTOM_PALLETS) == "table" then
    -- copy color maps and index map over if set
    if type(CUSTOM_PALLETS.colorMaps) == "table" then
      pallets.colorMaps = CUSTOM_PALLETS.colorMaps
    end
    if type(CUSTOM_PALLETS.indexMap) == "table" then
      pallets.indexMap = CUSTOM_PALLETS.indexMap
    end
  end

  -- update the shared variable, shared among all copies of this library
  -- if reloading, just outright replace the old copy, vanilla migration currently handles old lib migration
  CUSTOM_PALLETS = pallets

  ----------------------
  -- Helper functions --
  ----------------------

  --- Path to animations that use pallets
  local palletPath = "units/player"

  --[[--
    Checks if the given animation object uses pallets

    @param anim  Animation object
    @return true if the animation uses pallets
  ]]
  local function usesPallets(anim)
    return anim:GetImage():sub(1, #palletPath) == palletPath
  end

  --[[--
    Updates all animation objects to the updated color count. Needs to be called every time a pallet is added.
    Needed since increasing the pallet count increases the generated images in an animation

    @param added  number of pallets added
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
      if type(anim) == "table" and anim.Height ~= nil and anim.Height >= update and anim.Height < count and usesPallets(anim) then
        anim.Height = count
      end
    end
  end

  --[[--
    Checks that our library handles mech pallets

    @return true if this library handles pallets, false otherwise
  ]]
  local function handlesPallets()
    return GetColorCount == pallets.getCount and GetColorMap == pallets.getColorMap
  end

  --[[--
    Gets the given key from a pallet if the pallet exists

    @param id       Pallet ID
    @param key      Key to fetch
    @param fallback Optional fallback to use if the map exists, but the key does not
    @return Value of the key, or nil if the map does not exist
  ]]
  local function getIfPresent(id, key, fallback)
    -- IDs loaded from vanilla or libraries besids FURL are numerically indexed
    local idType = type(id)
    assert(idType == "number" or idType == "string")
    assert(type(key) == "string", "Key must be a string")
    -- fetch the pallet if it exists
    local pallet = pallets.map[id]
    if pallet == nil then
      return nil
    end
    -- fallback to ID for the name
    return pallet[key] or fallback
  end

  -------------
  -- Getters --
  -------------

  --[[--
    Gets the colormap ID based on the given map index.

    @param index  Vanilla colormap index
    @return  Colormap ID for the given index
  ]]
  function pallets.getMapID(index)
    assert(type(index) == "number", "Index must be a number")
    return pallets.indexMap[index]
  end

  --[[--
    Gets the colormap ID based on the given image offset.
    Used since there is a difference between the image offset of a pawn and the colors index in vanilla

    @param offset  ImageOffset from the pawn properties
    @return  Colormap ID for the given image offset
  ]]
  function pallets.getOffsetID(offset)
    assert(type(offset) == "number", "Offset must be a number")
    return pallets.indexMap[offset+1]
  end

  --[[--
    Gets the name for the given pallet

    @param id  Pallet ID
    @return  Pallets name, or nil if the ID does not exist
  ]]
  function pallets.getMapName(id)
    return getIfPresent(id, "name", id)
  end

  --[[--
    Gets the image offset for the given map ID

    @param id  Map ID
    @return  Image offset for the given map, or nil if the ID does not exist
  ]]
  function pallets.getOffset(id)
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
  -- Calling pallets.migrateHooks() will migrate either vanilla or another library to this library,
  -- then ensure this library's functions are used

  --[[--
    Gets the colormap for the given index

    @param id  Colormap numeric index. Vanilla are 1-9
    @return  Colormap at the given index
  ]]
  function pallets.getColorMap(index)
    assert(type(index) == "number", "Index must be a number")
    -- convert the index to an ID, then fetch the coorsponding map
    local id = pallets.getMapID(index)
    if id ~= nil then
      return getIfPresent(id, "colors")
    end
    return nil
  end

  --[[--
    Gets the number of pallets loaded

    @return  Number of pallets currently loaded
  ]]
  function pallets.getCount()
    return #pallets.indexMap
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

  --[[--
    Migrates missing pallets and overrides the vanilla functions
  ]]
  function pallets.migrateHooks()
    -- swap ourself for the global, to ensure we use the latest list
    if pallet ~= CUSTOM_PALLETS then
      pallets = CUSTOM_PALLETS
    end

    -- if one of the two vanilla pallet functions is not ours, run migrations
    -- uses the global to ensure we migrate to the latest library version
    if GetColorCount ~= pallets.getCount or GetColorMap ~= pallets.getColorMap then
      -- first, clone any pallets we are missing into our array

      local totalPallets = GetColorCount()
      if totalPallets > pallets.getCount() then
        -- first, create a map from indexes to FURL names
        local furlIDs = {}
        if type(FURL_COLORS) == "table" then
          for name, index in pairs(FURL_COLORS) do
            -- FURL stores imageOffset instead of pallet index
            furlIDs[index+1] = name
          end
        end

        -- migrate any pallets we are missing
        for index = pallets.getCount()+1, totalPallets do
          -- first, ensure there is a color map there
          local colors = GetColorMap(index)
          if colors == nil then
            break
          end

          -- use the name from FURL as the ID if present, or fallback to index (vanilla pallets)
          local id = furlIDs[index] or index
          -- create the pallet data
          pallets.map[id] = {
            name = vanillaMapNames[i],
            colors = colors,
            index = index
          }
          -- add the index to the index map, this map may change later
          pallets.indexMap[index] = id
        end
      end

      -- override the vanilla functions with our copies
      GetColorMap = pallets.getColorMap
      GetColorCount = pallets.getCount
    end
  end

  --- List of all key names for indexes in the vanilla pallets structure
  local PALLET_KEYS = {
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
    Adds a new pallet to the game

    @param ...  Varargs table parameters for pallet data. Contains all the colors from PALLET_KEYS, plus:
           ID: Unique ID for this pallet
           Name: Human readible name, if unset defaults to ID
  ]]
  function pallets.addPallet(...)
    -- ensure this library is in charge of pallets
    pallets.migrateHooks()

    -- allow passing in multiple pallets at once, more efficient for animation reloading
    local datas = {...}
    for _, data in ipairs(datas) do
      -- validations
      assert(type(data) == "table", "Pallet data must be a table")
      assert(type(data.ID) == "string", "Invalid pallet, missing string ID")
      assert(data.Name == nil or type(data.Name) == "string", "Name must be a string")

      -- construct each of the pieces of the color
      local colors = {}
      for i, key in ipairs(PALLET_KEYS) do
        if type(data[key]) ~= "table" then
          error("Invalid pallet, missing key " .. key)
        end
        assert(#data[key] == 3, "Color must contain three integers")
        colors[i] = GL_Color(unpack(data[key]))
      end

      -- create the pallet
      local index = pallets.getCount() + 1
      pallets.map[data.ID] = {
        name = data.Name,
        colors = colors,
        index = index
      }
      pallets.indexMap[index] = data.ID
    end

    -- reload animations to update the color count
    -- only need to reload once for all the pallets
    updateAnimations(#datas)
  end
end

-- take control of the vanilla functions
CUSTOM_PALLETS.migrateHooks()

-- return library, in general the global should not be used outside this script
return CUSTOM_PALLETS
