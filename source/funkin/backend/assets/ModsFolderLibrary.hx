package funkin.backend.assets;

import openfl.utils.AssetLibrary;
import lime.media.AudioBuffer;
import lime.graphics.Image;
import lime.text.Font;
import lime.utils.Bytes;

#if MOD_SUPPORT
import sys.FileStat;
import sys.FileSystem;
#end

using StringTools;

class ModsFolderLibrary extends AssetLibrary implements IModsAssetLibrary {
	public var basePath:String;
	public var modName:String;
	public var libName:String;
	//public var useImageCache:Bool = true;
	public var prefix = 'assets/';
	public var guarded:Bool = false;

	public function new(basePath:String, libName:String, ?modName:String) {
		#if (MOD_SUPPORT && CASE_INSENSITIVE_MODS)
		clearCaseCache();
		#end
		this.basePath = resolveBasePath(basePath);
		this.libName = libName;
		this.prefix = 'assets/$libName/';
		this.modName = modName == null ? libName : modName;
		super();
	}

	static function resolveBasePath(path:String):String {
		#if (mobile && sys)
		if (path != null && !path.startsWith("/")) {
			var cwd = haxe.io.Path.addTrailingSlash(Sys.getCwd());
			if (path.startsWith("./")) path = path.substr(2);
			path = haxe.io.Path.removeTrailingSlashes(cwd + path);
		}
		#end
		return path;
	}

	static function readFileBytes(path:String):Bytes {
		#if sys
		try {
			var data = sys.io.File.getBytes(path);
			return data == null || data.length == 0 ? null : Bytes.fromBytes(data);
		} catch (e:Dynamic) {
			return null;
		}
		#else
		return Bytes.fromFile(path);
		#end
	}

	function toString():String {
		return '(ModsFolderLibrary: $modName)';
	}

	#if MOD_SUPPORT
	private var editedTimes:Map<String, Float> = [];
	public var _parsedAsset:String = null;

	public function getEditedTime(asset:String):Null<Float> {
		return editedTimes[asset];
	}

	public override function getAudioBuffer(id:String):AudioBuffer {
		if (!exists(id, "SOUND"))
			return null;
		var path = getAssetPath();
		editedTimes[id] = FileSystem.stat(path).mtime.getTime();
		if (guarded) {
			if (!ModGuard.validateAudio(path)) return null;
			var buffer:AudioBuffer = null;
			ModGuard.beginLoad(path);
			try {
				buffer = AudioBuffer.fromFile(path);
			} catch (e:Dynamic) {
				Logs.warn('Failed to load sound "$id": $e');
				buffer = null;
			}
			ModGuard.endLoad();
			return buffer;
		}
		var e = AudioBuffer.fromFile(path);
		// LimeAssets.cache.audio.set('$libName:$id', e);
		return e;
	}

	public override function getBytes(id:String):Bytes {
		if (!exists(id, "BINARY"))
			return null;
		var path = getAssetPath();
		editedTimes[id] = FileSystem.stat(path).mtime.getTime();
		var e = readFileBytes(path);
		return e;
	}

	public override function getFont(id:String):Font {
		if (!exists(id, "FONT"))
			return null;
		var path = getAssetPath();
		editedTimes[id] = FileSystem.stat(path).mtime.getTime();
		#if mobile
		var font:Font = null;
		try {
			var bytes = readFileBytes(path);
			if (guarded && !ModGuard.validateFont(path, bytes))
				return null;
			if (bytes != null && bytes.length > 0) {
				ModGuard.beginLoad(path);
				font = Font.fromBytes(bytes);
				ModGuard.endLoad();
			}
		} catch (e:Dynamic) {
			ModGuard.endLoad();
			font = null;
		}
		if (font == null)
			return null;
		return ModsFolder.registerFont(font);
		#else
		return ModsFolder.registerFont(Font.fromFile(path));
		#end
	}

	public override function getImage(id:String):Image {
		if (!exists(id, "IMAGE"))
			return null;
		var path = getAssetPath();
		editedTimes[id] = FileSystem.stat(path).mtime.getTime();

		#if mobile
		Paths.loadTrace('image file "$path"');
		if (guarded) {
			var bytes:Bytes = null;
			try {
				bytes = readFileBytes(path);
			} catch (err:Dynamic) {
				bytes = null;
			}
			if (!ModGuard.validateImage(path, bytes)) return null;
			var image:Image = null;
			ModGuard.beginLoad(path);
			try {
				image = Image.fromBytes(bytes);
			} catch (err:Dynamic) {
				Logs.warn('Failed to load image "$id": $err');
				image = null;
			}
			ModGuard.endLoad();
			if (image == null || image.width <= 0 || image.height <= 0) {
				ModGuard.block(path, "image could not be decoded");
				return null;
			}
			return image;
		}
		if (!funkin.backend.utils.TextureGuard.canLoad(path, id))
			return null;
		var e:Image = null;
		try {
			e = Image.fromFile(path);
		} catch (err:Dynamic) {
			Logs.warn('Failed to load image "$id": $err');
			e = null;
		}
		return e;
		#else
		var e = Image.fromFile(path);
		return e;
		#end
	}

