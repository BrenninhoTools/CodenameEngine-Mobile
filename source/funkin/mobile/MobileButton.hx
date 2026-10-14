package funkin.mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import funkin.backend.assets.Paths;

class MobileButton extends FlxSprite
{
	public static var instances:Array<MobileButton> = [];

	public var animPrefix:String;
	public var onPress:Void->Void = null;
	public var enabled:Bool = true;

	public var justPressed(get, never):Bool;

	var lastCheckedFrame:Int = -1;
	var lastResult:Bool = false;

	static var frameCounter:Int = 0;
	static var frameCounterReady:Bool = false;

	public function new(x:Float = 0, y:Float = 0, image:String, animPrefix:String, scale:Float = 1)
	{
		super(x, y);

		if (!frameCounterReady)
		{
			frameCounterReady = true;
			FlxG.signals.preUpdate.add(() -> frameCounter++);
		}

		this.animPrefix = animPrefix;
		frames = Paths.getFrames(image);
		animation.addByIndices('idle', animPrefix, [0], "", 24, false);
		animation.addByPrefix('press', animPrefix, 24, false);
		animation.play('idle');
		animation.onFinish.add(onAnimationFinish);

		this.scale.set(scale, scale);
		updateHitbox();
		scrollFactor.set();
		antialiasing = true;

		instances.push(this);
	}

	public static function createBack(?camera:FlxCamera):MobileButton
	{
		var button = new MobileButton(0, 0, 'mobile/backButton', 'back', 0.65);
		button.x = FlxG.width - button.width - 10;
		button.y = FlxG.height - button.height - 10;
		if (camera != null)
			button.cameras = [camera];
		return button;
	}

	public static function createPause(?camera:FlxCamera):MobileButton
	{
		var button = new MobileButton(0, 0, 'mobile/pauseButton', 'pause', 0.8);
		button.x = FlxG.width - button.width - 15;
		button.y = 15;
		if (camera != null)
			button.cameras = [camera];
		return button;
	}

	public static function isBlocking():Bool
	{
		for (button in instances)
			if (button.isTouched(false))
				return true;
		return false;
	}

	public function isTouched(justPressedOnly:Bool = true):Bool
	{
		if (!enabled || !exists || !alive || !visible)
			return false;

		var camera = getDefaultCamera();
		var point = FlxPoint.get();
		var result = false;

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if ((justPressedOnly ? touch.justPressed : touch.pressed || touch.justReleased) && overlapsPoint(touch.getWorldPosition(camera, point), true, camera))
			{
				result = true;
				break;
			}
		}
		#end

		#if FLX_MOUSE
		if (!result && (justPressedOnly ? FlxG.mouse.justPressed : FlxG.mouse.pressed || FlxG.mouse.justReleased))
			result = overlapsPoint(FlxG.mouse.getWorldPosition(camera, point), true, camera);
		#end

		point.put();
		return result;
	}

	public function containsScreenPoint(x:Float, y:Float):Bool
	{
		if (!enabled || !exists || !alive || !visible)
			return false;
		return x >= this.x && x <= this.x + width && y >= this.y && y <= this.y + height;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (justPressed)
		{
			animation.play('press', true);
			if (onPress != null)
				onPress();
		}
	}

	function get_justPressed():Bool
	{
		if (lastCheckedFrame != frameCounter)
		{
			lastCheckedFrame = frameCounter;
			lastResult = isTouched(true);
		}
		return lastResult;
	}

	function onAnimationFinish(name:String)
	{
		if (name == 'press')
			animation.play('idle');
	}

	override function destroy()
	{
		instances.remove(this);
		onPress = null;
		super.destroy();
	}
}
