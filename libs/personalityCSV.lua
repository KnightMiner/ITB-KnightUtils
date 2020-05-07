----------------------------------------------------------------------------------------------
-- Personality CSV Parser
-- v0.2
-- https://github.com/KnightMiner/ITB-KnightUtils/blob/master/libs/personalityCSV.lua
----------------------------------------------------------------------------------------------
-- Contains helpers to parse the personality CSV files used in 1.1 into the Personality object
----------------------------------------------------------------------------------------------
-- Column Format:
-- * First column is for categories, it is ignored
-- * Second column contains dialog IDs
-- * From the third column onwards, any columns with a value in the second row are a pilot
-- Row Format:
-- * First row in the pilot's debug name
-- * Second row is the pilot's
-- * Third row is the parent pilot, lets you inherit dialog from another pilot
--   * If the value you pass for the start parameter is 3, no parents supported
-- * Fourth row is the pilot's in game name. Leave blank for a random name (recruits)
--   * If the value you pass for start is less than 4, uses first row
-- Each cell contains the dialog text. Comma separate for multiple options to randomly choose.
----------------------------------------------------------------------------------------------
local ftcsv = require("scripts/personalities/ftcsv")
local resourcePath = mod_loader.mods[modApi.currentMod].resourcePath

--[[--
  Splits a string into parts

	@param str  String to split
	@parma pat  Pattern for separators
	@return table of split strings
]]
local function split(str, pat)
	local t = {}
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(t,cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end

--- Recreate personality class as its private in vanilla
local PilotPersonality = {Label = "NULL"}
CreateClass(PilotPersonality)

--[[--
  Gets the pilot dialog for the given event
	@param event  Event name
	@return Dialog for event
]]
function PilotPersonality:GetPilotDialog(event)
	if self[event] ~= nil then
		if type(self[event]) == "table" then
			return random_element(self[event])
		end

		return self[event]
	end

	LOG("No pilot dialog found for "..event.." event in "..self.Label)
	return ""
end

--- final API object
local personality = {}

--[[--
  Parses a CSV file and extracts personality data

	@param path   Path to the CSV file, relative to the mod root
	@param start  First row of dialog data in the CSV file.
	              In vanilla, pilots.csv starts at 8, missions.csv at 3
]]
function personality.load(path, start)
	-- start the path in the mod folder, appending .csv
	local localPath = resourcePath .. path .. ".csv"
	local fullPath = GetWorkingDir() .. localPath
	-- load in the data file
	local ret = ftcsv.parse(fullPath, ',', {headers = false})
	-- nice error if file is missing
	if ret == nil then
		error("Failed to load file " .. localPath)
	end

	-- first two rows in the CSV are pilot names and IDs
	local ids = ret[2]

	-- iterate through each pilot, fetching dialog
	for index = 3, #ids do
		local id = ids[index]
		if id ~= "" then
			-- if missing from the global, create the personaltiy object for that pilot
			if Personality[id] == nil then
				-- third row of CSV lets you clone from another pilot, skip if start too early
				local parent = start > 3 and ret[3][index] or ""
				if parent == "" or Personality[parent] == nil then
					Personality[id] = PilotPersonality:new()
				else
					Personality[id] = Personality[parent]:new()
				end
				-- row 1 is debug name, row 4 display names, if start too early use debug name as pilot name
				-- mainly different for recruits, they have a blank display name to randomly generate
				Personality[id].Label = ret[1][index]
				Personality[id].Name = ret[start > 4 and 4 or 1][index]
			end
		end
	end

	-- loop through each row
	for rowIndex = start, #ret do
		-- fetch row from CSV
		local row = ret[rowIndex]
		-- internal dialog trigger is in column 2
		local trigger = row[2]
		if trigger ~= "" then
			-- loop through each column in the row
			for col = 3, #row do
				-- skip missing texts
				local text = row[col]
				local id = ids[col]
				if text ~= "" and id ~= "" then
					-- trim trailing comma
					if text:sub(#text) == "," then
						text = text:sub(1,#text-1)
					end
					-- remove non-ascii characters
					text = text
						:gsub("“",""):gsub("”","")
						:gsub("‘","'"):gsub("’","'")
						:gsub("…","..."):gsub("–","-")
					-- split texts on commas allowing them to have multiple sayings
					local final_texts = {text}
					-- except region names, they don't split those for some reason
          if trigger ~= "Region_Names" then
          	final_texts = split(text,"\",%s*\n*")
          end
					-- remove quotation marks around the final string
					for i, v in ipairs(final_texts) do
						final_texts[i] = string.gsub(v,"\"","")
					end
					-- save this text into the personality
					Personality[id][trigger] = final_texts
				end
			end
		end
	end
end

return personality
