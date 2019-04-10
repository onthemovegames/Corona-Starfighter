-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- Your code here
-- Hide the status bar
display.setStatusBar( display.HiddenStatusBar )

-- Go to the menu scene
local composer = require( "composer" )
composer.gotoScene("scene-menu")