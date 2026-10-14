package funkin.backend.utils;

import flixel.FlxG;
#if sys
import sys.io.File;
#end

class TextureGuard
{
	public static var fallbackMaxSize:Int = 4096;
	public static var maxBytes:Float = 256 * 1024 * 1024;

	public static function getMaxTextureSize():Int
	{
		var size = 0;
		try
		{
			size = FlxG.bitmap.maxTextureSize;
		}
		catch (e:Dynamic)
		{
			size = 0;
		}
		return size > 0 ? size : fallbackMaxSize;
	}

	public static function canLoad(path:String, ?id:String):Bool
	{
		var size = readImageSize(path);
		if (size == null)
			return true;
		var max = getMaxTextureSize();
		var name = id != null ? id : path;
		funkin.backend.assets.Paths.loadTrace('image size ${size.width}x${size.height} (max $max)');
		if (size.width > max || size.height > max)
		{
			Logs.warn('Skipped image "$name": ${size.width}x${size.height} is bigger than this GPU supports (${max}x${max})');
			funkin.backend.system.modules.AntiCrash.showNotice('Image too big for this device', '$name (${size.width}x${size.height}, max $max)');
			return false;
		}
		if (size.width * size.height * 4.0 > maxBytes)
		{
			Logs.warn('Skipped image "$name": ${size.width}x${size.height} needs too much memory');
			return false;
		}
		return true;
	}

	public static function readImageSize(path:String):{width:Int, height:Int}
	{
		#if sys
		var input:sys.io.FileInput = null;
		try
		{
			input = File.read(path, true);
			var header = haxe.io.Bytes.alloc(32);
			var read = input.readBytes(header, 0, 32);
			input.close();
			input = null;
			if (read >= 24 && header.get(0) == 0x89 && header.get(1) == 0x50 && header.get(2) == 0x4E && header.get(3) == 0x47)
				return {width: readIntBE(header, 16), height: readIntBE(header, 20)};
		}
		catch (e:Dynamic)
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

	static inline function readIntBE(bytes:haxe.io.Bytes, pos:Int):Int
		return (bytes.get(pos) << 24) | (bytes.get(pos + 1) << 16) | (bytes.get(pos + 2) << 8) | bytes.get(pos + 3);
}
