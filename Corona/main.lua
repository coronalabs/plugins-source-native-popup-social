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

local popupName = "social"
local serviceName = "twitter" -- Supported values: "twitter", "facebook", "sinaWeibo"

local isAvailable = native.canShowPopup( popupName, serviceName )

if isAvailable then
	local listener = {}
	function listener:popup( event )
		print( "name(" .. event.name .. ") type(" .. event.type .. ") action(" .. tostring(event.action) .. ") limitReached(" .. tostring(event.limitReached) .. ")" )
	end

	native.showPopup(
		popupName,
		{
			service = serviceName,
			message = "hi there!",
			listener = listener,
			image = 
			{
				{ filename = "world.jpg", baseDir = system.ResourceDirectory },
				{ filename = "bkg_wood.png", baseDir = system.ResourceDirectory },
			},
			url = 
			{ 
				"http://www.apple.com",
				"http://www.coronalabs.com",
				"http://docs.coronalabs.com",
				"http://developer.coronalabs.com" 
			}
		} )
else
	native.showAlert(
		"Cannot send " .. serviceName .. " message.",
		"Please setup your " .. serviceName .. " account or check your network connection",
		{ "OK" } )
end
