package funkin.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.util.FlxColor;

class Hitbox extends FlxTypedSpriteGroup<FlxSprite>
{
	public static var instance:Hitbox;

	public static var laneColors:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

	public var keyCount(default, null):Int = 4;
	public var hintAlpha:Float = 0.25;

	var pressedLanes:Array<Bool> = [];
	var justPressedLanes:Array<Bool> = [];
	var justReleasedLanes:Array<Bool> = [];
	var lastPressedLanes:Array<Bool> = [];

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

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			var lane = getLane(touch.gameX, touch.gameY);
			if (lane < 0)
				continue;
			if (touch.pressed)
				pressedLanes[lane] = true;
			if (touch.justPressed)
				justPressedLanes[lane] = true;
		}
		#elseif FLX_MOUSE
		var lane = getLane(FlxG.mouse.gameX, FlxG.mouse.gameY);
		if (lane >= 0)
		{
			if (FlxG.mouse.pressed)
				pressedLanes[lane] = true;
			if (FlxG.mouse.justPressed)
				justPressedLanes[lane] = true;
		}
		#end

		for (i in 0...keyCount)
		{
			if (justPressedLanes[i])
				pressedLanes[i] = true;
			if (lastPressedLanes[i] && !pressedLanes[i])
				justReleasedLanes[i] = true;
		}
	}

	function getLane(x:Float, y:Float):Int
	{
		for (button in MobileButton.instances)
			if (button.containsScreenPoint(x, y))
				return -1;

		var lane = Math.floor(x / (FlxG.width / keyCount));
		if (lane < 0 || lane >= keyCount)
			return -1;
		return lane;
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
			if (pressed(i))
				hint.alpha = hintAlpha;
			else if (hint.alpha > 0)
				hint.alpha = Math.max(0, hint.alpha - elapsed * 3);
		}
	}

	override function destroy()
	{
		FlxG.signals.preUpdate.remove(onPreUpdate);
		if (instance == this)
			instance = null;
		super.destroy();
	}
}
