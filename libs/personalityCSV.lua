----------------------------------------------------------------------------------------------
-- Personality CSV Parser
-- v0.1
-- https://github.com/KnightMiner/ITB-KnightUtils/blob/master/libs/personalityCSV.lua
----------------------------------------------------------------------------------------------
-- Contains helpers to parse the personality CSV files used in 1.1 into the Personality object
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
	@param start  First row of dialog data in the CSV file
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
	for index = 4, #ids do
		local id = ids[index]
		if id ~= "" then
			-- if missing from the global, create the personaltiy object for that pilot
			if Personality[id] == nil then
				-- third row of CSV lets you clone from another pilot
				local parent = ret[3][index]
				if parent == "" or Personality[parent] == nil then
					Personality[id] = PilotPersonality:new()
				else
					Personality[id] = Personality[parent]:new()
				end
				-- other data: row 1 is internal names, row 4 display names
				-- mainly different for recruits, they have a blank display name to randomly generate
				Personality[id].Label = ret[1][index]
				Personality[id].Name = ret[4][index]
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
			for col = 4, #row do
				-- skip missing texts
				local text = row[col]
				local id = ids[col]
				if text ~= "" and pilotId ~= "" then
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

--[[--
  Parses a CEO dialog CSV file and extracts personality data
	@param path  Path to the CSV file, relative to the mod root
]]
function personality.loadCEOs(path)
	personality.load(path, 3)
end

--[[--
  Parses a pilot CSV file and extracts personality data
	@param path  Path to the CSV file, relative to the mod root
]]
function personality.loadPilots(path)
	personality.load(path, 8)
end

return personality
