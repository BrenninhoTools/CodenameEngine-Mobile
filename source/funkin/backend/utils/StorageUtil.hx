package funkin.backend.utils;

import haxe.io.Path;
#if android
import extension.androidtools.content.Context;
#end
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class StorageUtil
{
	public static final MODS_FOLDER:String = "mods";
	public static final ADDONS_FOLDER:String = "addons";

	public static final STORAGE_DATA:String = "Data";
	public static final STORAGE_EXTERNAL:String = "External";
	public static final STORAGE_TYPES:Array<String> = [STORAGE_DATA, STORAGE_EXTERNAL];

	public static final EXTERNAL_FOLDER:String = ".CodenameEngine";
	static final STORAGE_TYPE_FILE:String = "storage_type.txt";

	public static var storageDirectory(get, never):String;
	public static var activeStorageType(default, null):String = STORAGE_DATA;

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
		activeStorageType = STORAGE_DATA;
		if (getStorageType() == STORAGE_EXTERNAL)
		{
			if (AndroidStorage.hasStoragePermission())
			{
				var external = AndroidStorage.getExternalStorageDirectory();
				if (external != null && external.length > 0)
				{
					var path = Path.addTrailingSlash(Path.addTrailingSlash(external) + EXTERNAL_FOLDER);
					if (createDirectory(path))
					{
						activeStorageType = STORAGE_EXTERNAL;
						return path;
					}
				}
			}
			else
				AndroidStorage.requestStoragePermission();
		}
		return getDataDirectory();
		#elseif (ios || switch)
		return Path.addTrailingSlash(openfl.filesystem.File.applicationStorageDirectory.nativePath);
		#elseif sys
		return Path.addTrailingSlash(Sys.getCwd());
		#else
		return "";
		#end
	}

	#if android
	public static function getDataDirectory():String
	{
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
	}
	#end

	static function getSettingsPath():String
		return Path.addTrailingSlash(lime.system.System.applicationStorageDirectory) + STORAGE_TYPE_FILE;

	public static function getStorageType():String
	{
		#if sys
		try
		{
			var path = getSettingsPath();
			if (FileSystem.exists(path))
			{
				var type = File.getContent(path).trim();
				if (STORAGE_TYPES.contains(type))
					return type;
			}
		}
		catch (e:Dynamic) {}
		#end
		return STORAGE_DATA;
	}

	public static function setStorageType(type:String)
	{
		if (!STORAGE_TYPES.contains(type))
			type = STORAGE_DATA;

		#if sys
		try
		{
			createDirectory(Path.directory(getSettingsPath()));
			File.saveContent(getSettingsPath(), type);
		}
		catch (e:Dynamic) {}
		#end

		#if android
		if (type == STORAGE_EXTERNAL && !AndroidStorage.hasStoragePermission())
			AndroidStorage.requestStoragePermission();
		#end
	}

	public static inline function needsRestart():Bool
		return getStorageType() != activeStorageType;

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

#if android
class AndroidStorage
{
	static final HELPER_CLASS:String = "org/codename/mobile/StorageHelper";

	public static function getExternalStorageDirectory():String
	{
		try
		{
			var method:Dynamic = lime.system.JNI.createStaticMethod(HELPER_CLASS, "getExternalStorageDirectory", "()Ljava/lang/String;");
			return method == null ? null : method();
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public static function hasStoragePermission():Bool
	{
		try
		{
			var method:Dynamic = lime.system.JNI.createStaticMethod(HELPER_CLASS, "hasStoragePermission", "()Z");
			return method != null && method() == true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public static function requestStoragePermission()
	{
		try
		{
			var method:Dynamic = lime.system.JNI.createStaticMethod(HELPER_CLASS, "requestStoragePermission", "()V");
			if (method != null)
				method();
		}
		catch (e:Dynamic) {}
	}
}
#end
