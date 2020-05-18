
-----------------------------------------------------------------------------------------
--
-- game.lua
--
-----------------------------------------------------------------------------------------
local function screenshot()

	--I set the filename to be "widthxheight_time.png"
	--e.g. "1920x1080_20140923151732.png"
	local date = os.date( "*t" )
	local timeStamp = table.concat({date.year .. date.month .. date.day .. date.hour .. date.min .. date.sec})
	local fname = display.pixelWidth.."x"..display.pixelHeight.."_"..timeStamp..".png"

	--capture screen
	local capture = display.captureScreen(false)

	--make sure image is right in the center of the screen
	capture.x, capture.y = display.contentWidth * 0.5, display.contentHeight * 0.5

	--save the image and then remove
	local function save()
		display.save( capture, { filename=fname, baseDir=system.DocumentsDirectory, isFullResolution=true } )
		capture:removeSelf()
		capture = nil
	end
	timer.performWithDelay( 100, save, 1)

	return true
end

--works in simulator too
local function onKeyEvent(event)
	if event.phase == "up" then
		--press s key to take screenshot which matches resolution of the device
    	    if event.keyName == "s" then
    		screenshot()
    	    end
        end
end

Runtime:addEventListener("key", onKeyEvent)


local composer = require( "composer" )
local json = require('json')
local scene = composer.newScene()

-- include Corona's "physics" library
local physics = require "physics"
physics.start()
physics.setGravity(0, 0)
-- physics.setDrawMode('hybrid')

local animation = require("plugin.animation")

-- Global device specific coordinates
local W = display.contentWidth
local H = display.contentHeight

--------------------------------------------

-- persistent data
local saveData
local highScore
local audioState
local paid
local gold
local firstTime = false

local filePath = system.pathForFile("saveData.json", system.DocumentsDirectory)
local file = io.open( filePath, "r" )

if file then
	local contents = file:read( "*a" )
	io.close( file )
	saveData = json.decode( contents )
end

if ( saveData == nil ) then
	firstTime = true
	saveData = {
		highScore = 0,
		audioState = true,
		paid = false,
		gold = false
	}
end

highScore = saveData.highScore
audioState = saveData.audioState
paid = saveData.paid
gold = saveData.gold

--------------------------------------------
-- in app purchase

local store
local targetAppStore = system.getInfo( "targetAppStore" )

if ( "apple" == targetAppStore ) then  -- iOS
    store = require( "store" )
elseif ( "google" == targetAppStore ) then  -- Android
    store = require( "plugin.google.iap.v3" )
elseif ( "amazon" == targetAppStore ) then  -- Amazon
    store = require( "plugin.amazon.iap" )
else
    print( "In-app purchases are not available for this platform." )
end

local productIdentifiers = {
    "pivot.gold"
}

local function productListener( event )
	for i = 1,#event.products do
        print( event.products[i].productIdentifier )
    end
end

local function transactionListener( event )
	local transaction = event.transaction

	-- print ('transaction listener', event.transaction, event.name)

	-- Google IAP initialization event
    if ( event.name == "init" ) then
        if not ( transaction.isError ) then
			-- Perform steps to enable IAP, load products, etc.
			store.loadProducts( productIdentifiers, productListener )

        else  -- Unsuccessful initialization; output error details
            -- print( transaction.errorType )
            -- print( transaction.errorString )
		end

    -- Store transaction event
	elseif ( event.name == "storeTransaction" ) then

        if ( transaction.state == "purchased" or transaction.state == "restored" ) then  -- Successful transaction
            -- print( json.prettify( event ) )
			-- print( "transaction: " .. json.prettify( transaction ) )

			activateGold()
        else  -- Unsuccessful transaction; output error details
			-- print( transaction.errorType )
			if (transaction.errorType == 7) then
				-- user already bought gold
				activateGold()
			end
            -- print( transaction.errorString )
		end

		store.finishTransaction(transaction)
	end
end

if (store) then
	store.init( transactionListener )
end

-- Load store products; store must be properly initialized by this point!
if (store and targetAppStore == "apple") then
	store.loadProducts( productIdentifiers, productListener )
end

--------------------------------------------

local sceneGroup
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
local bullet = nil
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
local goldText = nil
local pivotText = nil

