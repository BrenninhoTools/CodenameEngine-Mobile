package funkin.backend.system;

import flixel.FlxGame;
import flixel.FlxG;
import funkin.backend.system.modules.AntiCrash;
import funkin.backend.system.modules.CrashHandler;
import openfl.events.KeyboardEvent;
import openfl.events.Event;

class FunkinGame extends FlxGame {
	var skipNextTickUpdate:Bool = false;
	var manualPause:Bool = false; //fake autopause

	#if desktop
	var fullscreenListener:KeyboardEvent->Void;

	override function create(_):Void {
		super.create(_);

		if (stage == null) return;

		// In the future, make it so any keybinds are able to toggle fullscreen instead of just F11
		stage.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent) {
			if (e.keyCode == 122) {
				FlxG.fullscreen = !FlxG.fullscreen;
			}
		});
	}
	#end
	
	public override function switchState() {
		var attempts = 0;
		while (true) {
			try {
				super.switchState();
				break;
			} catch (e:Dynamic) {
				var failed = _state;
				attempts++;
				if (attempts > 3 || !AntiCrash.handleStateCreateError(e, failed) || _nextState == null)
					throw e;
				try {
					if (failed != null) failed.destroy();
				} catch (_:Dynamic) {}
				_state = null;
			}
		}
		// draw once to put all images in gpu then put the last update time to now to prevent lag spikes or whatever
		draw();
		ticks = getTicks();
		skipNextTickUpdate = true;
	}

	override function __enterFrame(deltaTime:Float) {
		// The state that threw must not update again, or it throws on every frame.
		if (CrashHandler.blocking) {
			ticks = getTicks();
			try {
				draw();
			} catch (_:Dynamic) {}
			return;
		}
		if (skipNextTickUpdate != (skipNextTickUpdate = false)) ticks = getTicks();
		if (manualPause) {
			var prevAutoPause = FlxG.autoPause;
			FlxG.autoPause = true;
			super.__enterFrame(deltaTime);
			FlxG.autoPause = prevAutoPause;
			draw();
			return;
		}
		super.__enterFrame(deltaTime);
	}


	override function step(deltaTime:Float):Void {
		try {
			super.step(deltaTime);
		} catch (e:Dynamic) {
			AntiCrash.handleError(e, "update");
		}
	}

	override function draw():Void {
		try {
			super.draw();
		} catch (e:Dynamic) {
			try {
				FlxG.cameras.unlock();
			} catch (_:Dynamic) {}
			AntiCrash.handleError(e, "draw");
		}
	}

	override public function onFocus(_):Void {
		if (manualPause) return;
		super.onFocus(_);
	}

	override public function onFocusLost(event:Event):Void {
		if (manualPause) return;
		super.onFocusLost(event);
	}

	public function toggleManualPause() {
		var prevAutoPause = FlxG.autoPause;
		FlxG.autoPause = true;

		if (!manualPause) {
			onFocusLost(null);
			manualPause = true;
		} else {
			manualPause = false;
			onFocus(null);
		}
		FlxG.autoPause = prevAutoPause;
	}
}
