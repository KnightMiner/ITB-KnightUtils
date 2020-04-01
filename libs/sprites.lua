------------------------------------------------------------------------------
-- Sprite Loader Library
-- v0.1
-- https://github.com/KnightMiner/ITB-KnightUtils/blob/master/libs/sprites.lua
------------------------------------------------------------------------------
-- Contains helpers to load sprites and create animations
-- Currently in Beta, subject to change and a bit incomplete
------------------------------------------------------------------------------
local sprites = {}
local mod = mod_loader.mods[modApi.currentMod]

--[[--
  Adds a sprite to the game

  @param path      Base sprite path
  @param filename  File to add
]]
function sprites.addSprite(path, filename)
  modApi:appendAsset(
    string.format("img/%s/%s.png", path, filename),
    string.format("%simg/%s/%s.png", mod.resourcePath, path, filename)
  )
end

--[[--
  Adds sprites for an achievement, adding both unlocked and greyed out

  @param name        Achievement base filename
  @param objectives  Optional list of objectives images to load, for use with GetImg
]]
function sprites.addAchievement(name, objectives)
  sprites.addSprite("achievements", name)
  sprites.addSprite("achievements", name .. "_gray")
  -- add any extra objective images requested
  if objectives then
    for _, objective in pairs(objectives) do
      sprites.addSprite("achievements", name .. "_" .. objective)
    end
  end
end

--[[--
  Converts a name into a path to a mech sprite

  @param name  Mech sprite name
  @return  Sprite path
]]
local function spritePath(path, name)
  return string.format("%s/%s.png", path, name)
end

--[[--
  Adds a sprite animations

  @param path      Base sprite path
  @param name      Animation name and filename
  @param settings  Animation settings, such as positions and frametime
]]
function sprites.addAnimation(path, name, settings)
  sprites.addSprite(path, name)
  settings = settings or {}
  settings.Image = spritePath(path, name)

  -- base animation is passed in settings
  local base = settings.Base or "Animation"
  settings.Base = nil

  -- create the animation
  ANIMS[name] = ANIMS[base]:new(settings)
end

--[[
  Adds the specific animation for a mech

  @param name        Mech name
  @param key         Key in object containing animation data
  @param suffix      Suffix for this animation type
  @param fileSuffix  Suffix used in the filepath. If unset, defaults to suffix
]]
local function addMechAnim(name, object, suffix, fileSuffix)
  if object then
    -- default fileSuffix to the animation suffix
    fileSuffix = fileSuffix or suffix

    -- add the sprite to the resource list
    local filename = name .. fileSuffix
    sprites.addSprite("units/player", filename)

    -- add the mech animation to the animation list
    object.Image = spritePath("units/player", filename)
    ANIMS[name..suffix] = ANIMS.MechUnit:new(object);
  end
end

--[[--
  Adds a list of resources to the game

  @param sprites  varargs parameter of all mechs to add
]]
function sprites.addMechs(...)
  for _, object in pairs({...}) do
    local name = object.Name

    -- these types are pretty uniform
    addMechAnim(name, object.Default,         ""                     )
    addMechAnim(name, object.Animated,        "a",        "_a"       )
    addMechAnim(name, object.Broken,          "_broken"              )
    addMechAnim(name, object.Death,           "d",        "_death"   )
    addMechAnim(name, object.Submerged,       "w",        "_w"       )
    addMechAnim(name, object.SubmergedBroken, "w_broken", "_w_broken")

    -- icon actually uses 2 images, and uses a different object type
    if object.Icon then
      -- firstly, we have the extra hanger sprite
      sprites.addSprite("units/player", name .. "_h")

      -- add the regular no shadow sprite
      local iconname = name .. "_ns"
      sprites.addSprite("units/player", iconname)

      -- second, we use MechIcon instead of MechUnit
      object.Icon.Image = spritePath("units/player", iconname)
      ANIMS[iconname] = ANIMS.MechIcon:new(object.Icon);
    end
  end
end

return sprites
