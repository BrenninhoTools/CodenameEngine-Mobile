package funkin.mobile;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;

class TouchUtil
{
	public static var tapDistance:Float = 24;
	public static var swipeDistance:Float = 70;

	public static var pressed(get, never):Bool;
	public static var justPressed(get, never):Bool;
	public static var justReleased(get, never):Bool;

	public static var tapped(get, never):Bool;
	public static var swipeUp(get, never):Bool;
	public static var swipeDown(get, never):Bool;
	public static var swipeLeft(get, never):Bool;
	public static var swipeRight(get, never):Bool;

	public static var verticalScroll(get, never):Int;
	public static var horizontalScroll(get, never):Int;

	static var initialized:Bool = false;
	static var frame:Int = 0;
	static var lastFrame:Int = -1;
	static var tracking:Bool = false;
	static var startX:Float = 0;
	static var startY:Float = 0;

	static var _tapped:Bool = false;
	static var _swipeX:Int = 0;
	static var _swipeY:Int = 0;

	public static function init()
	{
		if (initialized)
			return;
		initialized = true;
		FlxG.signals.preUpdate.add(onPreUpdate);
		FlxG.signals.postUpdate.add(refresh);
		FlxG.signals.preStateSwitch.add(reset);
	}

	public static function reset()
	{
		tracking = false;
		_tapped = false;
		_swipeX = 0;
		_swipeY = 0;
	}

	public static function overlaps(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if FLX_MOUSE
		if (object == null || !object.exists)
			return false;
		if (object is FlxObject)
		{
			var obj:FlxObject = cast object;
			var cam = camera != null ? camera : obj.getDefaultCamera();
			var point = FlxG.mouse.getWorldPosition(cam);
			var screen = obj.getScreenPosition(null, cam);
			var px = point.x - cam.scroll.x;
			var py = point.y - cam.scroll.y;
			var result = px >= screen.x && px < screen.x + obj.width && py >= screen.y && py < screen.y + obj.height;
			screen.put();
			point.put();
			return result;
		}
		return FlxG.mouse.overlaps(object, camera);
		#else
		return false;
		#end
	}

	public static function pressedOn(object:FlxBasic, ?camera:FlxCamera):Bool
		return justPressed && !MobileButton.isBlocking() && overlaps(object, camera);

	public static function tappedOn(object:FlxBasic, ?camera:FlxCamera):Bool
		return tapped && overlaps(object, camera);

	public static function tappedLeftHalf(object:FlxObject, ?camera:FlxCamera):Bool
	{
		#if FLX_MOUSE
		if (!tappedOn(object, camera))
			return false;
		var cam = camera != null ? camera : object.getDefaultCamera();
		var point = FlxG.mouse.getWorldPosition(cam);
		var screen = object.getScreenPosition(null, cam);
		var result = point.x - cam.scroll.x < screen.x + object.width * 0.5;
		screen.put();
		point.put();
		return result;
		#else
		return false;
		#end
	}

	static function onPreUpdate()
		frame++;

	static function refresh()
	{
		if (lastFrame == frame)
			return;
		lastFrame = frame;

		_tapped = false;
		_swipeX = 0;
		_swipeY = 0;

		#if FLX_MOUSE
		var mouse = FlxG.mouse;

		if (mouse.justPressed)
		{
			tracking = !MobileButton.isBlocking();
			startX = mouse.gameX;
			startY = mouse.gameY;
		}

		if (mouse.justReleased && tracking)
		{
			tracking = false;

			var dx:Float = mouse.gameX - startX;
			var dy:Float = mouse.gameY - startY;
			var absX:Float = Math.abs(dx);
			var absY:Float = Math.abs(dy);

			if (absX <= tapDistance && absY <= tapDistance)
				_tapped = true;
			else if (absX > absY && absX >= swipeDistance)
				_swipeX = dx > 0 ? 1 : -1;
			else if (absY >= absX && absY >= swipeDistance)
				_swipeY = dy > 0 ? 1 : -1;
		}
		#end
	}

	static function get_pressed():Bool
	{
		#if FLX_MOUSE
		return FlxG.mouse.pressed;
		#else
		return false;
		#end
	}

	static function get_justPressed():Bool
	{
		#if FLX_MOUSE
		return FlxG.mouse.justPressed;
		#else
		return false;
		#end
	}

	static function get_justReleased():Bool
	{
		#if FLX_MOUSE
		return FlxG.mouse.justReleased;
		#else
		return false;
		#end
	}

	static function get_tapped():Bool
	{
		refresh();
		return _tapped;
	}

	static function get_swipeUp():Bool
	{
		refresh();
		return _swipeY < 0;
	}

	static function get_swipeDown():Bool
	{
		refresh();
		return _swipeY > 0;
	}

	static function get_swipeLeft():Bool
	{
		refresh();
		return _swipeX < 0;
	}

	static function get_swipeRight():Bool
	{
		refresh();
		return _swipeX > 0;
	}

	static function get_verticalScroll():Int
	{
		refresh();
		return -_swipeY;
	}

	static function get_horizontalScroll():Int
	{
		refresh();
		return -_swipeX;
	}
}
