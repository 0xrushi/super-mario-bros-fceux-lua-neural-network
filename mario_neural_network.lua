----------------------------------------------------------------------------------------------------------------------------------------------------
--Super Mario Bros.
--Neural Network Learning
--by Michael Roberts
--06/2015
--
--Use with FCEUX v2.2.2


----------------------------------------------------------------------------------------------------------------------------------------------------
--RAM Addresses for variables
----------------------------------------------------------------------------------------------------------------------------------------------------

saveState = savestate.object(1)
savestate.save(saveState)

RamNametableHi = 0x20
RamNametableLow = 0x01
RamNametableSize = 0x2BF
RamNametableSolidStart = 0x01

--Screen attributes
RamObjectMapStart = 0x500
MapTileNum = 208

--Player attributes
RamPlayerX = 0x86
RamPlayerY = 0x3B8
RamPlayerScreenX = 0x6D
RamLives = 0x75A
RamCoins = 0x75E

--Game attributes
RamWorld = 0x75F
RamLevel = 0x760
--Score
RamScoreDigit1 = 0x7D8 --10^5
RamScoreDigit2 = 0x7D9 --10^4
RamScoreDigit3 = 0x7DA --10^3
RamScoreDigit4 = 0x7DB --10^2
RamScoreDigit5 = 0x7DC --10^1


--Enemy attributes
RamEnemyX = 0x87	--starting address in memory for multiple enemies
RamEnemyY = 0xCF
RamEnemyScreenX = 0x6E
EnemyNumSlots = 5
RamEnemyFlag = 0xF	--In Zelda, it's enemy direction used as flag

--Projectile attributes
--RamProjectileX = 0x87	--starting address in memory for multiple enemies
--RamProjectileY = 0xCF
--RamProjectileScreenX = 0x6E
--ProjectileNumSlots = 5
--RamProjectileFlag = 0xF	--In Zelda, it's enemy direction used as flag


------------------------------------------------------------------------------------------------------------------------------------------------------

--timer = 40
index = 1
--AReady = true
--BReady = true
vblankFlag = 0
vblankOff = 0
--PPU2002 = {}

generation = 1
fitness = 0
maxFitness = 0
startFitness = 0

timeStuck = 0
maxStuckTime = 100 --220
lastX = 0
lastY = 0
lastLives = 0
timerHold = 0
lastScreen = 0
screenTimeStuck = 0
maxScreenStuckTime = 350

playerX = 0
playerY = 0
playerRoomX = 0
playerRoomY = 0
playerMapX = 0
playerMapY = 0
playerLives = 0


room = {}
map = {}
for i=1,2*MapTileNum do
	map[i] = 0
end


enemyX = {}
enemyY = {}
enemyRoomX = {}
enemyRoomY = {}
enemyMapX = {}
enemyMapY = {}
enemyDir = {}
projectileX = {}
projectileY = {}
projectileRoomX = {}
projectileRoomY = {}


drawRoom = false
drawMap = false
drawView = true
drawCoord = false
drawNeurons = true
drawWeights = true
drawController = true
drawPopulation = true

viewRadius = 2
viewDiameter = 2*viewRadius+1

viewBox = {}
for i=1,viewDiameter*viewDiameter do
	viewBox[i] = 0
end



inputNum = viewDiameter*viewDiameter + 1
outputNum = 6	--6 buttons on the controller
layerNum = 2
layerSize = {inputNum,  12, outputNum}
--layerSize array has layerNum+1 entries. (inputNum layer is counted as layer 0)
 
populationSize = 25

populationFitness = {}
for i=1, populationSize do
	populationFitness[i] = nil
end
currentChild = 1
currentParent1 = 0
currentParent2 = 0
mutationProbability = .05
meanFitness = 0
stdvFitness = 0


inputViewNum = MapTileNum	--this is the number of inputs to X that are from the view or map

--inputSigmoidStrength = 4.394/inputNum
--hiddenSigmoidStrength = 4.394/layerSize
outputStepStrength = 0 --layerSize/4
--sigmoid strength = 4ln3/N    --4ln3 = 4.394
--where N=number of neurons input into current layer being calculated.

--X[1][] = input
--X[layerNum+1][] = output
--Y = output bool
--
--S[l] = W[l]*X[l-1]
--X[l] = f(S[l])
--f is shaping function (tanh)

