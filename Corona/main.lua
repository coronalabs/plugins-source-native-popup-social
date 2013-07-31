--*********************************************************************************************
-- ====================================================================
-- Corona SDK "Native Social Popup" Sample Code
-- ====================================================================
--
-- File: main.lua
--
-- Version 1.0
--
-- Copyright (C) 2013 Corona Labs Inc. All Rights Reserved.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of 
-- this software and associated documentation files (the "Software"), to deal in the 
-- Software without restriction, including without limitation the rights to use, copy, 
-- modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
-- and to permit persons to whom the Software is furnished to do so, subject to the 
-- following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all copies 
-- or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
-- DEALINGS IN THE SOFTWARE.
--
-- Published changes made to this software and associated documentation and module files (the
-- "Software") may be used and distributed by Corona Labs, Inc. without notification. Modifications
-- made to this software and associated documentation and module files may or may not become
-- part of an official software release. All modifications made to the software will be
-- licensed under these same terms and conditions.
--*********************************************************************************************

-- Supported services: twitter, facebook & sinaWeibo
-- Platforms: iOS
-- NOTE: More information on Sina Weibo here http://www.weibo.com/

-- If we are on the simulator, show a warning that this plugin is only supported on device
if "simulator" == system.getInfo( "environment" ) then
	native.showAlert( "Build for device", "This plugin is not supported on the Corona Simulator, please build for an iOS device or Xcode simulator", { "OK" } )
end

-- Hide the status bar
display.setStatusBar( display.HiddenStatusBar )

-- Require the widget library
local widget = require( "widget" )

-- This is the name of the native popup to show, in this case we are showing the "social" popup
local popupName = "social"

-- Display a background
local background = display.newImage( "world.jpg", true )

-- Display some text
local achivementText = display.newText( "You saved the planet!\n\nTouch any of the buttons below to share your victory with your friends!", 12, 10, display.contentWidth - 20, 0, native.systemFontBold, 18 )

-- Exectuted upon touching & releasing a widget button
local function onShareButtonReleased( event )
	local serviceName = event.target.id
	local isAvailable = native.canShowPopup( popupName, serviceName )

	-- If it is possible to show the popup
	if isAvailable then
		local listener = {}
		function listener:popup( event )
			print( "name(" .. event.name .. ") type(" .. event.type .. ") action(" .. tostring(event.action) .. ") limitReached(" .. tostring(event.limitReached) .. ")" )			
		end

		-- Show the popup
		native.showPopup( popupName,
		{
			service = serviceName,
			message = "I saved the planet using the Corona SDK!",
			listener = listener,
			image = 
			{
				{ filename = "world.jpg", baseDir = system.ResourceDirectory },
			},
			url = 
			{ 
				"http://www.apple.com",
				"http://www.coronalabs.com",
				"http://docs.coronalabs.com",
				"http://developer.coronalabs.com" 
			}
		})
	else
		-- Popup isn't available.. Show error message
		native.showAlert( "Cannot send " .. serviceName .. " message.", "Please setup your " .. serviceName .. " account or check your network connection", { "OK" } )
	end
end


-- Create a facebook button
local facebookButton = widget.newButton
{
	id = "facebook",
	left = 0,
	top = 180,
	width = 240,
	label = "Share On Facebook",
	onRelease = onShareButtonReleased,
}
facebookButton.x = display.contentCenterX

-- Create a twitter button
local twitterButton = widget.newButton
{
	id = "twitter",
	left = 0,
	top = 260,
	width = 240,
	label = "Share On Twitter",
	onRelease = onShareButtonReleased,
}
twitterButton.x = display.contentCenterX

-- Create a sinaWeibo button
local sinaWeiboButton = widget.newButton
{
	id = "sinaWeibo",
	left = 0,
	top = 340,
	width = 240,
	label = "Share On SinaWeibo",
	onRelease = onShareButtonReleased,
}
sinaWeiboButton.x = display.contentCenterX
