
-----------------------------------------------------------------------------------------
--
-- menu.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
local json = require('json')
local scene = composer.newScene()

-- include Corona's "physics" library
local physics = require "physics"
physics.start()
physics.setGravity(0, 0)
-- physics.setDrawMode('hybrid')

local animation = require("plugin.animation")
local explosion = system.pathForFile('explosion.json', system.DocumentsDirectory)
local t = json.decodeFile(explosion)

-- Global device specific coordinates
local W = display.contentWidth
local H = display.contentHeight

--------------------------------------------

-- persistent data
local saveData
local highScore

local filePath = system.pathForFile("saveData.json", system.DocumentsDirectory)
local file = io.open( filePath, "r" )

if file then
	local contents = file:read( "*a" )
	io.close( file )
	saveData = json.decode( contents )
end

if ( saveData == nil ) then
	saveData = { highScore = 0 }
end

highScore = saveData.highScore

--------------------------------------------

local group = display.newGroup()
local ammoGroup = display.newGroup()
local activeCircleGroup
local gameOverGroup = display.newGroup()

local background = nil
local physicsBackground = nil
local score = 1
local ammo = 3
local partialAmmo = 0
local isGrowing = false
local circles = {}
local laser = nil
local cannon = nil
local partialAmmoRect
local cannonAnimation = nil
local slowCannonAnimation = nil
local bulletFlying = false
local yOffset = 0

local scoreText = nil
local gameOverText = nil
local highScoreText = nil
local highScoreScoreText = nil
local playAgainText = nil
local pivotText = nil

local GROWING_TIME = math.max(1200, 2400 - score * 100)

function addPhysics (circle)
	physics.addBody(circle, 'dynamic')

	if (score > 10) then
		physics.addBody(partialAmmoRect, 'kinematic', { isSensor=true })

		local direction
		if (math.random(0,1) == 1) then
			direction = score
		else
			direction = -score
		end

		circle:setLinearVelocity(direction * 10, 0)
		partialAmmoRect:setLinearVelocity(direction * 10, 0)
	end
end

function drawCircle (y, firstCircle)
	local x = math.random()
	if x < 0.2 then x = 0.2 end
	if x > 0.8 then x = 0.8 end

    local circle = display.newCircle(W * x, y, 30)
	circle.strokeWidth = 5
	circle:setStrokeColor(0, 0, 0)
	circle:setFillColor(0, 156/255, 234/255)

	group:insert(circle)
	isGrowing = true

	if not firstCircle then
		local GROWING_TIME = math.max(1500, 2400 - score * 50)

		circle:setFillColor(1,0,0)
		circle:scale(0.5, 0.5)
		transition.scaleTo(circle, { xScale=1, yScale=1, time=GROWING_TIME })

		partialAmmoRect = display.newRoundedRect(circle.x, circle.y, 8, 14, 8)
		group:insert(partialAmmoRect)
		partialAmmoRect:setFillColor(112/255, 207/255, 255/255)

		timer.performWithDelay(100, function () addPhysics(circle) end)
		timer.performWithDelay(GROWING_TIME, function ()
			if (circle == circles[score + 1]) then
				circle:setFillColor(193/255, 71/255, 106/255)
				isGrowing = false
				partialAmmoRect.alpha = 0
				if (partialAmmoRect.isBodyActive) then
					physics.removeBody(partialAmmoRect)
				end
			end
		end)
	end

	table.insert(circles, circle)
	circle:addEventListener('collision', onCircleCollision)
end

function drawLaser (circle)
	laser = display.newLine(circle.x, circle.y, circle.x, circle.y - 1000)
	laser.strokeWidth = 2
	laser.rotation = 35
	laser:setStrokeColor(0, 156/255, 234/255)
	group:insert(laser)
end

