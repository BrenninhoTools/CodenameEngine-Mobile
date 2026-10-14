package funkin.backend.utils;

import haxe.io.Bytes;
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
	public static final ASSETS_FOLDER:String = "assets";
	public static final LOGS_FOLDER:String = "logs";

	public static final STORAGE_DATA:String = "Data";
	public static final STORAGE_MEDIA:String = "Media";
	public static final STORAGE_OBB:String = "Obb";
	public static final STORAGE_EXTERNAL:String = "External";
	public static final STORAGE_TYPES:Array<String> = [STORAGE_DATA, STORAGE_MEDIA, STORAGE_OBB, STORAGE_EXTERNAL];

	public static final EXTERNAL_FOLDER:String = ".CodenameEngine";
	public static final USER_FOLDERS:Array<String> = [MODS_FOLDER, ADDONS_FOLDER];

	static final STORAGE_TYPE_FILE:String = "storage_type.txt";
	static final STORAGE_PATH_FILE:String = "storage_path.txt";
	static final WRITE_TEST_FILE:String = ".write_test";
	static final COPY_BUFFER_SIZE:Int = 65536;

	public static var storageDirectory(get, never):String;
	public static var activeStorageType(default, null):String = STORAGE_DATA;
	public static var lastError(default, null):String = null;

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
		var type = getStorageType();
		var path = getDirectoryForType(type);
		if (path != null && isWritable(path))
		{
			activeStorageType = type;
			return path;
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

	public static function getDirectoryForType(type:String):String
	{
		#if android
		var path:String = null;
		try
		{
			switch (type)
			{
				case STORAGE_MEDIA:
					path = AndroidStorage.getExternalMediaDirectory();
				case STORAGE_OBB:
					path = Context.getObbDir();
				case STORAGE_EXTERNAL:
					if (AndroidStorage.hasStoragePermission())
					{
						var external = AndroidStorage.getExternalStorageDirectory();
						if (external != null && external.length > 0)
							path = Path.addTrailingSlash(external) + EXTERNAL_FOLDER;
					}
					else
						AndroidStorage.requestStoragePermission();
				default:
					path = getDataDirectory();
			}
		}
		catch (e:Dynamic)
		{
			path = null;
		}
		return (path == null || path.length == 0) ? null : Path.addTrailingSlash(path);
		#else
		return storageDirectory;
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
		if (path == null || path.length == 0 || !isWritable(Path.addTrailingSlash(path)))
			path = Context.getFilesDir();
		return Path.addTrailingSlash(path);
	}
	#end

	static function getSettingsDirectory():String
		return Path.addTrailingSlash(lime.system.System.applicationStorageDirectory);

	static function readSetting(file:String):String
	{
		#if sys
		try
		{
			var path = getSettingsDirectory() + file;
			if (FileSystem.exists(path))
				return File.getContent(path).trim();
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	static function writeSetting(file:String, value:String)
	{
		#if sys
		try
		{
			createDirectory(getSettingsDirectory());
			File.saveContent(getSettingsDirectory() + file, value);
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function getStorageType():String
	{
		var type = readSetting(STORAGE_TYPE_FILE);
		return (type != null && STORAGE_TYPES.contains(type)) ? type : STORAGE_DATA;
	}

	public static function setStorageType(type:String)
	{
		if (!STORAGE_TYPES.contains(type))
			type = STORAGE_DATA;
		writeSetting(STORAGE_TYPE_FILE, type);

		#if android
		if (type == STORAGE_EXTERNAL && !AndroidStorage.hasStoragePermission())
			AndroidStorage.requestStoragePermission();
		#end
	}

	public static function hasStorageTypeSetting():Bool
		return readSetting(STORAGE_TYPE_FILE) != null;

	public static function getExternalFolder():String
	{
		#if android
		var external = AndroidStorage.getExternalStorageDirectory();
		if (external != null && external.length > 0)
			return Path.addTrailingSlash(Path.addTrailingSlash(external) + EXTERNAL_FOLDER);
		#end
		return null;
	}

	public static function externalFolderExists():Bool
	{
		#if sys
		var folder = getExternalFolder();
		try
		{
			return folder != null && FileSystem.exists(folder);
		}
		catch (e:Dynamic) {}
		#end
		return false;
	}

	public static function autoDetectStorageType():Bool
	{
		#if android
		if (hasStorageTypeSetting())
			return true;

		if (hasStoragePermission() && hasExtractedAssets(getExternalFolder()))
			return applyDetectedType(STORAGE_EXTERNAL);

		for (type in [STORAGE_DATA, STORAGE_MEDIA, STORAGE_OBB])
		{
			var path = getDirectoryForType(type);
			if (path != null && hasExtractedAssets(path))
				return applyDetectedType(type);
		}

		if (externalFolderExists() && !hasStoragePermission())
			return false;

		return applyDetectedType(externalFolderExists() ? STORAGE_EXTERNAL : STORAGE_DATA);
		#else
		return true;
		#end
	}

	public static function applyDetectedType(type:String):Bool
	{
		writeSetting(STORAGE_TYPE_FILE, type);
		reload();
		Logs.trace('[StorageUtil] Using storage type ${activeStorageType}: ${storageDirectory}', INFO);
		return true;
	}

	public static function hasExtractedAssets(?path:String):Bool
	{
		#if sys
		if (path == null)
			path = storageDirectory;
		try
		{
			return path != null && FileSystem.exists(Path.addTrailingSlash(path) + ASSETS_FOLDER + "/.version");
		}
		catch (e:Dynamic) {}
		#end
		return false;
	}

	public static function hasStoragePermission():Bool
	{
		#if android
		return AndroidStorage.hasStoragePermission();
		#else
		return true;
		#end
	}

	public static function requestStoragePermission()
	{
		#if android
		AndroidStorage.requestStoragePermission();
		#end
	}

	public static function reload()
	{
		_storageDirectory = null;
		init();
	}

	public static inline function needsRestart():Bool
		return getStorageType() != activeStorageType;

	public static function init()
	{
		#if (sys && (mobile || switch))
		var path = storageDirectory;
		createDirectory(path);
		Sys.setCwd(path);
		for (folder in USER_FOLDERS)
			createDirectory(path + folder);
		#end
	}

	public static function getPreviousDirectory():String
	{
		#if sys
		var previous = readSetting(STORAGE_PATH_FILE);
		if (previous == null || previous.length == 0)
			return null;
		previous = Path.addTrailingSlash(previous);
		if (normalize(previous) == normalize(storageDirectory))
			return null;
		try
		{
			if (FileSystem.exists(previous) && FileSystem.isDirectory(previous))
				return previous;
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	public static function saveCurrentDirectory()
		writeSetting(STORAGE_PATH_FILE, storageDirectory);

	public static function getMigrationFiles():Array<String>
	{
		var previous = getPreviousDirectory();
		if (previous == null)
			return [];
		var files:Array<String> = [];
		for (folder in USER_FOLDERS)
			listFiles(previous, folder, files);
		return files;
	}

	public static function listFiles(root:String, relative:String, ?result:Array<String>):Array<String>
	{
		if (result == null)
			result = [];
		#if sys
		var full = Path.addTrailingSlash(root) + relative;
		try
		{
			if (!FileSystem.exists(full))
				return result;
			if (!FileSystem.isDirectory(full))
			{
				result.push(relative);
				return result;
			}
			for (entry in FileSystem.readDirectory(full))
				listFiles(root, relative + "/" + entry, result);
		}
		catch (e:Dynamic) {}
		#end
		return result;
	}

	public static inline function getModsPath():String
		return storageDirectory + MODS_FOLDER + "/";

	public static inline function getAddonsPath():String
		return storageDirectory + ADDONS_FOLDER + "/";

	public static function createDirectory(path:String):Bool
	{
		#if sys
		if (path == null || path.length == 0)
			return false;
		try
		{
			if (FileSystem.exists(path))
				return FileSystem.isDirectory(path);
			var parent = Path.directory(Path.removeTrailingSlashes(path));
			if (parent != null && parent.length > 0 && parent != path && !FileSystem.exists(parent))
				createDirectory(parent);
			FileSystem.createDirectory(path);
			return FileSystem.exists(path);
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
			return false;
		}
		#else
		return false;
		#end
	}

	public static function isWritable(path:String):Bool
	{
		#if sys
		if (!createDirectory(path))
			return false;
		var test = Path.addTrailingSlash(path) + WRITE_TEST_FILE;
		try
		{
			File.saveContent(test, "ok");
			var ok = FileSystem.exists(test);
			FileSystem.deleteFile(test);
			return ok;
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
			return false;
		}
		#else
		return false;
		#end
	}

	public static function saveBytes(target:String, bytes:Bytes):Bool
	{
		#if sys
		if (bytes == null)
			return false;
		var temp = target + ".tmp";
		try
		{
			createDirectory(Path.directory(target));
			File.saveBytes(temp, bytes);
			if (FileSystem.exists(target))
				FileSystem.deleteFile(target);
			FileSystem.rename(temp, target);
			return FileSystem.exists(target);
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
			deleteQuietly(temp);
			return false;
		}
		#else
		return false;
		#end
	}

	public static function copyFile(source:String, target:String):Bool
	{
		#if sys
		var temp = target + ".tmp";
		var input:sys.io.FileInput = null;
		var output:sys.io.FileOutput = null;
		try
		{
			createDirectory(Path.directory(target));
			input = File.read(source, true);
			output = File.write(temp, true);
			var buffer = Bytes.alloc(COPY_BUFFER_SIZE);
			while (true)
			{
				var read = 0;
				try
				{
					read = input.readBytes(buffer, 0, COPY_BUFFER_SIZE);
				}
				catch (e:haxe.io.Eof)
				{
					read = 0;
				}
				if (read <= 0)
					break;
				output.writeBytes(buffer, 0, read);
			}
			input.close();
			input = null;
			output.close();
			output = null;
			if (FileSystem.exists(target))
				FileSystem.deleteFile(target);
			FileSystem.rename(temp, target);
			return FileSystem.exists(target);
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
			try
			{
				if (input != null)
					input.close();
			}
			catch (_:Dynamic) {}
			try
			{
				if (output != null)
					output.close();
			}
			catch (_:Dynamic) {}
			deleteQuietly(temp);
			return false;
		}
		#else
		return false;
		#end
	}

	public static function copyAsset(id:String, target:String):Bool
	{
		#if android
		try
		{
			var path = lime.utils.Assets.getPath(id);
			if (path != null && AndroidStorage.copyAsset(path, target))
				return true;
		}
		catch (e:Dynamic) {}
		#end
		if (isFontAsset(id))
		{
			var fontBytes = getEmbeddedFontBytes(id);
			if (fontBytes != null)
				return saveBytes(target, fontBytes);
		}
		try
		{
			return saveBytes(target, lime.utils.Assets.getBytes(id));
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
		}
		return isFontAsset(id);
	}

	public static function isFontAsset(id:String):Bool
	{
		try
		{
			if (lime.utils.Assets.isLocal(id, FONT) || lime.utils.Assets.exists(id, FONT))
				return true;
		}
		catch (e:Dynamic) {}
		var ext = Path.extension(id).toLowerCase();
		return ext == "ttf" || ext == "otf";
	}

	public static function getEmbeddedFontBytes(id:String):Bytes
	{
		var key = flatName(id);
		try
		{
			for (name in haxe.Resource.listNames())
			{
				if (!name.startsWith("LIME_font_"))
					continue;
				if (flatName(name).endsWith(key))
				{
					var bytes = haxe.Resource.getBytes(name);
					if (bytes != null && bytes.length > 0)
						return bytes;
				}
			}
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
		}
		return null;
	}

	static function flatName(value:String):String
	{
		var buf = new StringBuf();
		for (i in 0...value.length)
		{
			var c = value.charCodeAt(i);
			var alnum = (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || (c >= "0".code && c <= "9".code);
			if (alnum)
				buf.addChar(c);
		}
		return buf.toString().toLowerCase();
	}

	public static function getFreeSpace(?path:String):Float
	{
		#if android
		return AndroidStorage.getFreeSpace(path == null ? storageDirectory : path);
		#else
		return -1;
		#end
	}

	public static function deleteQuietly(path:String)
	{
		#if sys
		try
		{
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path))
				FileSystem.deleteFile(path);
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function cleanTempFiles(root:String, relative:String)
	{
		for (file in listFiles(root, relative))
			if (file.endsWith(".tmp"))
				deleteQuietly(Path.addTrailingSlash(root) + file);
	}

	static function normalize(path:String):String
		return Path.removeTrailingSlashes(Path.normalize(path)).toLowerCase();
}

#if android
class AndroidStorage
{
	static final HELPER_CLASS:String = "org/codename/mobile/StorageHelper";

	static var methods:Map<String, Dynamic> = new Map();

	static function getMethod(name:String, signature:String):Dynamic
	{
		var key = name + signature;
		if (!methods.exists(key))
		{
			var method:Dynamic = null;
			try
			{
				method = lime.system.JNI.createStaticMethod(HELPER_CLASS, name, signature);
			}
			catch (e:Dynamic)
			{
				method = null;
			}
			methods.set(key, method);
		}
		return methods.get(key);
	}

	public static function getExternalStorageDirectory():String
	{
		try
		{
			var method = getMethod("getExternalStorageDirectory", "()Ljava/lang/String;");
			return method == null ? null : method();
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public static function getExternalMediaDirectory():String
	{
		try
		{
			var method = getMethod("getExternalMediaDirectory", "()Ljava/lang/String;");
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
			var method = getMethod("hasStoragePermission", "()Z");
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
			var method = getMethod("requestStoragePermission", "()V");
			if (method != null)
				method();
		}
		catch (e:Dynamic) {}
	}

	public static function copyAsset(assetPath:String, targetPath:String):Bool
	{
		try
		{
			var method = getMethod("copyAsset", "(Ljava/lang/String;Ljava/lang/String;)Z");
			return method != null && method(assetPath, targetPath) == true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public static function getFreeSpace(path:String):Float
	{
		try
		{
			var method = getMethod("getFreeSpace", "(Ljava/lang/String;)D");
			if (method == null)
				return -1;
			var value:Dynamic = method(path);
			return value == null ? -1 : value;
		}
		catch (e:Dynamic)
		{
			return -1;
		}
	}
}
#end
