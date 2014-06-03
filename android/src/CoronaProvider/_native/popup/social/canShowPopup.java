//
//  canShowPopup.java
//  Social Plugin
//
//  Copyright (c) 2013 Coronalabs. All rights reserved.
//

// Package name
package CoronaProvider._native.popup.social;

// Java Imports
import java.util.*;

// Android Imports
import android.content.Intent;
import android.content.Context;
import android.net.Uri;
import android.content.pm.ResolveInfo;
import android.os.Parcelable;

// JNLua imports
import com.naef.jnlua.LuaState;
import com.naef.jnlua.LuaType;

// Corona Imports
import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaEnvironment;

/**
 * Implements the canShowPopup() function in Lua.
 * <p>
 * Checks whether a chooser dialog can show the specified service.
 */
public class canShowPopup implements com.naef.jnlua.NamedJavaFunction 
{
	/**
	 * Gets the name of the Lua function as it would appear in the Lua script.
	 * @return Returns the name of the custom Lua function.
	 */
	@Override
	public String getName() 
	{
		return "canShowPopup";
	}

	// Function to create a custom chooser intent
	private boolean doesPackageExist( Context context, String packageNameSearch ) 
	{
		// Assume the package doesn't exist by default
		boolean doesExist = false;
		
		// Create a send intent
		Intent sharingIntent = new Intent( Intent.ACTION_SEND );
		
		// Set the type to text/plain. TODO: Should we expose this to the user? (because text/plain is the most basic mime type, and if they are attaching images, this check is moot..
		sharingIntent.setType( "text/plain" );
		
		// Resolve info
		List<ResolveInfo> resInfo = context.getPackageManager().queryIntentActivities( sharingIntent, 0 );
				
		// Loop though to see if we find a package name that contains what the user specified
		for ( ResolveInfo resolveInfo : resInfo ) 
		{
			if ( resolveInfo.activityInfo == null ) continue;

			// Does this package name match what we specified?  Optionally if they just put in "share" then they don't care about who they want to share it with
			// so we can say that it exists
			if ( resolveInfo.activityInfo.packageName.contains( packageNameSearch.toLowerCase() ) || "share".equals(packageNameSearch.toLowerCase()) )
			{
				// Match
				doesExist = true;
				break;
			}
		}
		
		return doesExist;
	}

	
	/**
	 * This method is called when the Lua function is called.
	 * <p>
	 * Warning! This method is not called on the main UI thread.
	 * @param luaState Reference to the Lua state.
	 *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
	 * @return Returns the number of values to be returned by the Lua function.
	 */
	@Override
	public int invoke( final LuaState luaState ) 
	{
		try 
		{			
			// Fetch the Lua function's first argument.
			// Will throw an exception if it is not of type string.
			String popupName = luaState.checkString( 1 );
			String packageName = luaState.checkString( 2 );
			
			// Get the corona activity
			CoronaActivity coronaActivity = null;
			if ( CoronaEnvironment.getCoronaActivity() != null )
			{
				coronaActivity = CoronaEnvironment.getCoronaActivity();
			}
			
			// Does the package exist
			boolean doesTargetPackageExist = false;
			
			// If the corona activity is alive
			if ( coronaActivity != null )
			{
				doesTargetPackageExist = doesPackageExist( coronaActivity, packageName );
			}
			
			// Push the result
			luaState.pushBoolean( doesTargetPackageExist );
		}
		
		catch( Exception ex ) 
		{
			// An exception will occur if given an invalid argument or no argument. Print the error.
			ex.printStackTrace();
		}
		
		// Return 1 since this Lua function returns 1 value.
		return 1;
	}
}
