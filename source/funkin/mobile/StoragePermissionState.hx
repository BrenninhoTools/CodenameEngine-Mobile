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

		infoText = new FlxText(40, 0, FlxG.width - 80, "Found an existing .CodenameEngine folder.\nAllow \"All files access\" to keep using it.", 28);
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
				finish(StorageUtil.STORAGE_EXTERNAL);
		}
	}

	function onAppHidden()
		leftApp = true;

	function onAppShown()
	{
		if (done || !leftApp)
			return;
		finish(StorageUtil.hasStoragePermission() ? StorageUtil.STORAGE_EXTERNAL : StorageUtil.STORAGE_DATA);
	}

	function finish(type:String)
	{
		if (done)
			return;
		done = true;
		StorageUtil.applyDetectedType(type);
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
