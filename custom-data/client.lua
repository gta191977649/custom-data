local localData = {} -- store our local (non-synced data)
local syncedData = {} -- store our synced data
local dataHandlers = {} -- store our data handlers
local playerElements = getElementByID("playerElements") -- we would need that aswell for binding handlers.
local otherElements = getElementByID("otherElements") -- we would need that aswell for binding handlers.

--[[
/***************************************************

***************************************************\
]]

function getCustomData(pElement, pKey, pIsLocal)
	local cachedTable = false -- store reference

	if pIsLocal then -- reference to local or synced data
		cachedTable = localData[pElement]
	else
		cachedTable = syncedData[pElement]
	end

	if cachedTable then -- check if such index exists?
		local wholeData = pKey == nil -- do we need whole data or certain key?

		return wholeData and cachedTable or cachedTable[pKey] -- return requested data
	end
end

--[[
/***************************************************

***************************************************\
]]

function getElementsByKey(pKey, pValue, pIsLocal, pMultipleResults)
	local cachedTable = false -- store reference
	local requestedElements = pMultipleResults and {} or false -- we want table or boolean, depending on 3rd argument
	local doesHaveData = false -- store whether element have data or not

	if pIsLocal then -- reference to local or synced data
		cachedTable = localData
	else
		cachedTable = syncedData
	end

	for element, _ in pairs(cachedTable) do -- loop through all elements
		doesHaveData = getCustomData(element, pKey, pIsLocal) -- search for the elements which meets conditions

		if doesHaveData then -- if so

			if pValue and pValue ~= doesHaveData then -- in case if we wanna filter also by value
				return false
			end

			if pMultipleResults then -- if we wanna multiple results
				requestedElements[#requestedElements + 1] = element
			else -- otherwise
				requestedElements = element
				break
			end
		end
	end

	return requestedElements -- return requested elements
end

--[[
/***************************************************

***************************************************\
]]

function setCustomData(pElement, pKey, pValue, pIsLocal, pOnServerEvent, pSyncer)
	local cachedTable = false -- reference to table
	local oldValue = false -- placeholder for old value

	if pIsLocal then -- whether is local or not
		cachedTable = localData[pElement] -- update reference

		if not cachedTable then -- if sub table doesn't exist...
			localData[pElement] = {} -- create it
			cachedTable = localData[pElement] -- update reference
		end
	else
		cachedTable = syncedData[pElement] -- update reference

		if not cachedTable then -- if sub table doesn't exist...
			syncedData[pElement] = {} -- create it
			cachedTable = syncedData[pElement] -- update reference
		end
	end

	oldValue = cachedTable[pKey] -- get old value for data handlers

	if pValue ~= oldValue then -- if data isn't equal, process it
		cachedTable[pKey] = pValue -- set our value

		handleDataChange(pElement, pKey, oldValue, pValue, pOnServerEvent, pSyncer) -- handle our functions (if there's any)
	end

	return pElement, pKey, pValue -- perhaps, you would need those values afterwards, so let's return them.
end

--[[
/***************************************************

***************************************************\
]]

function addDataHandler(pElementTypes, pKeys, pFunction, pOnServerEvent)
	local validTypes = type(pElementTypes) == "string" or type(pElementTypes) == "table" -- check if it's valid type
	local validKeys = type(pKeys) == "string" or type(pKeys) == "table" -- check if it's valid type
	local validFunction = type(pFunction) == "function" -- check if it's valid type
	local validEvent = type(pOnServerEvent) == "string" or type(pOnServerEvent) == "table" or not pOnServerEvent -- check if it's valid type

	if validTypes and validKeys and validFunction and validEvent then -- if all correct
		local elementType = false -- element type
		local currentHandler = false -- reference to table
		local currentSize = false -- new index for data

		local isKeysTable = type(pKeys) == "table" -- check if it's table
		local keysCount = isKeysTable and #pKeys or false -- if so, save keys count, otherwise make it boolean
		local requireKeyMatching = isKeysTable and keysCount > 0 or not isKeysTable -- check whether we need to verify key
		local newKeys = requireKeyMatching and {} or false -- if so, create table, otherwise make it boolean

		local isEventsTable = type(pOnServerEvent) == "table" -- check if it's table
		local eventsCount = isEventsTable and #pOnServerEvent or 0 -- if so, save events count - we will use them later
		local requireEventMatching = isEventsTable and eventsCount > 0 or not isEventsTable -- check whether we need to verify event
		local newEvents = requireEventMatching and {} or false -- if so, create table, otherwise make it boolean

		if requireKeyMatching then -- if we require key matching
			local keyName = false -- save key name here

			if isKeysTable then -- if key is passed as table
				for keyID = 1, keysCount do -- loop through each key
					keyName = pKeys[keyID] -- update variable
					newKeys[keyName] = true -- insert key name as index in new table
				end
			else -- otherwise
				newKeys[pKeys] = true -- ditto, but we don't need loop here
			end
		end

		if requireEventMatching then -- if we require event matching
			local eventName = false -- save event name here

			if isEventsTable then -- if event is passed as table
				for eventID = 1, eventsCount do -- loop through each event
					eventName = pOnServerEvent[eventID] -- update variable
					newEvents[eventName] = true -- insert event name as index in new table
				end
			else -- otherwise
				newEvents[pOnServerEvent] = true -- ditto, but we don't need loop here
			end
		end

		local packedData = {newKeys, newEvents, pFunction, requireKeyMatching, requireEventMatching} -- store our packed data
		local elementTypes = type(pElementTypes) -- check if it's string

		if elementTypes == "string" then -- if so
			currentHandler = dataHandlers[pElementTypes] -- store reference

			if not currentHandler then -- if such index doesn't exist...
				dataHandlers[pElementTypes] = {packedData} -- insert packed data
			else -- otherwise
				currentSize = #currentHandler + 1 -- get new index for data
				currentHandler[currentSize] = packedData -- insert packed data
			end
		else -- otherwise
			for typeID = 1, #pElementTypes do -- loop through given table
				elementType = pElementTypes[typeID] -- get element type
				currentHandler = dataHandlers[elementType] -- store reference

				if not currentHandler then -- if such index doesn't exist...
					dataHandlers[elementType] = {packedData} -- insert packed data
				else -- otherwise
					currentSize = #currentHandler + 1 -- get new index for data
					currentHandler[currentSize] = packedData -- insert packed data
				end
			end
		end

		return true
	end

	return false
end

--[[
/***************************************************

***************************************************\
]]

function handleDataChange(pElement, pKey, pOldValue, pNewValue, pOnServerEvent, pSyncer)
	local isValidElement = isElement(pElement) -- we want element to exist at the time when handler was processed

	if isValidElement then
		local elementType = getElementType(pElement) -- get our element type
		local elementHandlers = dataHandlers[elementType] -- check if there's any handler for this type of element

		if elementHandlers then -- yup, apparently there is something
			local handlerData = false -- remember, reuse it's always faster rather than recreating variable each time
			local handlerKeys = false -- remember, reuse it's always faster rather than recreating variable each time
			local handlerKey = false -- remember, reuse it's always faster rather than recreating variable each time
			local handlerServerEvent = false -- remember, reuse it's always faster rather than recreating variable each time
			local handlerFunction = false -- remember, reuse it's always faster rather than recreating variable each time
			local requireKeyMatching = false -- remember, reuse it's always faster rather than recreating variable each time
			local requireEventMatching = false -- remember, reuse it's always faster rather than recreating variable each time
			local isKeyEqual = false -- remember, reuse it's always faster rather than recreating variable each time
			local isEventEqual = false -- remember, reuse it's always faster rather than recreating variable each time

			for handlerID = 1, #elementHandlers do -- process our handlers by loop
				handlerData = elementHandlers[handlerID] -- cache target table to reduce indexing
				handlerKeys = handlerData[1] -- get our data
				handlerServerEvent = handlerData[2] -- get our data
				requireKeyMatching = handlerData[4] -- get our data
				requireEventMatching = handlerData[5] -- get our data

				isKeyEqual = requireKeyMatching and handlerKeys[pKey] or not requireKeyMatching and true or false -- verify whether key is required or not
				isEventEqual = requireEventMatching and handlerServerEvent[pOnServerEvent] or not requireEventMatching and true or false -- verify whether event is required or not

				if isKeyEqual and isEventEqual then -- if everything fine
					handlerFunction = handlerData[3] -- get our data
					handlerFunction(pElement, pKey, pOldValue, pNewValue, pOnServerEvent, pSyncer) -- process function
				end
			end
		end
	end
end

--[[
/***************************************************

***************************************************\
]]

function onClientDataHandler(pElement, pKey, pOldValue, pNewValue, pOnServerEvent, pSyncer)
	print("onClientDataHandler got triggered at key: "..pKey.." - syncer element: "..inspect(pSyncer))
end
addDataHandler("player", {"Key 2", "Key"}, onClientDataHandler, "onClientKeyChanged")

--[[
/***************************************************

***************************************************\
]]

function onClientDataSync(pData)
	syncedData = pData -- update data
end
addEvent("onClientDataSync", true)
addEventHandler("onClientDataSync", localPlayer, onClientDataSync)

--[[
/***************************************************

***************************************************\
]]

function onClientReceiveData(...)
	local dataFromServer = {...} -- use vararg, because data coming from server might be packed in table or not
	local isBuffer = dataFromServer[1] -- verify if it's buffered
	local elementToSet = false -- declare it once for better readability, and later reuse it
	local keyToSet = false -- declare it once for better readability, and later reuse it
	local valueToSet = false -- declare it once for better readability, and later reuse it
	local serverEventToSet = false -- declare it once for better readability, and later reuse it
	local responsibleElementToSet = false -- declare it once for better readability, and later reuse it

	if isBuffer then -- if yes, then use loop to iterate over table
		local dataPackage = dataFromServer[2] -- get data package
		local dataID = false -- reuse it later

		for i = 1, #dataPackage do -- loop through packed data
			dataID = dataPackage[i] -- cache target table to reduce indexing
			elementToSet = dataID[1] -- get our data
			keyToSet = dataID[2] -- get our data
			valueToSet = dataID[3] -- get our data
			serverEventToSet = dataID[4] -- get our data
			responsibleElementToSet = dataID[5] -- get our data

			setCustomData(elementToSet, keyToSet, valueToSet, false, serverEventToSet, responsibleElementToSet) -- set it locally
		end
	else -- otherwise process normally
		elementToSet = dataFromServer[2] -- get our data
		keyToSet = dataFromServer[3] -- get our data
		valueToSet = dataFromServer[4] -- get our data
		serverEventToSet = dataFromServer[5] -- get our data
		responsibleElementToSet = dataFromServer[6] -- get our data

		setCustomData(elementToSet, keyToSet, valueToSet, false, serverEventToSet, responsibleElementToSet) -- set it locally
	end
end
addEvent("onClientReceiveData", true)
addEventHandler("onClientReceiveData", root, onClientReceiveData)

--[[
/***************************************************

***************************************************\
]]

function onClientResourceStart()
	triggerServerEvent("onServerPlayerReady", localPlayer) -- let's tell server that client part is ready
end
addEventHandler("onClientResourceStart", resourceRoot, onClientResourceStart)

--[[
/***************************************************

***************************************************\
]]

function onClientPlayerQuit()
	localData[source] = nil -- clear any local data stored under player index
	syncedData[source] = nil -- clear any synced data stored under player index
end
addEventHandler("onClientPlayerQuit", playerElements, onClientPlayerQuit) -- let's bind handler just for players which are stored in our 'playerElements' parent

--[[
/***************************************************

***************************************************\
]]

function onClientElementDestroy()
	localData[source] = nil -- clear any local data stored under element index
	syncedData[source] = nil -- clear any synced data stored under element index
end
addEventHandler("onClientElementDestroy", otherElements, onClientElementDestroy) -- let's bind handler just for elements which are stored in our 'otherElements' parent