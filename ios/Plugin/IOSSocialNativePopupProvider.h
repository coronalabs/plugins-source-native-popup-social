//
//  IOSSocialNativePopupProvider.h
//
//  Copyright (c) 2013 CoronaLabs Inc. All rights reserved.
//

#ifndef _IOSSocialNativePopupProvider_H__
#define _IOSSocialNativePopupProvider_H__

#include "CoronaLua.h"
#include "CoronaMacros.h"

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
// where the '.' is replaced with '_'
CORONA_EXPORT int luaopen_CoronaProvider_native_popup_social( lua_State *L );

#endif // _IOSSocialNativePopupProvider_H__
