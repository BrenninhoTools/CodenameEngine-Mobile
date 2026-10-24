package funkin.mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;

class Hitbox extends FlxTypedSpriteGroup<FlxSprite>
{
	public static var instance:Hitbox;

	public static inline var MODE_LANES:String = "Four Lanes";
	public static inline var MODE_ARROWS:String = "Arrows";
	public static var MODES:Array<String> = [MODE_LANES, MODE_ARROWS];

	public static var ARROWS_SCALE:Float = 1.25;
	public static var ARROWS_SPREAD:Float = 0.8;

	public static var laneColors:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

	public var keyCount(default, null):Int = 4;
	public var hintAlpha:Float = 0.25;

	public var arrowTargets:Void->Array<FlxSprite> = null;
	public var arrowCamera:FlxCamera = null;

	var pressedLanes:Array<Bool> = [];
	var justPressedLanes:Array<Bool> = [];
	var justReleasedLanes:Array<Bool> = [];
	var lastPressedLanes:Array<Bool> = [];

	var touchLanes:Map<Int, Int> = new Map();

	var lastFrame:Int = -1;
	var updateFrame:Int = 0;

	public function new(keyCount:Int = 4)
	{
		super();
		instance = this;
		scrollFactor.set();
		setKeyCount(keyCount);
		FlxG.signals.preUpdate.add(onPreUpdate);
	}

	public static function isArrowsMode():Bool
		return Options.hitboxMode == MODE_ARROWS;

	public function setKeyCount(count:Int)
	{
		if (count < 1)
			count = 1;
		keyCount = count;

		for (member in members)
			if (member != null)
				member.destroy();
		clear();

		pressedLanes = [for (_ in 0...count) false];
		justPressedLanes = [for (_ in 0...count) false];
		justReleasedLanes = [for (_ in 0...count) false];
		lastPressedLanes = [for (_ in 0...count) false];

		var laneWidth = FlxG.width / count;
		for (i in 0...count)
		{
			var hint = new FlxSprite(Math.floor(laneWidth * i), 0).makeGraphic(Math.ceil(laneWidth), FlxG.height, FlxColor.WHITE);
			hint.color = laneColors[i % laneColors.length];
			hint.alpha = 0;
			hint.scrollFactor.set();
			add(hint);
		}
	}

	public function ensureKeyCount(count:Int)
	{
		if (count != keyCount && count > 0)
			setKeyCount(count);
	}

	function onPreUpdate()
		updateFrame++;

	function refresh()
	{
		if (lastFrame == updateFrame)
			return;
		lastFrame = updateFrame;

		for (i in 0...keyCount)
		{
			lastPressedLanes[i] = pressedLanes[i];
			pressedLanes[i] = false;
			justPressedLanes[i] = false;
			justReleasedLanes[i] = false;
		}

		var currentLanes:Map<Int, Int> = new Map();
		var world = FlxPoint.get();
		var camera = getArrowCamera();

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch.pressed || touch.justPressed)
			{
				touch.getWorldPosition(camera, world);
				processPointer(touch.touchPointID, touch.gameX, touch.gameY, world.x, world.y, touch.justPressed, currentLanes);
			}
			else if (touch.justReleased && !touchLanes.exists(touch.touchPointID))
			{
				touch.getWorldPosition(camera, world);
				var quickTap:Map<Int, Int> = new Map();
				processPointer(touch.touchPointID, touch.gameX, touch.gameY, world.x, world.y, true, quickTap);
			}
		}
		#elseif FLX_MOUSE
		if (FlxG.mouse.pressed || FlxG.mouse.justPressed)
		{
			FlxG.mouse.getWorldPosition(camera, world);
			processPointer(-1, FlxG.mouse.gameX, FlxG.mouse.gameY, world.x, world.y, FlxG.mouse.justPressed, currentLanes);
		}
		#end

		world.put();

		touchLanes = currentLanes;

		for (i in 0...keyCount)
		{
			if (justPressedLanes[i])
				pressedLanes[i] = true;
			if (lastPressedLanes[i] && !pressedLanes[i])
				justReleasedLanes[i] = true;
		}
	}

	function processPointer(id:Int, x:Float, y:Float, worldX:Float, worldY:Float, justPressed:Bool, currentLanes:Map<Int, Int>)
	{
		var lane = getLane(x, y, worldX, worldY);
		if (lane < 0)
			return;

		var previousLane = touchLanes.get(id);
		pressedLanes[lane] = true;
		if ((justPressed || previousLane == null || previousLane != lane) && !lastPressedLanes[lane])
			justPressedLanes[lane] = true;
		currentLanes.set(id, lane);
	}

	function getArrowCamera():FlxCamera
		return arrowCamera != null ? arrowCamera : FlxG.camera;

	function getLane(x:Float, y:Float, worldX:Float, worldY:Float):Int
	{
		for (button in MobileButton.instances)
			if (button.containsScreenPoint(x, y))
				return -1;

		if (isArrowsMode() && arrowTargets != null)
			return getArrowLane(worldX, worldY);

		var lane = Math.floor(x / (FlxG.width / keyCount));
		if (lane < 0 || lane >= keyCount)
			return -1;
		return lane;
	}

	function getArrowLane(worldX:Float, worldY:Float):Int
	{
		var targets = arrowTargets();
		if (targets == null)
			return -1;

		var camera = getArrowCamera();
		var point = FlxPoint.get();
		var best = -1;
		var bestDistance = Math.POSITIVE_INFINITY;
		for (i => target in targets)
		{
			if (target == null || !target.exists || i >= keyCount)
				continue;
			target.getScreenPosition(point, camera);
			var padX = target.width * 0.35;
			var padY = target.height * 0.6;
			if (worldX >= point.x - padX && worldX <= point.x + target.width + padX && worldY >= point.y - padY && worldY <= point.y + target.height + padY)
			{
				var distance = Math.abs(worldX - (point.x + target.width / 2)) + Math.abs(worldY - (point.y + target.height / 2));
				if (distance < bestDistance)
				{
					bestDistance = distance;
					best = i;
				}
			}
		}
		point.put();
		return best;
	}

	public function pressed(lane:Int):Bool
	{
		refresh();
		return lane >= 0 && lane < keyCount && pressedLanes[lane];
	}

	public function justPressed(lane:Int):Bool
	{
		refresh();
		return lane >= 0 && lane < keyCount && justPressedLanes[lane];
	}

	public function justReleased(lane:Int):Bool
	{
		refresh();
		return lane >= 0 && lane < keyCount && justReleasedLanes[lane];
	}

	public static inline function checkPressed(lane:Int, count:Int):Bool
		return instance != null && instance.exists && instance.keyCount == count && instance.pressed(lane);

	public static inline function checkJustPressed(lane:Int, count:Int):Bool
		return instance != null && instance.exists && instance.keyCount == count && instance.justPressed(lane);

	public static inline function checkJustReleased(lane:Int, count:Int):Bool
		return instance != null && instance.exists && instance.keyCount == count && instance.justReleased(lane);

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		for (i => hint in members)
		{
			if (hint == null)
				continue;
			if (pressed(i) && !Options.invisibleHitbox && !isArrowsMode())
				hint.alpha = Options.hitboxOpacity / 100;
			else if (hint.alpha > 0)
				hint.alpha = Math.max(0, hint.alpha - elapsed * 3);
		}
	}

	override function destroy()
	{
		arrowTargets = null;
		arrowCamera = null;
		FlxG.signals.preUpdate.remove(onPreUpdate);
		if (instance == this)
			instance = null;
		super.destroy();
	}
}
