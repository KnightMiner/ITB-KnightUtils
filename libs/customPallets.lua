------------------------------------------------------------------------------------
-- Custom Mech Pallet Library
-- v0.1
-- https://github.com/KnightMiner/ITB-KnightUtils/blob/master/libs/customPallets.lua
------------------------------------------------------------------------------------
-- Contains helpers to make custom mech pallets
------------------------------------------------------------------------------------

-- Current library version, so we can ensure the latest library version is used
local VERSION = "0.1"

-- if we have a global that is newer than or the same version as us, use that
-- if our version is newer or its not yet loaded, load the library
if CUSTOM_PALLETS == nil or not modApi:isVersion(VERSION, CUSTOM_PALLETS.version) then
  local pallets = {version = VERSION}

  -- update the global variable, shared among all copies of this script
  -- if reloading, just outright replace the old copy, vanilla migration currently handles old lib migration
  CUSTOM_PALLETS = pallets

  -- Need to create a local copy of the vanilla colormap in order to replace animations
  local colorMaps = {}
  -- Human readible names fr all color maps
  local colorMapNames = {
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

  -- copying all preexisting colors into an array
  -- this works for vanilla or FURL
  for i = 1, GetColorCount() do
    colorMaps[i] = GetColorMap(i)
  end

  ----------------------
  -- Helper functions --
  ----------------------

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
    Updates all animation objects to the updated color count.
    Since we increased the pallet count, the height needs to be correct to correctly split the image
  ]]
  local function updateAnimations()
    local count = GetColorCount()
    local update = count - 1

    -- update base objects, mostly needed for MechIcon as it does not use a units/player image path
    ANIMS.MechColors = count
    ANIMS.MechUnit.Height = count
    ANIMS.MechIcon.Height = count

    -- update other objects that use MechUnit
    for name, anim in pairs(ANIMS) do
      -- images loaded in units/player generate a vertical frame for each unit
      if type(anim) == "table" and anim.Height == update and usesPallets(anim) then
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

  -----------------------
  -- Vanilla overrides --
  -----------------------

  -- These two functions are equivelent to the vanilla GetColorMap and GetColorCount respectively
  -- Difference is they are called through this library, and they may be outdated if another
  -- library (such as FURL) overrides the functions
  -- Calling pallets.migrateHooks() will migrate either vanilla or another library to this library,
  -- then ensure this library's functions are used

  --[[--
    Gets the colormap for the given ID

    @param id  Colormap numeric ID. Vanilla are 1-9
    @return  Colormap at the given ID
  ]]
  function pallets.getColorMap(id)
    assert(type(id) == "number", "ID must be a number")
    return colorMaps[id]
  end

  --[[--
    Gets the number of pallets loaded

    @return  Number of pallets currently loaded
  ]]
  function pallets.getCount()
    return #colorMaps
  end

  -----------------------
  -- Library functions --
  -----------------------

  --[[--
    Gets the colormap based on the given image offset.
    Used since there is a difference between the colors in a pawn and the colors in this library.

    @param offset  ImageOffset from the pawn properties
    @return  Colormap for the given ImageOffset
  ]]
  function pallets.getPawnColor(offset)
    assert(type(offset) == "number", "Offset must be a number")
    return pallets.getColorMap(offset + 1)
  end

  --[[--
    Gets the the name of the pallet with the given ID

    @param id  Colormap numeric ID. Vanilla are 1-9
    @return  Name of the colormap at the given ID, or nil if the ID does not exist
  ]]
  function pallets.getColorMapName(id)
    assert(type(id) == "number", "ID must be a number")
    return colorMapNames[id]
  end

  --[[--
    Gets the the name of the pallet with the given ImageOffset.
    Used since there is a difference between the colors in a pawn and the colors in this library.

    @param offset  ImageOffset from the pawn properties
    @return  Name of the colormap for the given ImageOffset, or nil if the ImageOffset has no name
  ]]
  function pallets.getPawnColorName(offset)
    assert(type(offset) == "number", "Offset must be a number")
    return pallets.getColorMapName(offset + 1)
  end

  --[[--
    Adds a new pallet to the game

    @param name  Human readible pallet name, for a potential pallet chooser UI
    @param data  Pallet data, see PALLET_NAMES for required keys
    @return Image offset to use this pallet
  ]]
  function pallets.addPallet(name, data)
    -- validations
    assert(type(name) == "string", "Name must be a string")
    assert(type(data) == "table", "Pallet data must be a table")
    assert(handlesPallets(), "Pallets are not handled by this library, run pallets.migrateHooks() to fix this")

    -- construct each of the pieces of the color
    local pallet = {}
    for index, key in ipairs(PALLET_KEYS) do
      if type(data[key]) ~= "table" then
        error("Invalid pallet, missing key " .. key)
      end
      pallet[index] = GL_Color(unpack(data[key]))
    end

    -- add the colormap to the table
    local palletId = #colorMaps + 1
    colorMapNames[palletId] = name
    colorMaps[palletId] = pallet

    -- reload animations to update the color count
    updateAnimations()

    -- image offset is zero indexed instead of 1 indexed, so subtract one to make the return useful
    return palletId - 1
  end

  --[[--
    Overrides vanilla functions if needed, ensuring our version of GetColorCount and GetColorMap are used
  ]]
  function pallets.migrateHooks()
    -- if one of the two vanilla pallet functions is not ours, run migration
    -- handles both vanilla and FURL migration
    if not handlesPallets() then
      -- first, clone any pallets we are missing into our array
      if GetColorCount() > pallets.getCount() then
        for i = pallets.getCount()+1, GetColorCount() do
          colorMaps[i] = GetColorMap(i)
        end
      end

      -- override the vanilla functions with our copies
      GetColorMap = pallets.getColorMap
      GetColorCount = pallets.getCount

      -- migrate names from FURL
      if type(FURL_COLORS) == "table" then
        -- FURL stores name = imageoffset pairs
        for name, offset in pairs(FURL_COLORS) do
          if type(offset) == "number" then
            local id = offset + 1
            if colorMapNames[id] == nil then
              -- ensure name is a string
              if type(name) ~= "string" then
                name = tostring(name)
              end
              -- copy the name into our list
              colorMapNames[id] = name
            end
          end
        end
      end
    end
  end
end

-- take control of the vanilla functions
-- otherwise pallets.addPallet() won't do anything useful
CUSTOM_PALLETS.migrateHooks()

-- return library, in general the global should not be used outside this script
return CUSTOM_PALLETS