function activateCircle (circle)
	cannon = display.newRoundedRect(circle.x, circle.y, 18, 30, 3)
	cannon:setFillColor(0, 156/255, 234/255)
	cannon.strokeWidth = 5
	cannon:setStrokeColor(0, 0, 0)

	local circlePlaceholder = display.newRect(circle.x, circle.y, 100, 100)
	circlePlaceholder.alpha = 0

	activeCircleGroup = display.newGroup()
	activeCircleGroup.anchorChildren = true
	activeCircleGroup.anchorX = 0.5
	activeCircleGroup.anchorY = 0.5

	activeCircleGroup.x = circle.x
	activeCircleGroup.y = circle.y
	activeCircleGroup:insert(cannon)
	activeCircleGroup:insert(circle)
	activeCircleGroup:insert(circlePlaceholder)
	activeCircleGroup.rotation = 35

	local ROTATION_SPEED = math.min(0.1 + score / 20, 1.1)

	group:insert(activeCircleGroup)
	animation.to(activeCircleGroup, { rotation=-35 }, { speedScale=ROTATION_SPEED, iterations=-1, easing=easing.inOutSine, reflect=true })
	animation.to(laser, { rotation=-35 }, { speedScale=ROTATION_SPEED, iterations=-1, easing=easing.inOutSine, reflect=true })

	transition.to(circle.fill, { r=0, g=156/255, b=234/255, a=1, time=600, transition=easing.inCubic })
	slowCannonAnimation = animation.to(cannon, { y=cannon.y - 27 }, { time=800 })
end

function removeOldCircle ()
	while activeCircleGroup.numChildren > 0 do
		local child = activeCircleGroup[1]
		if child then child:removeSelf() end
	end
end

function drawAmmo ()
	while ammoGroup.numChildren > 0 do
		local child = ammoGroup[1]
		if child then child:removeSelf() end
	end

	for i=1,ammo  do
		local ammoRect = display.newRoundedRect(10 + 14 * i, 60, 8, 30, 8)
		ammoRect:setFillColor(0, 156/255, 234/255)
		ammoGroup:insert(ammoRect)
	end

	for i=1,partialAmmo  do
		local fixedPartialAmmoRect = display.newRoundedRect(10 + 14 * (ammo + 1), 78 - 10 * i, 8, 14, 8)
		fixedPartialAmmoRect:setFillColor(112/255, 207/255, 255/255)
		ammoGroup:insert(fixedPartialAmmoRect)
	end
end

function onCircleCollision (event)
	if (event.other == physicsBackground or event.other == partialAmmoRect) then return end

	timer.performWithDelay(400, function () bulletFlying = false end )

	display.remove(event.other)
	display.remove(laser)

	if (isGrowing) then
		isGrowing = false
		group:remove(partialAmmoRect)
		ammoGroup:insert(partialAmmoRect)
		partialAmmoRect.y = event.target.y + yOffset
		transition.to(partialAmmoRect, { x=10 + 14 * (ammo + 1), y=78 - 10 * (partialAmmo + 1), time=500, transition=easing.outCubic })

		if (partialAmmo == 2) then
			ammo = ammo + 1
			partialAmmo = 0
		else
			partialAmmo = partialAmmo + 1
		end
		timer.performWithDelay(500, drawAmmo)
	end

	event.target:setLinearVelocity(0,0)
	event.target:removeEventListener('collision', onCircleCollision)

	yOffset = yOffset + circles[score].y - circles[score + 1].y
	transition.to(group, { y=yOffset, time=600, transition=easing.outSine })
	transition.to(physicsBackground, { y=-yOffset, time=600, transition=easing.outSine })

	animation.to(scoreText, { xScale=1.2, yScale=1.2 }, { time=100, iterations=2, reflect=true })

	score = score + 1
	scoreText.text = score - 1

	transition.to(background.fill, { r = (169 + score * 2) / 255, g = (255 - score * 4) / 255, b = (172 - score * 4) / 255, a = 1, time=1000, transition=easing.inCubic })

	drawCircle(120 - yOffset)
	drawLaser(circles[score])

	activateCircle(circles[score])
end

function onBulletCollision (event)
	if (event.other == physicsBackground and event.phase == 'ended') then
		bulletFlying = false
		ammo = ammo - 1

		if (ammo < 1) then
			gameOver()
		else
			drawAmmo()
		end
	end