Y = {}
for i=1, outputNum do
	Y[i] = false
end

X = {}
S = {}
delta = {}
for l=1,layerNum+1 do
	X[l] = {}
	S[l] = {}
	delta[l] = {}
	for i=1, layerSize[l] do
		X[l][i] = 0
		S[l][i] = 0
		delta[l][i] = 0
	end
end


W = {}
memW = {}
for p=1, populationSize do
	W[p] = {}
	for l=1,layerNum do
		W[p][l] = {}
		memW[l] = {}
		for i=1,layerSize[l+1] do
			W[p][l][i] = {}
			memW[l][i] = {}
			for j=1,layerSize[l] do
				W[p][l][i][j] = 2*math.random() - 1 --math.random(3)-2
				memW[l][i][j] = W[p][l][i][j]
			end
		end
	end
end

--Training parameters

--trainingMode = 1 -> begin in training mode. 0 is game running mode
geneticMode = true
trainingMode = false

recordMode = 1
keyPressReady = true

randomChangeSize = .1
stepSize = .1
sampleRate = 10
sampleTimer = 0
controllerInput = {}
errorVal = 0

Y_Train = {}
for i=1, outputNum do
	Y_Train[i] = 0
end


--------------------------------------------------------------------------------------------------------------------------------------------
--Functions
--------------------------------------------------------------------------------------------------------------------------------------------

function readPPU()
	memory.writebyte(0x2006, RamNametableHi)
	memory.writebyte(0x2006, RamNametableLow)
	j=1
	for i=0,RamNametableSize do
		local val = memory.readbyte(0x2007)
		room[i+1] = val
		
		if (math.floor(i/32))%2 == 0 then
		if i%2 == 0 then
			map[j] = val
			j = j+1
		end
		end
		
		--if val <= RamNametableSolidStart then
		--	room[i+1] = 0
		--else
		--	room[i+1] = 1
		--end
	end
end



function inputView()
	for i = -viewRadius, viewRadius do
	for j = -viewRadius, viewRadius do
		local x = playerMapX+i-1
		local y = playerMapY+j-1
		local page = math.floor(x/16)
		local xAddress = x - 16*page+1
		local yAddress = y + 13*(page%2)
		if xAddress >= 1 and xAddress < 32 and yAddress >= 1 and yAddress <= 25 then
			viewBox[(i+viewRadius+1)+viewDiameter*(j+viewRadius)] = map[xAddress + 16*yAddress]
		else
			viewBox[(i+viewRadius+1)+viewDiameter*(j+viewRadius)] = 0
		end
	end
	end
end

	
	
function inputMap()
	for i=1, 2*MapTileNum do
		if memory.readbyte(0x500 + i-1) ~= 0 then
			map[i] = 1
		else
			map[i] = 0
		end
	end
	
	for i=1, EnemyNumSlots do
		if memory.readbyte(RamEnemyFlag+(i-1)) ~= 0 then
			local page = math.floor(enemyMapX[i]/16)
			local xAddress = enemyMapX[i] - 16*page
			local yAddress = enemyMapY[i] - 1 + 13*(page%2)
			if xAddress >= 1 and xAddress < 32 and yAddress >= 1 and yAddress <= 25 then
				map[xAddress + 16*yAddress] = -1
			end
		end
	end
end



function inputPlayer()
	playerX = memory.readbyte(RamPlayerX) + memory.readbyte(RamPlayerScreenX)*0x100 + 4
	playerY = memory.readbyte(RamPlayerY) + 16
	playerRoomX = math.floor(playerX/8)+1
	playerRoomY = math.floor(playerY/7.5)-7
	playerMapX = math.floor((playerX%512)/16)+1
	playerMapY = math.floor((playerY-32)/16)+1
end



