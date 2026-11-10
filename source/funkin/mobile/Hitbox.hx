package funkin.mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

private class HitboxZone extends FlxSprite
{
	public var lane:Int = 0;
	public var hitTest:(Float, Float) -> Bool = null;
	public var tinted:Bool = true;
	public var follow:Bool = false;

	public function new(lane:Int)
	{
		super();
		this.lane = lane;
		alpha = 0;
		scrollFactor.set();
		moves = false;
	}

	public function contains(x:Float, y:Float):Bool
	{
		if (!exists)
			return false;
		if (hitTest != null)
			return hitTest(x, y);
		return x >= this.x && x < this.x + width && y >= this.y && y < this.y + height;
	}

	override function destroy()
	{
		hitTest = null;
		super.destroy();
	}
}

class Hitbox extends FlxTypedGroup<FlxSprite>
{
	public static var instance:Hitbox;

	public static inline var MODE_LANES:String = "Four Lanes";
	public static inline var MODE_TRIANGLE:String = "Triangle";
	public static inline var MODE_ARROWS:String = "Arrows";
	public static inline var MODE_DPAD_LEFT:String = "D-Pad Left";
	public static inline var MODE_DPAD_RIGHT:String = "D-Pad Right";
	public static inline var MODE_DOUBLE_DPAD:String = "Double D-Pad";
	public static var MODES:Array<String> = [MODE_LANES, MODE_TRIANGLE, MODE_ARROWS, MODE_DPAD_LEFT, MODE_DPAD_RIGHT, MODE_DOUBLE_DPAD];

	public static var STYLES:Array<String> = ["Gradient", "Solid", "Outline", "Bottom Glow", "Edges", "Rounded", "Neon", "Arrows", "Corners"];
	public static var COLOR_MODES:Array<String> = ["Classic", "Pastel", "Neon", "White"];

	public static var ARROWS_SCALE:Float = 1.25;
	public static var ARROWS_SPREAD:Float = 0.8;
	public static var ARROWS_RAISE:Float = 70;
	public static var OPPONENT_SCALE:Float = 0.45;

	public static var laneColors:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
	static var pastelColors:Array<FlxColor> = [0xFFE7A6F2, 0xFFA6E9F2, 0xFFB8F2A6, 0xFFF2A6AC];
	static var neonColors:Array<FlxColor> = [0xFFFF2BD6, 0xFF2BF4FF, 0xFF4DFF2B, 0xFFFF2B4D];
	static var dpadNotes:Array<String> = ["purple", "blue", "green", "red"];

	public static var fadeSpeed:Float = 10;
	public static var dpadSize:Float = 124;
	public static var dpadGap:Float = 6;
	public static var dpadIdleAlpha:Float = 0.55;
	public static var triangleBorder:Int = 4;

	public var keyCount(default, null):Int = 4;
	public var mode(default, null):String = MODE_LANES;
	public var style(default, null):String = "Gradient";

	public var arrowTargets:Void->Array<FlxSprite> = null;
	public var arrowCamera(default, set):FlxCamera = null;

	var zones:Array<HitboxZone> = [];

	var pressedLanes:Array<Bool> = [];
	var justPressedLanes:Array<Bool> = [];
	var justReleasedLanes:Array<Bool> = [];
	var lastPressedLanes:Array<Bool> = [];
	var pressedZones:Map<HitboxZone, Bool> = new Map();

	var touchZones:Map<Int, HitboxZone> = new Map();

	var lastFrame:Int = -1;
	var updateFrame:Int = 0;

	public function new(keyCount:Int = 4)
	{
		super();
		instance = this;
		setKeyCount(keyCount);
		FlxG.signals.preUpdate.add(onPreUpdate);
	}

	public static function isArrowsMode():Bool
		return Options.hitboxMode == MODE_ARROWS;

	public static function getLaneColor(lane:Int):FlxColor
	{
		var palette = switch (Options.hitboxColors)
		{
			case "Pastel": pastelColors;
			case "Neon": neonColors;
			case "White": [FlxColor.WHITE];
			default: laneColors;
		}
		return palette[lane % palette.length];
	}