end

function animateCannon()
	local x, y = circles[score]:localToContent(0,0)

	if cannonAnimation ~= nil then
		animation.setPosition(cannonAnimation, 200)
	end

	if cannonAnimation ~= nil then
		animation.setPosition(slowCannonAnimation, 800)
	end

	cannonAnimation = animation.to(cannon, { y = 7 + cannon.y },{ iterations = 2, time = 100, reflect = true})
end

function shootBullet ()
	local x, y = circles[score]:localToContent(0,0)
	local bullet = display.newRoundedRect(x, y - yOffset, 10, 50, 10)

	bullet:setFillColor(0, 156/255, 234/255)

	bullet.strokeWidth = 0
	bullet:setStrokeColor(0, 0, 0)

	group:insert(bullet)
	bullet:toBack()
	-- background:toBack()

	-- display.newEmitter(t)

	physics.addBody(bullet, 'dynamic', { isSensor = true })

	local angle = activeCircleGroup.rotation
	local flyAngle = (angle - 90) / 180 * math.pi
	local flySpeed = 800 + score * 8

	bullet.rotation = angle
	bullet:setLinearVelocity(flySpeed * math.cos(flyAngle), flySpeed * math.sin(flyAngle))

	bullet:addEventListener('collision', onBulletCollision)

	bulletFlying = true
end

local function onScreenTouch ( event )
	if ( event.phase == "began" and not bulletFlying) then
		animateCannon()
		shootBullet()
	end
	return true
end


-- for detecting when lasers leave the screen
function createPhysicsBackground ()
	physicsBackground = display.newRect(0, 0, W, H)
	physicsBackground.anchorX = 0
	physicsBackground.anchorY = 0
	physicsBackground.x = 0 + display.screenOriginX
	physicsBackground.y = 0 + display.screenOriginY
	physicsBackground.alpha = 0

	physics.addBody(physicsBackground, 'static', { isSensor = true })
	group:insert(physicsBackground)
end

function everyFrame (event)
	if (circles[score + 1] == nil) then return end

	if (circles[score + 1].x > W - 30) then
		circles[score + 1]:setLinearVelocity(-score * 10, 0)
		if (partialAmmoRect.isBodyActive) then
			partialAmmoRect:setLinearVelocity(-score * 10, 0)
		end
	elseif (circles[score + 1].x < 30) then
		circles[score + 1]:setLinearVelocity(score * 10, 0)
		if (partialAmmoRect.isBodyActive) then
			partialAmmoRect:setLinearVelocity(score * 10, 0)
		end
	end
end

function gameOver ()
	if (score - 1 > highScore) then
		saveHighScore()
		highScoreText.alpha = 1
		highScoreScoreText.text = 'High Score: ' .. highScore
	else
		highScoreText.alpha = 0
	end

	ammoGroup.alpha = 0
	background:removeEventListener('touch', onScreenTouch)
	transition.fadeOut(group, { time=1000 })
	timer.performWithDelay(1000, function () transition.fadeIn(gameOverGroup, { time=600 }) end)
	timer.performWithDelay(1500, function () playAgainText:addEventListener('touch', initGame) end)
end

function initGame ()
	animation.to(playAgainText, { xScale=1.1, yScale=1.1 }, { time=70, iterations=2, reflect=true })
	while group.numChildren > 0 do
		local child = group[1]
		if child then child:removeSelf() end
	end

	score = 1
	circles = {}
	laser = nil
	ammo = 3
	partialAmmo = 0
	yOffset = 0
	bulletFlying = false

	scoreText.text = score - 1

	group.y = 0

	createPhysicsBackground()
	drawCircle(H - 60, true)
	drawCircle(130)

	drawLaser(circles[score])
	drawAmmo()

	playAgainText:removeEventListener('touch', initGame)
	timer.performWithDelay(1000, function () background:addEventListener('touch', onScreenTouch) end)

	activateCircle(circles[score])

	transition.fadeOut(gameOverGroup, { time = 500 })

	timer.performWithDelay(500, function () transition.fadeIn(group, { time=1000 }) end)
	timer.performWithDelay(500, function () transition.fadeIn(ammoGroup, { time=1000 }) end)
	timer.performWithDelay(500, function () transition.fadeIn(scoreText, { time=1000 }) end)

	transition.to(background.fill, { r = 169/255, g = 1, b = 172/255, a = 1, time=1000, transition=easing.inCubic })
	highScoreText.alpha = 0
