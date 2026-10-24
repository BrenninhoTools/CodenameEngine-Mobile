package funkin.mobile;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;

class TouchUtil
{
	public static inline var DEFAULT_STEP_SIZE:Float = 80;
	public static inline var DEFAULT_TAP_DISTANCE:Float = 28;
	public static inline var DEFAULT_SWIPE_DISTANCE:Float = 70;

	public static var tapDistance:Float = DEFAULT_TAP_DISTANCE;
	public static var swipeDistance:Float = DEFAULT_SWIPE_DISTANCE;
	public static var stepSize:Float = DEFAULT_STEP_SIZE;
	public static var tapMaxTime:Float = 0.45;
	public static var momentumEnabled:Bool = true;
	public static var momentumFriction:Float = 5;
	public static var momentumMinSpeed:Float = 450;
	public static var maxStepsPerFrame:Int = 3;
	public static var firstStepRatio:Float = 0.6;
	public static var flickSpeed:Float = 900;

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

	public static var dragging(get, never):Bool;
	public static var dragX(get, never):Float;
	public static var dragY(get, never):Float;
	public static var deltaX(get, never):Float;
	public static var deltaY(get, never):Float;

	static var initialized:Bool = false;
	static var frame:Int = 0;
	static var lastFrame:Int = -1;

	static var tracking:Bool = false;
	static var moved:Bool = false;
	static var axis:Int = 0;
	static var startX:Float = 0;
	static var startY:Float = 0;
	static var lastX:Float = 0;
	static var lastY:Float = 0;
	static var startTime:Float = 0;
	static var pendingY:Float = 0;
	static var velocityY:Float = 0;
	static var velocityX:Float = 0;
	static var horizontalFired:Bool = false;
	static var momentumY:Float = 0;
	static var stepsEmitted:Int = 0;

	static var _tapped:Bool = false;
	static var _swipeX:Int = 0;
	static var _swipeY:Int = 0;
	static var _stepsY:Int = 0;
	static var _deltaX:Float = 0;
	static var _deltaY:Float = 0;

	public static function init()
	{
		if (initialized)
			return;
		initialized = true;
		FlxG.signals.preUpdate.add(onPreUpdate);
		FlxG.signals.postUpdate.add(refresh);
		FlxG.signals.preStateSwitch.add(onStateSwitch);
	}

	static function onStateSwitch()
	{
		stepSize = DEFAULT_STEP_SIZE;
		tapDistance = DEFAULT_TAP_DISTANCE;
		swipeDistance = DEFAULT_SWIPE_DISTANCE;
		reset();
	}

	public static function reset()
	{
		tracking = false;
		moved = false;
		axis = 0;
		pendingY = 0;
		velocityY = 0;
		velocityX = 0;
		horizontalFired = false;
		momentumY = 0;
		stepsEmitted = 0;
		_tapped = false;
		_swipeX = 0;
		_swipeY = 0;
		_stepsY = 0;
		_deltaX = 0;
		_deltaY = 0;
	}

