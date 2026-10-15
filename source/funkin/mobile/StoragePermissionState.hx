package funkin.mobile;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import funkin.backend.system.MainState;
import funkin.backend.utils.StorageUtil;

class StoragePermissionState extends FlxState
{
	var infoText:FlxText;
	var checkTimer:Float = 0;
	var requested:Bool = false;
	var leftApp:Bool = false;
	var done:Bool = false;

	override function create()
	{
		super.create();

		infoText = new FlxText(40, 0, FlxG.width - 80, "Codename Engine keeps its assets and mods in the .CodenameEngine folder.\nAllow \"All files access\" to use it.", 28);
		infoText.alignment = CENTER;
		infoText.screenCenter(Y);
		add(infoText);

		FlxG.signals.focusLost.add(onAppHidden);
		FlxG.signals.focusGained.add(onAppShown);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (done)
			return;

		if (!requested)
		{
			requested = true;
			StorageUtil.requestStoragePermission();
		}

		checkTimer -= elapsed;
		if (checkTimer <= 0)
		{
			checkTimer = 0.5;
			if (StorageUtil.hasStoragePermission())
				finish(true);
		}
	}

	function onAppHidden()
		leftApp = true;

	function onAppShown()
	{
		if (done || !leftApp)
			return;
		finish(StorageUtil.hasStoragePermission());
	}

	function finish(granted:Bool)
	{
		if (done)
			return;
		done = true;
		StorageUtil.onPermissionResult(granted);
		if (CopyState.needsCopy())
			FlxG.switchState(new CopyState());
		else
			FlxG.switchState(new MainState());
	}

	override function destroy()
	{
		FlxG.signals.focusLost.remove(onAppHidden);
		FlxG.signals.focusGained.remove(onAppShown);
		super.destroy();
	}
}