function inputEnemies()
	for i=1,EnemyNumSlots do
		if memory.readbyte(RamEnemyFlag+(i-1)) ~= 0 then
			enemyX[i] = memory.readbyte(RamEnemyX+(i-1)) + memory.readbyte(RamEnemyScreenX+(i-1))*0x100
			enemyY[i] = memory.readbyte(RamEnemyY+(i-1)) + 24
		else
			enemyX[i] = -1
			enemyY[i] = -1
		end
		enemyRoomX[i] = math.floor(enemyX[i]/8)+1
		enemyRoomY[i] = math.floor(enemyY[i]/7.5)-7
		enemyMapX[i] = math.floor((enemyX[i]%512)/16)+1
		enemyMapY[i] = math.floor((enemyY[i]-32)/16)
	end
	--for i=1,ProjectileNumSlots do
	--	if memory.readbyte(RamProjectileFlag-(i-1)) ~= 0 then
	--		projectileX[i] = memory.readbyte(RamProjectileX-(i-1))
	--		projectileY[i] = memory.readbyte(RamProjectileY-(i-1))
	--	else
	--		projectileX[i] = -1
	--		projectileY[i] = -1
	--	end
	--	projectileRoomX[i] = math.floor(projectileX[i]/8)
	--	projectileRoomY[i] = math.floor(projectileY[i]/7.5)
	--end
end



function inputViewToX(startPosition)
	for i=1,(viewDiameter)*(viewDiameter) do
		X[1][startPosition-1+i] = viewBox[i]
	end
end



function inputMapToX(startPosition)
	for i=1,MapTileNum do
		if map[i] <= RamNametableSolidStart then
			X[1][startPosition-1+i] = 0
		else
			X[1][startPosition-1+i] = 1
		end
	end
end



function inputCoordToX(startPosition)
	X[1][startPosition] = playerMapX/32
	X[1][startPosition+1] = playerMapY/13
	--X[1][startPosition+2] = playerHealth
end



function inputEnemyToX(startPosition)
	for i=0,EnemyNumSlots-1 do
		X[1][startPosition+2*i] = enemyMapX[i+1]/32
		X[1][startPosition+2*i+1] = enemyMapY[i+1]/13
	end
	--for i=0,ProjectileNumSlots-1 do
	--	X[1][startPosition+2*i+14] = projectileX[i+1]/256
	--	X[1][startPosition+2*i+15] = projectileY[i+1]/240
	--end
end



function inputNoise(val)
	for i=1,inputNum do
		X[1][i] = X[1][i] + val*(2*math.random()-1)
		if X[1][i] > 1 then
			X[1][i] = 1
		end
		if X[1][i] < -1 then
			X[1][i] = -1
		end
	end
end



