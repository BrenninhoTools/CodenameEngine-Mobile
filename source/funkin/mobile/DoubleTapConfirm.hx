package funkin.mobile;

import flixel.FlxG;
import flixel.input.FlxInput.FlxInputState;

class DoubleTapConfirm
{
	public static inline var TAP_WINDOW:Float = 0.4;
	public static inline var TAP_DISTANCE:Float = 60;

	public static var enabled(get, never):Bool;

	static var users:Int = 0;
	static var registered:Bool = false;
	static var armedTime:Float = -1;
	static var armedX:Float = 0;
	static var armedY:Float = 0;
	static var suppressing:Bool = false;
	static var passing:Bool = false;

	static function get_enabled():Bool
		return users > 0;

	public static function enable()
	{
		#if mobile
		users++;
		if (!registered)
		{
			registered = true;
			FlxG.signals.preUpdate.add(onPreUpdate);
			FlxG.signals.preStateSwitch.add(reset);
		}
		#end
	}

	public static function disable()
	{
		if (users > 0)
			users--;
		if (users == 0)
			clearState();
	}

	static function reset()
	{
		users = 0;
		clearState();
	}

	static function clearState()
	{
		armedTime = -1;
		suppressing = false;
		passing = false;
	}

	static function onPreUpdate()
	{
		#if FLX_MOUSE
		if (users <= 0)
			return;

		var mouse = FlxG.mouse;
		var x = mouse.gameX;
		var y = mouse.gameY;

		if (x < -50000 || (EditorVirtualPad.instance != null && EditorVirtualPad.instance.isOverButton(x, y)))
			return;

		if (mouse.justPressed)
		{
			var now = haxe.Timer.stamp();
			var near = Math.abs(x - armedX) <= TAP_DISTANCE && Math.abs(y - armedY) <= TAP_DISTANCE;
			if (armedTime >= 0 && now - armedTime <= TAP_WINDOW && near)
			{
				armedTime = -1;
				passing = true;
				suppressing = false;
				return;
			}
			armedTime = now;
			armedX = x;
			armedY = y;
			suppressing = true;
			passing = false;
		}

		if (passing)
		{
			if (!mouse.pressed && !mouse.justPressed)
				passing = false;
			return;
		}

		if (suppressing)
		{
			var released = mouse.justReleased || (!mouse.pressed && !mouse.justPressed);
			@:privateAccess {
				mouse._leftButton.current = FlxInputState.RELEASED;
				mouse._leftButton.last = FlxInputState.RELEASED;
			}
			if (released)
				suppressing = false;
		}
		#end
	}
}