local backgroundMusic
local audioOn, audioOff
local settings, settingsBackground, settingsOpen, settingsScrim
local restorePurchaseText

local powerUpIcon, powerUpText
local powerUpTimerBorder, powerUpTimerFill

local POWERUP_TIME = 10000
local GROWING_TIME = math.max(1200, 2400 - score * 100)

local powerUp = nil
local doubleMultiplier = false

function buyGold (event)
	if (store and event.phase == "began") then
		store.purchase( 'pivot.gold' )
	end
end

function activateGold ()
	print('activating gold')
	local file = io.open( filePath, "w" )
	paid = true
	saveData.paid = true

	if file then
		file:write( json.encode( saveData ) )
		io.close( file )
	end

	goldText.text = 'Gold Skin Activated'
	gold = true
	goldText:removeEventListener('touch', buyGold)

	if (cannon) then
		setGoldCannon()
	end
end

function goldClicked (event)
	if (event.phase == "began") then
		if (not paid) then
			buyGold({ phase="began" }) -- lol
		elseif gold then
			gold = false
			goldText.text = 'Gold Skin'
		else
			gold = true
			goldText.text = 'Gold Skin Activated'
		end
		local file = io.open( filePath, "w" )

		saveData.gold = gold

		if file then
			file:write( json.encode( saveData ) )
			io.close( file )
		end
	end
end

local function disposeSound( event )
    audio.stop( 1 )
    audio.dispose( backgroundMusic )
    backgroundMusic = nil
end

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
	circle:setFillColor(0, 156/255, 234/255)
	circle:setStrokeColor(0, 0, 0)

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
	if powerUp == 'MAGNET' then
		laser:setStrokeColor(0, 255/255, 255/255)
	else
		laser:setStrokeColor(0, 156/255, 234/255)
	end
	group:insert(laser)
end

function setGoldCannon ()
	cannon:setStrokeColor(253/255, 205/255, 0)
	transition.to(circles[score].stroke, { r=253/255, g=205/255, b=0, a=1, time=600, transition=easing.inCubic })
end

function activateCircle (circle)
	cannon = display.newRoundedRect(circle.x, circle.y, 18, 30, 3)
	cannon.strokeWidth = 5
	if powerUp == 'MAGNET' then
		cannon:setFillColor(0, 255/255, 255/255)
	else
		cannon:setFillColor(0, 156/255, 234/255)
	end

	if (gold) then
		setGoldCannon()
	else
		cannon:setStrokeColor(0, 0, 0)
	end

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

	local ROTATION_SPEED = math.min(0.06 + score / 33, 1.1)

	group:insert(activeCircleGroup)
	animation.to(activeCircleGroup, { rotation=-35 }, { speedScale=ROTATION_SPEED, iterations=-1, easing=easing.inOutSine, reflect=true })
	animation.to(laser, { rotation=-35 }, { speedScale=ROTATION_SPEED, iterations=-1, easing=easing.inOutSine, reflect=true })

	if powerUp == 'MAGNET' then
		transition.to(circle.fill, { r=0, g=255/255, b=255/255, a=1, time=600, transition=easing.inCubic })
	else
		transition.to(circle.fill, { r=0, g=156/255, b=234/255, a=1, time=600, transition=easing.inCubic })
	end

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

	if score == 1 then
		createPowerUp()
	end

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
		bullet:removeSelf()
		bullet = nil
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
	bullet = display.newRoundedRect(x, y - yOffset, 10, 50, 10)

	if powerUp == 'MAGNET' then
		bullet:setFillColor(0/255, 255/255, 255/255)
	else
		bullet:setFillColor(0, 156/255, 234/255)
	end

	bullet.strokeWidth = 0
	bullet:setStrokeColor(0, 0, 0)

	group:insert(bullet)
	bullet:toBack()

	physics.addBody(bullet, 'dynamic', { isSensor = true })

	local angle = activeCircleGroup.rotation
	local flyAngle = (angle - 90) / 180 * math.pi
	local flySpeed = 800 + score * 8

	bullet.rotation = angle
	bullet:setLinearVelocity(flySpeed * math.cos(flyAngle), flySpeed * math.sin(flyAngle))

	bullet:addEventListener('collision', onBulletCollision)

	bulletFlying = true
