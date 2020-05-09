---------------------------------------------------------------------------
-- Weapon Shop Library
-- v0.4
-- https://github.com/KnightMiner/ITB-KnightUtils/blob/master/libs/shop.lua
---------------------------------------------------------------------------
-- Contains helpers to add weapons to the shop and to create a shop UI
---------------------------------------------------------------------------

-- Current library version, so we can ensure the latest library version is used
local VERSION = "0.4"

-- if we have a global that is newer than or the same version as us, use that
-- if our version is newer or its not yet loaded, load the library
if WEAPON_SHOP == nil or not modApi:isVersion(VERSION, WEAPON_SHOP.version) then
  -- migrate old version or build new data object
  local shop = WEAPON_SHOP or {}
  WEAPON_SHOP = shop

  -- set needed properties
  shop.version = VERSION
  -- format: id -> enabled
  shop.weapons = shop.weapons or {}

  ---------
  -- API --
  ---------

  --[[--
    Adds a weapon to the shop
    @param id       Weapon ID to add
    @param enabled  If true, the weapon will be enabled (default). False it will be disabled
  ]]
  function shop:addWeapon(id, enabled)
    -- backwards compability, extract ID and enabled from the table
    if type(id) == "table" then
      enabled = not id.default or id.default.enabled
      id = id.id
    end
    assert(type(id) == "string", "ID must be a string")
    -- default enabled to true
    if enabled == nil then
      enabled = true
    end
    assert(type(enabled) == "boolean", "Enabled must be a boolean")
    -- if already defined, skip redefining
    if self.weapons[id] ~= nil then
      return
    end
    -- add the weapon
    self.weapons[id] = enabled
  end

  --[[--
    Checks if a weapon has been unlocked
    @param id  Weapon ID to check
    @return true if the weapon is unlocked, false otherwise
  ]]
  local function isUnlocked(id)
    -- must exist
    local weapon = _G[id]
    if type(weapon) ~= "table" then
      return false
    end
    -- no unlocked function means it is unlocked
    if not weapon.GetUnlocked then
      return true
    end
    -- catch errors in getUnlocked, in case the code they write is unsafe
    -- means this lib does not crash
    local unlocked = false
    local ran, error = pcall(function()
      unlocked = weapon:GetUnlocked()
    end)
    if not ran then
      LOG("Unlock check failed for " .. id .. ":\n" .. error)
    end
    return unlocked
  end

  --[[--
    Gets a list of all enabled weapons
    @return  Table containg all enabled weapons
  ]]
  function shop:getWeaponDeck()
    -- start building a deck
    local deck = {}
    for id, enabled in pairs(self.weapons) do
      if enabled and isUnlocked(id) then
        table.insert(deck, id)
      end
    end
    return deck
  end

  --------
  -- UI --
  --------
  -- dimensions of a button
  local CHECKBOX = 25
  local TEXT_PADDING = 18
  local WEAPON_WIDTH = 120 + 8
  local WEAPON_HEIGHT = 80 + 8 + TEXT_PADDING
  -- button spacing
  local WEAPON_GAP = 16
  local CELL_WIDTH = WEAPON_WIDTH + WEAPON_GAP
  local CELL_HEIGHT = WEAPON_HEIGHT + WEAPON_GAP
  local PADDING = 12
  local BUTTON_HEIGHT = 40

  --- Cache of recolored images for each palette ID
  local surfaces = {}

  --- Extra UI components
  local WEAPON_FONT = sdlext.font("fonts/NunitoSans_Regular.ttf", 10)
  local MOD_COLOR = sdl.rgb(50, 125, 75)
  --- Like DecoCAligned, but absolute instead of relative
  local DecoCenter = Class.inherit(UiDeco)
  function DecoCenter:new(hSize, tOffset)
  	UiDeco.new(self)
  	self.cOffset = -hSize / 2
  	self.tOffset = tOffset or 0
  end
  function DecoCenter:draw(screen, widget)
  	widget.decorationx = widget.rect.w/2 + self.cOffset
  	widget.decorationy = self.tOffset
  end

  --- Header with a smaller font size
  local classHeader = DecoFrameHeader()
  classHeader.font = deco.uifont.default.font
  classHeader.height = 20

  --[[--
    Gets the name for a weapon
    @param id  Weapon ID
    @return Weapon name
  ]]
  local function getWeaponKey(id, key)
    assert(type(id) == "string", "ID must be a string")
  	assert(type(key) == "string", "Key must be a string")
    local textId = id .. "_" .. key
    if IsLocalizedText(textId) then
      return GetLocalizedText(textId)
    end
    return _G[id] and _G[id][key] or id
  end

  --[[--
    Gets the image for the given weapon, or creates one if missing
    @param id  weapon ID
    @return  Surface for this palette button
  ]]
  local function getOrCreateWeaponSurface(id)
    assert(id ~= nil, "ID must be defined")
    local surface = surfaces[id]
  	if not surface then
      local weapon = _G[id]
      assert(type(weapon) == "table", "Missing weapon from shop")
  		surface = sdlext.getSurface({
  			path = "img/" .. weapon.Icon,
  			scale = 2
  		})
  		surfaces[id] = surface
  	end
    return surface
  end

  --- List of all available weapons in vanilla
  local VANILLA_WEAPONS = {
  	"Prime_Punchmech", "Prime_Lightning", "Prime_Lasermech", "Prime_ShieldBash",
  	"Prime_Rockmech", "Prime_RightHook", "Prime_RocketPunch", "Prime_Shift",
  	"Prime_Flamethrower", "Prime_Areablast", "Prime_Spear", "Prime_Leap",
  	"Prime_SpinFist", "Prime_Sword",  "Prime_Smash",
    "Brute_Tankmech", "Brute_Jetmech", "Brute_Mirrorshot", "Brute_PhaseShot",
    "Brute_Grapple", "Brute_Shrapnel", "Brute_Sniper", "Brute_Shockblast",
  	"Brute_Beetle", "Brute_Unstable", "Brute_Heavyrocket", "Brute_Splitshot",
  	"Brute_Bombrun", "Brute_Sonic",
    "Ranged_Artillerymech", "Ranged_Rockthrow", "Ranged_Defensestrike", "Ranged_Rocket",
  	"Ranged_Ignite", "Ranged_ScatterShot", "Ranged_BackShot", "Ranged_Ice",
  	"Ranged_SmokeBlast", "Ranged_Fireball", "Ranged_RainingVolley", "Ranged_Wide",
  	"Ranged_Dual",
    "Science_Pullmech", "Science_Gravwell", "Science_Swap", "Science_Repulse",
  	"Science_AcidShot", "Science_Confuse", "Science_SmokeDefense", "Science_Shield",
  	"Science_FireBeam", "Science_FreezeBeam", "Science_LocalShield",
  	"Science_PushBeam",
    "Support_Boosters", "Support_Smoke", "Support_Refrigerate", "Support_Destruct",
    "DeploySkill_ShieldTank", "DeploySkill_Tank", "DeploySkill_AcidTank", "DeploySkill_PullTank",
    "Support_Force", "Support_SmokeDrop", "Support_Repair", "Support_Missiles",
  	"Support_Wind", "Support_Blizzard",
    "Passive_FlameImmune", "Passive_Electric", "Passive_Leech", "Passive_MassRepair",
  	"Passive_Defenses", "Passive_Burrows", "Passive_AutoShields", "Passive_Psions",
  	"Passive_Boosters", "Passive_Medical", "Passive_FriendlyFire", "Passive_ForceAmp",
    "Passive_CritDefense",
  }
  local VANILLA_LOOKUP = {}
  for _, id in ipairs(VANILLA_WEAPONS) do
  	VANILLA_LOOKUP[id] = true
  end

  --- Speccial values for the preset dropdown
  local PRESET_VANILLA = "Vanilla"
  local PRESET_RANDOM = "Random"
  local PRESET_NEW = "New"
  local PRESET_WIDTH = 2
  -- any letter works as a preset
  local ALL_PRESETS = {}
  for i = 1, 10 do ALL_PRESETS[i] = string.char(64+i) end

  --[[--
    Logic to create the actual weapn UI
  ]]
  local function createUI()
    -- load old config and available presets, used for the new item display
    local oldConfig = {}
    local presets = {}
    sdlext.config("modcontent.lua", function(config)
      oldConfig = config.shopWeaponsEnabled or {}
      if config.shopWeaponPresets ~= nil then
        for key in pairs(config.shopWeaponPresets) do
          table.insert(presets, key)
        end
      end
    end)
    -- if not up to Z, support new presets
    table.sort(presets)
    if #presets < #ALL_PRESETS then
      table.insert(presets, PRESET_NEW)
    end
    table.insert(presets, 1, PRESET_VANILLA)
    table.insert(presets, 2, PRESET_RANDOM)

    --- list of all weapon buttons in the UI
    local buttons = {}

    --- Called on exit to save the weapon order
    local function onExit(self)
  		-- update in library
      local enabled = {}
  		local any = false
  		for _, button in ipairs(buttons) do
  			WEAPON_SHOP.weapons[button.id] = button.checked
  			enabled[button.id] = button.checked
  			if button.checked then any = true end
  		end
  		-- no weapons selected will fallback to vanilla logic, so just give vanilla
  		if not any then
  			for _, id in ipairs(VANILLA_WEAPONS) do
  				WEAPON_SHOP.weapons[id] = true
  				enabled[id] = true
  			end
  		end
  		-- update in config
      sdlext.config("modcontent.lua", function(config)
        config.shopWeaponsEnabled = enabled
      end)
    end

  	--- saves a preset to the config file
    local setPreset --- function will be defined later
  	local function savePreset(presetId)
      -- no saving vanilla/random
      if presetId == PRESET_VANILLA or presetId == PRESET_RANDOM then
        return
      end
      -- if new, get a new preset identifier
      if presetId == PRESET_NEW then
        -- its just the first unset preset, luckily they are in alphabetical order
        for _, presetCheck in ipairs(ALL_PRESETS) do
          if not list_contains(presets, presetCheck) then
            presetId = presetCheck
            break
          end
        end
        assert(presetId ~= PRESET_NEW)
        -- add to the dropdown
        table.insert(presets, #presets, presetId)
        setPreset(presetId)
        -- if full, remove new
        if #presets == #ALL_PRESETS + 2 then
          remove_element(PRESET_NEW, presets)
        end
      end
  		-- build data to save as an array
  		local enabled = {}
  		local any = false
  		for _, button in ipairs(buttons) do
  			if button.checked then
  				enabled[button.id] = true
  				any = true
  			end
  		end
  		-- if nothing, clear the preset
  		if not any then
        enabled = nil
        -- bring back new if missing (too many presets)
        if presets[#presets] ~= PRESET_NEW then
          table.insert(presets, PRESET_NEW)
        end
        -- remove preset from dropdown
        setPreset(PRESET_NEW)
        remove_element(presetId, presets)
  		end
  		-- update the preset in config
  		sdlext.config("modcontent.lua", function(config)
  			if enabled ~= nil and config.shopWeaponPresets == nil then
  				config.shopWeaponPresets = {}
  			end
  			config.shopWeaponPresets[presetId] = enabled
  		end)
  	end

  	--- loads a preset from the config file
  	local function loadPreset(presetId)
      if presetId == PRESET_NEW then
        return false
      end
      -- randomly enable preset
      if presetId == PRESET_RANDOM then
        for _, button in ipairs(buttons) do
          button.checked = math.random() > 0.5
        end
        return true
      end
  		-- load preset from config
  		local enabled
  		-- vanilla is a preset
  		if presetId == PRESET_VANILLA then
  			enabled = VANILLA_LOOKUP
  		else
  			-- load preset from config
  			sdlext.config("modcontent.lua", function(config)
  				if config.shopWeaponPresets ~= nil then
  					enabled = config.shopWeaponPresets[presetId]
  				end
  			end)
  			-- if nothing, use an empty map
  			if enabled == nil then
  				enabled = {}
  			end
  		end
  		-- update buttons based on the preset
  		for _, button in ipairs(buttons) do
  			button.checked = enabled[button.id] or false
  		end
  		return true
  	end

    -- main UI logic
    sdlext.showDialog(function(ui, quit)
      ui.onDialogExit = onExit

      -- main frame
      local frametop = Ui()
        :width(0.8):height(0.8)
        :posCentered()
        :caption("Select Weapons")
        :decorate({ DecoFrameHeader(), DecoFrame() })
        :addTo(ui)
      -- scrollable content
      local scrollArea = UiScrollArea()
        :width(1):height(1)
        :addTo(frametop)
      -- define the window size to fit as many weapons as possible, comes out to about 5
      local weaponsPerRow = math.floor(ui.w * frametop.wPercent / CELL_WIDTH)
      frametop
        :width((weaponsPerRow * CELL_WIDTH + (2 * PADDING)) / ui.w)
        :posCentered()
      ui:relayout()

      -- add button area on the bottom
      local line = Ui()
          :width(1):heightpx(frametop.decorations[1].bordersize)
          :decorate({ DecoSolid(frametop.decorations[1].bordercolor) })
          :addTo(frametop)
      local buttonLayout = UiBoxLayout()
          :hgap(20)
          :padding(24)
          :width(1)
          :addTo(frametop)
      buttonLayout:heightpx(BUTTON_HEIGHT + buttonLayout.padt + buttonLayout.padb)
      ui:relayout()
      scrollArea:heightpx(scrollArea.h - (buttonLayout.h + line.h))
      line:pospx(0, scrollArea.y + scrollArea.h)
      buttonLayout:pospx(0, line.y + line.h)

  		-------------
  		-- Buttons --
  		-------------
      local enableSaveLoad

      --- Button to enable all weapons
  		local size = weaponsPerRow > 6 and 1.5 or 1
      local enableAllButton = Ui()
        :widthpx(WEAPON_WIDTH * size):heightpx(BUTTON_HEIGHT)
        :settooltip("Enables all weapons")
        :decorate({
          DecoButton(),
          DecoAlign(0, 2),
          DecoText("Enable All"),
        })
        :addTo(buttonLayout)
      function enableAllButton.onclicked()
        for _, button in ipairs(buttons) do
          button.checked = true
        end
        enableSaveLoad(true)
        return true
      end
      --- Button to disable all weapons
      local disableAllButton = Ui()
        :widthpx(WEAPON_WIDTH * size):heightpx(BUTTON_HEIGHT)
        :settooltip("Disables all weapons")
        :decorate({
          DecoButton(),
          DecoAlign(0, 2),
          DecoText("Disable All"),
        })
        :addTo(buttonLayout)
      function disableAllButton.onclicked()
        for _, button in ipairs(buttons) do
          button.checked = false
        end
        enableSaveLoad(true)
        return true
      end

  		-- add spacer before preset buttons
  		-- width is crafted to right align the preset buttons
  		Ui()
  			:widthpx(frametop.w                          -- button area width
  				- buttonLayout.padl - buttonLayout.padr    -- padding on sides
  				- WEAPON_WIDTH * (PRESET_WIDTH + size * 3) -- all buttons, 2 are half sized, one fixed
  				- buttonLayout.gapHorizontal * 5)          -- gap between buttons
  			:heightpx(BUTTON_HEIGHT):addTo(buttonLayout)
  		-- preset dropdown
  		local presetDropdown = UiDropDown(presets)
        :widthpx(WEAPON_WIDTH * PRESET_WIDTH):heightpx(BUTTON_HEIGHT)
        :settooltip("Select weapons preset")
  			:decorate({
  				DecoButton(),
  				DecoAlign(0, 2),
  				DecoText("Preset:"),
  				DecoDropDownText(nil, nil, nil, 33),
  				DecoAlign(0, -2),
  				DecoDropDown(),
  			})
  			:addTo(buttonLayout)
  		function presetDropdown:destroyDropDown()
  			UiDropDown.destroyDropDown(self)
        enableSaveLoad(true)
  		end
      --- localized earlier before savePreset
      function setPreset(id)
        presetDropdown.value = id
      end
  		--- loads the current preset
  		size = size / 2
  		local loadPresetButton = Ui()
  			:widthpx(WEAPON_WIDTH * size):heightpx(BUTTON_HEIGHT)
  			:settooltip("Loads the current preset, replacing the selected weapons")
  			:decorate({
  				DecoButton(),
  				DecoAlign(0, 2),
  				DecoText("Load"),
  			})
  			:addTo(buttonLayout)
  		function loadPresetButton.onclicked()
  			loadPreset(presetDropdown.value)
        enableSaveLoad(false)
  			return true
  		end
  		--- Saves the current preset
      local savePresetButton = Ui()
        :widthpx(WEAPON_WIDTH * size):heightpx(BUTTON_HEIGHT)
        :settooltip("Saves the current weapons to the selected preset. If nothing is checked, deletes the current preset.")
        :decorate({
          DecoButton(),
          DecoAlign(0, 2),
          DecoText("Save"),
        })
        :addTo(buttonLayout)
  		savePresetButton.disabled = true
      function savePresetButton.onclicked()
  			local value = presetDropdown.value
  			if value ~= PRESET_VANILLA then
        	savePreset(value)
  			end
        enableSaveLoad(false)
        return true
      end
      --- Define function to enable/disable the buttons, localized earlier
      function enableSaveLoad(enable)
        local value = presetDropdown.value
        if enable then
          -- vanilla and random cannot save, new cannot load
          savePresetButton.disabled = value == PRESET_VANILLA or value == PRESET_RANDOM
          loadPresetButton.disabled = value == PRESET_NEW
        else
          -- random can always load
          savePresetButton.disabled = true
          loadPresetButton.disabled = value ~= PRESET_RANDOM
        end
      end

  		-------------
  		-- Weapons --
  		-------------

      --- sort the buttons by class
      local classes = {}
      for id, enabled in pairs(WEAPON_SHOP.weapons) do
        if isUnlocked(id) then
          local weapon = _G[id]
          -- first, determine the weapon class
          local class
    			if oldConfig[id] == nil and not VANILLA_LOOKUP[id] then
    				class = "new"
    			elseif weapon.Passive ~= "" then
    				class = "Passive"
    			else
    				class = weapon:GetClass()
    				if class == "" then class = "Any" end
    			end
          -- if this is the first we have seen the class, make a group
          if classes[class] == nil then
    				if class == "new" then
    					classes[class] = {weapons = {}, name = GetLocalizedText("Upgrade_New"), sortName = "1"}
    				else
              local key = "Skill_Class" .. class
    	        classes[class] = {weapons = {}, name = IsLocalizedText(key) and GetLocalizedText(key) or class}
    				end
          end
          table.insert(classes[class].weapons, {id = id, name = getWeaponKey(id, "Name"), enabled = enabled})
        end
      end
      --- conver the map into a list and sort, plus sort the weapons
      local sortName = function(a, b) return (a.sortName or a.name) < (b.sortName or b.name) end
      local classList = {}
      for id, data in pairs(classes) do
        table.sort(data.weapons, sortName)
        table.insert(classList, data)
      end
      table.sort(classList, sortName)
      -- create a frame for each class
      local offset = 0
      for _, class in ipairs(classList) do
        -- 2 of the paddings is for the height, plus a little extra pading
        local height = math.ceil(#class.weapons / weaponsPerRow) * CELL_HEIGHT + 4 * PADDING
        local classArea = Ui()
          :width(1)
          :heightpx(height)
          :padding(PADDING)
          :pospx(0, offset)
          :caption(class.name)
          :decorate({ classHeader, DecoFrame() })
          :addTo(scrollArea)
        offset = offset + height
        --- Create a button for each weapon
        for index, weapon in pairs(class.weapons) do
  				local id = weapon.id
          local col = (index-1) % weaponsPerRow
          local row = math.floor((index-1) / weaponsPerRow)
  				local decoName = DecoText(weapon.name, WEAPON_FONT)
          local button = UiCheckbox()
            :widthpx(WEAPON_WIDTH):heightpx(WEAPON_HEIGHT)
            :pospx(CELL_WIDTH * col, CELL_HEIGHT * row)
            :settooltip(getWeaponKey(id, "Description"))
            :decorate({
              DecoButton(nil, not VANILLA_LOOKUP[id] and MOD_COLOR),
              DecoAlign(-4, (TEXT_PADDING / 2)),
              DecoSurface(getOrCreateWeaponSurface(weapon.id)),
              DecoCenter(CHECKBOX, WEAPON_HEIGHT / 2),
              DecoCheckbox(),
              DecoCenter(decoName.surface:w(), (decoName.surface:h() - WEAPON_HEIGHT) / 2 + 4),
              decoName,
            })
            :addTo(classArea)
          button.id = id
          button.checked = weapon.enabled
          --- enable the save and load buttons when we make a change
          function button:onclicked()
      			enableSaveLoad(true)
            return true
          end
          table.insert(buttons, button)
        end
      end
      ui:relayout()
    end)
  end

  ----------------
  -- Inititlize --
  ----------------

  --[[--
    Safely sets a value in an object
    @param value value to set
    @param data  data  data table to set
  ]]
  local function safeSet(value, data, ...)
    assert(type(data) == "table", "Data must be a table")
    local keys = {...}
    assert(#keys > 0, "Missing keys to set")
    for i = 1, #keys - 1 do
      local key = keys[i]
      -- nil means its missing
      if data[key] == nil then
        data[key] = {}
      -- non table means something went wrong, just stop so we don't corrupt
      elseif type(data[key]) ~= "table" then
        return
      end
      data = data[key]
    end
    -- finally, set the desired value
    data[keys[#keys]] = value
  end

  --[[--
    Checks for keys from the old shop library, for migration
    @param name  key name to check
    @return true if the key is from the old shop library
  ]]
  local function isKey(name)
    -- old shop lib starts all keys with opt_
    if name:sub(1, 4) ~= "opt_" then
      return false
    end
    local weaponId = name:sub(5)
    local weapon = _G[weaponId]
    return type(weapon) == "table" and weapon.GetSkillEffect
  end

  --[[--
    Called after all mods are initialized, should not be called by mods using this API
  ]]
  function shop:_modsInitialized()
    -- create the button in the mod config menu
    local button = sdlext.addModContent("", createUI)
    button.caption = "Select Shop Weapons"
    button.tip = "Select which weapons are available in runs from the shop, time pods, and perfect island bonuses. Will not have any affect in existing save games."

    -- add a getUnlocked function to skills
    if Skill.GetUnlocked == nil then
      function Skill:GetUnlocked()
        if self.Unlocked == nil then
          return true
        end
        return self.Unlocked
      end
    end

    -- allow setting a custom rarity, since the default logic ignores that key
    local oldSkillGetRarity = Skill.GetRarity
    function Skill:GetRarity()
      if self.CustomRarity ~= nil then
        assert(type(self.CustomRarity) == 'number')
        return math.max(0, math.min(4, self.CustomRarity))
      end
      return oldSkillGetRarity(self)
    end

    -- set config options for old versions of the shop lib to true, so we can find them
    sdlext.config("modcontent.lua", function(config)
      -- loop through mods config options
      for modId, modData in pairs(mod_loader.mod_options) do
        for _, option in ipairs(modData.options) do
          -- if its a checkbox, and is named in right form, set it
          if option.enabled ~= nil and isKey(option.id) then
            safeSet(true, config, "modOptions", modId, "options", option.id, "enabled")
          end
        end
      end
    end)
  end

  --[[--
    Called after all mods are loaded, should not be called by mods using this API
  ]]
  local loaded = false
  function shop:_modsLoaded()
    -- prevent running multiple times
    if loaded then
      return
    end
    loaded = true

    -- import weapons from other libraries and from vanilla
    local oldGame = GAME
    GAME = {}
    initializeDecks()
    local weapons = GAME.WeaponDeck
    GAME = oldGame
    for _, id in ipairs(weapons) do
      if shop.weapons[id] == nil then
        shop.weapons[id] = true
      end
    end

    -- override inititlize decks to pull from our list
    local oldInitializeDecks = initializeDecks
    function initializeDecks(...)
      oldInitializeDecks(...)

      GAME.WeaponDeck = shop:getWeaponDeck()
    end
    -- override get weapon drop to pull from our list during reshuffling
    local oldGetWeaponDrop = getWeaponDrop
    function getWeaponDrop(...)
      -- catch an empty deck before vanilla does
      if #GAME.WeaponDeck == 0 then
        GAME.WeaponDeck = shop:getWeaponDeck()
    		LOG("Reshuffling Weapon Deck!\n")
      end
      -- deck will never be empty, so call remainder of vanilla logic
      return oldGetWeaponDrop(...)
    end

    -- load in the config based on what should be enabled
    sdlext.config("modcontent.lua", function(config)
      for id, enabled in pairs(config.shopWeaponsEnabled) do
        if shop.weapons[id] ~= nil then
          shop.weapons[id] = enabled
        end
      end
    end)
  end

  --[[--
    Called during mod loading to attach the after load hook
  ]]
  function shop:load()
    if self._addedLoadedHook then
      return
    end
    self._addedLoadedHook = true
    modApi:addModsLoadedHook(function()
      shop:_modsLoaded()
    end)
  end

  -- add the mod init and loaded hooks, may have been added by an earlier library version so skip if already done
  if not shop._addedInitHook then
    shop._addedInitHook = true
    modApi:addModsInitializedHook(function()
      shop:_modsInitialized()
    end)
  end
end

return WEAPON_SHOP
