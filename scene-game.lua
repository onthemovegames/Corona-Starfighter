local composer = require( "composer" )
local scene = composer.newScene()

local widget = require( "widget" )
local physics = require( "physics" )
physics.start()
physics.setGravity(0, 0)
--physics.setDrawMode( "hybrid" ) -- If you want to see the physics bodies in the game, uncomment this line. This will help show you where the boundaries for each object are.

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------
-- These values are set for easier access later on.
local acw = display.actualContentWidth
local ach = display.actualContentHeight
local cx = display.contentCenterX
local cy = display.contentCenterY
local top = display.screenOriginY
local left = display.screenOriginX
local right = display.viewableContentWidth - left
local bottom = display.viewableContentHeight - display.screenOriginY

-- The next lines are forward declares
local createEnemyShips, timerForEnemies -- forward declares for function and timer
local enemyShip = {} -- a table to store the enemy circles
local enemyCounter = 0 -- a counter to store the number of enemies

local playerShip -- forward declare the player ship
local playerScore -- stores the text object that displays player score
local playerScoreCounter = 0 -- a counter to store the players score

local createBullets, timerForBullets -- variables to track bullet function and timer
local bullet = {} -- table that will hold the bullet
local bulletCounter = 0 -- although not necessary, I've added a counter to keep track of the number of bullets. This might be handy if you want to display how many shots the player took or player accuracy.

local onGlobalCollision -- forward declare for collisions. Collisions is what I use to detect hits between player-enemy and bullets-enemy.

-- -----------------------------------------------------------------------------------
-- Scene event functions

-- This is called to stop the game. It will stop bullets, stop enemies, and disallow movement by player. We will also set the stage focus to nil which restore default behavior. This will tell the app that the game is over and the player should no longer be interacting with the player ship.
local function stopGame()
    playerShip:removeEventListener( "touch", playerShip )
    timer.cancel(timerForEnemies)
    timer.cancel(timerForBullets)
    display.getCurrentStage():setFocus( nil )
end

-- This is called when the menu button is touched. This will send the player back to the menu.
local function onMenuTouch( event )
  if ( "ended" == event.phase ) then
    stopGame()
    composer.gotoScene("scene-menu")    
  end
end

local function increasePlayerScore()
    playerScoreCounter = playerScoreCounter + 1
    playerScore.text = "Score: "..playerScoreCounter
end