end

function createPowerUp ()
	powerUpIcon = display.newImage('magnet.png')
	powerUpIcon.width = 40; powerUpIcon.height = 40;
	powerUpIcon.x = 100
	powerUpIcon.y = 200 - yOffset
	group:insert(powerUpIcon)

	powerUpIcon:toFront()
	timer.performWithDelay(100, function () physics.addBody(powerUpIcon, 'dynamic', { isSensor = true }) end)

	powerUpIcon:addEventListener('collision', onPowerUpCollision)
end

function endPowerUp()
	powerUp = nil
	powerUpIcon:removeSelf()

	powerUpTimerBorder:removeSelf()
	powerUpTimerFill:removeSelf()

	transition.to(circles[score].fill, { r=0, g=156/255, b=234/255, a=1, time=600, transition=easing.inCubic })
	transition.to(cannon.fill, { r=0, g=156/255, b=234/255, a=1, time=600, transition=easing.inCubic })
	transition.to(laser.stroke, { r=0, g=156/255, b=234/255, a=1, time=600, transition=easing.inCubic })
end

function onPowerUpCollision (event)
	if (event.other == physicsBackground) then return end

	bulletFlying = false
	display.remove(event.other)

	local x, y = powerUpIcon:localToContent(0,0)

	powerUpText = display.newText('MAGNET', x, y, "VacationPostcardNF", 30)
	powerUpText:setFillColor(black)
	powerUpText.alpha = 0
	transition.to(powerUpText, { y=y-10, alpha=1, easing=easing.outCubic, time=300})
	timer.performWithDelay(2000, function () powerUpText:removeSelf() powerUpText = nil end)

	transition.to(circles[score].fill, { r=0, g=255/255, b=255/255, a=1, time=600, transition=easing.inCubic })
	transition.to(cannon.fill, { r=0, g=255/255, b=255/255, a=1, time=600, transition=easing.inCubic })
	transition.to(laser.stroke, { r=0, g=255/255, b=255/255, a=1, time=600, transition=easing.inCubic })

	powerUp = 'MAGNET'

	group:remove(powerUpIcon)
	sceneGroup:insert(powerUpIcon)

	powerUpIcon.y = y
	transition.to(powerUpIcon, { x=W-25, y=180, time=500, transition=easing.outCubic })

	powerUpTimerFill = display.newRect(W - 30, 410, 20, 200)
	powerUpTimerFill:setFillColor(0,1,1)
	powerUpTimerFill.anchorY = 1

	powerUpTimerBorder = display.newRect(W - 30, 310, 20, 200)
	powerUpTimerBorder:setFillColor(0,0,0,0)
	powerUpTimerBorder:setStrokeColor(0,0,0)
	powerUpTimerBorder.strokeWidth = 5

	transition.scaleTo(powerUpTimerFill, { yScale=0.01, time=POWERUP_TIME})
	timer.performWithDelay(POWERUP_TIME, endPowerUp)
end


local function onScreenTouch ( event )
	if ( event.phase == "began" and not bulletFlying) then
		animateCannon()
		shootBullet()
		if (burst) then
			timer.performWithDelay(50, shootBullet)
			timer.performWithDelay(100, shootBullet)
		end
	end
	return true
end

local function toggleAudio(event)
	if event.phase == "began" then
		audioState = not audioState

		audioOff.isVisible = not audioState
		audioOn.isVisible = audioState

		if audioState then
			audio.fade({channel=1, time=1000, volume=1.0})
		else
			audio.setVolume( 0.0, {channel=1} )
		end

		local file = io.open( filePath, "w" )
		saveData.audioState = audioState

		if file then
			file:write( json.encode( saveData ) )
			io.close( file )
		end

	end

	return true
end

function openSettings (event)
	if event.phase == 'began' then
		if (settingsOpen) then
			closeSettings({ phase = 'ended' })
			return true
		end

		settingsBackground:setFillColor((169 + score * 2) / 255, (255 - score * 4) / 255, (172 - score * 4) / 255)
		settingsBackground.alpha = 1

		audioOff.isVisible = not audioState
		audioOn.isVisible = audioState
		restorePurchaseText.isVisible = true

		settingsOpen = true
		settingsScrim:addEventListener('touch', closeSettings)

		if (store) then
			restorePurchaseText:addEventListener('touch', store.restore)
		end
	end
	return true
