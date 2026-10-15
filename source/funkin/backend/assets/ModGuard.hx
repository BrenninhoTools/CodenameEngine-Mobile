package funkin.backend.assets;

import haxe.io.Bytes;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef BlockedAsset =
{
	var path:String;
	var size:Float;
	var reason:String;
}

class ModGuard
{
	public static inline var BLOCKED_FILE:String = "crash/blocked_assets.txt";
	public static inline var LOADING_FILE:String = "crash/.loading";
	public static inline var SUSPECTS_FILE:String = "crash/suspect_assets.txt";
	public static inline var SUSPECT_STRIKES:Int = 2;
	public static inline var MAX_IMAGE_SIDE:Int = 16384;
	public static inline var MAX_IMAGE_BYTES:Float = 256 * 1024 * 1024;

	public static var enabled:Bool = true;
	public static var trackLoading:Bool = #if mobile true #else false #end;

	static var blocked:Map<String, BlockedAsset> = null;
	static var loadingDepth:Int = 0;
	static var currentLoad:String = null;
	static var pendingDraw:Array<String> = [];
	static var initialized:Bool = false;

	public static function init()
	{
		if (initialized)
			return;
		initialized = true;
		load();
		recoverFromCrash();
		flixel.FlxG.signals.postDraw.add(onPostDraw);
	}

	static function onPostDraw()
	{
		if (pendingDraw.length == 0)
			return;
		pendingDraw.resize(0);
		writeMarker();
	}

	static function writeMarker()
	{
		#if sys
		try
		{
			var lines:Array<String> = [];
			if (currentLoad != null)
				lines.push('L\t$currentLoad');
			for (p in pendingDraw)
				lines.push('D\t$p');
			File.saveContent(LOADING_FILE, lines.join("\n"));
		}
		catch (_:Dynamic) {}
		#end
	}

	static function load()
	{
		if (blocked != null)
			return;
		blocked = [];
		#if sys
		try
		{
			if (!FileSystem.exists(BLOCKED_FILE))
				return;
			for (line in File.getContent(BLOCKED_FILE).split("\n"))
			{
				var parts = line.split("\t");
				if (parts.length < 3)
					continue;
				var size = Std.parseFloat(parts[1]);
				if (parts[2].startsWith("empty or unreadable"))
					continue;
				blocked.set(key(parts[0]), {path: parts[0], size: Math.isNaN(size) ? -1 : size, reason: parts.slice(2).join("\t")});
			}
		}
		catch (_:Dynamic) {}
		#end
	}

	static function save()
	{
		#if sys
		try
		{
			if (!FileSystem.exists("crash"))
				FileSystem.createDirectory("crash");
			var lines = [for (b in blocked) '${b.path}\t${b.size}\t${b.reason}'];
			File.saveContent(BLOCKED_FILE, lines.join("\n"));
		}
		catch (_:Dynamic) {}
		#end
	}

	static function recoverFromCrash()
	{
		#if sys
		try
		{
			if (!FileSystem.exists(LOADING_FILE))
				return;
			var content = File.getContent(LOADING_FILE).trim();
			File.saveContent(LOADING_FILE, "");
			if (content.length == 0 || !funkin.backend.system.modules.AntiCrashSession.previousSessionCrashed)
				return;
			var suspects = readSuspects();
			for (line in content.split("\n"))
			{
				var tab = line.indexOf("\t");
				if (tab < 0)
					continue;
				var kind = line.substr(0, tab);
				var path = line.substr(tab + 1);
				if (kind == "L")
					block(path, "the game closed while loading this file");
				else if (kind == "D")
				{
					var count = (suspects.exists(path) ? suspects.get(path) : 0) + 1;
					if (count >= SUSPECT_STRIKES)
					{
						suspects.remove(path);
						block(path, "the game closed right after showing this file " + count + " times");
					}
					else
					{
						suspects.set(path, count);
						Logs.trace('[ModGuard] "$path" is suspected of closing the game ($count/$SUSPECT_STRIKES)', WARNING);
					}
				}
			}
			saveSuspects(suspects);
		}
		catch (_:Dynamic) {}
		#end
	}

	static function readSuspects():Map<String, Int>
	{
		var map:Map<String, Int> = [];
		#if sys
		try
		{
			if (FileSystem.exists(SUSPECTS_FILE))
				for (line in File.getContent(SUSPECTS_FILE).split("\n"))
				{
					var parts = line.split("\t");
					if (parts.length == 2)
						map.set(parts[0], Std.parseInt(parts[1]) ?? 0);
				}
		}
		catch (_:Dynamic) {}
		#end
		return map;
	}

	static function saveSuspects(map:Map<String, Int>)
	{
		#if sys
		try
		{
			File.saveContent(SUSPECTS_FILE, [for (k => v in map) '$k\t$v'].join("\n"));
		}
		catch (_:Dynamic) {}
		#end
	}

	static inline function key(path:String):String
		return haxe.io.Path.normalize(path).toLowerCase();