function drawGui()
	local mapDrawX = -8
	local mapDrawY = 0
	local mapScale = 8
	local viewDrawX = 56
	local viewDrawY = 56
	local neuronDrawSpacing = 32
	local neuronVerticalSpacing = 4
	local controllerDrawX = 176
	local controllerDrawY = 48 --200
	local drawNeuronsX = 88
	
	if drawRoom == true then
		for i=0,RamNametableSize do
			local x = i%32
			local y = math.floor(i/32)
			if tunicColor%2 == 0 then
				gui.text(x*8, 64+y*8, room[i+1]%16)
			else
				gui.text(x*8, 64+y*8, math.floor(room[i+1]/16))
			end
			--if room[i+1] <= 0x77 then
			--	gui.box(mapDrawX+x*mapScale, mapDrawY+y*mapScale, mapDrawX+x*mapScale+mapScale, mapDrawY+y*mapScale+mapScale, "black")
			--else
			--	gui.box(mapDrawX+x*mapScale, mapDrawY+y*mapScale, mapDrawX+x*mapScale+mapScale, mapDrawY+y*mapScale+mapScale, "blue")
			--end
		end
		gui.box(mapDrawX+playerMapX*mapScale, mapDrawY+mapScale*(playerMapY-8), mapDrawX+mapScale*(playerMapX+1.5), mapDrawY+mapScale*(playerMapY-6.5), "green")
		for i=1,EnemyNumSlots do
			if enemyX[i] ~= -1 then
				gui.box(mapDrawX+enemyRoomX[i]*mapScale, mapDrawY+mapScale*(enemyRoomY[i]-8), mapDrawX+mapScale*(enemyRoomX[i]+1.5), mapDrawY+mapScale*(enemyRoomY[i]-6.5), "red")
			end
		end
		--for i=1,ProjectileNumSlots do
		--	if projectileX[i] ~= -1 then
		--		gui.box(mapDrawX+projectileRoomX[i]*mapScale, mapDrawY+mapScale*(projectileRoomY[i]-8), mapDrawX+mapScale*(projectileRoomX[i]+1), mapDrawY+mapScale*(projectileRoomY[i]-7), "red")
		--	end
		--end
	end
	
	if drawMap == true then
	--gui.box(0,0,256,240,"black")
		for i=0,2*MapTileNum-1 do
			local x = 16*math.floor(i/208) + i%16 + 1
			local y = math.floor(i/16) - 13*math.floor(i/208) + 1
			--local x = i%16 + 1 -- + 16*(i%208)
			--local y = math.floor(i/16) + 1 - 13*(i%208)
			--gui.text(mapDrawX+x*16, mapDrawY++y*16, map[i+1]%16)
			
			if map[i+1] == 0 then
				gui.box(mapDrawX+x*mapScale, mapDrawY+y*mapScale, mapDrawX+(x+1)*mapScale-1, mapDrawY+(y+1)*mapScale-1, "black")
			elseif map[i+1] == 1 then
				gui.box(mapDrawX+x*mapScale, mapDrawY+y*mapScale, mapDrawX+(x+1)*mapScale-1, mapDrawY+(y+1)*mapScale-1, "blue")
			elseif map[i+1] == -1 then
				gui.box(mapDrawX+x*mapScale, mapDrawY+y*mapScale, mapDrawX+(x+1)*mapScale-1, mapDrawY+(y+1)*mapScale-1, "red")
			end
		end
		gui.box(mapDrawX+playerMapX*mapScale, mapDrawY+mapScale*playerMapY, mapDrawX+mapScale*(playerMapX+1)-1, mapDrawY+mapScale*(playerMapY+1)-1, "green")
		gui.box(mapDrawX+(playerMapX-viewRadius)*mapScale, mapDrawY+mapScale*(playerMapY-viewRadius), mapDrawX+(playerMapX+viewRadius+1)*mapScale, mapDrawY+mapScale*(playerMapY+viewRadius+1), "clear", "white")
		--Draw enemies on map. Replaced by inputing enemies into map[i] as -1 values
		--for i=1,EnemyNumSlots do
		--	if enemyX[i] ~= -1 then
		--		gui.box(mapDrawX+enemyMapX[i]*mapScale, mapDrawY+mapScale*enemyMapY[i], mapDrawX+mapScale*(enemyMapX[i]+1)-1, mapDrawY+mapScale*(enemyMapY[i]+1)-1, "red")
		--	end
		--end
		--for i=1,4 do
		--	if projectileX[i] ~= -1 then
		--		gui.box(mapDrawX+projectileRoomX[i]*mapScale, mapDrawY+mapScale*(projectileRoomY[i]-8), mapDrawX+mapScale*(projectileRoomX[i]+1), mapDrawY+mapScale*(projectileRoomY[i]-7), "red")
		--	end
		--end
	end
	
	if drawView == true then
		for i=1,viewDiameter*viewDiameter do
			local x = (i-1)%viewDiameter - viewRadius
			local y = math.floor((i-1)/viewDiameter) - viewRadius
			if viewBox[i] == 1 then
				gui.box(viewDrawX+8*x, viewDrawY+8*y, viewDrawX+8*(x+1)-1, viewDrawY+8*(y+1)-1, "blue")
			elseif viewBox[i] == 0 then
				gui.box(viewDrawX+8*x, viewDrawY+8*y, viewDrawX+8*(x+1)-1, viewDrawY+8*(y+1)-1, "black")
			elseif viewBox[i] == -1 then
				gui.box(viewDrawX+8*x, viewDrawY+8*y, viewDrawX+8*(x+1)-1, viewDrawY+8*(y+1)-1, "red")
			end
		end
		gui.box(viewDrawX, viewDrawY, viewDrawX+8-1, viewDrawY+8-1, "green")
	end
	
	if drawCoord == true then
		gui.text(192,8,playerX)
		gui.text(224,8,playerY)
		gui.text(192,16,playerMapX)
		gui.text(224,16,playerMapY)
		--gui.text(168,48,playerHealth)
	end
	
	if drawNeurons == true then
		for l=1,layerNum+1 do
			local layerDrawSpacing = (neuronVerticalSpacing*inputNum) / layerSize[l]
			for i=1, layerSize[l] do
				if X[l][i] >= -0.5 and X[l][i] <= 0.5 then
					gui.box(drawNeuronsX+neuronDrawSpacing*(l-1), 10+(i-1)*layerDrawSpacing, drawNeuronsX+3+neuronDrawSpacing*(l-1), 10+i*layerDrawSpacing, "gray", "black")
				elseif X[l][i] > 0.5 then
					gui.box(drawNeuronsX+neuronDrawSpacing*(l-1), 10+(i-1)*layerDrawSpacing, drawNeuronsX+3+neuronDrawSpacing*(l-1), 10+i*layerDrawSpacing, "green", "black")
				elseif X[l][i] < -0.5 then
					gui.box(drawNeuronsX+neuronDrawSpacing*(l-1), 10+(i-1)*layerDrawSpacing, drawNeuronsX+3+neuronDrawSpacing*(l-1), 10+i*layerDrawSpacing, "red", "black")
				end
			end
		end
	end
	
	if drawController == true then
		gui.box(controllerDrawX-1, controllerDrawY-1, controllerDrawX+64, controllerDrawY+24, "black")
		--A
		if Y[1] == true then
			gui.box(controllerDrawX+56, controllerDrawY+8, controllerDrawX+63, controllerDrawY+15, "blue")
		else
			gui.box(controllerDrawX+56, controllerDrawY+8, controllerDrawX+63, controllerDrawY+15, "gray")
		end
		--up
		if Y[2] == true then
			gui.box(controllerDrawX+8, controllerDrawY, controllerDrawX+15, controllerDrawY+7, "blue")
		else
			gui.box(controllerDrawX+8, controllerDrawY, controllerDrawX+15, controllerDrawY+7, "gray")
		end
		--left
		if Y[3] == true then
			gui.box(controllerDrawX, controllerDrawY+8, controllerDrawX+7, controllerDrawY+15, "blue")
		else
			gui.box(controllerDrawX, controllerDrawY+8, controllerDrawX+7, controllerDrawY+15, "gray")
		end
		--B
		if Y[4] == true then
			gui.box(controllerDrawX+40, controllerDrawY+8, controllerDrawX+47, controllerDrawY+15, "blue")
		else
			gui.box(controllerDrawX+40, controllerDrawY+8, controllerDrawX+47, controllerDrawY+15, "gray")
		end
		--right
		if Y[5] == true then
			gui.box(controllerDrawX+16, controllerDrawY+8, controllerDrawX+23, controllerDrawY+15, "blue")
		else
			gui.box(controllerDrawX+16, controllerDrawY+8, controllerDrawX+23, controllerDrawY+15, "gray")
		end
		--down
		if Y[6] == true then
			gui.box(controllerDrawX+8, controllerDrawY+16, controllerDrawX+15, controllerDrawY+23, "blue")
		else
			gui.box(controllerDrawX+8, controllerDrawY+16, controllerDrawX+15, controllerDrawY+23, "gray")
		end
	end
	
	if drawWeights == true then			
		for l=1,layerNum do
		local layerInSpacing = (neuronVerticalSpacing*inputNum) / layerSize[l]
		local layerOutSpacing = (neuronVerticalSpacing*inputNum) / layerSize[l+1]
			for i=1,layerSize[l+1] do
			for j=1,layerSize[l] do
				if W[currentChild][l][i][j] >= .6 then
					gui.line(drawNeuronsX+3+neuronDrawSpacing*(l-1), 10+(j-.5)*layerInSpacing, drawNeuronsX-1+neuronDrawSpacing*l, 10+(i-.5)*layerOutSpacing, {0,0,255,48})
				end
				if W[currentChild][l][i][j] <= -.6 then
					gui.line(drawNeuronsX+3+neuronDrawSpacing*(l-1), 10+(j-.5)*layerInSpacing, drawNeuronsX-1+neuronDrawSpacing*l, 10+(i-.5)*layerOutSpacing, {255,0,0,48})
				end
			end
			end
		end
	end
	
	if drawPopulation == true then
		if currentParent1 > 0 then
			gui.box(4, 8*currentParent1, 10, 8*(currentParent1+1)-2, "blue")
		end
		if currentParent2 > 0 then
			gui.box(4, 8*currentParent2, 10, 8*(currentParent2+1)-2, "blue")
		end
		gui.box(4, 8*currentChild, 10, 8*(currentChild+1)-2, "green")
		for i=1, populationSize do
			if populationFitness[i] ~= nil then
				gui.text(12, 8*i, populationFitness[i])
			end
		end
	end