end

function closeSettings (event)
	if event.phase == 'ended' then
		settingsBackground.alpha = 0
		audioOff.isVisible = false
		audioOn.isVisible = false
		restorePurchaseText.isVisible = false

		settingsOpen = false
		settingsScrim:removeEventListener('touch', closeSettings)
		if (store) then
			restorePurchaseText:removeEventListener('touch', store.restore)
		end
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

	if (powerUp == 'MAGNET' and bullet) then
		if (not bullet.x) then return end

		local bx, by = bullet:localToContent(0,0)
		local vx, vy = bullet:getLinearVelocity()
		local bulletSlope = -vy / vx
		local dy = by - 130

		if (bullet.x + 1 / bulletSlope * dy < circles[score + 1].x) then
			bullet:setLinearVelocity(vx + 20, vy)
			bullet.rotation = bullet.rotation + 1
		else
			bullet:setLinearVelocity(vx - 20, vy)
			bullet.rotation = bullet.rotation - 1
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
	bullet = nil
	ammo = 3
	partialAmmo = 0
	yOffset = 0
	bulletFlying = false
	powerUp = nil

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
	sceneGroup = self.view

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
	timer.performWithDelay(500, function () transition.to(pivotText, { y=H/2-20, alpha=1, easing=easing.outCubic, time=300}) end)

	scoreText = display.newText('0', W / 2, 60, "VacationPostcardNF", 60)
	scoreText:setFillColor(black)

	gameOverText = display.newText('GAME OVER', W / 2, 200, "VacationPostcardNF", 60)
	gameOverText:setFillColor(black)

	highScoreText = display.newText('HIGH SCORE!', W / 2, 130, "VacationPostcardNF", 50)
	highScoreText:setFillColor(0, 156/255, 234/255)

	highScoreScoreText = display.newText('High Score: ' .. highScore, W / 2, H - 130, "VacationPostcardNF", 40)
	highScoreScoreText:setFillColor(black)

	playAgainText = display.newText('Play Again', W / 2, H - 60, "VacationPostcardNF", 50)
	playAgainText:setFillColor(black)

	goldText = display.newText('Gold Skin Activated', W / 2, H - 190, "VacationPostcardNF", 20)
	goldText:setFillColor(black)
	gameOverGroup:insert(goldText)

	goldText:addEventListener('touch', goldClicked)

	if (not gold) then
		goldText.text = 'Gold Skin'
	end

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

		settingsScrim = display.newRect(W / 2, H / 2, W, H)
		settingsScrim.alpha = 0.01

		settings = display.newImage('settings.png')
		settings.width = 30; settings.height = 30; settings.x = W-40; settings.y = 60

		settingsBackground = display.newRoundedRect(W / 2, H / 2, 200, 200, 20)
		settingsBackground.strokeWidth = 5
		settingsBackground:setStrokeColor(0, 0, 0)
		settingsBackground.alpha = 0

		audioOn = display.newImage('audio-on.png')
		audioOn.width = 30; audioOn.height = 30; audioOn.x = W / 2; audioOn.y = H / 2 - 40

		audioOff = display.newImage('audio-off.png')
		audioOff.width = 30; audioOff.height = 30; audioOff.x = W / 2; audioOff.y = H / 2 - 40

		audioOn:addEventListener( "touch", toggleAudio)
		audioOff:addEventListener( "touch", toggleAudio)

		audioOn.isVisible = false
		audioOff.isVisible = false

		restorePurchaseText = display.newText('RESTORE PURCHASE', W / 2, H / 2 + 40, "VacationPostcardNF", 20)
		restorePurchaseText:setFillColor(black)
		restorePurchaseText.isVisible = false

		backgroundMusic = audio.loadStream('Pivot.mp3')

		if (not audio.isChannelPlaying(1)) then
			backgroundMusicChannel = audio.play(backgroundMusic, { channel=1, loops=-1, onComplete=disposeSound })
			audio.resume()

			if audioState then
				audio.fade({channel=1, time=1000, volume=1.0})
			else
				audio.setVolume(0.0, {channel = 1})
			end
		end

		settings:addEventListener( "touch", openSettings)
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