//
//  showPopup.java
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
import android.content.ComponentName;
import android.content.Context;
import android.net.Uri;
import android.content.pm.ResolveInfo;
import android.content.pm.ActivityInfo;
import android.os.Build;
import android.os.Parcelable;

// JNLua imports
import com.naef.jnlua.LuaState;
import com.naef.jnlua.LuaType;

// Corona Imports
import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeListener;
import com.ansca.corona.CoronaRuntimeTask;
import com.ansca.corona.CoronaRuntimeTaskDispatcher;
import com.ansca.corona.storage.FileContentProvider;
import com.ansca.corona.storage.FileServices;

/**
 * Implements the showPopup() function in Lua.
 * <p>
 * Show's a chooser dialog.
 */
public class showPopup implements com.naef.jnlua.NamedJavaFunction 
{
	/**
	 * Gets the name of the Lua function as it would appear in the Lua script.
	 * @return Returns the name of the custom Lua function.
	 */
	@Override
	public String getName() 
	{
		return "showPopup";
	}

	// Creates a custom chooser intent with given string. It also exclude some app from chooser as specified in forbiddenList.
	private Intent customChooserIntent( Context context, Intent prototype, List<String> forbiddenList, String shareString ) {
		// Android N provides a simple way of excluding components with Intent.EXTRA_EXCLUDE_COMPONENTS
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
			Intent chooserIntent = Intent.createChooser(prototype, shareString);
			List<ResolveInfo> activities = context.getPackageManager().queryIntentActivities(prototype, 0 /* no flag */);
			if (activities.isEmpty()) {
				return chooserIntent;
			}
			List<ComponentName> componentNames = new ArrayList<ComponentName>();
			for (ResolveInfo resolveInfo : activities) {
				if (forbiddenList.contains(resolveInfo.activityInfo.packageName)) {
					ActivityInfo activityInfo = resolveInfo.activityInfo;
					componentNames.add(new ComponentName(activityInfo.packageName, activityInfo.name));
				}
			}
			chooserIntent.putExtra(Intent.EXTRA_EXCLUDE_COMPONENTS, componentNames.toArray(new Parcelable[0]));
			return chooserIntent;
		}

