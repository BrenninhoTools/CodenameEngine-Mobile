package funkin.backend.system.modules;

import flixel.FlxG;
import flixel.FlxState;
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

class AntiCrash
{
	public static var enabled:Bool = true;

	public static inline var ERROR_WINDOW:Float = 2.5;
	public static inline var ERRORS_BEFORE_RECOVERY:Int = 3;
	public static inline var SCRIPT_ERRORS_BEFORE_DISABLE:Int = 25;
	public static inline var MAX_REPORTS_PER_MINUTE:Int = 10;

	public static var totalCaught(default, null):Int = 0;
	public static var lastError(default, null):String = null;

	static var errorTimes:Array<Float> = [];
	static var recoveryLevels:Map<String, Int> = [];
	static var blockedStateScripts:Map<String, Bool> = [];
	static var scriptErrorTimes:Map<String, Array<Float>> = [];
	static var mutedScripts:Map<String, Bool> = [];
	static var reportTimes:Array<Float> = [];
	static var handling:Bool = false;
	static var notice:AntiCrashNotice;

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
			report(message, stack, context);
			recover(message, context);
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
		report(message, stack, 'creating $key');
		var level = nextLevel(key);
		showNotice('Failed to open ${shortName(key)}', message);

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

		if (times.length >= SCRIPT_ERRORS_BEFORE_DISABLE)
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

	static function recover(message:String, context:String)
	{
		var culprit = Script.curScript;
		Script.curScript = null;
		if (culprit != null && culprit.active)
		{
			culprit.active = false;
			var name = culprit.path != null ? culprit.path : culprit.fileName;
			Logs.trace('[AntiCrash] Disabled script "$name" that caused: $message', WARNING);
			showNotice('Script disabled: ${shortName(name)}', message);
			return;
		}

		var now = haxe.Timer.stamp();
		errorTimes.push(now);
		while (errorTimes.length > 0 && now - errorTimes[0] > ERROR_WINDOW)
			errorTimes.shift();

		if (errorTimes.length < ERRORS_BEFORE_RECOVERY)
		{
			showNotice('Error caught ($context)', message);
			return;
		}

		errorTimes.resize(0);
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
					showNotice('Disabled scripts of ${shortName(key)}', message);
					requestState(() -> recreate(state));
				}
				else if (!requestFallback(state))
					resetToDefaultMod();
			case 1:
				if (!requestFallback(state))
					resetToDefaultMod();
			case 2:
				if (!resetToDefaultMod())
					escalateToCrashHandler(message, CallStack.exceptionStack(true));
			default:
				escalateToCrashHandler(message, CallStack.exceptionStack(true));
		}
	}

	static function nextLevel(key:String):Int
	{
		var level = recoveryLevels.exists(key) ? recoveryLevels.get(key) : 0;
		recoveryLevels.set(key, level + 1);
		return level;
	}

	static function requestFallback(state:FlxState):Bool
	{
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
			funkin.backend.MusicBeatState.skipTransIn = funkin.backend.MusicBeatState.skipTransOut = true;
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

	static function getStateKey(state:FlxState):String
	{
		if (state == null)
			return "null";
		var className = Type.getClassName(Type.getClass(state));
		var scriptName:String = null;
		if (state is funkin.backend.MusicBeatState)
			scriptName = @:privateAccess (cast state : funkin.backend.MusicBeatState).scriptName;
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
		var dot = value.lastIndexOf(".", value.indexOf(":") < 0 ? value.length : value.indexOf(":"));
		return dot >= 0 && value.indexOf(":") < 0 ? value.substr(dot + 1) : value;
	}

	static function escalateToCrashHandler(message:String, stack:Array<StackItem>)
	{
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
		return Std.string(error);
	}

	static function report(message:String, stack:Array<StackItem>, context:String)
	{
		var stackText = stack == null || stack.length == 0 ? "(no stack)" : CallStack.toString(stack);
		var mod = ModsFolder.currentModFolder != null ? ModsFolder.currentModFolder : "(default)";
		var state = FlxG.state != null ? Type.getClassName(Type.getClass(FlxG.state)) : "null";
		var text = '[AntiCrash] $context | mod: $mod | state: $state\n$message\n$stackText';
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
			File.saveContent('crash/AntiCrash_${date}_${totalCaught}.txt', text);
		}
		catch (_:Dynamic) {}
		#end
	}

	public static function showNotice(title:String, ?detail:String)
	{
		try
		{
			if (Lib.current == null || Lib.current.stage == null)
				return;
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
		var text = '⚠ AntiCrash: $title';
		if (detail != null && detail.length > 0)
			text += "\n" + (detail.length > 160 ? detail.substr(0, 160) + "..." : detail);
		field.text = text;
		var stageWidth = stage != null ? stage.stageWidth : 1280;
		field.width = Math.min(stageWidth - 20, 720);
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
