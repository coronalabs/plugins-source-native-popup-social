--*********************************************************************************************
-- ====================================================================
-- Corona SDK "Native Social Popup" Sample Code
-- ====================================================================
--
-- File: main.lua
--
-- Version 1.1
--
-- Copyright (C) 2015 Corona Labs Inc. All Rights Reserved.
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
--
-- Revision History:
-- 		1.0: Initial version
-- 		1.1: UI update to allow certain things to be pre-filled. 
--			 Several bugfixes and improvements.
--*********************************************************************************************

-- Platforms: iOS, Android
-- Supported services: 
-- 		iOS: twitter, facebook, sinaWeibo, and tencentWeibo as of iOS 7.
-- 		Android: Anything that can be added to a share intent.
-- NOTE: More information on Sina Weibo here http://www.weibo.com/

-- If we are on the simulator, show a warning that this plugin is only supported on device
local isSimulator = "simulator" == system.getInfo( "environment" )

if isSimulator then
	native.showAlert( "Build for device", "This plugin is not supported on the Corona Simulator, please build for an iOS/Android device or Xcode simulator", { "OK" } )
end

-- Hide the status bar
display.setStatusBar( display.HiddenStatusBar )

-- Require the widget library
local widget = require( "widget" )

-- Use the iOS 7 theme for this sample
widget.setTheme( "widget_theme_ios7" )

-- This is the name of the native popup to show, in this case we are showing the "social" popup
local popupName = "social"

-- Display a background
local background = display.newImage( "world.jpg", display.contentCenterX, display.contentCenterY, true )

-- Display some text
local achivementText = display.newText --( "You saved the planet!\n\nTouch any of the buttons below to share your victory with your friends!", 12, 10, display.contentWidth - 20, 0, native.systemFontBold, 18 )
{
	text = "You saved the planet!\nTouch any of the buttons below to share your victory with your friends!",
	x = display.contentCenterX,
	y = 60,
	-- Keep our text field within inner 80% of the screen so that it won't roll off on some devices.
	width = (0.8) * display.contentWidth,
	height = 0,
	font = native.systemFontBold,
	fontSize = 18,
	align = "center",
}

local sendMessage = false
local sendURL = false
local sendImage = false

-- Exectuted upon touching & releasing a widget button
local function onShareButtonReleased( event )
	local serviceName = event.target.id
	local isAvailable = native.canShowPopup( popupName, serviceName )

	-- For demonstration purposes, we set isAvailable to true here for Android.
	if "Android" == system.getInfo( "platformName" ) then
		isAvailable = true
	end

	-- If it is possible to show the popup
	if isAvailable then
		local listener = {}
		function listener:popup( event )
			print( "name(" .. event.name .. ") type(" .. event.type .. ") action(" .. tostring(event.action) .. ") limitReached(" .. tostring(event.limitReached) .. ")" )			
		end
		
		local options = {}
		options.service = serviceName
		options.listener = listener
		if sendMessage then
			options.message = "I saved the planet using Corona SDK"
		end
		if sendURL then
			options.url = { "http://www.coronalabs.com" }
		end
		if sendImage then
			options.image = {
				{ filename = "Icon.png", baseDir = system.ResourceDirectory },
			}
		end

		-- Show the popup
		native.showPopup( popupName, options )
	else
		if isSimulator then
			native.showAlert( "Build for device", "This plugin is not supported on the Corona Simulator, please build for an iOS/Android device or the Xcode simulator", { "OK" } )
		else
			-- Popup isn't available.. Show error message
			native.showAlert( "Cannot send " .. serviceName .. " message.", "Please setup your " .. serviceName .. " account or check your network connection (on android this means that the package/app (ie Twitter) is not installed on the device)", { "OK" } )
		end
	end
end


local function onSwitchPress( event )
    local switch = event.target
    print( "Switch with ID '"..switch.id.."' is on: "..tostring(switch.isOn) )
    if switch.id == "message" then
    	sendMessage = switch.isOn
    elseif switch.id == "url" then
    	sendURL = switch.isOn
    elseif switch.id == "image" then
    	sendImage = switch.isOn
    end
end

-- Create the checkbox for sending a message
local messageCheckbox = widget.newSwitch
{
    left = 50,
    top = 125,
    style = "checkbox",
    id = "message",
    onPress = onSwitchPress
}
local messageLabel = display.newText("Send message", messageCheckbox.x + 35, messageCheckbox.y, native.systemFont, 20)
messageLabel:setFillColor(1)
messageLabel.anchorX = 0

-- Create the checkbox for sending a URL
local urlCheckbox = widget.newSwitch
{
    left = 50,
    top = 175,
    style = "checkbox",
    id = "url",
    onPress = onSwitchPress
}
local urlLabel = display.newText("Send URL", urlCheckbox.x + 35, urlCheckbox.y, native.systemFont, 20)
urlLabel:setFillColor(1)
urlLabel.anchorX = 0

-- Create the checkbox for sending an image
local imageCheckbox = widget.newSwitch
{
    left = 50,
    top = 225,
    style = "checkbox",
    id = "image",
    onPress = onSwitchPress
}
local imageLabel = display.newText("Send Image", imageCheckbox.x + 35, imageCheckbox.y, native.systemFont, 20)
imageLabel:setFillColor(1)
imageLabel.anchorX = 0


-- Use the share intent on Android to get any platform we could want
if "Android" == system.getInfo( "platformName" ) then
	-- Create a background to go behind our widget buttons
	local buttonBackground = display.newRect( display.contentCenterX, display.contentHeight - 25, 220, 50 )
	buttonBackground:setFillColor( 0 )

	-- Create a share button
	local shareButton = widget.newButton
	{
		id = "share",
		left = 0,
		top = 430,
		width = 240,
		label = "Show Share Popup",
		onRelease = onShareButtonReleased,
	}
	shareButton.x = display.contentCenterX
else -- We're on iOS and need a button for each social service we want to support
	-- Create a background to go behind our widget buttons
	local buttonBackground = display.newRect( display.contentCenterX, 380, 220, 200 )
	buttonBackground:setFillColor( 0 )

	-- Create a facebook button
	local facebookButton = widget.newButton
	{
		id = "facebook",
		left = 0,
		top = 280,
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
		top = facebookButton.y + facebookButton.contentHeight * 0.5,
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
		top = twitterButton.y + twitterButton.contentHeight * 0.5,
		width = 240,
		label = "Share On SinaWeibo",
		onRelease = onShareButtonReleased,
	}
	sinaWeiboButton.x = display.contentCenterX

	-- Create a tencentWeibo button
	local tencentWeiboButton = widget.newButton
	{
		id = "tencentWeibo",
		left = 0,
		top = sinaWeiboButton.y + sinaWeiboButton.contentHeight * 0.5,
		width = 240,
		label = "Share On TencentWeibo",
		onRelease = onShareButtonReleased,
	}
	tencentWeiboButton.x = display.contentCenterX
end
