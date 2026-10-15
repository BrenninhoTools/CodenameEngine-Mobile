package funkin.backend.system.modules;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import funkin.backend.assets.ModsFolder;
import funkin.backend.scripting.Script;
import haxe.CallStack;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

enum AntiCrashCategory
{
	NULL_ACCESS;
	MISSING_FIELD;
	INVALID_CAST;
	OUT_OF_BOUNDS;
	DIVISION;
	MEMORY;
	STACK_OVERFLOW;
	ASSET;
	SHADER;
	AUDIO;
	SCRIPT;
	NATIVE;
	UNKNOWN;
}

class AntiCrash
{
	public static var enabled(get, set):Bool;
	static var forceDisabled:Bool = false;

	public static inline var ERROR_WINDOW:Float = 2.5;
	public static inline var ERRORS_BEFORE_RECOVERY:Int = 3;
	public static inline var SCRIPT_ERRORS_BEFORE_MUTE:Int = 25;
	public static inline var MAX_REPORTS_PER_MINUTE:Int = 10;
	public static inline var MAX_HISTORY:Int = 50;

	public static var totalCaught(default, null):Int = 0;
	public static var totalRecovered(default, null):Int = 0;
	public static var lastError(default, null):String = null;
	public static var history(default, null):Array<String> = [];

	static var errorTimes:Array<Float> = [];
	static var recoveryLevels:Map<String, Int> = [];
	static var blockedStateScripts:Map<String, Bool> = [];
	static var scriptErrorTimes:Map<String, Array<Float>> = [];
	static var mutedScripts:Map<String, Bool> = [];
	static var reportTimes:Array<Float> = [];
	static var handling:Bool = false;
	static var notice:AntiCrashNotice;
	static var initialized:Bool = false;

	static function get_enabled():Bool
		return !forceDisabled && Options.antiCrash;

	static function set_enabled(value:Bool):Bool
	{
		forceDisabled = !value;
		return value;
	}

	public static function init()
	{
		if (initialized)
			return;
		initialized = true;
		AntiCrashSession.init();
		funkin.backend.assets.ModGuard.init();
	}

	public static function guard(context:String, func:Void->Void):Bool
	{
		try
		{
			func();
			return true;
		}
		catch (e:Dynamic)
		{
			handleError(e, context);
			return false;
		}
	}

	public static function guardValue<T>(context:String, func:Void->T, fallback:T):T
	{
		try
		{
			return func();
		}
		catch (e:Dynamic)
		{
			handleError(e, context);
			return fallback;
		}
	}

	public static function handleError(error:Dynamic, context:String):Void
	{
		var stack = CallStack.exceptionStack(true);
		var message = describe(error);
		totalCaught++;
		lastError = message;

		if (!enabled || handling)
		{
			escalateToCrashHandler(message, stack);
			return;
		}

		handling = true;
		try
		{
			var category = classify(message, stack);
			report(message, stack, context, category);
			recover(message, stack, context, category);
			totalRecovered++;
		}
		catch (inner:Dynamic)
		{
			handling = false;
			escalateToCrashHandler(message + "\n\nAntiCrash failed: " + describe(inner), stack);
			return;
		}
		handling = false;
	}

	public static function handleStateCreateError(error:Dynamic, state:FlxState):Bool
	{
		var stack = CallStack.exceptionStack(true);
		var message = describe(error);
		totalCaught++;
		lastError = message;
		if (!enabled)
			return false;

		var key = getStateKey(state);
		var category = classify(message, stack);
		report(message, stack, 'creating $key', category);
		var level = nextLevel(key);
		showNotice('Failed to open ${shortName(key)}', hint(category, message));
		cleanupFor(category, stack);
		totalRecovered++;

		switch (level)
		{
			case 0:
				if (hasStateScripts(state))
				{
					blockedStateScripts.set(key, true);
					requestState(() -> recreate(state));
					return true;
				}
				return requestFallback(state);
			case 1:
				return requestFallback(state);
			case 2:
				return resetToDefaultMod();
			default:
				totalRecovered--;
				return false;
		}
	}

