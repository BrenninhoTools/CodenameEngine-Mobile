package funkin.backend.system.modules;

import flixel.FlxG;
import funkin.backend.assets.ModsFolder;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#if (target.threaded)
import sys.thread.Thread;
#end

class AntiCrashSession
{
	public static inline var SESSION_FILE:String = "crash/.session";
	public static inline var STRIKES_FILE:String = "crash/.strikes";
	public static inline var STRIKES_FOR_SAFE_MODE:Int = 2;
	public static inline var STABLE_TIME:Float = 45;
	public static inline var FREEZE_TIME:Float = 8;

	public static var previousSessionCrashed(default, null):Bool = false;
	public static var safeModeTriggered(default, null):Bool = false;

	static var foreground:Bool = true;
	static var startStamp:Float = 0;
	static var lastFrameStamp:Float = 0;
	static var stableMarked:Bool = false;
	static var freezeReported:Bool = false;
	static var watchdogRunning:Bool = false;
	static var currentStateName:String = "boot";
	static var pendingNotices:Array<Array<String>> = [];

	public static function init()
	{
		startStamp = lastFrameStamp = haxe.Timer.stamp();
		checkPreviousSession();
		writeSession("running");

		FlxG.signals.postStateSwitch.add(onStateSwitch);
		FlxG.signals.focusLost.add(onFocusLost);
		FlxG.signals.focusGained.add(onFocusGained);
		FlxG.signals.postUpdate.add(onUpdate);
		lime.app.Application.current.onExit.add((_) -> writeSession("closed"));

		startWatchdog();
	}

	static function checkPreviousSession()
	{
		#if sys
		try
		{
			if (!FileSystem.exists(SESSION_FILE))
				return;
			var lines = File.getContent(SESSION_FILE).split("\n");
			var status = lines.length > 0 ? lines[0].trim() : "";
			var mod = lines.length > 1 ? lines[1].trim() : "";
			var state = lines.length > 2 ? lines[2].trim() : "";
			if (status != "running")
			{
				clearStrikes();
				return;
			}

			previousSessionCrashed = true;
			Logs.trace('[AntiCrash] The previous session closed unexpectedly in "$state" (mod: ${mod == "" ? "(default)" : mod})', WARNING);

			var blamedFile = false;
			try
			{
				blamedFile = FileSystem.exists(funkin.backend.assets.ModGuard.LOADING_FILE)
					&& File.getContent(funkin.backend.assets.ModGuard.LOADING_FILE).trim().length > 0;
			}
			catch (_:Dynamic) {}
			if (blamedFile)
				return;

			var strikes = readStrikes();
			var count = strikes.mod == mod ? strikes.count + 1 : 1;
			saveStrikes(mod, count);

			if (mod != "" && count >= STRIKES_FOR_SAFE_MODE && Options.lastLoadedMod == mod)
			{
				safeModeTriggered = true;
				Options.lastLoadedMod = null;
				clearStrikes();
				Logs.trace('[AntiCrash] Safe mode: "$mod" was disabled after closing the game $count times in a row', WARNING);
				queueNotice('Safe mode: "$mod" was disabled', 'The game closed unexpectedly $count times in a row with this mod. You can enable it again in the mods menu.');
			}
			else
				queueNotice('The game closed unexpectedly last time', 'It happened in ${shortState(state)}. Check the crash folder and logs/latest.log.');
		}
		catch (_:Dynamic) {}
		#end
	}

	static function readStrikes():{mod:String, count:Int}
	{
		#if sys
		try
		{
			if (FileSystem.exists(STRIKES_FILE))
			{
				var parts = File.getContent(STRIKES_FILE).split("\n");
				return {mod: parts[0].trim(), count: Std.parseInt(parts[1].trim()) ?? 0};
			}
		}
		catch (_:Dynamic) {}
		#end
		return {mod: null, count: 0};
	}

	static function saveStrikes(mod:String, count:Int)
	{
		#if sys
		try
		{
			ensureFolder();
			File.saveContent(STRIKES_FILE, '$mod\n$count');
		}
		catch (_:Dynamic) {}
		#end
	}

	static function clearStrikes()
	{
		#if sys
		try
		{
			if (FileSystem.exists(STRIKES_FILE))
				FileSystem.deleteFile(STRIKES_FILE);
		}
		catch (_:Dynamic) {}
		#end
	}

	public static function markHandledCrash()
		writeSession("handled");

	static function writeSession(status:String)
	{
		#if sys
		try
		{
			ensureFolder();
			var mod = ModsFolder.currentModFolder != null ? ModsFolder.currentModFolder : "";
			File.saveContent(SESSION_FILE, '$status\n$mod\n$currentStateName\n${Date.now().toString()}');
		}
		catch (_:Dynamic) {}
		#end
	}

	static function ensureFolder()
	{
		#if sys
		if (!FileSystem.exists("crash"))
			FileSystem.createDirectory("crash");
		#end
	}

	static function onStateSwitch()
	{
		try
		{
			currentStateName = AntiCrash.getStateKey(FlxG.state);
		}
		catch (_:Dynamic) {}
		if (foreground)
			writeSession("running");
		flushNotices();
	}

	static function onFocusLost()
	{
		foreground = false;
		writeSession("background");
	}

	static function onFocusGained()
	{
		foreground = true;
		lastFrameStamp = haxe.Timer.stamp();
		freezeReported = false;
		writeSession("running");
	}

	static function onUpdate()
	{
		var now = haxe.Timer.stamp();
		if (freezeReported)
		{
			Logs.trace('[AntiCrash] The game recovered after freezing for ${Math.round(now - lastFrameStamp)}s', WARNING);
			freezeReported = false;
		}
		lastFrameStamp = now;

		if (!stableMarked && now - startStamp > STABLE_TIME)
		{
			stableMarked = true;
			clearStrikes();
		}

		if (pendingNotices.length > 0)
			flushNotices();
	}

	public static function queueNotice(title:String, ?detail:String)
		pendingNotices.push([title, detail]);

	static function flushNotices()
	{
		if (openfl.Lib.current == null || openfl.Lib.current.stage == null)
			return;
		var notices = pendingNotices;
		pendingNotices = [];
		for (n in notices)
			AntiCrash.showNotice(n[0], n[1]);
	}

	static function startWatchdog()
	{
		#if (target.threaded)
		if (watchdogRunning)
			return;
		watchdogRunning = true;
		Thread.create(() ->
		{
			while (watchdogRunning)
			{
				Sys.sleep(1);
				if (!foreground || freezeReported)
					continue;
				var frozen = haxe.Timer.stamp() - lastFrameStamp;
				if (frozen >= FREEZE_TIME)
				{
					freezeReported = true;
					var line = '[AntiCrash] Freeze detected: no frame for ${Math.round(frozen)}s in "$currentStateName" (mod: ${ModsFolder.currentModFolder != null ? ModsFolder.currentModFolder : "(default)"})';
					#if mobile
					funkin.mobile.MobileLog.write(line);
					#else
					Sys.println(line);
					#end
				}
			}
		});
		#end
	}

	static function shortState(state:String):String
	{
		if (state == null || state == "")
			return "an unknown screen";
		var colon = state.indexOf(":");
		var className = colon >= 0 ? state.substr(0, colon) : state;
		var dot = className.lastIndexOf(".");
		var name = dot >= 0 ? className.substr(dot + 1) : className;
		return colon >= 0 ? name + state.substr(colon) : name;
	}
}
