//
//  IOSSocialNativePopupProvider.mm
//
//  Copyright (c) 2013 CoronaLabs Inc. All rights reserved.
//

#include "IOSSocialNativePopupProvider.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Social/Social.h>
#import <Accounts/Accounts.h>

#import "CoronaRuntime.h"
#include "CoronaAssert.h"
#include "CoronaEvent.h"
#include "CoronaLua.h"
#include "CoronaLibrary.h"

// ----------------------------------------------------------------------------

@class UIViewController;

namespace Corona
{

// ----------------------------------------------------------------------------

class IOSSocialNativePopupProvider
{
	public:
		typedef IOSSocialNativePopupProvider Self;

	public:
		static int Open( lua_State *L );
		static int Finalizer( lua_State *L );
		static Self *ToLibrary( lua_State *L );

	protected:
		IOSSocialNativePopupProvider();
		bool Initialize( void *platformContext );

	public:
		int ValueForKey( lua_State *L );

	public:
		UIViewController* GetAppViewController() const { return fAppViewController; }

	public:
		static int canShowPopup( lua_State *L );
		static int showPopup( lua_State *L );

	private:
		UIViewController *fAppViewController;
};

// ----------------------------------------------------------------------------

const char *kServiceProviderName[] = { "twitter", "facebook", "sinaWeibo", "tencentWeibo" };

typedef enum ServiceProviderType {
	kServiceProviderTwitter,
	kServiceProviderFacebook,
	kServiceProviderSinaweibo,
	kServiceProviderTencentweibo,

	kNumServiceProviderTypes
};

static const char kPopupName[] = "social";
static const char kMetatableName[] = __FILE__; // Globally unique value

int
IOSSocialNativePopupProvider::Open( lua_State *L )
{
	CoronaLuaInitializeGCMetatable( L,
		kMetatableName, Finalizer );
	void *platformContext = CoronaLuaGetContext( L );

	const char *name = lua_tostring( L, 1 ); CORONA_ASSERT( 0 == strcmp( kPopupName, name ) );
	int result = CoronaLibraryProviderNew( L, "native.popup", name, "com.coronalabs" );

	if ( result > 0 )
	{
		int libIndex = lua_gettop( L );

		Self *library = new Self;

		if ( library->Initialize( platformContext ) )
		{
			static const luaL_Reg kFunctions[] =
			{
				{ "canShowPopup", canShowPopup },
				{ "showPopup", showPopup },

				{ NULL, NULL }
			};

			// Register functions as closures, giving each access to the
			// 'library' instance via ToLibrary()
			{
				lua_pushvalue( L, libIndex ); // push library
				CoronaLuaPushUserdata( L, library, kMetatableName ); // push library ptr
				luaL_openlib( L, NULL, kFunctions, 1 );
				lua_pop( L, 1 ); // pop library
			}
		}
	}

	return result;
}

int
IOSSocialNativePopupProvider::Finalizer( lua_State *L )
{
	Self *library = (Self *)CoronaLuaToUserdata( L, 1 );
	delete library;
	return 0;
}

IOSSocialNativePopupProvider::Self *
IOSSocialNativePopupProvider::ToLibrary( lua_State *L )
{
	// library is pushed as part of the closure
	Self *library = (Self *)CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
	return library;
}

// ----------------------------------------------------------------------------

IOSSocialNativePopupProvider::IOSSocialNativePopupProvider()
:	fAppViewController( nil )
{
}

bool
IOSSocialNativePopupProvider::Initialize( void *platformContext )
{
	bool result = ( ! fAppViewController );

	if ( result )
	{
		id<CoronaRuntime> runtime = (id<CoronaRuntime>)platformContext;
		fAppViewController = runtime.appViewController; // TODO: Should we retain?
	}

	return result;
}

// ----------------------------------------------------------------------------

static const char *kEventName = CoronaEventPopupName();

static bool
IsSocialFrameworkAvailable()
{
	return nil != [SLComposeViewController class];	
}

static const char*
StringForControllerResult( SLComposeViewControllerResult value )
{
	static const char kCancelledAction[] = "cancelled";
	static const char kSentAction[] = "sent";
	
	const char *result = NULL;
	
	switch ( value )
	{
		case SLComposeViewControllerResultCancelled:
			result = kCancelledAction;
			break;
		case SLComposeViewControllerResultDone:
			result = kSentAction;
			break;
		default:
			break;
	}

	return result;
}

static void
PushEvent( lua_State *L )
{
	Corona::Lua::NewEvent( L, kEventName );
	lua_pushstring( L, kPopupName );
	lua_setfield( L, -2, CoronaEventTypeKey() );
}

static void
PushEvent( lua_State *L, SLComposeViewControllerResult result )
{
	PushEvent( L );

	const char *value = StringForControllerResult( result );

	if ( value )
	{
		lua_pushstring( L, value );
		lua_setfield( L, -2, "action" );
	}
}

// Error situation
static void
PushEvent( lua_State *L, const char *value )
{
	PushEvent( L );

	// The value that could not fit
	lua_pushstring( L, value );
	lua_setfield( L, -2, "limitReached" );
}

static bool
AddImage( lua_State *L, SLComposeViewController *controller, Corona::Lua::Ref listenerRef )
{
	using namespace Corona;

	bool result = false;

	// pathService->PushPath( L, -1 );
	CoronaLibraryCallFunction( L, "system", "pathForTable", "t>s", CoronaLuaNormalize( L, -1 ) );
	const char *str = lua_tostring( L, -1 );
	if ( str )
	{
		NSString *path = [NSString stringWithUTF8String:str];
		UIImage *image = [UIImage imageWithContentsOfFile:path];
		result = [controller addImage:image];
		if ( ! result && listenerRef )
		{
			// Create event
			PushEvent( L, str );
			Lua::DispatchEvent( L, listenerRef, 0 );
		}
	}
	lua_pop( L, 1 );

	return result;
}

static bool
AddUrl( lua_State *L, SLComposeViewController *controller, Corona::Lua::Ref listenerRef )
{
	using namespace Corona;

	bool result = false;

	const char *str = lua_tostring( L, -1 );
	if ( str )
	{
		NSString *path = [NSString stringWithUTF8String:str];
		NSURL *url = [NSURL URLWithString:path];
		result = [controller addURL:url];
		if ( ! result && listenerRef )
		{
			// Limit reached: create event and invoke listener
			PushEvent( L, str );
			Lua::DispatchEvent( L, listenerRef, 0 );
		}
	}

	return result;
}

int
IOSSocialNativePopupProvider::canShowPopup( lua_State *L )
{
	// If the SLComposeViewController class isn't available, don't proceed any further (prevent's crash on iOS versions less than 6.0)
	if ( NSClassFromString( @"SLComposeViewController" ) == Nil )
	{
		CoronaLuaWarning( L, "The Social plugin is only supported on iOS versions greater or equal to iOS 6.0\n" );
		return 0;
	}

	bool isAvailable = false;	
	const char *serviceName = lua_tostring( L, -1 );
	
	// Second argument (service) should be a string
	if ( lua_isstring( L, -1 ) )
	{
		// Check if passed service type matches the 4 services we support
		if ( 0 == strcmp( kServiceProviderName[kServiceProviderTwitter], serviceName ) )
		{
			isAvailable = [SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter];
		}
		else if ( 0 == strcmp( kServiceProviderName[kServiceProviderFacebook], serviceName ) )
		{
			isAvailable = [SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook];
		}
		else if ( 0 == strcmp( kServiceProviderName[kServiceProviderSinaweibo], serviceName ) )
		{
			isAvailable = [SLComposeViewController isAvailableForServiceType:SLServiceTypeSinaWeibo];
		}
		else if ( 0 == strcmp( kServiceProviderName[kServiceProviderTencentweibo], serviceName ) )
		{
			// TencentWeibo is only available on iOS 7, so if we are running on an iOS version less than 7, then we set isAvailable to false
			if ( [[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending )
			{
				isAvailable = false;
			}
			else
			{
				if ( NULL != SLServiceTypeTencentWeibo )
				{
					isAvailable = [SLComposeViewController isAvailableForServiceType:SLServiceTypeTencentWeibo];
				}
			}
		}
		else
		{
			luaL_error( L, "native.canShowPopup( '%s' ): Invalid service specified. Supported services are: %s, %s, %s, $s", kPopupName, kServiceProviderName[kServiceProviderTwitter], kServiceProviderName[kServiceProviderFacebook], kServiceProviderName[kServiceProviderSinaweibo], kServiceProviderName[kServiceProviderTencentweibo] );
		}
	}
	else
	{
		luaL_error( L, "native.canShowPopup( '%s' ) expects 2 arguments `popupType`, `service`. For example: native.canShowPopup( '%s', '%s' )", kPopupName, kPopupName, kServiceProviderName[kServiceProviderTwitter] );
	}
	lua_pop( L, 1 );
	
	// Push the result
	lua_pushboolean( L, isAvailable );

	return 1;
}

int
IOSSocialNativePopupProvider::showPopup( lua_State *L )
{
	using namespace Corona;

	// Library instance
	Self *context = ToLibrary( L );
	
	// If the SLComposeViewController class isn't available, don't proceed any further (prevent's crash on iOS versions less than 6.0)
	if ( NSClassFromString( @"SLComposeViewController" ) == nil )
	{
		CoronaLuaWarning( L, "The Social plugin is only supported on iOS versions greater or equal to iOS 6.0\n" );
		return 0;
	}
		
	// If we have context, and our social framework is available 
	if ( context && IsSocialFrameworkAvailable() )
	{
		Self& library = * context;
				
		// Pointer to our SLComposeViewController
		SLComposeViewController *controller = nil;
		
		// Initialize our app view controller
		UIViewController *appViewController = library.GetAppViewController();

		// Retrieve keys from our "options" table
		if ( lua_istable( L, 2 ) )
		{
			Lua::Ref listenerRef = NULL;

			// options.listener
			lua_getfield( L, -1, "listener" );
			if ( Lua::IsListener( L, -1, kEventName ) )
			{
				// Create native reference to listener
				listenerRef = Lua::NewRef( L, -1 );
			}
			lua_pop( L, 1 );
			
			
			// options.provider (this is a required param)
			lua_getfield( L, -1, "service" );
			const char *service = lua_tostring( L, -1 );
			if ( lua_isstring( L, -1 ) )
			{
				NSString *SLServiceType = nil;
				
				// Check if passed service type matches the 3 services we support, and set the service type accordingly
				if ( 0 == strcmp( kServiceProviderName[kServiceProviderTwitter], service ) )
				{
					SLServiceType = SLServiceTypeTwitter;
				}
				else if ( 0 == strcmp( kServiceProviderName[kServiceProviderFacebook], service ) )
				{
					SLServiceType = SLServiceTypeFacebook;
				}
				else if ( 0 == strcmp( kServiceProviderName[kServiceProviderSinaweibo], service ) )
				{
					SLServiceType = SLServiceTypeSinaWeibo;
				}
				else if ( 0 == strcmp( kServiceProviderName[kServiceProviderTencentweibo], service ) )
				{
					// TencentWeibo is only available on iOS 7, so if we are running on an iOS version less than 7, just return
					if ( [[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending )
					{
						return 0;
					}
					else
					{
						if ( NULL != SLServiceTypeTencentWeibo )
						{
							SLServiceType = SLServiceTypeTencentWeibo;
						}
					}
				}
				
				// TODO: Have this show a popup similar to the Share Intent on Android
				if ( nil == SLServiceType )
				{
					luaL_error( L, "native.showPopup( '%s', serviceName ) invalid service specified. Supported services are: %s, %s, $s, %s", kPopupName, kServiceProviderName[kServiceProviderTwitter], kServiceProviderName[kServiceProviderFacebook], kServiceProviderName[kServiceProviderSinaweibo], kServiceProviderName[kServiceProviderTencentweibo] );
				}
			
				// Set up our SLComposeViewController, for the service type specified
				controller = [SLComposeViewController composeViewControllerForServiceType:SLServiceType];
				
				// Default completion handler
				SLComposeViewControllerCompletionHandler defaultHandler =
					^(SLComposeViewControllerResult result)
					{
						// Only dismiss the controller if we are running on iOS 6 or lower (As of iOS 7, if the app links against the iOS 7 SDK, the view controller will dismiss itself even if the caller supplies a completionHandler.)
						if ( [[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending )
						{
							// Dismiss the social composition view controller.
							[appViewController dismissViewControllerAnimated:YES completion:nil];
						}
					};
				[controller setCompletionHandler:defaultHandler];
				
				// If a listener was set
				if ( listenerRef )
				{
					// Custom completion handler
					[controller setCompletionHandler:^(SLComposeViewControllerResult result)
					{
						// Inherit default behavior
						defaultHandler( result );

						// Create event and invoke listener
						PushEvent( L, result ); // push event
						Lua::DispatchEvent( L, listenerRef, 0 );

						// Free native reference to listener
						Lua::DeleteRef( L, listenerRef );
					}];
				}
			}
			else
			{
				luaL_error( L, "native.showPopup( %s ) service expected, got nil", kPopupName );
			}
			lua_pop( L, 1 );
			

			// options.message
			// Set the initial message text
			lua_getfield( L, -1, "message" );
			const char *msg = lua_tostring( L, -1 );
			if ( msg )
			{
				NSString *message = [NSString stringWithUTF8String:msg];
				
				// Due to Facebook's Platform Policy, we can't pre-fill text in this manner on iOS 8.0+.
				// Technically, this can be worked-around by not having the facebook app installed.
				// For consistency with Android, we only take the pre-filled message for social media
				// platforms outside of Facebook. See details at:
				// https://developers.facebook.com/docs/apps/review/prefill
				if ( [[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending
						&& [controller serviceType] == SLServiceTypeFacebook)
				{
					CoronaLuaWarning( L, "native.showPopup( %s ) cannot accept pre-filled messages for Facebook as of iOS 8.0. See facebook's platform policy at: https://developers.facebook.com/docs/apps/review/prefill\n", kPopupName );
					message = @"";
				}
        
				if ( ! [controller setInitialText:message] )
				{
					if ( listenerRef )
					{
						// Limit reached: create event and invoke listener
						PushEvent( L, msg ); // push event
						Lua::DispatchEvent( L, listenerRef, 0 );
					}
				}
			}
			lua_pop( L, 1 );

			// options.image
			lua_getfield( L, -1, "image" );
			if ( lua_istable( L, -1 ) )
			{
				int numImages = lua_objlen( L, -1 );
				if ( numImages > 0 )
				{
					bool noError = true;

					// table is an array of 'path' tables
					for ( int i = 1; noError && i <= numImages; i++ )
					{
						lua_rawgeti( L, -1, i );
						noError = AddImage( L, controller, listenerRef );
						lua_pop( L, 1 );
					}
				}
				else
				{
					AddImage( L, controller, listenerRef );
				}
			}
			lua_pop( L, 1 );

			// options.url
			lua_getfield( L, -1, "url" );
			if ( lua_istable( L, -1 ) )
			{
				int numUrls = lua_objlen( L, -1 );
				if ( numUrls > 0 )
				{
					bool noError = true;

					// table is an array of 'path' tables
					for ( int i = 1; noError && i <= numUrls; i++ )
					{
						lua_rawgeti( L, -1, i );
						noError = AddUrl( L, controller, listenerRef );
						lua_pop( L, 1 );
					}
				}
			}
			else if ( LUA_TSTRING == lua_type( L, -1 ) )
			{
				AddUrl( L, controller, listenerRef );
			}
			lua_pop( L, 1 );
		}

		// Present the social composition view controller modally.
		[appViewController presentViewController:controller animated:YES completion:nil];
	}

	return 0;
}


// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

CORONA_EXPORT
int luaopen_CoronaProvider_native_popup_social( lua_State *L )
{
	return Corona::IOSSocialNativePopupProvider::Open( L );
}

// ----------------------------------------------------------------------------