		return customChooserIntentLegacy(context, prototype, forbiddenList, shareString);
	}

	// Iterates all activities returned by queryIntentActivities. Filters out ones in forbiddenList and sort to create a new chooser intent.
	private Intent customChooserIntentLegacy( Context context, Intent prototype, List<String> forbiddenList, String shareString )
		{
		List<Intent> targetedShareIntents = new ArrayList<Intent>();
		List<HashMap<String, String>> intentMetaInfo = new ArrayList<HashMap<String, String>>();
		Intent chooserIntent;

		Intent dummy = new Intent(prototype.getAction());
		dummy.setType(prototype.getType());
		List<ResolveInfo> resInfo = context.getPackageManager().queryIntentActivities( dummy, 0 );

		// If there are activities
		if ( !resInfo.isEmpty() ) 
		{
			for ( ResolveInfo resolveInfo : resInfo ) 
			{
				if (resolveInfo.activityInfo == null || forbiddenList.contains( resolveInfo.activityInfo.packageName ) )
					continue;
				
				HashMap<String, String> info = new HashMap<String, String>();
				info.put( "packageName", resolveInfo.activityInfo.packageName );
				info.put( "className", resolveInfo.activityInfo.name );
				info.put( "simpleName", String.valueOf( resolveInfo.activityInfo.loadLabel( context.getPackageManager() ) ) );
				intentMetaInfo.add( info );
			}

			// If Meta Info
			if ( !intentMetaInfo.isEmpty() ) 
			{
				// Sort for readability
				Collections.sort( intentMetaInfo, new Comparator<HashMap<String, String>>() 
				{
					@Override
					public int compare( HashMap<String, String> map, HashMap<String, String> map2 ) 
					{
						return map.get( "simpleName" ).compareTo( map2.get( "simpleName" ) );
					}
				});

				// Create the custom intent list
				for ( HashMap<String, String> metaInfo : intentMetaInfo ) 
				{
					Intent targetedShareIntent = (Intent) prototype.clone();
					targetedShareIntent.setPackage( metaInfo.get( "packageName") );
					targetedShareIntent.setClassName( metaInfo.get( "packageName" ), metaInfo.get( "className" ) );
					targetedShareIntents.add( targetedShareIntent );
				}

				chooserIntent = Intent.createChooser( targetedShareIntents.remove( targetedShareIntents.size() - 1), shareString );
				chooserIntent.putExtra( Intent.EXTRA_INITIAL_INTENTS, targetedShareIntents.toArray( new Parcelable[]{} ) );
				return chooserIntent;
			}
		}

		return Intent.createChooser( prototype, shareString );
	}
	
	// Event task
	private static class RaisePopupResultEventTask implements CoronaRuntimeTask 
	{
		private int fLuaListenerRegistryId;
		private int fResultCode;

		public RaisePopupResultEventTask( int luaListenerRegistryId, int resultCode ) 
		{
			fLuaListenerRegistryId = luaListenerRegistryId;
			fResultCode = resultCode;
		}

		@Override
		public void executeUsing( CoronaRuntime runtime )
		{
			try 
			{
				// Fetch the Corona runtime's Lua state.
				final LuaState L = runtime.getLuaState();

				// Dispatch the lua callback
				if ( CoronaLua.REFNIL != fLuaListenerRegistryId ) 
				{
					// Setup the event
					CoronaLua.newEvent( L, "popup" );

					// Event type
					L.pushString( "social" );
					L.setField( -2, "type" );

					// Set the event.action key based on whether the message was sent, or cancelled
					switch (fResultCode) {
						case CoronaActivity.RESULT_CANCELED:
							// Event action
							L.pushString( "cancelled" );
							L.setField( -2, "action" );
							break;

						case CoronaActivity.RESULT_OK:
							// Event action
							L.pushString( "sent" );
							L.setField( -2, "action" );
							break;
					}

					// Dispatch the event
					CoronaLua.dispatchEvent( L, fLuaListenerRegistryId, 0 );
				}
			}
			catch ( Exception ex ) 
			{
				ex.printStackTrace();
			}
		}
	}
	
	// Our lua callback listener
 	private int fListener;
	private Intent sharingIntent;	
		
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
		boolean disableFacebook = false;
		try 
		{			
			// Fetch the Lua function's first argument.
			// Will throw an exception if it is not of type string.
			final String popupName = luaState.checkString( 1 );
			
			// Check if the Lua function's first argument is a Lua array, which is of type table in Lua.
			// Will throw an exception if it is not an array, table, or if no argument was given.
			final int luaTableStackIndex = 2;
			luaState.checkType( luaTableStackIndex, LuaType.TABLE );
			
			// Get the listener field
			luaState.getField( luaTableStackIndex, "listener" );
			if ( CoronaLua.isListener( luaState, -1, "popup" ) ) 
			{
				// Assign the callback listener to a new lua ref
				fListener = CoronaLua.newRef( luaState, -1 );
			}
			else
			{
				// Assign the listener to a nil ref
				fListener = CoronaLua.REFNIL;
			}

			// Get the message field
			luaState.getField( luaTableStackIndex, "message" );
			final String socialMessage = luaState.toString( -1 );
			// Pop the message key
			luaState.pop( 1 );
			
			// Get the image field
			luaState.getField( luaTableStackIndex, "image" );
			// Number of images
			int numImages = 0;
			// If the image field is a table, get the table's length
			if ( luaState.isTable( -1 ) )
			{
				numImages = luaState.length( -1 );
			}
			
			// Images
			List<String> images = new ArrayList<String>();

			// If there are images
			if ( numImages > 0 )
			{
				// table is an array of 'images'
				for ( int i = 1; i <= numImages; i++ )
				{
					luaState.rawGet( -1, i );
					
					// Get the filename key
					luaState.getField( -1, "filename" );
					final String fileName = luaState.toString( -1 );
					// Pop the fileName key
					luaState.pop( 1 );
					
					// Get the image path from lua using the pathforFile function
					
					// Get the baseDir key
					luaState.getField( -1, "baseDir" );
					luaState.getGlobal( "system" );
					luaState.getField( -1, "pathForFile" );
					luaState.pushString( fileName );
					luaState.pushValue( -4 ); // Basedir is at position -4
					luaState.call( 2, 1 );  // Call pathForFile() with 2 arguments and 1 return value.
					final String filePath = luaState.toString( -1 );
					images.add( filePath );
					luaState.pop( 1 );
	
					// Pop the image
					luaState.pop( 1 );
				}
			}
			// Pop the image key
			luaState.pop( 1 );
			
			// Get the url field
			luaState.getField( luaTableStackIndex, "url" );
			List<String> urls = new ArrayList<String>();
			
			// If the url field is a table
			if ( luaState.isTable( -1 ) )
			{				
				int numUrls = luaState.length( -1 );
				
				// If there are urls
				if ( numUrls > 0 )
				{
					// table is an array of 'urls'
					for ( int i = 1; i <= numUrls; i ++ )
					{
						luaState.rawGet( -1, i );
						urls.add( luaState.toString( -1 ) );

						// Pop the url
						luaState.pop( 1 );
					}
				}
			}
			// If the url field is a string
			if ( luaState.type( -1 ) == LuaType.STRING )
			{
				urls.add( luaState.toString( -1 ) );
			}
			
			// Pop the url key
			luaState.pop( 1 );

			// Assign the sharing intent
			sharingIntent = new Intent( Intent.ACTION_SEND );

			// Get the corona application context
			Context coronaApplication = CoronaEnvironment.getApplicationContext();
			FileServices fileServices = new FileServices( coronaApplication );

			// If there is only one image
			if ( 1 == images.size() )
			{					
				// Set the image uri
				Uri imageUri = FileContentProvider.createContentUriForFile( coronaApplication, images.get( 0 ) );
				// Set the sharing mime type
				sharingIntent.setType( fileServices.getMimeTypeFrom( imageUri ) );
				// Set the images
				sharingIntent.putExtra( Intent.EXTRA_STREAM, imageUri );
			}
			else if ( images.size() > 1 )
			{
				// We need to make the sharing intent multiple
				sharingIntent = new Intent( Intent.ACTION_SEND_MULTIPLE );
				
				// Get the image uri's
				ArrayList<Uri> imageUris = new ArrayList<Uri>();
			    // Convert from paths to Android friendly Parcelable Uri's
			    for ( int i = 0; i < images.size(); i ++ )
			    {
					// Set the image uri
			    	Uri imageUri = FileContentProvider.createContentUriForFile( coronaApplication, images.get( i ) );
					// Set the sharing mime type
					sharingIntent.setType( fileServices.getMimeTypeFrom( imageUri ) );
					// Add the uri to the arrayList
			        imageUris.add( imageUri );
			    }
				
			    sharingIntent.putParcelableArrayListExtra( Intent.EXTRA_STREAM, imageUris );
			}
			else // If there are no images, set the mime type to text/plain
			{
				// Set the type to text/plain.
				sharingIntent.setType( "text/plain" );
			}

			// Create a string builder, to store the message and urls
			StringBuilder postMessage = new StringBuilder();
			if (socialMessage != null) {
				if (socialMessage.length() > 0 ) {
					postMessage.append( socialMessage );
					postMessage.append( " " );

					// Disable facebook from appearing in the share
					// intent if there's just a message here.
					disableFacebook = (urls.isEmpty() && images.isEmpty());
				}
			} 
						
			// Append the url's to the message
			if ( 1 == urls.size() ) 
			{
				//postMessage.append( ". " );
				postMessage.append( urls.get( 0 ) );
			}
			else if ( urls.size() > 1 )
			{
				//postMessage.append( ". " );
				// Loop through the url's
				for ( int i = 0; i < urls.size(); i ++ )
				{
					// Append sb with the url
					postMessage.append( urls.get( i ) );

					// For each url but the last, insert a comma
					if ( i < urls.size() - 1 ) 
					{
						postMessage.append( ", " );
					}				
				}
			}
			
			// String to store our full string ( message + urls )
			final String newMessage = postMessage.toString();
			sharingIntent.putExtra( Intent.EXTRA_TEXT, newMessage );
		}
		catch( Exception ex ) 
		{
			// An exception will occur if given an invalid argument or no argument. Print the error.
			ex.printStackTrace();
		}
		
		// Setup the lua callback and execute the sharing intent

		// Corona Activity
		CoronaActivity coronaActivity = null;
		if ( CoronaEnvironment.getCoronaActivity() != null )
		{
			coronaActivity = CoronaEnvironment.getCoronaActivity();
		}

		// Corona runtime task dispatcher
		final CoronaRuntimeTaskDispatcher dispatcher = new CoronaRuntimeTaskDispatcher(luaState);

		// We don't add facebook to the share intent if they're just trying to send a pre-filled message
		// All other cases will allow Facebook to appear in the share intent,
		// but a pre-filled message will be silently dropped.
		final boolean allowFacebook = !disableFacebook;

		// Create a new runnable object to invoke our activity
		Runnable activityRunnable = new Runnable()
		{
			public void run()
			{
				final int requestCode = CoronaEnvironment.getCoronaActivity().registerActivityResultHandler( new CoronaActivity.OnActivityResultHandler() 
				{
					// This method is called when we return to the CoronaActivity
					@Override
					public void onHandleActivityResult( CoronaActivity activity, int requestCode, int resultCode, Intent data ) 
					{
						// Unregister this handler
						activity.unregisterActivityResultHandler( this );
						
						// Create a task
						RaisePopupResultEventTask task = new RaisePopupResultEventTask( fListener, resultCode );
					   
						// Send the task to the Corona runtime asynchronously.
						dispatcher.send( task );
					}
				});

				// Activities we do not wish to show
				String[] hiddenPackages;
				if (allowFacebook) {
					hiddenPackages = new String[] { "com.google.android.apps.uploader" };
				} else {
					hiddenPackages = new String[] { "com.facebook.katana", "com.google.android.apps.uploader" };
				}

				// Invoke custom chooser
				if ( CoronaEnvironment.getCoronaActivity() != null )
				{
					Intent intent = customChooserIntent( CoronaEnvironment.getCoronaActivity(), sharingIntent, Arrays.asList(hiddenPackages), "Share via:" );
					CoronaEnvironment.getCoronaActivity().startActivityForResult( intent, requestCode );
				}
			}
	    };
			
		// Run the activity on the uiThread
		if ( coronaActivity != null )
		{
			coronaActivity.runOnUiThread( activityRunnable );
		}
	
		// Return 0 since this Lua function does not return any values.
		return 0;
	}
}