	function set_arrowCamera(value:FlxCamera):FlxCamera
	{
		arrowCamera = value;
		for (zone in zones)
			if (zone != null && zone.follow)
				zone.cameras = value != null ? [value] : null;
		return value;
	}

	public function setKeyCount(count:Int)
	{
		if (count < 1)
			count = 1;
		keyCount = count;
		rebuild();
	}

	public function ensureKeyCount(count:Int)
	{
		if (count != keyCount && count > 0)
			setKeyCount(count);
	}

	public function rebuild()
	{
		for (zone in zones)
			if (zone != null)
				zone.destroy();
		zones = [];
		clear();
		touchZones.clear();
		pressedZones.clear();

		pressedLanes = [for (_ in 0...keyCount) false];
		justPressedLanes = [for (_ in 0...keyCount) false];
		justReleasedLanes = [for (_ in 0...keyCount) false];
		lastPressedLanes = [for (_ in 0...keyCount) false];

		style = STYLES.contains(Options.hitboxStyle) ? Options.hitboxStyle : STYLES[0];
		mode = MODES.contains(Options.hitboxMode) ? Options.hitboxMode : MODE_LANES;
		var fourKeys = keyCount == 4;

		switch (mode)
		{
			case MODE_ARROWS:
				buildArrows();
			case MODE_TRIANGLE if (fourKeys):
				buildTriangle();
			case MODE_DPAD_LEFT if (fourKeys):
				buildDPad(false);
			case MODE_DPAD_RIGHT if (fourKeys):
				buildDPad(true);
			case MODE_DOUBLE_DPAD if (fourKeys):
				buildDPad(false);
				buildDPad(true);
			default:
				buildLanes();
		}

		for (zone in zones)
			zone.alpha = idleAlphaFor(zone);
	}

	function addZone(zone:HitboxZone)
	{
		zones.push(zone);
		add(zone);
	}

	function buildLanes()
	{
		var laneWidth = Math.floor(FlxG.width / keyCount);
		for (i in 0...keyCount)
		{
			var width = i == keyCount - 1 ? FlxG.width - laneWidth * i : laneWidth;
			var zone = new HitboxZone(i);
			zone.loadGraphic(createLaneBitmap(style, Std.int(Math.max(1, width)), FlxG.height, i));
			zone.setPosition(laneWidth * i, 0);
			zone.color = getLaneColor(i);
			addZone(zone);
		}
	}

	function buildTriangle()
	{
		var gameWidth:Float = FlxG.width;
		var gameHeight:Float = FlxG.height;
		for (i in 0...4)
		{
			var bounds = triangleBounds(i, gameWidth, gameHeight);
			var zone = new HitboxZone(i);
			zone.loadGraphic(createTriangleBitmap(i, gameWidth, gameHeight));
			zone.setPosition(bounds.x, bounds.y);
			zone.color = getLaneColor(i);
			var lane = i;
			zone.hitTest = (x, y) -> triangleContains(lane, x, y, gameWidth, gameHeight);
			addZone(zone);
		}
	}

	function buildDPad(onRight:Bool)
	{
		var atlas = loadNoteAtlas();
		var size = Std.int(dpadSize);
		var pad = dpadGap * 0.5 + size * 0.12;
		for (i in 0...4)
		{
			var zone = new HitboxZone(i);
			zone.loadGraphic(createDPadBitmap(size, getLaneColor(i), atlas, dpadNotes[i]));
			zone.tinted = false;
			var position = dpadPosition(i, onRight);
			zone.setPosition(position.x, position.y);
			position.put();
			var zoneRef = zone;
			zone.hitTest = (x, y) -> x >= zoneRef.x - pad && x < zoneRef.x + zoneRef.width + pad && y >= zoneRef.y - pad && y < zoneRef.y + zoneRef.height + pad;
			addZone(zone);
		}
	}

