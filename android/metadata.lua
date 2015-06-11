local metadata =
{
    plugin =
	{
	        format = 'jar',
	        manifest = 
	        {
	                permissions = {},
	                usesPermissions =
	                {
	                        "android.permission.INTERNET",
	                        "android.permission.ACCESS_NETWORK_STATE",
	                },
	                usesFeatures = {},
	                applicationChildElements =
	                {
	                	-- Array of strings
	                },
	        },
	},
}

return metadata