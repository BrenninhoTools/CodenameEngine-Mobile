package funkin.mobile;

import flixel.FlxG;
import flixel.input.actions.FlxAction.FlxActionDigital;
import funkin.backend.system.Controls;

class MobileControls
{
	public static function trigger(controls:Controls, control:Control)
	{
		if (controls == null)
			return;
		var action:FlxActionDigital = cast controls.getActionFromControl(control);
		if (action == null)
			return;
		@:privateAccess {
			action._timestamp = FlxG.game.ticks;
			action.triggered = true;
		}
	}
}