end

function saveHighScore()
	local file = io.open( filePath, "w" )
	highScore = score - 1
	saveData.highScore = highScore

	if file then
		file:write( json.encode( saveData ) )
        io.close( file )
    end
end

--------------------------------------------

function scene:create( event )
	local sceneGroup = self.view

	-- Called when the scene's view does not exist.
	--
	-- timer.performWithDelay(500, startPhysics)
	-- INSERT code here to initialize the scene
	-- e.g. add display objects to 'sceneGroup', add touch listeners, etc.

	background = display.newRect(0, 0, W, H)
	background.anchorX = 0
	background.anchorY = 0
	background.x = 0 + display.screenOriginX
	background.y = 0 + display.screenOriginY

	background:setFillColor(169/255, 253/255, 172/255)
	sceneGroup:insert(background)

	pivotText = display.newText('PIVOT', W/2, H/2 - 5, "VacationPostcardNF", 80)
	pivotText:setFillColor(black)
	pivotText.alpha = 0
	transition.to(pivotText, { y=H/2-20, alpha=1, easing=easing.outCubic, time=300})

	scoreText = display.newText('0', W / 2, 60, "VacationPostcardNF", 60)
	scoreText:setFillColor(black)

	gameOverText = display.newText('GAME OVER', W / 2, 200, "VacationPostcardNF", 60)
	gameOverText:setFillColor(black)

	highScoreText = display.newText('HIGH SCORE!', W / 2, 130, "VacationPostcardNF", 50)
	highScoreText:setFillColor(0, 156/255, 234/255)

	highScoreScoreText = display.newText('High Score: ' .. highScore, W / 2, H - 130, "VacationPostcardNF", 40)
	highScoreScoreText:setFillColor(0, 156/255, 234/255)

	playAgainText = display.newText('Play Again', W / 2, H - 60, "VacationPostcardNF", 50)
	playAgainText:setFillColor(black)

	gameOverGroup:insert(gameOverText)
	gameOverGroup:insert(highScoreText)
	gameOverGroup:insert(highScoreScoreText)
	gameOverGroup:insert(playAgainText)

	gameOverGroup.alpha = 0
	scoreText.alpha = 0

	group.alpha = 0
	ammoGroup.alpha = 0

	timer.performWithDelay(2300, function () transition.to(pivotText, { alpha = 0 }) end)
	timer.performWithDelay(2500, initGame)
end

Runtime:addEventListener('enterFrame', everyFrame)

function scene:show( event )
	local sceneGroup = self.view
    local phase = event.phase

	if phase == "will" then
		-- Called when the scene is still off screen and is about to move on screen
	elseif phase == "did" then
		-- Called when the scene is now on screen
		--
		-- INSERT code here to make the scene come alive
        -- e.g. start timers, begin animation, play audio, etc.

	end
end

function scene:hide( event )
	local sceneGroup = self.view
    local phase = event.phase

	if event.phase == "will" then
		-- Called when the scene is on screen and is about to move off screen
		--
		-- INSERT code here to pause the scene
		-- e.g. stop timers, stop animation, unload sounds, etc.)
	elseif phase == "did" then
		-- Called when the scene is now off screen
	end
end

function scene:destroy( event )
    local sceneGroup = self.view

	-- Called prior to the removal of scene's "view" (sceneGroup)
	--
	-- INSERT code here to cleanup the scene
    -- e.g. remove display objects, remove touch listeners, save state, etc.
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------

return scene