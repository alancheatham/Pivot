
-----------------------------------------------------------------------------------------
--
-- menu.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
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

local startCircle
local background = nil
local score = 1
local scoreText = nil
local circles = {}
local laser = nil
local group = display.newGroup()
local activeCircleGroup
local cannon = nil
local cannonAnimation = nil
local slowCannonAnimation = nil

local yOffset = 0

function addPhysics (circle)
	physics.addBody(circle, 'dynamic')
	circle:setLinearVelocity(100, 0)
end

function drawCircle (y, disablePhysics)
	local x = math.random()
	if x < 0.2 then x = 0.2 end
	if x > 0.8 then x = 0.8 end

    local circle = display.newCircle(W * x, y, 30)
	circle:setFillColor(193/255, 71/255, 106/255)
	circle.strokeWidth = 5
	circle:setStrokeColor(0, 0, 0)

	group:insert(circle)

	if not disablePhysics then
		timer.performWithDelay(100, function () addPhysics(circle) end)
	end
	table.insert(circles, circle)
	circle:addEventListener('collision', onCircleCollision)
end

function drawLaser (circle)
	laser = display.newLine(circle.x, circle.y, circle.x, circle.y - 1000)
	laser.strokeWidth = 2
	laser.rotation = 30
	laser:setStrokeColor(0, 156/255, 234/255)
	group:insert(laser)
	laser:toBack()
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

	group:insert(activeCircleGroup)
	animation.to(activeCircleGroup, { rotation = -35 }, { speedScale = 0.18 + score / 20, iterations=-1, easing = easing.inOutSine, reflect=true })
	animation.to(laser, { rotation = -35 }, { speedScale = 0.18 + score / 20, iterations=-1, easing = easing.inOutSine, reflect=true })

	transition.to(circle.fill, { r = 0, g = 156 / 255, b = 234 / 255, a = 1, time=600, transition=easing.inCubic })
	slowCannonAnimation = animation.to(cannon, { y = cannon.y - 27 }, { time = 800 })
end

function removeOldCircle ()
	while activeCircleGroup.numChildren > 0 do
		local child = activeCircleGroup[1]
		if child then child:removeSelf() end
	end
end

function onCircleCollision (event)
	display.remove(event.other)
	display.remove(laser)

	event.target:setLinearVelocity(0,0)
	event.target:removeEventListener('collision', onCircleCollision)

	yOffset = yOffset + circles[score].y - circles[score + 1].y
	transition.to(group, { y = yOffset, time = 600, transition=easing.outSine })
	score = score + 1
	scoreText.text = score - 1

	transition.to(background.fill, { r = (169 + score * 2) / 255, g = (255 - score * 4) / 255, b = (172 - score * 4) / 255, a = 1, time=1000, transition=easing.inCubic })

	drawCircle(120 - yOffset)
	drawLaser(circles[score])

	activateCircle(circles[score])
end

function onScreenTouch ( event )
	if ( event.phase == "began" ) then
		local x, y = circles[score]:localToContent(0,0)
		local fly = display.newRoundedRect(x, y - yOffset, 10, 50, 10)

		if cannonAnimation ~= nil then
			animation.setPosition(cannonAnimation, 200)
		end

		if cannonAnimation ~= nil then
			animation.setPosition(slowCannonAnimation, 800)
		end
		cannonAnimation = animation.to(cannon, { y = 7 + cannon.y },{ iterations = 2, time = 100, reflect = true})

		fly:setFillColor(0, 156/255, 234/255)

		fly.strokeWidth = 0
		fly:setStrokeColor(0, 0, 0)

		group:insert(fly)
		fly:toBack()

		physics.addBody(fly, 'dynamic', { isSensor = true })

		local angle = activeCircleGroup.rotation
		local flyAngle = (angle - 90) / 180 * math.pi
		local flySpeed = 800

		fly.rotation = angle
		fly:setLinearVelocity(flySpeed * math.cos(flyAngle), flySpeed * math.sin(flyAngle))
	end
	return true
end

function everyFrame (event)
	if (circles[score + 1] == nil) then return end

	if (circles[score + 1].x > W - 30) then
		circles[score + 1]:setLinearVelocity(-100)
	elseif (circles[score + 1].x < 30) then
		circles[score + 1]:setLinearVelocity(100)
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

	-- display a background image
	background = display.newRect(0, 0, W, H)
	background.anchorX = 0
	background.anchorY = 0
	background.x = 0 + display.screenOriginX
	background.y = 0 + display.screenOriginY

	background:setFillColor(169/255, 253/255, 172/255)

	background:addEventListener('touch', onScreenTouch )


	-- create/position logo/title image on upper-half of the screen
	-- all display objects must be inserted into group
    sceneGroup:insert( background )

	drawCircle(H - 80, true)
	drawCircle(120)

	drawLaser(circles[score])

	scoreText = display.newText('0', W / 2, 60, native.systemFont, 30)
	scoreText:setFillColor(black)
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

		activateCircle(circles[score])
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

	if playBtn then
		playBtn:removeSelf()	-- widgets must be manually removed
		playBtn = nil
	end
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------

return scene