end



function multiply(matrixIn, vectorIn, rows, collumns)
	local vectorOut = {}
	
	for i=1,rows do
			vectorOut[i] = 0
			for j=1,collumns do
				vectorOut[i] = vectorOut[i] + matrixIn[i][j]*vectorIn[j]
			end
	end
	
	return vectorOut
end



function sigmoid(inputVector, inputLength, strength)
	local vectorOut = {}
	for i=1,inputLength do
		vectorOut[i] = 2/(1+math.exp(-strength*inputVector[i])) - 1
	end
	return vectorOut
end



function tanh(inputVector, inputLength)
	local vectorOut = {}
	for i=1,inputLength do
		vectorOut[i] = (math.exp(inputVector[i]) - math.exp(-inputVector[i])) / (math.exp(inputVector[i]) + math.exp(-inputVector[i]))
	end
	return vectorOut
end



function stepFunction(inputVector, inputLength)
	local vectorOut = {}
	for i=1,inputLength do
		if inputVector[i] >= outputStepStrength then
			vectorOut[i] = true
		else
			vectorOut[i] = false
		end
	end
	return vectorOut
end



function forwardPropogate()
	X[1][1] = -1
	for l=1, layerNum do
		S[l+1] = multiply(W[currentChild][l], X[l], layerSize[l+1], layerSize[l])
		X[l+1] = tanh(S[l+1], layerSize[l+1])
		if l < layerNum then
			X[l+1][1] = -1
		end
	end
	Y = stepFunction(X[layerNum+1], outputNum)
	
	--make it so up/down etc. can't be hit at same time
	doublePressNegate(3,5)
	doublePressNegate(2,6)
	doublePressNegate(5,6)
	doublePressNegate(2,5)
	doublePressNegate(3,6)
