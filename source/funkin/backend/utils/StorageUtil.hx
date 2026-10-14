package funkin.backend.utils;

import haxe.io.Path;
#if android
import extension.androidtools.content.Context;
#end
#if sys
import sys.FileSystem;
#end

class StorageUtil
{
	public static final MODS_FOLDER:String = "mods";
	public static final ADDONS_FOLDER:String = "addons";

	public static var storageDirectory(get, never):String;

	static var _storageDirectory:String = null;

	static function get_storageDirectory():String
	{
		if (_storageDirectory == null)
			_storageDirectory = findStorageDirectory();
		return _storageDirectory;
	}

	static function findStorageDirectory():String
	{
		#if android
		var path:String = null;
		try
		{
			path = Context.getExternalFilesDir();
		}
		catch (e:Dynamic)
		{
			path = null;
		}
		if (path == null || path.length == 0)
			path = Context.getFilesDir();
		return Path.addTrailingSlash(path);
		#elseif (ios || switch)
		return Path.addTrailingSlash(openfl.filesystem.File.applicationStorageDirectory.nativePath);
		#elseif sys
		return Path.addTrailingSlash(Sys.getCwd());
		#else
		return "";
		#end
	}

	public static function init()
	{
		#if (sys && (mobile || switch))
		var path = storageDirectory;
		createDirectory(path);
		Sys.setCwd(path);
		createDirectory(path + MODS_FOLDER);
		createDirectory(path + ADDONS_FOLDER);
		#end
	}

	public static inline function getModsPath():String
		return storageDirectory + MODS_FOLDER + "/";

	public static inline function getAddonsPath():String
		return storageDirectory + ADDONS_FOLDER + "/";

	public static function createDirectory(path:String):Bool
	{
		#if sys
		try
		{
			if (!FileSystem.exists(path))
				FileSystem.createDirectory(path);
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}
}