	function buildArrows()
	{
		for (i in 0...keyCount)
		{
			var zone = new HitboxZone(i);
			zone.loadGraphic(createLaneBitmap(style, 160, 160, i));
			zone.color = getLaneColor(i);
			zone.follow = true;
			zone.visible = false;
			if (arrowCamera != null)
				zone.cameras = [arrowCamera];
			addZone(zone);
		}
	}

	function dpadPosition(index:Int, onRight:Bool):FlxPoint
	{
		var area = funkin.backend.utils.ScreenUtil.usableArea();
		var margin:Float = 24;
		var step = dpadSize + dpadGap;
		var clusterWidth = dpadSize * 3 + dpadGap * 2;
		var left = onRight ? area.right - margin - clusterWidth : area.left + margin;
		var bottom = FlxG.height - funkin.backend.utils.ScreenUtil.safeBottom - margin - dpadSize;
		return switch (index)
		{
			case 0: FlxPoint.get(left, bottom - step * 0.5);
			case 1: FlxPoint.get(left + step, bottom);
			case 2: FlxPoint.get(left + step, bottom - step);
			default: FlxPoint.get(left + step * 2, bottom - step * 0.5);
		}
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
		pressedZones.clear();

		var currentZones:Map<Int, HitboxZone> = new Map();
		var world = FlxPoint.get();
		var camera = getArrowCamera();

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch.pressed || touch.justPressed)
			{
				touch.getWorldPosition(camera, world);
				processPointer(touch.touchPointID, touch.gameX, touch.gameY, world.x, world.y, touch.justPressed, currentZones);
			}
			else if (touch.justReleased && !touchZones.exists(touch.touchPointID))
			{
				touch.getWorldPosition(camera, world);
				processPointer(touch.touchPointID, touch.gameX, touch.gameY, world.x, world.y, true, new Map());
			}
		}
		#elseif FLX_MOUSE
		if (FlxG.mouse.pressed || FlxG.mouse.justPressed)
		{
			FlxG.mouse.getWorldPosition(camera, world);
			processPointer(-1, FlxG.mouse.gameX, FlxG.mouse.gameY, world.x, world.y, FlxG.mouse.justPressed, currentZones);
		}
		#end

		world.put();
		touchZones = currentZones;

		for (i in 0...keyCount)
		{
			if (justPressedLanes[i])
				pressedLanes[i] = true;
			if (lastPressedLanes[i] && !pressedLanes[i])
				justReleasedLanes[i] = true;
		}
	}

	function processPointer(id:Int, x:Float, y:Float, worldX:Float, worldY:Float, justPressed:Bool, currentZones:Map<Int, HitboxZone>)
	{
		for (button in MobileButton.instances)
			if (button.containsScreenPoint(x, y))
				return;

		var zone = mode == MODE_ARROWS ? getArrowZone(worldX, worldY) : getZoneAt(x, y);
		if (zone == null || zone.lane < 0 || zone.lane >= keyCount)
			return;

		var lane = zone.lane;
		var previous = touchZones.get(id);
		pressedLanes[lane] = true;
		pressedZones.set(zone, true);
		if ((justPressed || previous == null || previous.lane != lane) && !lastPressedLanes[lane])
			justPressedLanes[lane] = true;
		currentZones.set(id, zone);
	}

	function getArrowCamera():FlxCamera
		return arrowCamera != null ? arrowCamera : FlxG.camera;

	function getZoneAt(x:Float, y:Float):HitboxZone
	{
		var index = zones.length - 1;
		while (index >= 0)
		{
			var zone = zones[index];
			if (zone != null && zone.contains(x, y))
				return zone;
			index--;
		}
		return null;
	}

	function getArrowZone(worldX:Float, worldY:Float):HitboxZone
	{
		if (arrowTargets == null)
			return null;
		var targets = arrowTargets();
		if (targets == null)
			return null;

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
		return best >= 0 && best < zones.length ? zones[best] : null;
	}

	function syncArrowZones()
	{
		if (mode != MODE_ARROWS)
			return;
		var targets = arrowTargets != null ? arrowTargets() : null;
		for (zone in zones)
		{
			var target = targets != null && zone.lane < targets.length ? targets[zone.lane] : null;
			if (target == null || !target.exists || !target.visible)
			{
				zone.visible = false;
				continue;
			}
			var padX = target.width * 0.35;
			var padY = target.height * 0.6;
			zone.visible = true;
			zone.setGraphicSize(Std.int(target.width + padX * 2), Std.int(target.height + padY * 2));
			zone.updateHitbox();
			zone.scrollFactor.copyFrom(target.scrollFactor);
			zone.setPosition(target.x - padX, target.y - padY);
		}
	}

	function idleAlphaFor(zone:HitboxZone):Float
	{
		if (Options.invisibleHitbox || mode == MODE_ARROWS)
			return 0;
		var opacity = Options.hitboxOpacity / 100;
		if (!zone.tinted)
			return dpadIdleAlpha * Math.max(opacity, 0.35);
		return Options.hitboxHint && mode != MODE_ARROWS ? opacity * 0.2 : 0;
	}

	function pressedAlphaFor(zone:HitboxZone):Float
	{
		if (Options.invisibleHitbox || mode == MODE_ARROWS)
			return 0;
		var opacity = Options.hitboxOpacity / 100;
		return zone.tinted ? opacity : Math.min(1, Math.max(opacity, 0.35) * 1.6);
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
		refresh();
		syncArrowZones();

		var fade = Math.min(1, elapsed * fadeSpeed);
		for (zone in zones)
		{
			if (zone == null)
				continue;
			var idle = idleAlphaFor(zone);
			if (pressedZones.exists(zone))
				zone.alpha = pressedAlphaFor(zone);
			else if (Math.abs(zone.alpha - idle) > 0.005)
				zone.alpha += (idle - zone.alpha) * fade;
			else
				zone.alpha = idle;
		}
	}

	override function destroy()
	{
		arrowTargets = null;
		@:bypassAccessor arrowCamera = null;
		zones = [];
		FlxG.signals.preUpdate.remove(onPreUpdate);
		if (instance == this)
			instance = null;
		super.destroy();
	}

	public static function triangleBounds(index:Int, width:Float, height:Float):Rectangle
	{
		return switch (index)
		{
			case 0: new Rectangle(0, 0, width / 2, height);
			case 1: new Rectangle(0, height / 2, width, height / 2);
			case 2: new Rectangle(0, 0, width, height / 2);
			default: new Rectangle(width / 2, 0, width / 2, height);
		}
	}

	static function triangleScore(index:Int, x:Float, y:Float, width:Float, height:Float):Float
	{
		var dx = (x - width / 2) / (width / 2);
		var dy = (y - height / 2) / (height / 2);
		return switch (index)
		{
			case 0: -dx;
			case 1: dy;
			case 2: -dy;
			default: dx;
		}
	}

	public static function triangleContains(index:Int, x:Float, y:Float, width:Float, height:Float):Bool
	{
		if (x < 0 || y < 0 || x >= width || y >= height)
			return false;
		var score = triangleScore(index, x, y, width, height);
		for (other in 0...4)
			if (other != index && triangleScore(other, x, y, width, height) > score)
				return false;
		return true;
	}

	static function createTriangleBitmap(index:Int, width:Float, height:Float):BitmapData
	{
		var bounds = triangleBounds(index, width, height);
		var cx = width / 2 - bounds.x;
		var cy = height / 2 - bounds.y;
		var points:Array<Array<Float>> = switch (index)
		{
			case 0: [[0, 0], [0, bounds.height], [cx, cy]];
			case 1: [[0, bounds.height], [bounds.width, bounds.height], [cx, cy]];
			case 2: [[0, 0], [bounds.width, 0], [cx, cy]];
			default: [[bounds.width, 0], [bounds.width, bounds.height], [cx, cy]];
		}
		var inset = triangleBorder / 2;
		var clampX = (v:Float) -> Math.max(inset, Math.min(bounds.width - inset, v));
		var clampY = (v:Float) -> Math.max(inset, Math.min(bounds.height - inset, v));

		var shape = new Shape();
		shape.graphics.lineStyle(triangleBorder, 0xFFFFFF, 1);
		shape.graphics.beginFill(0xFFFFFF, 0.3);
		shape.graphics.moveTo(clampX(points[0][0]), clampY(points[0][1]));
		for (i in 1...points.length)
			shape.graphics.lineTo(clampX(points[i][0]), clampY(points[i][1]));
		shape.graphics.lineTo(clampX(points[0][0]), clampY(points[0][1]));
		shape.graphics.endFill();
		return drawShape(shape, Std.int(Math.max(1, Math.ceil(bounds.width))), Std.int(Math.max(1, Math.ceil(bounds.height))));
	}

	static function loadNoteAtlas():FlxAtlasFrames
	{
		try
		{
			return Paths.getSparrowAtlas("game/notes/default");
		}
		catch (_:Dynamic) {}
		return null;
	}

	static function createDPadBitmap(size:Int, color:FlxColor, atlas:FlxAtlasFrames, prefix:String):BitmapData
	{
		var radius = size * 0.28;
		var shape = new Shape();
		var dark:FlxColor = color;
		dark.brightness *= 0.55;

		shape.graphics.beginFill(dark.rgb, 0.9);
		shape.graphics.drawRoundRect(0, 0, size, size, radius, radius);
		shape.graphics.endFill();
		shape.graphics.beginFill(color.rgb, 0.75);
		shape.graphics.drawRoundRect(5, 5, size - 10, size - 10, radius * 0.85, radius * 0.85);
		shape.graphics.endFill();
		shape.graphics.beginFill(0xFFFFFF, 0.18);
		shape.graphics.drawRoundRect(9, 9, size - 18, (size - 18) * 0.45, radius * 0.7, radius * 0.7);
		shape.graphics.endFill();

		var bitmap = drawShape(shape, size, size);

		if (atlas != null)
		{
			var frame = null;
			for (candidate in atlas.frames)
				if (candidate != null && candidate.name != null && StringTools.startsWith(candidate.name, prefix) && candidate.name.indexOf("hold") < 0)
				{
					frame = candidate;
					break;
				}
			if (frame != null)
			{
				try
				{
					var arrow = frame.paint(null, null, true);
					var target = size * 0.62;
					var scale = Math.min(target / arrow.width, target / arrow.height);
					var matrix = new Matrix();
					matrix.scale(scale, scale);
					matrix.translate((size - arrow.width * scale) / 2, (size - arrow.height * scale) / 2);
					bitmap.draw(arrow, matrix, new ColorTransform(1, 1, 1, 0.9), null, null, true);
					arrow.dispose();
				}
				catch (_:Dynamic) {}
			}
		}
		return bitmap;
	}

	public static function createLaneBitmap(style:String, width:Int, height:Int, lane:Int):BitmapData
	{
		return switch (style)
		{
			case "Solid":
				var bitmap = new BitmapData(width, height, true, 0x70FFFFFF);
				bitmap.fillRect(new Rectangle(0, 0, 3, height), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(width - 3, 0, 3, height), 0xFFFFFFFF);
				bitmap;

			case "Outline":
				var bitmap = new BitmapData(width, height, true, 0x18FFFFFF);
				var thickness = 8;
				var inset = 4;
				bitmap.fillRect(new Rectangle(inset, inset, width - inset * 2, thickness), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(inset, height - inset - thickness, width - inset * 2, thickness), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(inset, inset, thickness, height - inset * 2), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(width - inset - thickness, inset, thickness, height - inset * 2), 0xFFFFFFFF);
				bitmap;

			case "Bottom Glow":
				FlxGradient.createGradientBitmapData(width, height, [0x00FFFFFF, 0x10FFFFFF, 0xD0FFFFFF], 1, 90);

			case "Edges":
				FlxGradient.createGradientBitmapData(width, height, [0xE0FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0xE0FFFFFF], 1, 0);

			case "Rounded":
				var shape = new Shape();
				shape.graphics.lineStyle(5, 0xFFFFFF, 1);
				shape.graphics.beginFill(0xFFFFFF, 0.3);
				shape.graphics.drawRoundRect(8, 8, width - 16, height - 16, 48, 48);
				shape.graphics.endFill();
				drawShape(shape, width, height);

			case "Neon":
				var bitmap = new BitmapData(width, height, true, 0x08FFFFFF);
				var glow = Std.int(Math.max(1, width * 0.22));
				for (x in 0...glow)
				{
					var t = 1 - x / glow;
					var color = (Std.int(255 * t * t * t) << 24) | 0xFFFFFF;
					bitmap.fillRect(new Rectangle(x, 0, 1, height), color);
					bitmap.fillRect(new Rectangle(width - 1 - x, 0, 1, height), color);
				}
				bitmap;

			case "Arrows":
				var shape = new Shape();
				shape.graphics.beginFill(0xFFFFFF, 0.18);
				shape.graphics.drawRect(0, 0, width, height);
				shape.graphics.endFill();
				var size = Math.min(width, height) * 0.55;
				var angle = [180, 90, -90, 0][lane % 4] * Math.PI / 180;
				var points:Array<Array<Float>> = [[0.5, 0], [0, -0.48], [0, -0.2], [-0.45, -0.2], [-0.45, 0.2], [0, 0.2], [0, 0.48]];
				shape.graphics.lineStyle(6, 0xFFFFFF, 1);
				shape.graphics.beginFill(0xFFFFFF, 0.55);
				for (i in 0...points.length)
				{
					var px = width / 2 + (points[i][0] * Math.cos(angle) - points[i][1] * Math.sin(angle)) * size;
					var py = height / 2 + (points[i][0] * Math.sin(angle) + points[i][1] * Math.cos(angle)) * size;
					if (i == 0)
						shape.graphics.moveTo(px, py);
					else
						shape.graphics.lineTo(px, py);
				}
				shape.graphics.endFill();
				drawShape(shape, width, height);

			case "Corners":
				var bitmap = new BitmapData(width, height, true, 0x10FFFFFF);
				var length = Std.int(Math.min(width, height) * 0.25);
				var thick = 10;
				var inset = 6;
				for (corner in [[inset, inset, 1, 1], [width - inset, inset, -1, 1], [inset, height - inset, 1, -1], [width - inset, height - inset, -1, -1]])
				{
					var cx = corner[0];
					var cy = corner[1];
					bitmap.fillRect(new Rectangle(corner[2] > 0 ? cx : cx - length, corner[3] > 0 ? cy : cy - thick, length, thick), 0xFFFFFFFF);
					bitmap.fillRect(new Rectangle(corner[2] > 0 ? cx : cx - thick, corner[3] > 0 ? cy : cy - length, thick, length), 0xFFFFFFFF);
				}
				bitmap;

			default:
				var glow = Std.int(Math.max(2, width * 0.18));
				var bitmap = new BitmapData(width, height, true, 0x22FFFFFF);
				for (x in 0...glow)
				{
					var t = 1 - x / glow;
					var color = (Std.int(0x22 + (0xD0 - 0x22) * t * t) << 24) | 0xFFFFFF;
					bitmap.fillRect(new Rectangle(x, 0, 1, height), color);
					bitmap.fillRect(new Rectangle(width - 1 - x, 0, 1, height), color);
				}
				bitmap;
		}
	}

	static function drawShape(shape:Shape, width:Int, height:Int):BitmapData
	{
		var bitmap = new BitmapData(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), true, 0);
		bitmap.draw(shape, null, null, null, null, true);
		return bitmap;
	}
}
