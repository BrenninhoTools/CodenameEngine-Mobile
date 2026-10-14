package funkin.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.backend.system.MainState;
import funkin.backend.utils.StorageUtil;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class CopyState extends FlxState
{
	public static final ASSETS_FOLDER:String = "assets/";
	public static final VERSION_FILE:String = "assets/.version";

	static var _files:Array<String> = null;

	var files:Array<String> = [];
	var index:Int = 0;
	var failed:Int = 0;
	var overwrite:Bool = false;

	var statusText:FlxText;
	var progressText:FlxText;
	var progressBar:FlxSprite;
	var progressBack:FlxSprite;

	public static function getVersionKey():String
		return funkin.backend.system.macros.GitCommitMacro.commitHash + "-" + lime.app.Application.current.meta.get("version");

	public static function getFilesToCopy():Array<String>
	{
		if (_files == null)
			_files = [for (id in lime.utils.Assets.list()) if (id.startsWith(ASSETS_FOLDER)) id];
		return _files;
	}

	public static function needsCopy():Bool
	{
		#if (sys && mobile)
		var versionPath = StorageUtil.storageDirectory + VERSION_FILE;
		try
		{
			if (!FileSystem.exists(versionPath) || File.getContent(versionPath).trim() != getVersionKey())
				return true;
		}
		catch (e:Dynamic)
		{
			return true;
		}
		for (id in getFilesToCopy())
			if (!FileSystem.exists(StorageUtil.storageDirectory + id))
				return true;
		#end
		return false;
	}

	override function create()
	{
		super.create();

		#if (sys && mobile)
		var versionPath = StorageUtil.storageDirectory + VERSION_FILE;
		try
		{
			overwrite = FileSystem.exists(versionPath) && File.getContent(versionPath).trim() != getVersionKey();
		}
		catch (e:Dynamic)
		{
			overwrite = true;
		}

		files = [
			for (id in getFilesToCopy())
				if (overwrite || !FileSystem.exists(StorageUtil.storageDirectory + id)) id
		];
		#end

		statusText = new FlxText(0, FlxG.height * 0.4, FlxG.width, "Extracting assets...", 32);
		statusText.alignment = CENTER;
		add(statusText);

		progressBack = new FlxSprite(FlxG.width * 0.15, FlxG.height * 0.55).makeGraphic(Std.int(FlxG.width * 0.7), 24, 0xFF333333);
		add(progressBack);

		progressBar = new FlxSprite(progressBack.x, progressBack.y).makeGraphic(Std.int(progressBack.width), 24, FlxColor.WHITE);
		progressBar.origin.set(0, 0);
		progressBar.scale.x = 0;
		add(progressBar);

		progressText = new FlxText(0, progressBack.y + 40, FlxG.width, "", 20);
		progressText.alignment = CENTER;
		add(progressText);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		#if (sys && mobile)
		var start = haxe.Timer.stamp();
		while (index < files.length && haxe.Timer.stamp() - start < 0.03)
		{
			copyFile(files[index]);
			index++;
		}
		#end

		var progress = files.length == 0 ? 1 : index / files.length;
		progressBar.scale.x = progress;
		progressText.text = '$index / ${files.length}' + (failed > 0 ? ' ($failed failed)' : '');

		if (index >= files.length)
			finish();
	}

	function copyFile(id:String)
	{
		#if (sys && mobile)
		try
		{
			var target = StorageUtil.storageDirectory + id;
			createFolders(Path.directory(target));
			var bytes = lime.utils.Assets.getBytes(id);
			if (bytes == null)
			{
				failed++;
				return;
			}
			File.saveBytes(target, bytes);
		}
		catch (e:Dynamic)
		{
			failed++;
		}
		#end
	}

	function createFolders(path:String)
	{
		#if sys
		if (path == null || path.length == 0 || FileSystem.exists(path))
			return;
		createFolders(Path.directory(path));
		StorageUtil.createDirectory(path);
		#end
	}

	var finished:Bool = false;

	function finish()
	{
		if (finished)
			return;
		finished = true;

		#if (sys && mobile)
		try
		{
			File.saveContent(StorageUtil.storageDirectory + VERSION_FILE, getVersionKey());
		}
		catch (e:Dynamic) {}
		#end

		_files = null;
		FlxG.switchState(new MainState());
	}
}
