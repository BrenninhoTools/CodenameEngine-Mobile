package funkin.backend.utils;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

class ScreenUtil
{
	public static inline var BACKGROUND_COVERAGE:Float = 0.85;

	public static var autoAdapt:Bool = true;

	static var registered:Bool = false;

	public static var isFull(get, never):Bool;
	public static var extraWidth(get, never):Float;
	public static var extraHeight(get, never):Float;
	public static var sideOffset(get, never):Float;
	public static var verticalOffset(get, never):Float;

	static inline function get_isFull():Bool
		return funkin.backend.system.FunkinRatioScaleMode.isFullScreenStyle();

	static inline function get_extraWidth():Float
		return Math.max(0, FlxG.width - FlxG.initialWidth);

	static inline function get_extraHeight():Float
		return Math.max(0, FlxG.height - FlxG.initialHeight);

	static inline function get_sideOffset():Float
		return extraWidth / 2;

	static inline function get_verticalOffset():Float
		return extraHeight / 2;

	public static function init()
	{
		if (registered)
			return;
		registered = true;
		FlxG.signals.postStateSwitch.add(() -> adaptState(FlxG.state));
	}

	public static function adaptState(state:FlxState)
	{
		if (!autoAdapt || !isFull || state == null || (extraWidth <= 0 && extraHeight <= 0))
			return;
		if (state is funkin.game.PlayState || state is funkin.editors.ui.UIState)
			return;
		try
		{
			adaptMembers(state.members);
		}
		catch (e:Dynamic) {}
	}

	static function adaptMembers(members:Array<FlxBasic>)
	{
		if (members == null)
			return;
		for (member in members)
		{
			if (member == null || !member.exists)
				continue;
			if (member is FlxSprite && !(member is FlxSpriteGroup))
				adaptBackground(cast member);
		}
	}

	public static function adaptBackground(sprite:FlxSprite):Bool
	{
		if (sprite == null || sprite is FlxText || sprite.graphic == null)
			return false;
		var className = Type.getClassName(Type.getClass(sprite));
		if (className != null && (className.indexOf("Backdrop") >= 0 || className.indexOf("Alphabet") >= 0))
			return false;
		if (sprite.width < FlxG.initialWidth * BACKGROUND_COVERAGE || sprite.height < FlxG.initialHeight * BACKGROUND_COVERAGE)
			return false;
		if (sprite.width >= FlxG.width && sprite.height >= FlxG.height)
			return false;
		coverSprite(sprite);
		return true;
	}

	public static function coverSprite(sprite:FlxSprite, extraScale:Float = 1)
	{
		if (sprite == null || sprite.frameWidth <= 0 || sprite.frameHeight <= 0)
			return;
		var centerX = sprite.x + sprite.width / 2;
		var centerY = sprite.y + sprite.height / 2;
		if (Math.abs(centerX - FlxG.initialWidth / 2) < Math.abs(centerX - FlxG.width / 2))
			centerX += sideOffset;
		if (Math.abs(centerY - FlxG.initialHeight / 2) < Math.abs(centerY - FlxG.height / 2))
			centerY += verticalOffset;
		var needed = Math.max(FlxG.width / sprite.width, FlxG.height / sprite.height) * extraScale;
		if (needed > 1)
		{
			sprite.scale.x *= needed;
			sprite.scale.y *= needed;
			sprite.updateHitbox();
		}
		sprite.x = centerX - sprite.width / 2;
		sprite.y = centerY - sprite.height / 2;
	}

	public static function centerLayout(object:FlxObject)
	{
		if (object == null || !isFull)
			return;
		object.x += sideOffset;
		object.y += verticalOffset;
	}

	public static function centerGroup<T:FlxObject>(group:FlxTypedGroup<T>)
	{
		if (group == null || !isFull)
			return;
		for (member in group.members)
			centerLayout(member);
	}
}