end



function doublePressNegate(button1, button2)
	if Y[button1] == true and Y[button2] == true then
		if X[layerNum+1][button1] > X[layerNum+1][button2] then
			Y[button2] = false
		else
			Y[button1] = false
		end
	end
end



function outputToController()
	local controllerInput = {}
	controllerInput = {A=Y[1], up=Y[2], left=Y[3], B=Y[4], select=nil, right=Y[5], down=Y[6], start=nil}
	joypad.write(1, controllerInput)
end



function controllerOverride()
	local controllerInput = {}
	controllerInput = joypad.read(1)
	Y[1] = controllerInput["A"]
	Y[2] = controllerInput["up"]
	Y[3] = controllerInput["left"]
	Y[4] = controllerInput["B"]
	Y[5] = controllerInput["right"]
	Y[6] = controllerInput["down"]
end



function updateWeightsFromMem()
	for l=1,layerNum do
		for i=1,layerSize[l+1] do
		for j=1,layerSize[l] do
			--if math.random() < stepSize then
			--	W[l][i][j] = (memW[l][i][j] + 2)%3 - 1
			--else
			--	W[l][i][j] = memW[l][i][j]
			--end
			
			W[currentChild][l][i][j] = memW[l][i][j] + randomChangeSize*(2*math.random() - 1)
			
			--if W[i][j][k] > 1 then
			--	W[i][j][k] = 1
			--end
			--if W[i][j][k] < -1 then
			--	W[i][j][k] = -1
			--end
		end
		end
	end
end



function updateWeightsRandom()
	for l=1,layerNum do
		for i=1,layerSize[l+1] do
		for j=1,layerSize[l] do
			W[currentChild][l][i][j] = 2*math.random() - 1 --math.random(3)-2
			memW[l][i][j] = W[currentChild][l][i][j]
		end
		end
	end
end



function updateMemWeights()
	for l=1,layerNum do
		for i=1,layerSize[l+1] do
		for j=1,layerSize[l] do
			memW[l][i][j] = W[currentChild][l][i][j]
		end
		end
	end
end



function restartOld()		
	if fitness > maxFitness then
		maxFitness = fitness
		updateMemWeights()
	end
		
	updateWeightsFromMem()
		
	if fitness <= minFitness then
	if maxFitness <= minFitness then
		updateWeightsRandom()
	end
	end
	
	generation = generation + 1
	fitness = 0
	timeStuck = 0
		
	savestate.load(saveState)
		
	inputPlayer()
	inputMap()
	inputView()
end



