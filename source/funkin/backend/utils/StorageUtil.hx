package funkin.backend.utils;

import haxe.io.Bytes;
import haxe.io.Path;
#if android
import androidmanager.content.Context;
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
	static final REEXTRACT_FILE:String = "reextract.txt";
	public static final CRASH_FOLDER:String = "crash";
	public static final NO_MEDIA_FILE:String = ".nomedia";
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
		switch (type)
		{
			case STORAGE_MEDIA:
				path = AndroidStorage.getPath(MEDIA);
			case STORAGE_OBB:
				path = AndroidStorage.getPath(OBB);
			case STORAGE_EXTERNAL:
				if (AndroidStorage.hasStoragePermission())
					path = AndroidStorage.getPath(ROOT, EXTERNAL_FOLDER);
				else
					AndroidStorage.requestStoragePermission();
			default:
				path = getDataDirectory();
		}
		if (type != STORAGE_DATA && !AndroidStorage.isMounted())
			path = null;
		return (path == null || path.length == 0) ? null : Path.addTrailingSlash(path);
		#else
		return storageDirectory;
		#end
	}

	#if android
	public static function getDataDirectory():String
	{
		var path = AndroidStorage.isMounted() ? AndroidStorage.getPath(EXTERNAL) : null;
		if (path == null || path.length == 0 || !isWritable(Path.addTrailingSlash(path)))
			path = AndroidStorage.getPath(INTERNAL);
		if (path == null || path.length == 0)
			path = lime.system.System.applicationStorageDirectory;
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
		var external = AndroidStorage.getPath(ROOT, EXTERNAL_FOLDER);
		if (external != null && external.length > 0)
			return Path.addTrailingSlash(external);
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
		{
			if (getStorageType() == STORAGE_EXTERNAL && !hasStoragePermission())
				return false;
			return true;
		}

		if (hasStoragePermission())
			return applyDetectedType(STORAGE_EXTERNAL);

		if (!externalFolderExists())
		{
			for (type in [STORAGE_DATA, STORAGE_MEDIA, STORAGE_OBB])
			{
				var path = getDirectoryForType(type);
				if (path != null && hasExistingInstall(path))
					return applyDetectedType(type);
			}
		}

		return false;
		#else
		return true;
		#end
	}

	public static function onPermissionResult(granted:Bool)
	{
		if (granted)
			applyDetectedType(STORAGE_EXTERNAL);
		else
		{
			Logs.trace('[StorageUtil] Storage permission denied, using Data instead', WARNING);
			applyDetectedType(STORAGE_DATA);
		}
	}

	public static function applyDetectedType(type:String):Bool
	{
		writeSetting(STORAGE_TYPE_FILE, type);
		reload();
		Logs.trace('[StorageUtil] Using storage type ${activeStorageType}: ${storageDirectory}', INFO);
		return true;
	}

	public static function hasExistingInstall(?path:String):Bool
	{
		if (path == null)
			path = storageDirectory;
		if (path == null)
			return false;
		path = Path.addTrailingSlash(path);
		return funkin.mobile.CopyState.hasExtractedMods(path) || funkin.mobile.CopyState.hasLegacyAssets(path);
	}

	public static function hasStoragePermission():Bool
	{
		#if android
		return AndroidStorage.hasStoragePermission();
		#else
		return true;
		#end
	}

	public static function requestStoragePermission(?callback:Bool->Void)
	{
		#if android
		AndroidStorage.requestStoragePermission(callback);
		#else
		if (callback != null)
			callback(true);
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
		createDirectory(path + LOGS_FOLDER);
		createDirectory(path + CRASH_FOLDER);
		if (activeStorageType == STORAGE_EXTERNAL || activeStorageType == STORAGE_MEDIA)
			ensureNoMedia(path);
		#end
	}

	static function ensureNoMedia(path:String)
	{
		#if android
		if (AndroidStorage.createNoMedia(path))
			return;
		#end
		#if sys
		try
		{
			var file = path + NO_MEDIA_FILE;
			if (!FileSystem.exists(file))
				File.saveContent(file, "");
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function requestReextract()
		writeSetting(REEXTRACT_FILE, "1");

	public static function isReextractRequested():Bool
		return readSetting(REEXTRACT_FILE) == "1";

	public static function clearReextract()
	{
		#if sys
		try
		{
			var path = getSettingsDirectory() + REEXTRACT_FILE;
			if (FileSystem.exists(path))
				FileSystem.deleteFile(path);
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function getDirectorySize(path:String):Float
	{
		#if android
		var size = AndroidStorage.getSize(path);
		if (size >= 0)
			return size;
		#end
		var total:Float = 0;
		#if sys
		try
		{
			if (!FileSystem.exists(path))
				return 0;
			if (!FileSystem.isDirectory(path))
				return FileSystem.stat(path).size;
			for (entry in FileSystem.readDirectory(path))
				total += getDirectorySize(Path.addTrailingSlash(path) + entry);
		}
		catch (e:Dynamic) {}
		#end
		return total;
	}

	public static function deleteDirectory(path:String):Bool
	{
		#if sys
		try
		{
			if (!FileSystem.exists(path))
				return true;
			if (!FileSystem.isDirectory(path))
			{
				FileSystem.deleteFile(path);
				return true;
			}
			for (entry in FileSystem.readDirectory(path))
				deleteDirectory(Path.addTrailingSlash(path) + entry);
			FileSystem.deleteDirectory(path);
			return true;
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
		}
		#end
		return false;
	}

	public static function countFolders(path:String):Int
	{
		#if sys
		try
		{
			if (!FileSystem.exists(path))
				return 0;
			var count = 0;
			for (entry in FileSystem.readDirectory(path))
				if (FileSystem.isDirectory(Path.addTrailingSlash(path) + entry))
					count++;
			return count;
		}
		catch (e:Dynamic) {}
		#end
		return 0;
	}

	public static function formatSize(bytes:Float):String
	{
		if (bytes < 0)
			return "unknown";
		var units = ["B", "KB", "MB", "GB", "TB"];
		var unit = 0;
		while (bytes >= 1024 && unit < units.length - 1)
		{
			bytes /= 1024;
			unit++;
		}
		return (Math.round(bytes * 10) / 10) + " " + units[unit];
	}

	public static function getStorageInfo():String
	{
		var lines = [
			'Storage: ${activeStorageType}',
			'Path: ${storageDirectory}',
			'Free space: ${formatSize(getFreeSpace())}',
			'Mods: ${countFolders(getModsPath())}',
			'Addons: ${countFolders(getAddonsPath())}',
			'Mods extracted: ${funkin.mobile.CopyState.hasExtractedMods() ? "yes" : "no"}',
			'Assets: read from the app'
		];
		return lines.join("\n");
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
		#if android
		if (AndroidStorage.isWritable(path))
			return true;
		#end
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
		try
		{
			return saveBytes(target, lime.utils.Assets.getBytes(id));
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
		}
		return false;
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
	public static function getPath(location:androidmanager.content.Storage.StorageLocation, ?subfolder:String):String
	{
		try
		{
			return androidmanager.content.Storage.getPath(location, subfolder);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public static function isMounted():Bool
	{
		try
		{
			return androidmanager.content.Storage.available && androidmanager.content.Storage.writable;
		}
		catch (e:Dynamic)
		{
			return true;
		}
	}

	public static function hasStoragePermission():Bool
	{
		try
		{
			return androidmanager.tools.PermissionUtils.isExternalStorageManager();
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public static function requestStoragePermission(?callback:Bool->Void)
	{
		try
		{
			if (hasStoragePermission())
			{
				if (callback != null)
					callback(true);
				return;
			}
			androidmanager.tools.PermissionUtils.requestManageExternalStorage(callback);
		}
		catch (e:Dynamic)
		{
			if (callback != null)
				callback(false);
		}
	}

	public static function isWritable(path:String):Bool
	{
		try
		{
			return androidmanager.content.Storage.isWritable(path);
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public static function createNoMedia(path:String):Bool
	{
		try
		{
			return androidmanager.content.Storage.createNoMedia(path);
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public static function getSize(path:String):Float
	{
		try
		{
			return androidmanager.content.Storage.getSize(path);
		}
		catch (e:Dynamic)
		{
			return -1;
		}
	}

	public static function copyAsset(assetPath:String, targetPath:String):Bool
	{
		try
		{
			return androidmanager.content.Assets.copy(assetPath, targetPath);
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
			var space = androidmanager.content.Storage.getSpace(path);
			return space == null ? -1 : space.available;
		}
		catch (e:Dynamic)
		{
			return -1;
		}
	}
}
#end