	public override function getPath(id:String):String {
		if (!__parseAsset(id)) return null;
		return getAssetPath();
	}

	public inline function getFolders(folder:String):Array<String>
		return __getFiles(folder, true);

	public inline function getFiles(folder:String):Array<String>
		return __getFiles(folder, false);

	public function __getFiles(folder:String, folders:Bool = false) {
		if (!folder.endsWith("/")) folder += "/";
		if (!__parseAsset(folder)) return [];
		var path = getAssetPath();
		try {
			var result:Array<String> = [];
			for(e in FileSystem.readDirectory(path))
				if (FileSystem.isDirectory('$path$e') == folders)
					result.push(e);
			return result;
		} catch(e) {
			// woops!!
		}
		return [];
	}

	public override function exists(asset:String, type:String):Bool {
		if(!__parseAsset(asset)) return false;
		var path = getAssetPath();
		if (!FileSystem.exists(path)) return false;
		if (guarded && ModGuard.isBlocked(path)) return false;
		return true;
	}

	private function getAssetPath() {
		#if CASE_INSENSITIVE_MODS
		return resolveCaseInsensitive(basePath, _parsedAsset);
		#else
		return '$basePath/$_parsedAsset';
		#end
	}

	#if CASE_INSENSITIVE_MODS
	static var __caseCache:Map<String, Map<String, String>> = [];

	public static function clearCaseCache()
		__caseCache = [];

	static function getDirectoryEntries(directory:String):Map<String, String> {
		if (__caseCache.exists(directory)) return __caseCache.get(directory);
		var entries:Map<String, String> = null;
		try {
			if (FileSystem.exists(directory) && FileSystem.isDirectory(directory)) {
				entries = [];
				for (entry in FileSystem.readDirectory(directory)) {
					var lower = entry.toLowerCase();
					if (!entries.exists(lower)) entries.set(lower, entry);
				}
			}
		} catch(e) {
			entries = null;
		}
		__caseCache.set(directory, entries);
		return entries;
	}

	public static function resolveCaseInsensitive(base:String, relative:String):String {
		var fullPath = '$base/$relative';
		if (FileSystem.exists(fullPath)) return fullPath;

		var trailingSlash = relative.endsWith("/");
		var current = base;
		for (part in relative.split("/")) {
			if (part == "") continue;
			var entries = getDirectoryEntries(current);
			if (entries == null) return fullPath;
			var actual = entries.get(part.toLowerCase());
			if (actual == null) return fullPath;
			current = '$current/$actual';
		}
		return trailingSlash ? current + "/" : current;
	}
	#end

	private function __isCacheValid(cache:Map<String, Dynamic>, asset:String, isLocalCache:Bool = false) {
		if (!editedTimes.exists(asset))
			return false;
		var editedTime = editedTimes[asset];
		if (editedTime == null || editedTime < FileSystem.stat(getPath(asset)).mtime.getTime()) {
			// destroy already existing to prevent memory leak!!!
			/*var asset = cache[asset];
			if (asset != null) {
				switch(Type.getClass(asset)) {
					case lime.graphics.Image:
						trace("getting rid of image cause replaced");
						cast(asset, lime.graphics.Image);
				}
			}*/
			return false;
		}

		if (!isLocalCache) asset = '$libName:$asset';

		return cache.exists(asset) && cache[asset] != null;
	}

	private function __parseAsset(asset:String):Bool {
		if (!asset.startsWith(prefix)) return false;
		_parsedAsset = asset.substr(prefix.length);
		if(ModsFolder.useLibFile) {
			var file = new haxe.io.Path(_parsedAsset);
			if(file.file.startsWith("LIB_")) {
				var library = file.file.substr(4);
				if(library != modName) return false;

				_parsedAsset = file.dir + "." + file.ext;
			}
		}
		return true;
	}

	public override function list(type:String):Array<String> {
		var result = [];
		__listAppend(result, '');
		return result;
	}

	function __listAppend(arr:Array<String>, folder:String) {
		var directory = '$basePath/$folder';
		var files:Array<String> = null;
		try {
			if (FileSystem.exists(directory) && FileSystem.isDirectory(directory)) files = FileSystem.readDirectory(directory);
		} catch(e) {
			files = null;
		}
		if (files == null) return;
		for(file in files) {
			var fullPath = '$basePath/$folder/$file';
			if (FileSystem.isDirectory(fullPath))
				__listAppend(arr, '$folder$file/');
			else
				arr.push('$prefix$folder$file');
		}
	}
	#end

	// Backwards compat

	@:noCompletion public var folderPath(get, set):String;
	@:noCompletion private inline function get_folderPath():String {
		return basePath;
	}
	@:noCompletion private inline function set_folderPath(value:String):String {
		return basePath = value;
	}
}