function inputController()
	--controllerInput = {A=true, up=false, left=false, B=false, select=nil, right=false, down=false, start=nil}
	controllerInput = joypad.read(1)
	for i=1, outputNum do
		Y_Train[i] = 0
	end
	if controllerInput["A"] == true then
		Y_Train[1] = 1
	end
	if controllerInput["up"] == true then
		Y_Train[2] = 1
	end
	if controllerInput["left"] == true then
		Y_Train[3] = 1
	end
	if controllerInput["B"] == true then
		Y_Train[4] = 1
	end
	if controllerInput["right"] == true then
		Y_Train[5] = 1
	end
	if controllerInput["down"] == true then
		Y_Train[6] = 1
	end

	if controllerInput["select"] == true then
		trainingMode = false

		timeStuck = 0
		screenTimeStuck = 0
		
		savestate.load(saveState)
		
		inputPlayer()
		inputEnemies()
		inputMap()
		inputView()
		fitness = playerX
	end
	if controllerInput["up"] == true and keyPressReady == true then
		recordMode = (recordMode+1)%2
		keyPressReady = false
	end
	if controllerInput["up"] == false then
		keyPressReady = true
	end
end



function backPropogate()
	for i=1, outputNum do
		delta[layerNum+1][i] = (1-X[layerNum+1][i]*X[layerNum+1][i]) * (X[layerNum+1][i] - Y_Train[i])
	end
	
	for l=0, layerNum-2 do
		for j=1, layerSize[layerNum-l] do
			local matrixProduct = 0
			for k=1, layerSize[layerNum-l+1] do
				matrixProduct = matrixProduct + W[layerNum-l][k][j] * delta[layerNum-l+1][k]
			end
			delta[layerNum-l][j] = (1 - X[layerNum-l][j]*X[layerNum-l][j]) * matrixProduct
		end
	end
end



function batchGradientDescent()
	for l=1, layerNum do
		for i=1, layerSize[l+1] do
		for j=1, layerSize[l] do
	
	--l = math.random(layerNum)
	--i = math.random(layerSize[l+1])
	--j = math.random(layerSize[l])
			W[currentChild][l][i][j] = W[currentChild][l][i][j] - stepSize * delta[l+1][i] * X[l][j]
		end
		end
	end
end



function restart()
	generation = generation + 1/populationSize
	if populationFitness[currentChild] == nil then
		populationFitness[currentChild] = fitness
	elseif fitness > populationFitness[currentChild] then
		populationFitness[currentChild] = fitness
	end
	
	
	if #populationFitness < populationSize then
		currentChild = currentChild + 1
	else
		currentChild = minimum(populationFitness)
		if math.random() <= .5 then
			currentParent1 = maximum(populationFitness)
			if currentParent1 == currentChild then
				currentParent1 = math.random(populationSize-1)
				if currentParent1 >= currentChild then
					currentParent1 = currentParent1+1
				end
			end
		else
			currentParent1 = math.random(populationSize-1)
			if currentParent1 >= currentChild then
				currentParent1 = currentParent1+1
			end
		end
		currentParent2 = math.random(populationSize-2)
		if currentParent2 >= currentChild then
			currentParent2 = currentParent2+1
		end
		if currentParent2 >= currentParent1 then
			currentParent2 = currentParent2+1
		end
		if currentParent2 == currentChild then
			currentParent2 = currentParent2+1
		end
		
		meanFitness = mean(populationFitness)
		stdvFitness = standardDev(populationFitness)
		if stdvFitness <= meanFitness/6 then
			uniformCrossover(mutationProbability*2)
		else
			uniformCrossover(mutationProbability)
		end
	end
	
	timeStuck = 0
	screenTimeStuck = 0
	savestate.load(saveState)
	inputPlayer()
	startFitness = playerX
end



function minimum(vectorIn)
	local val = vectorIn[1]
	local index = 1
	for i=1, #vectorIn do
		if vectorIn[i] < val then
			index = i
			val = vectorIn[i]
		end
	end
	return index
end



function maximum(vectorIn)
	local val = vectorIn[1]
	local index = 1
	for i=1, #vectorIn do
		if vectorIn[i] > val then
			index = i
			val = vectorIn[i]
		end
	end
	return index
end



