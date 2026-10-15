package funkin.editors.ui;

import flixel.system.scaleModes.StageSizeScaleMode;

class UIScaleMode extends StageSizeScaleMode {
	override public function onMeasure(Width:Int, Height:Int):Void {
		#if mobile
		if (Width > 0 && Height > 0) {
			var logicalWidth = FlxG.initialWidth;
			var logicalHeight = FlxG.initialHeight;
			if (Width / Height >= FlxG.initialWidth / FlxG.initialHeight)
				logicalWidth = Math.round(logicalHeight * Width / Height);
			else
				logicalHeight = Math.round(logicalWidth * Height / Width);
			@:privateAccess {
				FlxG.width = logicalWidth;
				FlxG.height = logicalHeight;
			}
			for (camera in FlxG.cameras.list) {
				camera.width = logicalWidth;
				camera.height = logicalHeight;
			}
			gameSize.set(Width, Height);
			updateDeviceSize(Width, Height);
			updateScaleOffset();
			updateGamePosition();
			return;
		}
		#end
		if ((Width < FlxG.initialWidth || Height < FlxG.initialHeight) && !Options.bypassEditorsResize) {
			@:privateAccess {
				FlxG.width = FlxG.initialWidth;
				FlxG.height = FlxG.initialHeight;
			}
	
			updateGameSize(Width, Height);
			updateDeviceSize(Width, Height);
			updateScaleOffset();
			updateGamePosition();
		} else {
			super.onMeasure(Width, Height);

			for (camera in FlxG.cameras.list) {
				camera.width = Width;
				camera.height = Height;
			}
		}
	}

	override function updateGameSize(Width:Int, Height:Int):Void
	{
		var ratio:Float = FlxG.width / FlxG.height;
		var realRatio:Float = Width / Height;

		var scaleY:Bool = realRatio < ratio;

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
			for(camera in FlxG.cameras.list) {
				camera.width = FlxG.initialWidth;
				camera.height = FlxG.initialHeight;
			}

			FlxG.width = FlxG.initialWidth;
			FlxG.height = FlxG.initialHeight;
		}
	}
}