	public static function onScriptError(script:Script, message:String):Bool
	{
		if (!enabled || script == null)
			return true;
		var key = script.path != null ? script.path : script.fileName;
		if (mutedScripts.exists(key))
			return false;
		var times = scriptErrorTimes.get(key);
		if (times == null)
			scriptErrorTimes.set(key, times = []);
		var now = haxe.Timer.stamp();
		times.push(now);
		while (times.length > 0 && now - times[0] > ERROR_WINDOW)
			times.shift();

		addHistory('script $key: $message');

		if (times.length >= SCRIPT_ERRORS_BEFORE_MUTE)
		{
			mutedScripts.set(key, true);
			times.resize(0);
			Logs.trace('[AntiCrash] Script "$key" keeps failing, further errors from it are muted: $message', WARNING);
			showNotice('Script keeps failing: ${shortName(key)}', message);
			return false;
		}
		return true;
	}

	public static function isStateScriptBlocked(className:String, scriptName:String):Bool
		return blockedStateScripts.exists(makeKey(className, scriptName));

	public static function reset()
	{
		errorTimes.resize(0);
		recoveryLevels.clear();
		blockedStateScripts.clear();
		scriptErrorTimes.clear();
		mutedScripts.clear();
	}

	public static function classify(message:String, ?stack:Array<StackItem>):AntiCrashCategory
	{
		var lower = message == null ? "" : message.toLowerCase();
		inline function has(text:String)
			return lower.indexOf(text) >= 0;

		if (has("stack overflow") || has("too much recursion"))
			return STACK_OVERFLOW;
		if (has("memory") || has("bad_alloc") || has("allocation"))
			return MEMORY;
		if (has("null object reference") || has("null access") || has("null pointer"))
			return NULL_ACCESS;
		if (has("invalid field") || has("has no field") || has("unknown variable") || has("does not have"))
			return MISSING_FIELD;
		if (has("invalid cast") || has("cannot cast"))
			return INVALID_CAST;
		if (has("out of bounds") || has("outside range") || has("invalid index"))
			return OUT_OF_BOUNDS;
		if (has("by 0") || has("division by zero"))
			return DIVISION;
		if (has("shader") || has("glsl") || has("program"))
			return SHADER;
		if (has("sound") || has("audio") || has("vorbis") || has("openal"))
			return AUDIO;
		if (has("could not find asset") || has("not found") || has("no such file") || has("invalid directory"))
			return ASSET;
		if (has("segmentation") || has("sigsegv") || has("signal"))
			return NATIVE;
		if (stack != null && stackContains(stack, "hscript"))
			return SCRIPT;
		return UNKNOWN;
	}

	public static function hint(category:AntiCrashCategory, message:String):String
	{
		var text = switch (category)
		{
			case NULL_ACCESS: "Something used a missing object";
			case MISSING_FIELD: "A script used something that does not exist in this engine version";
			case INVALID_CAST: "A value had the wrong type";
			case OUT_OF_BOUNDS: "A list was read outside of its size";
			case DIVISION: "Division by zero";
			case MEMORY: "Low memory, caches were cleared";
			case STACK_OVERFLOW: "Infinite recursion";
			case ASSET: "A file is missing";
			case SHADER: "A shader is not supported on this device";
			case AUDIO: "A sound failed to play";
			case SCRIPT: "A script failed";
			case NATIVE: "Native error";
			case UNKNOWN: null;
		}
		if (message == null || message.length == 0)
			return text;
		return text == null ? message : '$text: $message';
	}

