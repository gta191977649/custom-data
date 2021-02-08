local localData = {} -- store our local (non-synced data)
local syncedData = {} -- store our synced data
local bufferData = {} -- store our data which will be processed via timer
local batchData = {} -- store our data which will be processed via function
local playerElements = createElement("playerElement", "playerElements") -- this element will hold our players which are ready to accept events, it's solution for "Server triggered client-side event onClientDoSomeMagic, but event is not added client-side.". We would need that aswell for binding handlers.
local otherElements = createElement("otherElement", "otherElements") -- this element will do the same, but it's desired for non-player elements

--[[
/***************************************************

***************************************************\
]]

local function bufferFunction(pBuffer, pReceivers, pSyncer)
	local validReceivers = isElement(pReceivers) or type(pReceivers) == "table" -- make sure that receiver is a valid element or array table

	if validReceivers then -- if so
		triggerClientEvent(pReceivers, "onClientReceiveData", pSyncer or playerElements, true, bufferData[pBuffer]) -- send as buffered data
	end

	bufferData[pBuffer] = nil -- clear our queue
end

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

function getElementsByKey(pKey, pValue, pIsLocal, pMultipleResults)
	local cachedTable = false
	local requestedElements = pMultipleResults and {} or false
	local doesHaveData = false

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

function setCustomData(pElement, pKey, pValue, pIsLocal, pReceivers, pSyncer, pOnServerEvent, pBuffer, pTimeout)
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
	
	oldValue = cachedTable[pKey] -- get our old value

	if pValue ~= oldValue then -- if data isn't equal, process it

		cachedTable[pKey] = pValue -- set our value

		if not pIsLocal then -- if our data isn't local, we want to it sync with client
			pReceivers = pReceivers == "all" and playerElements or pReceivers -- clarify who will receive sync event

			if pBuffer then -- if we want to send it in one big trigger

				if pTimeout == -1 then -- if it's batched data
					local existingBatch = batchData[pBuffer]

					if not existingBatch then -- if it doesn't exist
						batchData[pBuffer] = {}
						existingBatch = batchData[pBuffer]
						existingBatch[1] = {pElement, pKey, pValue, pOnServerEvent, pSyncer, pReceivers}
					else -- otherwise, let's simply add it to queue
						local batchSize = #existingBatch + 1

						existingBatch[batchSize] = {pElement, pKey, pValue, pOnServerEvent, pSyncer, pReceivers}
					end
				else -- otherwise
					local existingBuffer = bufferData[pBuffer] -- let's check if there's buffer under such name

					if not existingBuffer then -- if doesn't exist
						bufferData[pBuffer] = {} -- create a sub table using it's name
						existingBuffer = bufferData[pBuffer] -- update reference
						existingBuffer[1] = {pElement, pKey, pValue, pOnServerEvent, pSyncer} -- insert data to queue on 1st index, because table it's empty, so there's no need for getting it's length

						setTimer(bufferFunction, pTimeout, 1, pBuffer, pReceivers, pSyncer) -- use timer to pass data with delay
					else -- otherwise, let's simply add it to queue
						local bufferSize = #existingBuffer + 1 -- get length of table

						existingBuffer[bufferSize] = {pElement, pKey, pValue, pOnServerEvent, pSyncer} -- add data to queue
					end
				end
			else -- otherwise
				local validReceivers = isElement(pReceivers) or type(pReceivers) == "table" -- make sure that receiver is a valid element or array table

				if validReceivers then
					triggerClientEvent(pReceivers, "onClientReceiveData", pSyncer or playerElements, false, pElement, pKey, pValue, pOnServerEvent, pSyncer) -- send simply
				end
			end
		end
	end

	return pElement, pKey, pValue -- perhaps, you would need those values afterwards, so let's return them.
end

--[[
/***************************************************

***************************************************\
]]

function forceBatchDataSync(pQueue)
	if pQueue then -- if we passed queue name
		local dataQueue = batchData[pQueue] -- check if it exists

		if dataQueue then -- if so
			dataQueue = dataQueue[1] -- move us to 1st index

			if dataQueue then -- if such data exists
				local receiversList = dataQueue[6]
				local validReceivers = isElement(receiversList) or type(receiversList) == "table" -- make sure that receiver is a valid element or array table

				if validReceivers then
					local syncerElement = dataQueue[5]

					triggerClientEvent(receiversList, "onClientReceiveData", syncerElement or playerElements, true, batchData[pQueue]) -- send as batched data
				end

				batchData[pQueue] = nil -- clear our queue

				return true
			end
		end
	else -- otherwise, force all queues to sync
		local dataPackage = false
		local receiversList = false
		local validReceivers = false
		local syncerElement = false

		for queueName, queueData in pairs(batchData) do
			dataPackage = queueData[1]

			if dataPackage then
				receiversList = dataPackage[6]

				if receiversList then
					validReceivers = isElement(receiversList) or type(receiversList) == "table" -- make sure that receiver is a valid element or array table

					if validReceivers then
						syncerElement = dataPackage[5]

						triggerClientEvent(receiversList, "onClientReceiveData", syncerElement or playerElements, true, queueData) -- send as batched data
					end
				end
			end
		end

		batchData = {} -- reset batch table

		return true
	end

	return false
end

--[[
/***************************************************

***************************************************\
]]

function onServerPlayerReady()
	if client then -- let's check if it's valid player - remember, do not use 'source'
		setElementParent(client, playerElements) -- add player to our special group of "ready players"

		triggerClientEvent(client, "onClientDataSync", client, syncedData) -- we need to send copy of server-side data to client, otherwise client wouldn't have it

		setCustomData(client, "Key", "Value", false, "all", client, "onClientKeyChanged", "queue_1", 1000)
	end
end
addEvent("onServerPlayerReady", true)
addEventHandler("onServerPlayerReady", root, onServerPlayerReady)

--[[
/***************************************************

***************************************************\
]]

function onPlayerQuit()
	localData[source] = nil -- clear any local data stored under player index
	syncedData[source] = nil -- clear any synced data stored under player index
end
addEventHandler("onPlayerQuit", playerElements, onPlayerQuit) -- let's bind handler just for players which are stored in our 'playerElements' parent

--[[
/***************************************************

***************************************************\
]]

function onElementDestroy()
	localData[source] = nil -- clear any local data stored under element index
	syncedData[source] = nil -- clear any synced data stored under element index
end
addEventHandler("onElementDestroy", otherElements, onElementDestroy) -- let's bind handler just for elements which are stored in our 'otherElements' parent