function uniformCrossover(probability)
	for l=1, layerNum do
		for i=1, layerSize[l+1] do
		for j=1, layerSize[l] do
			if math.random() < probability then
				W[currentChild][l][i][j] = 2*math.random()-1
			else
				if math.random() <=0.5 then
					W[currentChild][l][i][j] = W[currentParent1][l][i][j]
				else
					W[currentChild][l][i][j] = W[currentParent2][l][i][j]
				end
			end
		end
		end
	end
end



function mean(arrayIn)
	local sum = 0
	--if #arrayIn > 0 then
		for i=1, #arrayIn do
			sum = sum + arrayIn[i]
		end
		return sum / #arrayIn
	--else
	--	return 0
	--end
end



function standardDev(arrayIn)
	local sum = 0
	local stdv = 0
	local meanVal = mean(arrayIn)
	--if #arrayIn > 1 then
		for i=1, #arrayIn do
			sum = sum + (arrayIn[i] - meanVal) * (arrayIn[i] - meanVal)
		end
		stdv = math.sqrt(sum / (#arrayIn-1))
		return stdv
	--else
	--	return 0
	--end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------
--Main Code
------------------------------------------------------------------------------------------------------------------------------------------------------------


inputPlayer()
lastX = playerX
lastY = playerY
lastScreen = memory.readbyte(RamPlayerScreenX)
startFitness = playerX
playerLives = memory.readbyte(RamLives)
lastLives = playerLives

while (true) do

	--read PPU only when changing rooms
	--vblankFlag = memory.readbyte(0xE3)
	--if vblankFlag == 1 then
	--	vblankOff = 1
	--elseif vblankOff == 1 then
	--	readPPU()
	--	vblankOff = 0
	--end
	
	inputPlayer()
	inputEnemies()
	inputMap()
	inputView()
	
	
	
	index = 2	--first neuron slot is for constant X[1] = 1
	inputViewToX(index)
	index = index + viewDiameter*viewDiameter
	
	--inputCoordToX(index)
	--index = index + 2
	
	--inputEnemyToX(index)
	--index = index + 2*EnemyNumSlots
	
	--inputNoise(.1)
	
	forwardPropogate()
	
	if trainingMode == true then
		inputController()
		if recordMode == 1 then
			sampleTimer = sampleTimer + 1
			if sampleTimer >= sampleRate then
				sampleTimer = 0
				backPropogate()
				batchGradientDescent()
			
				errorVal = 0
				for i=1, 6 do
					errorVal = errorVal + ((X[layerNum+1][i] - Y_Train[i])*(X[layerNum+1][i] - Y_Train[i]))/2
				end
			end
			gui.text(0,8,errorVal)
			--outputToController()
		end
	else
		outputToController()
		--timeStuck = 0
		--screenTimeStuck = 0
		
		fitness = playerX - startFitness
		
		if timerHold == 0 then
			if math.abs(playerX - lastX) < 2 then
				timeStuck = timeStuck + 1
			else
				timeStuck = 0
			end
			if memory.readbyte(RamPlayerScreenX) == lastScreen then
				screenTimeStuck = screenTimeStuck + 1
			else
				screenTimeStuck = 0
			end
		end
	
		if (timeStuck >= maxStuckTime) or (screenTimeStuck >= maxScreenStuckTime) then
			if geneticMode == true then
				emu.print(fitness)
				restart()
			else
				restartOld()
			end
		end
		
		playerLives = memory.readbyte(RamLives)
		if lastLives ~= playerLives then
			--timerHold = 200
			--timeStuck = 0
			--screenTimeStuck = 0
			savestate.load(saveState)
			restart()
		end
		
		if timerHold > 0 then
			timerHold = timerHold - 1
		end
		
		--Cause seizures if he sits still for too long
		--if timeStuck >= maxStuckTime then
		--	inputNoise(.7)
		--end
	end
	
	drawGui()
	
	gui.text(220, 8, math.floor(generation))
	gui.text(48, 8, fitness)
	--gui.text(48, 16, startFitness)
	--gui.text(48, 24, timerHold)
	--gui.text(64, 24, timeStuck)
	--gui.text(48, 16, math.floor(meanFitness))
	--gui.text(48, 24, math.floor(stdvFitness))
	
	
	lastX = playerX
	lastY = playerY
	lastScreen = memory.readbyte(RamPlayerScreenX)
	lastLives = playerLives

	
	emu.frameadvance()
	
end

------------------------------------------------------------------------------------------------------------------------------------------------------------