	static function recover(message:String, stack:Array<StackItem>, context:String, category:AntiCrashCategory)
	{
		cleanupFor(category, stack);

		var culprit = Script.curScript;
		Script.curScript = null;
		if (culprit != null && culprit.active)
		{
			culprit.active = false;
			var name = culprit.path != null ? culprit.path : culprit.fileName;
			Logs.trace('[AntiCrash] Disabled script "$name" that caused: $message', WARNING);
			showNotice('Script disabled: ${shortName(name)}', hint(category, message));
			return;
		}

		var now = haxe.Timer.stamp();
		errorTimes.push(now);
		while (errorTimes.length > 0 && now - errorTimes[0] > ERROR_WINDOW)
			errorTimes.shift();

		if (errorTimes.length < ERRORS_BEFORE_RECOVERY && category != STACK_OVERFLOW)
		{
			showNotice('Error caught ($context)', hint(category, message));
			return;
		}

		errorTimes.resize(0);

		if (closeBrokenSubState(message, category))
			return;

		var state = FlxG.state;
		var key = getStateKey(state);
		var level = nextLevel(key);
		Logs.trace('[AntiCrash] Recovering "$key" (level $level)', WARNING);

		switch (level)
		{
			case 0:
				if (hasStateScripts(state))
				{
					blockedStateScripts.set(key, true);
					showNotice('Disabled scripts of ${shortName(key)}', hint(category, message));
					requestState(() -> recreate(state));
				}
				else if (!requestFallback(state))
					resetToDefaultMod();
			case 1:
				if (!requestFallback(state))
					resetToDefaultMod();
			case 2:
				if (!resetToDefaultMod())
					escalateToCrashHandler(message, stack);
			default:
				escalateToCrashHandler(message, stack);
		}
	}

	static function closeBrokenSubState(message:String, category:AntiCrashCategory):Bool
	{
		var state = FlxG.state;
		if (state == null || state.subState == null)
			return false;

		var deepest:FlxState = state;
		while (deepest.subState != null)
			deepest = deepest.subState;
		var sub:FlxSubState = cast deepest;
		var parent = @:privateAccess sub._parentState;
		var name = Type.getClassName(Type.getClass(sub));

		try
		{
			if (parent != null)
				parent.closeSubState();
			else
				sub.close();
		}
		catch (e:Dynamic)
		{
			try
			{
				if (parent != null)
				{
					@:privateAccess parent.subState = null;
					sub.destroy();
				}
			}
			catch (_:Dynamic)
			{
				return false;
			}
		}

		if (parent is funkin.game.PlayState)
		{
			try
			{
				parent.persistentUpdate = true;
				var play:funkin.game.PlayState = cast parent;
				if (play.paused)
					play.paused = false;
			}
			catch (_:Dynamic) {}
		}

		Logs.trace('[AntiCrash] Closed substate $name', WARNING);
		showNotice('Closed ${shortName(name)}', hint(category, message));
		return true;
	}

	static function cleanupFor(category:AntiCrashCategory, stack:Array<StackItem>)
	{
		if (stack != null)
		{
			if (stackContains(stack, "FlxTweenManager") || stackContains(stack, "FlxTween"))
				safe(() -> flixel.tweens.FlxTween.globalManager.clear());
			if (stackContains(stack, "FlxTimerManager") || stackContains(stack, "FlxTimer"))
				safe(() -> flixel.util.FlxTimer.globalManager.clear());
		}

		switch (category)
		{
			case MEMORY:
				freeMemory();
			case AUDIO:
				safe(() -> FlxG.sound.list.forEachAlive((s) -> if (s != null && !s.playing) s.destroy()));
			default:
		}
	}

	public static function freeMemory()
	{
		safe(() -> FlxG.bitmap.clearUnused());
		safe(() -> FlxG.bitmap.clearCache());
		safe(() -> openfl.utils.Assets.cache.clear());
		safe(() -> funkin.backend.utils.MemoryUtil.clearMajor());
	}

	static inline function safe(func:Void->Void)
	{
		try
			func()
		catch (_:Dynamic) {}
	}

	static function stackContains(stack:Array<StackItem>, text:String):Bool
	{
		for (item in stack)
		{
			var str = Std.string(item);
			if (str.indexOf(text) >= 0)
				return true;
		}
		return false;
	}

	static function nextLevel(key:String):Int
	{
		var level = recoveryLevels.exists(key) ? recoveryLevels.get(key) : 0;
		recoveryLevels.set(key, level + 1);
		return level;
	}

	static function requestFallback(state:FlxState):Bool
	{
		if (state is funkin.game.PlayState)
		{
			showNotice('Leaving the song', null);
			if (funkin.game.PlayState.isStoryMode)
				requestState(() -> new funkin.menus.StoryMenuState());
			else
				requestState(() -> new funkin.menus.FreeplayState());
			return true;
		}
		if (state is funkin.menus.MainMenuState)
		{
			if (ModsFolder.currentModFolder != null)
				return resetToDefaultMod();
			showNotice('Returning to title', null);
			requestState(() -> new funkin.menus.TitleState());
			return true;
		}
		showNotice('Returning to main menu', null);
		requestState(() -> new funkin.menus.MainMenuState());
		return true;
	}

