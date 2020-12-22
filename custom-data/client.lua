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
	local cachedTable = false

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

function setCustomData(pElement, pKey, pValue, pIsLocal, pOnServerEvent)
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

		handleDataChange(pElement, pKey, oldValue, pValue, pOnServerEvent) -- handle our functions (if there's any)
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
	local validEvent = type(pOnServerEvent) == "string" or type(pOnServerEvent) == "nil" -- check if it's valid type

	if validTypes and validKeys and validFunction and validEvent then -- if all correct
		local cachedData = false -- remember, reuse it's always faster rather than recreating variable each time :)
		local currentSize = false -- remember, reuse it's always faster rather than recreating variable each time :)
		local currentHandlers = dataHandlers -- reference to main table

		pKeys = {pKeys, pOnServerEvent, pFunction} -- we need pack this into table, because it will be processed by loop

		if type(pElementTypes) == "string" then -- if element type was passed as a string

			if not currentHandlers[pElementTypes] then -- if sub table doesn't exist
				currentHandlers[pElementTypes] = {} -- create it
			end

			currentHandlers = currentHandlers[pElementTypes] -- update reference
			currentSize = #currentHandlers + 1 -- get new index for data handler
			currentHandlers[currentSize] = pKeys -- insert packed data
		else -- otherwise
			for i = 1, #pElementTypes do
				cachedData = pElementTypes[i]

				if not currentHandlers[cachedData] then -- if sub table doesn't exist
					currentHandlers[cachedData] = {} -- create it
				end

				currentHandlers = currentHandlers[cachedData] -- update reference
				currentSize = #currentHandlers + 1 -- get new index for data handler
				currentHandlers[currentSize] = pKeys -- insert packed data
			end
		end
	end
end

--[[
/***************************************************

***************************************************\
]]

function handleDataChange(pElement, pKey, pOldValue, pNewValue, pOnServerEvent)
	local isValidElement = isElement(pElement) -- we want element to exist at the time when handler was processed

	if isValidElement then
		local elementType = getElementType(pElement) -- get our element type
		local elementHandlers = dataHandlers[elementType] -- check if there's any handler for this type of element

		if elementHandlers then -- yup, apparently there is something
			local handlerData = false -- remember, reuse it's always faster rather than recreating variable each time :)
			local handlerKeys = false -- remember, reuse it's always faster rather than recreating variable each time :)
			local handlerKey = false -- remember, reuse it's always faster rather than recreating variable each time :)
			local handlerServerEvent = false -- remember, reuse it's always faster rather than recreating variable each time :)
			local handlerFunction = false -- remember, reuse it's always faster rather than recreating variable each time :)

			for i = 1, #elementHandlers do -- process our handlers by loop
				handlerData = elementHandlers[i]
				handlerKeys = handlerData[1]
				handlerServerEvent = handlerData[2]
				handlerFunction = handlerData[3]

				if handlerServerEvent == pOnServerEvent then -- if called event matches data handler event

					if type(handlerKeys) == "string" then -- if key is a string

						if handlerKeys == pKey then -- and it's equal to called key
							handlerFunction(pElement, pKey, pOldValue, pNewValue, pOnServerEvent)
						end
					else -- otherwise
						for i = 1, #handlerKeys do
							handlerKey = handlerKeys[i]

							if handlerKey == pKey then -- it's equal to called key
								handlerFunction(pElement, pKey, pOldValue, pNewValue, pOnServerEvent)
							end
						end
					end
				end
			end
		end
	end
end

--[[
/***************************************************

***************************************************\
]]

function onClientDataHandler(pElement, pKey, pOldValue, pNewValue, pOnServerEvent)
	print("onClientDataHandler got triggered :)")
end
addDataHandler("player", "Key", onClientDataHandler, nil)

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

	if isBuffer then -- if yes, then use loop to iterate over table
		local dataPackage = dataFromServer[2]
		local cachedIndex = false

		for i = 1, #dataPackage do
			cachedIndex = dataPackage[i]
			elementToSet = cachedIndex[1]
			keyToSet = cachedIndex[2]
			valueToSet = cachedIndex[3]
			serverEventToSet = cachedIndex[4]

			setCustomData(elementToSet, keyToSet, valueToSet, false, serverEventToSet)
		end
	else -- otherwise process normally
		elementToSet = dataFromServer[2]
		keyToSet = dataFromServer[3]
		valueToSet = dataFromServer[4]
		serverEventToSet = dataFromServer[5]

		setCustomData(elementToSet, keyToSet, valueToSet, false, serverEventToSet)
	end
end
addEvent("onClientReceiveData", true)
addEventHandler("onClientReceiveData", root, onClientReceiveData)

--[[
/***************************************************

***************************************************\
]]

function onClientResourceStart()
	triggerServerEvent("onServerPlayerReady", localPlayer) -- let's tell server that client part is ready :)
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