	static function fileSize(path:String):Float
	{
		#if sys
		try
		{
			return FileSystem.stat(path).size;
		}
		catch (_:Dynamic) {}
		#end
		return -1;
	}

	public static function isBlocked(path:String):Bool
	{
		if (!enabled || path == null)
			return false;
		load();
		var entry = blocked.get(key(path));
		if (entry == null)
			return false;
		var size = fileSize(path);
		if (entry.size >= 0 && size >= 0 && size != entry.size)
		{
			blocked.remove(key(path));
			save();
			Logs.trace('[ModGuard] "$path" changed, unblocking it', INFO);
			return false;
		}
		return true;
	}

	public static function block(path:String, reason:String)
	{
		load();
		blocked.set(key(path), {path: path, size: fileSize(path), reason: reason});
		save();
		Logs.trace('[ModGuard] Blocked "$path": $reason', WARNING);
		funkin.backend.system.modules.AntiCrash.showNotice('Mod file disabled: ${haxe.io.Path.withoutDirectory(path)}', reason);
	}

	public static function clearBlocked()
	{
		load();
		blocked.clear();
		save();
	}

	public static function getBlocked():Array<BlockedAsset>
	{
		load();
		return [for (b in blocked) b];
	}

	public static function beginLoad(path:String)
	{
		#if sys
		if (!trackLoading || !enabled)
			return;
		if (loadingDepth++ > 0)
			return;
		currentLoad = path;
		writeMarker();
		#end
	}

	public static function endLoad()
	{
		#if sys
		if (!trackLoading || !enabled)
			return;
		if (--loadingDepth > 0)
			return;
		loadingDepth = 0;
		if (currentLoad != null && !pendingDraw.contains(currentLoad))
			pendingDraw.push(currentLoad);
		currentLoad = null;
		writeMarker();
		#end
	}

	public static function reject(path:String, reason:String):Bool
	{
		block(path, reason);
		return false;
	}

	public static function validateImage(path:String, bytes:Bytes):Bool
	{
		if (bytes == null)
			return false;
		if (bytes.length < 8)
			return reject(path, "image file is too small to be valid");

		var size:{width:Int, height:Int} = null;
		if (isPng(bytes))
		{
			var result = checkPng(bytes);
			if (result.error != null)
				return reject(path, result.error);
			size = {width: result.width, height: result.height};
		}
		else if (bytes.get(0) == 0xFF && bytes.get(1) == 0xD8)
		{
			size = readJpegSize(bytes);
			if (size == null)
				return reject(path, "broken JPEG image");
		}
		else if (startsWith(bytes, "RIFF") && bytes.length > 12 && bytes.getString(8, 4) == "WEBP")
			return reject(path, "WebP images are not supported");
		else if (startsWith(bytes, "GIF8"))
			return reject(path, "GIF images are not supported");
		else
			return reject(path, "unknown image format");

		if (size.width <= 0 || size.height <= 0 || size.width > MAX_IMAGE_SIDE || size.height > MAX_IMAGE_SIDE)
			return reject(path, 'invalid image size ${size.width}x${size.height}');

		var max = funkin.backend.utils.TextureGuard.getMaxTextureSize();
		if (size.width > max || size.height > max)
			return reject(path, 'image is ${size.width}x${size.height}, this GPU supports up to ${max}x${max}');
		if (size.width * size.height * 4.0 > MAX_IMAGE_BYTES)
			return reject(path, 'image is too big for memory (${size.width}x${size.height})');
		return true;
	}

	static inline function isPng(bytes:Bytes):Bool
		return bytes.get(0) == 0x89 && bytes.get(1) == 0x50 && bytes.get(2) == 0x4E && bytes.get(3) == 0x47 && bytes.get(4) == 0x0D && bytes.get(5) == 0x0A
			&& bytes.get(6) == 0x1A && bytes.get(7) == 0x0A;

