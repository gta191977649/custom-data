local localData = {} -- store our local (non-synced data)
local syncedData = {} -- store our synced data
local queuedData = {} -- store our data which will be processed in one trigger
local playerElements = createElement("playerElement", "playerElements") -- this element will hold our players which are ready to accept events, it's solution for "Server triggered client-side event onClientDoSomeMagic, but event is not added client-side.". We would need that aswell for binding handlers.
local otherElements = createElement("otherElement", "otherElements") -- this element will do the same, but it's desired for non-player elements

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

function setCustomData(pElement, pKey, pValue, pIsLocal, pOnServerEvent, pBuffer, pTimeout)
	local cachedTable = pIsLocal and localData[pElement] or syncedData[pElement] -- do we need data from local or synced table?
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

			if pBuffer then -- if we want to send it in one big trigger :)
				local existingBuffer = queuedData[pBuffer] -- let's check if there's buffer under such name

				if not existingBuffer then -- if doesn't exist
					local bufferFunction = false -- placeholder for our buffer function

					queuedData[pBuffer] = {} -- create a sub table using it's name
					existingBuffer = queuedData[pBuffer] -- update reference
					existingBuffer[1] = {pElement, pKey, pValue, pOnServerEvent} -- insert data to queue on 1st index, because table it's empty, so there's no need for getting it's length

					bufferFunction = function()
						triggerClientEvent(playerElements, "onClientReceiveData", getRandomPlayer() or playerElements, true, queuedData[pBuffer]) -- send as buffered data
						queuedData[pBuffer] = nil -- after data was sent, clear our queue
					end

					setTimer(bufferFunction, pTimeout, 1) -- use timer to pass data with delay
				else -- otherwise, let's simply add it to queue
					local bufferSize = #existingBuffer + 1 -- get length of table

					existingBuffer[bufferSize] = {pElement, pKey, pValue, pOnServerEvent} -- add data to queue
				end
			else -- otherwise
				triggerClientEvent(playerElements, "onClientReceiveData", getRandomPlayer() or playerElements, false, pElement, pKey, pValue, pOnServerEvent) -- send simply
			end
		end
	end

	return pElement, pKey, pValue -- perhaps, you would need those values afterwards, so let's return them.
end

--[[
/***************************************************

***************************************************\
]]

function onServerPlayerReady()
	if client then -- let's check if it's valid player - remember, do not use 'source'!
		setElementParent(client, playerElements) -- add player to our special group of "ready players"
		triggerClientEvent(client, "onClientDataSync", client, syncedData) -- we need to send copy of server-side data to client, otherwise client wouldn't have it!

		local element, key, value = setCustomData(client, "Key", "Value", false, nil, true, 1000)

		--outputChatBox("Element: "..tostring(element)..", Key: "..key..", Value: "..tostring(value)) -- Would print something like: "Element: userdata: 00000009, Key: Key, Value: Value" - just in case if you need this data
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