	static function resetToDefaultMod():Bool
	{
		try
		{
			showNotice('Mod disabled after repeated crashes', ModsFolder.currentModFolder);
			recoveryLevels.clear();
			blockedStateScripts.clear();
			Options.lastLoadedMod = ModsFolder.currentModFolder = null;
			Logs.trace('[AntiCrash] Switched to mod: (default)', WARNING);
			requestState(() -> new MainState());
			return true;
		}
		catch (e:Dynamic)
		{
			Logs.trace('[AntiCrash] Could not reset mod: ${describe(e)}', ERROR);
			return false;
		}
	}

	static function requestState(factory:Void->FlxState)
	{
		funkin.backend.MusicBeatState.skipTransIn = funkin.backend.MusicBeatState.skipTransOut = true;
		safe(() -> if (funkin.game.PlayState.instance != null) funkin.game.PlayState.instance.paused = true);
		@:privateAccess FlxG.game._nextState = factory;
	}

	static function recreate(state:FlxState):FlxState
	{
		try
		{
			if (state is funkin.backend.scripting.ModState)
				return new funkin.backend.scripting.ModState(funkin.backend.scripting.ModState.lastName, funkin.backend.scripting.ModState.lastData);
			var created:FlxState = Type.createInstance(Type.getClass(state), []);
			if (created != null)
				return created;
		}
		catch (e:Dynamic) {}
		return new funkin.menus.MainMenuState();
	}

	static function hasStateScripts(state:FlxState):Bool
	{
		if (state is funkin.backend.MusicBeatState)
		{
			var pack = (cast state : funkin.backend.MusicBeatState).stateScripts;
			return pack != null && pack.scripts.length > 0;
		}
		return false;
	}

	public static function getStateKey(state:FlxState):String
	{
		if (state == null)
			return "null";
		var className = Type.getClassName(Type.getClass(state));
		var scriptName:String = null;
		if (state is funkin.backend.MusicBeatState)
			scriptName = (cast state : funkin.backend.MusicBeatState).scriptName;
		return makeKey(className, scriptName);
	}

	static inline function makeKey(className:String, scriptName:String):String
		return scriptName == null ? className : '$className:$scriptName';

	static function shortName(value:String):String
	{
		if (value == null)
			return "";
		var slash = value.lastIndexOf("/");
		if (slash >= 0)
			value = value.substr(slash + 1);
		if (value.indexOf(":") >= 0)
			return value;
		var dot = value.lastIndexOf(".");
		return dot >= 0 ? value.substr(dot + 1) : value;
	}

	static function escalateToCrashHandler(message:String, stack:Array<StackItem>)
	{
		AntiCrashSession.markHandledCrash();
		try
		{
			CrashHandler.present(message, stack);
		}
		catch (_:Dynamic) {}
	}

	public static function describe(error:Dynamic):String
	{
		if (error == null)
			return "Unknown error";
		if (Std.isOfType(error, openfl.errors.Error))
			return (cast error : openfl.errors.Error).message;
		if (Std.isOfType(error, openfl.events.ErrorEvent))
			return (cast error : openfl.events.ErrorEvent).text;
		if (Std.isOfType(error, haxe.Exception))
			return (cast error : haxe.Exception).message;
		return Std.string(error);
	}

	static function addHistory(line:String)
	{
		history.push(DateTools.format(Date.now(), "%H:%M:%S") + " " + line);
		while (history.length > MAX_HISTORY)
			history.shift();
	}