-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

    local sceneGroup = self.view
    -- Code here runs when the scene is first created but has not yet appeared on screen

    -- Create the background
    local background = display.newImageRect(sceneGroup, "images/background.png", 475, 713)
        background.x = cx
        background.y = cy

    -- Create the black bar at the top of the screen
    local topbar = display.newImageRect(sceneGroup, "images/topbar.png", 475, 31)        
        topbar.anchorY = 0
        topbar.x = cx
        topbar.y = top

    -- Create a text object to keep track of the player score
    playerScore = display.newText(sceneGroup, "Score: "..playerScoreCounter, 0, 0, native.systemFont, 20)
        playerScore:setFillColor(1)
        playerScore.anchorX = 1
        playerScore.x = right - 5
        playerScore.y = topbar.y + 15

    -- Create a button to allow the player to return to the menu
    local btn_menu = widget.newButton({
      label = "Menu",
      fontSize = 24,
      labelColor = { default={ 1, 1, 1 }, over={ 1, 1, 1, 0.5 } },
      onEvent = onMenuTouch
    })
    btn_menu.x = left + 40
    btn_menu.y = topbar.y + 15
    sceneGroup:insert(btn_menu)    

    -- Create a player ship
    playerShip = display.newImageRect(sceneGroup, "images/playerShip.png", 75, 100)
        playerShip.x = math.random(100,400)
        playerShip.y = bottom - 75
        playerShip.id = "player" -- assign an id for physics collision later

        local image_outline = graphics.newOutline( 2, "images/playerShip.png" ) -- If we created a physics body without an outline, the physics body will be squared around the ship. In our case, it'll be a 75x100 square. Instead of a block, it'll make a better game if we create an outline around the image. This will make the hit area just on the image of the ship itself. Uncomment line 8 to this tighter integration.
        physics.addBody( playerShip, { outline=image_outline } ) -- make it a physics object

    -- touch listener function
    function playerShip:touch( event )
        if event.phase == "began" then
            -- first we set the focus on the object
            display.getCurrentStage():setFocus( self, event.id )
            self.isFocus = true

            -- then we store the original x and y position
            self.markX = self.x
        elseif self.isFocus then
            if event.phase == "moved" then
                -- then drag our object
                self.x = event.x - event.xStart + self.markX
            elseif event.phase == "ended" or event.phase == "cancelled" then
                -- we end the movement by removing the focus from the object
                display.getCurrentStage():setFocus( self, nil )
                self.isFocus = false
            end
        end
        return true -- return true so Corona knows that the touch event was handled properly
    end
    playerShip:addEventListener( "touch", playerShip )

    -- The game over function. Display background, title, and a menu button
    gameOver = function()        
        local gameOverBackground = display.newRect(sceneGroup, 0, 0, acw, ach)
            gameOverBackground.x = cx
            gameOverBackground.y = cy
            gameOverBackground:setFillColor(0,0,0,0.45)

        local gameOverTitle = display.newImageRect(sceneGroup, "images/gameOver.png", 339, 284)
            gameOverTitle.x = cx
            gameOverTitle.y = cy * 0.65

        local gameOverMenu = display.newImageRect(sceneGroup, "images/toMenu.png", 203, 65)
            gameOverMenu.x = cx
            gameOverMenu.y = gameOverTitle.y + 250
            gameOverMenu:addEventListener("touch", onMenuTouch)

        stopGame() -- stop the game when it's game over
    end

    -- Create an enemy ship that spawn at the top of the screen. The ships start off screen to make it look like they are flying in. The x position is a randomly assigned X position.
    createEnemyShips = function()
        enemyCounter = enemyCounter + 1

        enemyShip[enemyCounter] = display.newImageRect(sceneGroup, "images/enemyShip.png", 70, 46)
            enemyShip[enemyCounter].x = math.random(left+20, right-20)
            enemyShip[enemyCounter].y = top - 50
            enemyShip[enemyCounter].id = "enemy" -- set an id. This is used for physics collisions.            
            physics.addBody( enemyShip[enemyCounter] ) -- add a physics body to our enemy ship. I left this as the default rectangle body. Creating an outline creates overhead and eats up more memory. That shouldn't be a concern in this game, but something to think about.
            enemyShip[enemyCounter].isSensor = true -- by making it a sensor, the enemy ship will not respond to physic collisions

        transition.to(enemyShip[enemyCounter], {y=bottom+50, time=math.random(3750,6000), onComplete=function(self) display.remove(self) end}) -- transition.to is what we use to move our enemy ships
    end

    -- Create bullets that spawn in front of the player. 
    createBullets = function()
        bulletCounter = bulletCounter + 1

        bullet[bulletCounter] = display.newImageRect(sceneGroup, "images/bullet.png", 10, 25)
            bullet[bulletCounter].x = playerShip.x
            bullet[bulletCounter].y = playerShip.y - 40 -- start the bullet in front of the player ship
            bullet[bulletCounter].id = "bullet" -- set an id. This is used for physics collisions.            
            physics.addBody( bullet[bulletCounter] ) -- add a physics body to our bullet
            bullet[bulletCounter].isSensor = true -- by making it a sensor, the bullet will not respond to physic collisions

        transition.to(bullet[bulletCounter], {y=top-50, time=1500, onComplete=function(self) display.remove(self) end})
    end

    -- Create a global collision function that will be trigged when two physics objects collide. In our case, it's bullet-enemy or player-enemy.
    onGlobalCollision = function(event)
        local obj1 = event.object1 -- store the objects into obj1 and obj2 for easy reference later
        local obj2 = event.object2

        -- Since it's always a bad idea to remove a display object in the middle of collision detection (funky things can happen, it's like taking food right out of your mouth before you swallow), we have a function that's called 1ms after collision happens. This function removes both objects.
        local function removeEnemyAndBullet() 
            display.remove(obj1)
            display.remove(obj2)
            increasePlayerScore()
        end

        if ( event.phase == "began" ) then            
            -- Detect collision between enemy and bullet. If so, call removeEnemyAndBullet
            if(obj1.id == "enemy" and obj2.id == "bullet") then                 
                timer.performWithDelay ( 1, removeEnemyAndBullet )
            end
            if(obj1.id == "bullet" and obj2.id == "enemy") then                 
                timer.performWithDelay ( 1, removeEnemyAndBullet )
            end

            -- Detect collision between enemy and player. If so, call gameOver.
            if(obj1.id == "enemy" and obj2.id == "player") then                 
                timer.performWithDelay ( 1, gameOver )
            end
            if(obj1.id == "player" and obj2.id == "enemy") then                 
                timer.performWithDelay ( 1, gameOver )
            end
        end
    end
end


-- show()
function scene:show( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is still off screen (but is about to come on screen)

    elseif ( phase == "did" ) then
        -- Code here runs when the scene is entirely on screen

        -- The game will start to run from here. When the scene is loaded, enemy ships will be generated, the player will start firing, and colliding physics objects will be acted on.
        timerForEnemies = timer.performWithDelay(1000, createEnemyShips, 0)
        timerForBullets = timer.performWithDelay(750, createBullets, 0)
        Runtime:addEventListener( "collision", onGlobalCollision )
    end
end


-- hide(), this function is not used in this template and here for learning purposes only.
function scene:hide( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is on screen (but is about to go off screen)

    elseif ( phase == "did" ) then
        -- Code here runs immediately after the scene goes entirely off screen

    end
end


-- destroy(), this function is not used in this template and here for learning purposes only.
function scene:destroy( event )

    local sceneGroup = self.view
    -- Code here runs prior to the removal of scene's view

end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene