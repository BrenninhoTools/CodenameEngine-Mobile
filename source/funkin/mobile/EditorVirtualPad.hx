package funkin.mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;

typedef EditorPadButton =
{
	var name:String;
	var sprite:FlxSprite;
	var keys:Array<FlxKey>;
	var sticky:Bool;
	var wheel:Int;
	var col:Int;
	var row:Int;
	var left:Bool;
	var pressed:Bool;
	var latched:Bool;
	var repeatTimer:Float;
}

class EditorVirtualPad extends FlxTypedGroup<FlxSprite>
{
	public static var instance:EditorVirtualPad;
	public static var hidden:Bool = false;

	public static inline var BUTTON_SCALE:Float = 0.66;
	public static inline var MARGIN:Float = 10;
	public static inline var GAP:Float = 6;
	public static inline var IDLE_ALPHA:Float = 0.8;
	public static inline var WHEEL_REPEAT:Float = 0.08;

	public var padCamera:FlxCamera;
	public var buttons:Array<EditorPadButton> = [];

	var toggleButton:EditorPadButton;
	var lastWidth:Int = -1;
	var lastHeight:Int = -1;
	var pendingWheel:Int = 0;

	public function new()
	{
		super();
		instance = this;

		padCamera = new FlxCamera();
		padCamera.bgColor = 0;
		FlxG.cameras.add(padCamera, false);
		cameras = [padCamera];

		addButton("up", [UP], true, 1, 2);
		addButton("left", [LEFT], true, 0, 1);
		addButton("right", [RIGHT], true, 2, 1);
		addButton("down", [DOWN], true, 1, 0);
		toggleButton = addButton("toggle", [], true, 0, 0);

		addButton("space", [SPACE], false, 0, 0);
		addButton("enter", [ENTER], false, 1, 0);
		addButton("escape", [ESCAPE], false, 2, 0);
		addButton("delete", [DELETE], false, 0, 1);
		addButton("shift", [SHIFT], false, 1, 1, true);
		addButton("control", [CONTROL], false, 2, 1, true);
		addButton("redo", [CONTROL, Y], false, 0, 2);
		addButton("undo", [CONTROL, Z], false, 1, 2);
		addButton("scrolldown", [], false, 0, 3, false, -1);
		addButton("scrollup", [], false, 1, 3, false, 1);

		FlxG.signals.preUpdate.add(onPreUpdate);
		layout();
		applyVisibility();
	}

	function addButton(name:String, keys:Array<FlxKey>, left:Bool, col:Int, row:Int, sticky:Bool = false, wheel:Int = 0):EditorPadButton
	{
		var sprite = new FlxSprite();
		sprite.frames = Paths.getFrames('mobile/editorPad');
		sprite.animation.addByPrefix('idle', '$name idle', 0, false);
		sprite.animation.addByPrefix('press', '$name press', 0, false);
		sprite.animation.play('idle');
		sprite.scale.set(BUTTON_SCALE, BUTTON_SCALE);
		sprite.updateHitbox();
		sprite.scrollFactor.set();
		sprite.antialiasing = true;
		sprite.alpha = IDLE_ALPHA;
		add(sprite);

		var button:EditorPadButton = {
			name: name,
			sprite: sprite,
			keys: keys,
			sticky: sticky,
			wheel: wheel,
			col: col,
			row: row,
			left: left,
			pressed: false,
			latched: false,
			repeatTimer: 0
		};
		buttons.push(button);
		return button;
	}

	function layout()
	{
		lastWidth = FlxG.width;
		lastHeight = FlxG.height;
		padCamera.setSize(FlxG.width, FlxG.height);
		padCamera.setPosition(0, 0);

		for (button in buttons)
		{
			var size = button.sprite.width + GAP;
			if (button.left)
				button.sprite.x = MARGIN + button.col * size;
			else
				button.sprite.x = FlxG.width - MARGIN - (button.col + 1) * size + GAP;
			button.sprite.y = FlxG.height - MARGIN - (button.row + 1) * size + GAP;
		}
	}

	function applyVisibility()
	{
		for (button in buttons)
			button.sprite.visible = button == toggleButton || !hidden;
	}

	function keepOnTop()
	{
		var list = FlxG.cameras.list;
		if (list.length > 0 && list[list.length - 1] != padCamera && list.contains(padCamera))
		{
			FlxG.cameras.remove(padCamera, false);
			FlxG.cameras.add(padCamera, false);
		}
	}

	function onPreUpdate()
	{
		if (!exists)
			return;

		if (FlxG.width != lastWidth || FlxG.height != lastHeight)
			layout();
		keepOnTop();

		var touched:Array<Bool> = [for (_ in buttons) false];
		var justTouched:Array<Bool> = [for (_ in buttons) false];

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
			if (touch.pressed || touch.justPressed)
				markTouch(touch.gameX, touch.gameY, touch.justPressed, touched, justTouched);
		#end
		#if FLX_MOUSE
		if (#if FLX_TOUCH FlxG.touches.list.length == 0 && #end (FlxG.mouse.pressed || FlxG.mouse.justPressed))
			markTouch(FlxG.mouse.gameX, FlxG.mouse.gameY, FlxG.mouse.justPressed, touched, justTouched);
		#end

		for (i => button in buttons)
		{
			if (!button.sprite.visible)
			{
				if (button.pressed)
					releaseButton(button);
				continue;
			}

			if (justTouched[i])
				onButtonDown(button);
			else if (!touched[i] && button.pressed)
				releaseButton(button);

			if (button.pressed && button.wheel != 0)
			{
				button.repeatTimer -= FlxG.elapsed;
				if (button.repeatTimer <= 0)
				{
					button.repeatTimer = WHEEL_REPEAT;
					pendingWheel += button.wheel;
				}
			}

			var down = button.pressed || button.latched;
			var anim = down ? 'press' : 'idle';
			if (button.sprite.animation.name != anim)
				button.sprite.animation.play(anim);
			button.sprite.alpha = down ? 1 : IDLE_ALPHA;
			button.sprite.color = button.latched ? 0xFFA8C8FF : 0xFFFFFFFF;
		}

		if (pendingWheel != 0)
		{
			@:privateAccess {
				FlxG.mouse.wheel = pendingWheel;
				FlxG.mouse._wheelUsed = true;
			}
			pendingWheel = 0;
		}

		#if FLX_MOUSE
		if (isOverButton(FlxG.mouse.gameX, FlxG.mouse.gameY))
			FlxG.mouse.setRawPositionUnsafe(-100000, -100000);
		#end
	}

	function markTouch(x:Float, y:Float, justPressed:Bool, touched:Array<Bool>, justTouched:Array<Bool>)
	{
		for (i => button in buttons)
		{
			if (!button.sprite.visible || !contains(button.sprite, x, y))
				continue;
			touched[i] = true;
			if (justPressed)
				justTouched[i] = true;
		}
	}

	function onButtonDown(button:EditorPadButton)
	{
		if (button == toggleButton)
		{
			hidden = !hidden;
			if (hidden)
				for (b in buttons)
					if (b != toggleButton)
					{
						if (b.pressed)
							releaseButton(b);
						if (b.latched)
						{
							b.latched = false;
							setKeys(b.keys, false);
						}
					}
			applyVisibility();
			button.pressed = true;
			return;
		}

		if (button.sticky)
		{
			button.latched = !button.latched;
			setKeys(button.keys, button.latched);
			button.pressed = true;
			return;
		}

		button.pressed = true;
		button.repeatTimer = 0;
		setKeys(button.keys, true);
	}

	function releaseButton(button:EditorPadButton)
	{
		button.pressed = false;
		if (button.sticky || button == toggleButton)
			return;
		setKeys(button.keys, false);
	}

	function setKeys(keys:Array<FlxKey>, down:Bool)
	{
		#if FLX_KEYBOARD
		for (key in keys)
			@:privateAccess FlxG.keys.updateKeyStates(key, down);
		#end
	}

	static inline function contains(sprite:FlxSprite, x:Float, y:Float):Bool
		return x >= sprite.x && x <= sprite.x + sprite.width && y >= sprite.y && y <= sprite.y + sprite.height;

	public function isOverButton(x:Float, y:Float):Bool
	{
		for (button in buttons)
			if (button.sprite.visible && contains(button.sprite, x, y))
				return true;
		return false;
	}

	override function destroy()
	{
		FlxG.signals.preUpdate.remove(onPreUpdate);
		for (button in buttons)
			if (button.pressed || button.latched)
				setKeys(button.keys, false);
		if (padCamera != null && FlxG.cameras.list.contains(padCamera))
			FlxG.cameras.remove(padCamera, true);
		padCamera = null;
		if (instance == this)
			instance = null;
		buttons = [];
		super.destroy();
	}
}
