package funkin.backend.system;

import flixel.system.scaleModes.RatioScaleMode;

class FunkinRatioScaleMode extends RatioScaleMode {
	@:isVar public var width(get, set):Null<Int> = null;
	@:isVar public var height(get, set):Null<Int> = null;

	override public function onMeasure(Width:Int, Height:Int):Void
	{
		if (isFullScreenStyle() && Width > 0 && Height > 0)
		{
			var targetWidth:Int = width;
			var targetHeight:Int = height;
			if (Width / Height >= width / height)
				targetWidth = Math.round(height * Width / Height);
			else
				targetHeight = Math.round(width * Height / Width);

			@:privateAccess {
				FlxG.width = targetWidth;
				FlxG.height = targetHeight;
			}
			for (camera in FlxG.cameras.list)
			{
				camera.width = targetWidth;
				camera.height = targetHeight;
			}
			gameSize.set(Width, Height);
			updateDeviceSize(Width, Height);
			updateScaleOffset();
			updateGamePosition();
			return;
		}
		super.onMeasure(Width, Height);
	}

	public override function updateGameSize(Width:Int, Height:Int):Void
	{
		var ratio:Float = width / height;
		var realRatio:Float = Width / Height;

		var scaleY:Bool = realRatio < ratio;
		if (fillScreen)
		{
			scaleY = !scaleY;
		}

		var targetWidth:Int = width;
		var targetHeight:Int = height;

		if (scaleY)
		{
			gameSize.x = Width;
			gameSize.y = Math.floor(gameSize.x / ratio);
		}
		else
		{
			gameSize.y = Height;
			gameSize.x = Math.floor(gameSize.y * ratio);
		}

		@:privateAccess {

			for(c in FlxG.cameras.list) {
				if (c.width == FlxG.width && c.height == FlxG.height) {
					c.width = targetWidth;
					c.height = targetHeight;
				}
			}

			FlxG.width = targetWidth;
			FlxG.height = targetHeight;
		}
	}

	public static inline function isFullScreenStyle():Bool
		return #if mobile Options.screenStyle == "Full" #else false #end;

	public static function refresh() {
		@:privateAccess
		if (FlxG.game != null) FlxG.game.onResize(null);
	}

	public function resetSize() {
		width = null;
		height = null;
	}
	private inline function get_width():Null<Int>
		return this.width == null ? FlxG.initialWidth : this.width;
	private inline function get_height():Null<Int>
		return this.height == null ? FlxG.initialHeight : this.height;
	private inline function set_width(v:Null<Int>):Null<Int> {
		this.width = v;
		@:privateAccess
		FlxG.game.onResize(null);
		return v;
	}
	private inline function set_height(v:Null<Int>):Null<Int> {
		this.height = v;
		@:privateAccess
		FlxG.game.onResize(null);
		return v;
	}
}