	public static function getEnvironmentInfo():String
	{
		var lines:Array<String> = [];
		inline function add(label:String, value:Void->Dynamic)
		{
			try
				lines.push('$label: ${value()}')
			catch (_:Dynamic) {}
		}
		add("Engine", () -> Flags.VERSION_MESSAGE);
		add("Commit", () -> Flags.COMMIT_HASH);
		add("Platform", () -> lime.system.System.platformLabel);
		add("Device", () -> lime.system.System.deviceVendor + " " + lime.system.System.deviceModel);
		add("Mod", () -> ModsFolder.currentModFolder != null ? ModsFolder.currentModFolder : "(default)");
		add("State", () -> getStateKey(FlxG.state));
		add("SubState", () -> FlxG.state != null && FlxG.state.subState != null ? Type.getClassName(Type.getClass(FlxG.state.subState)) : "none");
		add("Song", () -> funkin.game.PlayState.SONG != null && funkin.game.PlayState.instance != null ? funkin.game.PlayState.SONG.meta.name : "none");
		add("Memory", () -> flixel.util.FlxStringUtil.formatBytes(openfl.system.System.totalMemory));
		add("Storage", () -> funkin.backend.utils.StorageUtil.storageDirectory);
		add("Caught", () -> '$totalCaught (recovered $totalRecovered)');
		return lines.join("\n");
	}

	static function report(message:String, stack:Array<StackItem>, context:String, category:AntiCrashCategory)
	{
		var stackText = stack == null || stack.length == 0 ? "(no stack)" : CallStack.toString(stack);
		addHistory('$context [$category]: $message');
		var text = '[AntiCrash] $context ($category)\n$message\n$stackText';
		Logs.trace(text, ERROR);

		#if sys
		var now = haxe.Timer.stamp();
		while (reportTimes.length > 0 && now - reportTimes[0] > 60)
			reportTimes.shift();
		if (reportTimes.length >= MAX_REPORTS_PER_MINUTE)
			return;
		reportTimes.push(now);
		try
		{
			if (!FileSystem.exists("crash"))
				FileSystem.createDirectory("crash");
			var date = DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S");
			var full = [
				'Context: $context',
				'Category: $category',
				'Error: $message',
				'',
				getEnvironmentInfo(),
				'',
				'Stack:',
				stackText,
				'',
				'Recent errors:',
				history.join("\n")
			].join("\n");
			File.saveContent('crash/AntiCrash_${date}_${totalCaught}.txt', full);
		}
		catch (_:Dynamic) {}
		#end
	}

	public static function showNotice(title:String, ?detail:String)
	{
		try
		{
			if (Lib.current == null || Lib.current.stage == null)
			{
				AntiCrashSession.queueNotice(title, detail);
				return;
			}
			if (notice == null || notice.disposed)
			{
				notice = new AntiCrashNotice();
				Lib.current.stage.addChild(notice);
			}
			else if (notice.parent != null)
				notice.parent.setChildIndex(notice, notice.parent.numChildren - 1);
			notice.show(title, detail);
		}
		catch (_:Dynamic) {}
	}
}

class AntiCrashNotice extends Sprite
{
	static inline var SHOW_TIME:Float = 4;

	public var disposed(default, null):Bool = false;

	var field:TextField;
	var timeLeft:Float = 0;
	var lastStamp:Float = 0;

	public function new()
	{
		super();
		mouseEnabled = mouseChildren = false;
		field = new TextField();
		field.selectable = false;
		field.multiline = true;
		field.wordWrap = true;
		field.defaultTextFormat = new TextFormat("_sans", 16, 0xFFFFFF);
		field.background = true;
		field.backgroundColor = 0x000000;
		field.border = true;
		field.borderColor = 0xFFCC33;
		addChild(field);
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	public function show(title:String, ?detail:String)
	{
		var text = 'AntiCrash: $title';
		if (detail != null && detail.length > 0)
			text += "\n" + (detail.length > 200 ? detail.substr(0, 200) + "..." : detail);
		field.text = text;
		var stageWidth = stage != null ? stage.stageWidth : 1280;
		field.width = Math.min(stageWidth - 20, 760);
		field.height = field.textHeight + 10;
		x = 10;
		y = 10;
		alpha = 1;
		visible = true;
		timeLeft = SHOW_TIME;
		lastStamp = haxe.Timer.stamp();
	}

	function onFrame(_)
	{
		if (!visible)
			return;
		var now = haxe.Timer.stamp();
		timeLeft -= now - lastStamp;
		lastStamp = now;
		if (timeLeft < 0.5)
			alpha = Math.max(0, timeLeft / 0.5);
		if (timeLeft <= 0)
			visible = false;
	}
}