	public static function stopMomentum()
	{
		momentumY = 0;
		pendingY = 0;
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

	public static function pickRow<T:FlxObject>(objects:Array<T>, ?camera:FlxCamera, padding:Float = 16):Int
	{
		#if FLX_MOUSE
		if (objects == null)
			return -1;
		var best = -1;
		var bestDistance = Math.POSITIVE_INFINITY;
		for (index => obj in objects)
		{
			if (obj == null || !obj.exists || !obj.visible)
				continue;
			var cam = camera != null ? camera : obj.getDefaultCamera();
			var point = FlxG.mouse.getWorldPosition(cam);
			var screen = obj.getScreenPosition(null, cam);
			var py = point.y - cam.scroll.y;
			var top = screen.y - padding;
			var bottom = screen.y + obj.height + padding;
			if (py >= top && py <= bottom)
			{
				var distance = Math.abs(py - (screen.y + obj.height / 2));
				if (distance < bestDistance)
				{
					bestDistance = distance;
					best = index;
				}
			}
			screen.put();
			point.put();
		}
		return best;
		#else
		return -1;
		#end
	}

	public static function tappedRow<T:FlxObject>(objects:Array<T>, ?camera:FlxCamera, padding:Float = 16):Int
		return tapped ? pickRow(objects, camera, padding) : -1;

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
		_stepsY = 0;
		_deltaX = 0;
		_deltaY = 0;

		#if FLX_MOUSE
		var mouse = FlxG.mouse;
		var elapsed = Math.max(FlxG.elapsed, 0.0001);
		var now = haxe.Timer.stamp();

		if (mouse.justPressed)
		{
			tracking = !MobileButton.isBlocking();
			moved = false;
			axis = 0;
			startX = lastX = mouse.gameX;
			startY = lastY = mouse.gameY;
			startTime = now;
			pendingY = 0;
			velocityY = 0;
			velocityX = 0;
			horizontalFired = false;
			momentumY = 0;
			stepsEmitted = 0;
		}

		if (tracking && (mouse.pressed || mouse.justReleased))
		{
			var x = mouse.gameX;
			var y = mouse.gameY;
			_deltaX = x - lastX;
			_deltaY = y - lastY;
			lastX = x;
			lastY = y;

			var totalX = x - startX;
			var totalY = y - startY;
			if (!moved && (Math.abs(totalX) > tapDistance || Math.abs(totalY) > tapDistance))
			{
				moved = true;
				axis = Math.abs(totalY) >= Math.abs(totalX) ? 1 : 2;
				if (axis == 1)
					pendingY = -totalY;
			}
			else if (moved && axis == 1)
				pendingY -= _deltaY;

			velocityX = velocityX * 0.6 + (_deltaX / elapsed) * 0.4;
			velocityY = velocityY * 0.6 + (-_deltaY / elapsed) * 0.4;

			if (moved && axis == 1)
				emitSteps();
			else if (moved && axis == 2 && !horizontalFired && Math.abs(totalX) >= swipeDistance)
			{
				horizontalFired = true;
				_swipeX = totalX > 0 ? 1 : -1;
			}
		}

		if (mouse.justReleased && tracking)
		{
			tracking = false;
			var dx:Float = mouse.gameX - startX;
			var dy:Float = mouse.gameY - startY;
			var absX:Float = Math.abs(dx);
			var absY:Float = Math.abs(dy);

			if (!moved && absX <= tapDistance && absY <= tapDistance && now - startTime <= tapMaxTime)
				_tapped = true;
			else if (axis == 2)
			{
				if (!horizontalFired && (absX >= swipeDistance || (absX >= swipeDistance * 0.5 && Math.abs(velocityX) >= flickSpeed)))
					_swipeX = dx > 0 ? 1 : -1;
				horizontalFired = true;
			}
			else if (axis == 1)
			{
				if (stepsEmitted == 0 && (absY >= swipeDistance || (absY >= swipeDistance * 0.5 && Math.abs(velocityY) >= flickSpeed)))
				{
					_swipeY = dy > 0 ? 1 : -1;
					if (_stepsY == 0)
						_stepsY = -_swipeY;
				}
				if (momentumEnabled && Math.abs(velocityY) >= momentumMinSpeed)
					momentumY = velocityY;
			}
			pendingY = 0;
		}

		if (!tracking && momentumY != 0)
		{
			pendingY += momentumY * elapsed;
			momentumY *= Math.exp(-momentumFriction * elapsed);
			if (Math.abs(momentumY) < momentumMinSpeed * 0.5)
			{
				momentumY = 0;
				pendingY = 0;
			}
			else
				emitSteps();
		}
		#end
	}

	static function emitSteps()
	{
		var size = Math.max(10, stepSize);
		while (Math.abs(_stepsY) < maxStepsPerFrame)
		{
			var threshold = stepsEmitted == 0 ? size * firstStepRatio : size;
			if (Math.abs(pendingY) < threshold)
				break;
			var direction = pendingY > 0 ? 1 : -1;
			_stepsY += direction;
			pendingY -= direction * threshold;
			stepsEmitted++;
		}
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
		return _stepsY;
	}

	static function get_horizontalScroll():Int
	{
		refresh();
		return -_swipeX;
	}

	static function get_dragging():Bool
	{
		refresh();
		return tracking && moved;
	}

	static function get_dragX():Float
	{
		refresh();
		return lastX - startX;
	}

	static function get_dragY():Float
	{
		refresh();
		return lastY - startY;
	}

	static function get_deltaX():Float
	{
		refresh();
		return _deltaX;
	}

	static function get_deltaY():Float
	{
		refresh();
		return _deltaY;
	}
}