	static function checkPng(bytes:Bytes):{error:String, width:Int, height:Int}
	{
		var len = bytes.length;
		var pos = 8;
		var width = 0;
		var height = 0;
		var colorType = -1;
		var sawHeader = false;
		var sawData = false;
		var sawPalette = false;
		var chunks = 0;

		while (true)
		{
			if (pos + 8 > len)
				return {error: "truncated PNG (missing end)", width: width, height: height};
			var length = readIntBE(bytes, pos);
			if (length < 0 || pos + 12 + length > len)
				return {error: "truncated or corrupted PNG chunk", width: width, height: height};
			var type = bytes.getString(pos + 4, 4);
			for (i in 0...4)
			{
				var c = bytes.get(pos + 4 + i);
				if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122)))
					return {error: "corrupted PNG chunk name", width: width, height: height};
			}

			if (chunks == 0 && type != "IHDR")
				return {error: "PNG header is missing", width: width, height: height};

			switch (type)
			{
				case "IHDR":
					if (length != 13)
						return {error: "invalid PNG header", width: width, height: height};
					width = readIntBE(bytes, pos + 8);
					height = readIntBE(bytes, pos + 12);
					var depth = bytes.get(pos + 16);
					colorType = bytes.get(pos + 17);
					var compression = bytes.get(pos + 18);
					var filter = bytes.get(pos + 19);
					var interlace = bytes.get(pos + 20);
					var validDepth = switch (colorType)
					{
						case 0: depth == 1 || depth == 2 || depth == 4 || depth == 8 || depth == 16;
						case 3: depth == 1 || depth == 2 || depth == 4 || depth == 8;
						case 2, 4, 6: depth == 8 || depth == 16;
						default: false;
					}
					if (!validDepth || compression != 0 || filter != 0 || interlace > 1)
						return {error: 'unsupported PNG format (color $colorType, depth $depth)', width: width, height: height};
					sawHeader = true;
				case "PLTE":
					sawPalette = true;
				case "IDAT":
					if (colorType == 3 && !sawPalette)
						return {error: "PNG palette is missing", width: width, height: height};
					if (length > 0)
						sawData = true;
				case "IEND":
					if (!sawHeader || !sawData)
						return {error: "PNG has no image data", width: width, height: height};
					return {error: null, width: width, height: height};
				default:
			}

			pos += 12 + length;
			if (++chunks > 100000)
				return {error: "PNG has too many chunks", width: width, height: height};
		}
	}

	static function readJpegSize(bytes:Bytes):{width:Int, height:Int}
	{
		var pos = 2;
		var len = bytes.length;
		while (pos + 4 < len)
		{
			if (bytes.get(pos) != 0xFF)
				return null;
			var marker = bytes.get(pos + 1);
			if (marker == 0xD9 || marker == 0xDA)
				return null;
			var segment = (bytes.get(pos + 2) << 8) | bytes.get(pos + 3);
			if (segment < 2 || pos + 2 + segment > len)
				return null;
			if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC)
			{
				if (pos + 9 > len)
					return null;
				var height = (bytes.get(pos + 5) << 8) | bytes.get(pos + 6);
				var width = (bytes.get(pos + 7) << 8) | bytes.get(pos + 8);
				return {width: width, height: height};
			}
			pos += 2 + segment;
		}
		return null;
	}

	public static function validateAudio(path:String):Bool
		return validateAudioBytes(path, readHeader(path, 64));

	public static function validateAudioBytes(path:String, header:Bytes):Bool
	{
		if (header == null)
			return true;
		if (header.length < 12)
			return reject(path, "sound file is too small to be valid");
		var ext = haxe.io.Path.extension(path).toLowerCase();

		if (startsWith(header, "OggS"))
		{
			if (header.length >= 36 && header.getString(28, 8) == "OpusHead")
				return reject(path, "Opus sounds are not supported, use Vorbis .ogg");
			if (header.length >= 35 && header.get(28) == 0x01 && header.getString(29, 6) == "vorbis")
				return true;
			return reject(path, "unsupported .ogg codec");
		}
		if (startsWith(header, "RIFF") && header.getString(8, 4) == "WAVE")
			return true;
		if (startsWith(header, "ID3") || (header.get(0) == 0xFF && (header.get(1) & 0xE0) == 0xE0))
			return true;
		if (startsWith(header, "fLaC"))
			return reject(path, "FLAC sounds are not supported");
		return reject(path, 'not a valid ${ext == "" ? "sound" : ext} file');
	}

	public static function validateFont(path:String, bytes:Bytes):Bool
	{
		if (bytes == null)
			return false;
		if (bytes.length < 12)
			return reject(path, "font file is too small to be valid");
		var tag = bytes.getString(0, 4);
		if (bytes.get(0) == 0 && bytes.get(1) == 1 && bytes.get(2) == 0 && bytes.get(3) == 0)
			return true;
		if (tag == "OTTO" || tag == "true" || tag == "ttcf" || tag == "typ1")
			return true;
		if (tag == "wOF2")
			return reject(path, "WOFF2 fonts are not supported");
		if (tag == "wOFF")
			return reject(path, "WOFF fonts are not supported");
		return reject(path, "not a valid font file");
	}

	static function readHeader(path:String, count:Int):Bytes
	{
		#if sys
		var input:sys.io.FileInput = null;
		try
		{
			input = File.read(path, true);
			var buffer = Bytes.alloc(count);
			var read = 0;
			try
			{
				read = input.readBytes(buffer, 0, count);
			}
			catch (_:haxe.io.Eof) {}
			input.close();
			return read <= 0 ? null : buffer.sub(0, read);
		}
		catch (_:Dynamic)
		{
			try
			{
				if (input != null)
					input.close();
			}
			catch (_:Dynamic) {}
		}
		#end
		return null;
	}

	static inline function startsWith(bytes:Bytes, text:String):Bool
		return bytes.length >= text.length && bytes.getString(0, text.length) == text;

	static inline function readIntBE(bytes:Bytes, pos:Int):Int
		return (bytes.get(pos) << 24) | (bytes.get(pos + 1) << 16) | (bytes.get(pos + 2) << 8) | bytes.get(pos + 3);
}
