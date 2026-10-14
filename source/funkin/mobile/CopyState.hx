package funkin.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.backend.system.MainState;
import funkin.backend.utils.StorageUtil;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

private enum CopyKind
{
	ASSET;
	BUNDLED;
	MIGRATE;
}

private typedef CopyJob =
{
	var kind:CopyKind;
	var source:String;
	var target:String;
}

class CopyState extends FlxState
{
	public static final ASSETS_FOLDER:String = "assets/";
	public static final VERSION_FILE:String = "assets/.version";
	public static final BUNDLED_FOLDERS:Array<String> = ["mods/", "addons/"];

	static inline var MAX_RETRIES:Int = 2;
	static inline var FRAME_BUDGET:Float = 0.03;

	static var _assetFiles:Array<String> = null;
	static var _bundledFiles:Array<String> = null;

	var jobs:Array<CopyJob> = [];
	var retryJobs:Array<CopyJob> = [];
	var failedJobs:Array<CopyJob> = [];
	var index:Int = 0;
	var attempt:Int = 0;
	var overwrite:Bool = false;
	var migrationSource:String = null;

	var statusText:FlxText;
	var progressText:FlxText;
	var progressBar:FlxSprite;
	var progressBack:FlxSprite;

	public static function getVersionKey():String
		return lime.app.Application.current.meta.get("version");

	public static function getStartState():Class<FlxState>
	{
		#if android
		if (!StorageUtil.hasStorageTypeSetting())
			return StorageSetupState;
		#end
		return needsCopy() ? CopyState : MainState;
	}

	static function collectAssetLists()
	{
		if (_assetFiles != null)
			return;
		_assetFiles = [];
		_bundledFiles = [];
		for (id in lime.utils.Assets.list())
		{
			if (id.startsWith(ASSETS_FOLDER))
				_assetFiles.push(id);
			else
				for (folder in BUNDLED_FOLDERS)
					if (id.startsWith(folder))
					{
						_bundledFiles.push(id);
						break;
					}
		}
	}

	public static function getFilesToCopy():Array<String>
	{
		collectAssetLists();
		return _assetFiles;
	}

	public static function getBundledFiles():Array<String>
	{
		collectAssetLists();
		return _bundledFiles;
	}

	static function isVersionOutdated():Bool
	{
		#if sys
		var versionPath = StorageUtil.storageDirectory + VERSION_FILE;
		try
		{
			if (!FileSystem.exists(versionPath))
				return true;
			var stored = File.getContent(versionPath).trim();
			var key = getVersionKey();
			return stored != key && !stored.endsWith("-" + key);
		}
		catch (e:Dynamic)
		{
			return true;
		}
		#else
		return false;
		#end
	}

	static function missing(relative:String):Bool
	{
		#if sys
		try
		{
			return !FileSystem.exists(StorageUtil.storageDirectory + relative);
		}
		catch (e:Dynamic)
		{
			return true;
		}
		#else
		return false;
		#end
	}

	public static function needsCopy():Bool
	{
		#if (sys && mobile)
		if (isVersionOutdated() || StorageUtil.getPreviousDirectory() != null)
			return true;
		var files = getFilesToCopy();
		var step = Std.int(Math.max(1, files.length / 40));
		var i = 0;
		while (i < files.length)
		{
			var id = files[i];
			if (!StorageUtil.isFontAsset(id) && missing(id))
				return true;
			i += step;
		}
		StorageUtil.saveCurrentDirectory();
		#end
		return false;
	}

	override function create()
	{
		super.create();

		#if (sys && mobile)
		var root = StorageUtil.storageDirectory;
		var hasVersion = FileSystem.exists(root + VERSION_FILE);
		overwrite = hasVersion && isVersionOutdated();

		for (id in getFilesToCopy())
			if (overwrite || missing(id))
				jobs.push({kind: ASSET, source: id, target: root + id});

		for (id in getBundledFiles())
			if (missing(id))
				jobs.push({kind: BUNDLED, source: id, target: root + id});

		migrationSource = StorageUtil.getPreviousDirectory();
		if (migrationSource != null)
			for (file in StorageUtil.getMigrationFiles())
				if (!file.endsWith(".tmp") && missing(file))
					jobs.push({kind: MIGRATE, source: migrationSource + file, target: root + file});
		#end

		statusText = new FlxText(0, FlxG.height * 0.4, FlxG.width, getStatus(), 32);
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

	function getStatus():String
	{
		if (attempt > 0)
			return "Retrying failed files...";
		if (index < jobs.length)
			return switch (jobs[index].kind)
			{
				case ASSET: "Extracting assets...";
				case BUNDLED: "Extracting mods...";
				case MIGRATE: "Moving mods to the new storage...";
			}
		return "Finishing...";
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (finished)
			return;

		#if (sys && mobile)
		var start = haxe.Timer.stamp();
		while (index < jobs.length && haxe.Timer.stamp() - start < FRAME_BUDGET)
		{
			var job = jobs[index];
			if (!runJob(job))
				retryJobs.push(job);
			index++;
		}
		#end

		var progress = jobs.length == 0 ? 1 : index / jobs.length;
		progressBar.scale.x = progress;
		statusText.text = getStatus();
		progressText.text = '$index / ${jobs.length}' + (retryJobs.length > 0 ? ' (${retryJobs.length} to retry)' : '');

		if (index >= jobs.length)
		{
			if (retryJobs.length > 0 && attempt < MAX_RETRIES)
			{
				attempt++;
				jobs = retryJobs;
				retryJobs = [];
				index = 0;
			}
			else
			{
				failedJobs = retryJobs;
				retryJobs = [];
				finish();
			}
		}
	}

	function runJob(job:CopyJob):Bool
	{
		#if (sys && mobile)
		return switch (job.kind)
		{
			case ASSET, BUNDLED: StorageUtil.copyAsset(job.source, job.target);
			case MIGRATE: StorageUtil.copyFile(job.source, job.target);
		}
		#else
		return true;
		#end
	}

	var finished:Bool = false;

	function finish()
	{
		if (finished)
			return;
		finished = true;

		#if (sys && mobile)
		var root = StorageUtil.storageDirectory;
		StorageUtil.cleanTempFiles(root, "assets");
		var assetsFailed = false;
		for (job in failedJobs)
		{
			funkin.mobile.MobileLog.write('[CopyState] Failed to copy ${job.source} -> ${job.target}' + (StorageUtil.lastError != null ? ' (${StorageUtil.lastError})' : ''));
			if (job.kind == ASSET)
				assetsFailed = true;
		}

		if (!assetsFailed)
		{
			try
			{
				File.saveContent(root + VERSION_FILE, getVersionKey());
			}
			catch (e:Dynamic) {}
		}

		StorageUtil.saveCurrentDirectory();
		#end

		_assetFiles = null;
		_bundledFiles = null;

		if (failedJobs.length > 0)
		{
			statusText.text = '${failedJobs.length} files could not be copied.\nCheck logs/latest.log for details.';
			statusText.color = FlxColor.YELLOW;
			progressText.text = "";
			new flixel.util.FlxTimer().start(3, (_) -> FlxG.switchState(new MainState()));
		}
		else
			FlxG.switchState(new MainState());
	}
}
