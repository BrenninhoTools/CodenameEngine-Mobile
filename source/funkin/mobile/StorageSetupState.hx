package funkin.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.backend.system.MainState;
import funkin.backend.utils.StorageUtil;

class StorageSetupState extends FlxState
{
	static final DESCRIPTIONS:Map<String, String> = [
		"Data" => "Android/data (default, removed when the app is uninstalled)",
		"Media" => "Android/media (removed when the app is uninstalled)",
		"Obb" => "Android/obb (removed when the app is uninstalled)",
		"External" => "Internal storage/.CodenameEngine (kept after uninstalling, reuses already extracted assets)"
	];

	var options:Array<String> = StorageUtil.STORAGE_TYPES.copy();
	var buttons:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var curSelected:Int = 0;

	var titleText:FlxText;
	var infoText:FlxText;

	var waitingPermission:Bool = false;
	var permissionTimer:Float = 0;
	var done:Bool = false;

	override function create()
	{
		super.create();

		titleText = new FlxText(0, 40, FlxG.width, "Choose where to store assets and mods", 36);
		titleText.alignment = CENTER;
		add(titleText);

		var buttonWidth = Std.int(FlxG.width * 0.8);
		var buttonHeight = 100;
		var startY = 130;
		for (i => option in options)
		{
			var button = new FlxSprite((FlxG.width - buttonWidth) / 2, startY + i * (buttonHeight + 20)).makeGraphic(buttonWidth, buttonHeight, FlxColor.WHITE);
			button.color = 0xFF2A2A40;
			buttons.push(button);
			add(button);

			var label = new FlxText(button.x + 20, button.y + 12, buttonWidth - 40, option + "\n" + DESCRIPTIONS.get(option), 22);
			labels.push(label);
			add(label);
		}

		infoText = new FlxText(0, FlxG.height - 90, FlxG.width, "Tap an option to select it, tap it again to confirm. You can change it later in Options > Mobile Options.", 20);
		infoText.alignment = CENTER;
		add(infoText);

		changeSelection(0);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (done)
			return;

		if (waitingPermission)
		{
			permissionTimer -= elapsed;
			if (permissionTimer <= 0)
			{
				permissionTimer = 0.5;
				if (StorageUtil.hasStoragePermission())
				{
					waitingPermission = false;
					apply(StorageUtil.STORAGE_EXTERNAL);
				}
			}
			if (TouchUtil.tapped && TouchUtil.overlaps(buttons[curSelected]))
				StorageUtil.requestStoragePermission();
			if (TouchUtil.tapped && !TouchUtil.overlaps(buttons[curSelected]))
			{
				for (i => button in buttons)
					if (TouchUtil.overlaps(button))
					{
						waitingPermission = false;
						changeSelection(i);
						break;
					}
			}
			return;
		}

		if (TouchUtil.tapped)
		{
			for (i => button in buttons)
			{
				if (TouchUtil.overlaps(button))
				{
					if (i == curSelected)
						confirm();
					else
						changeSelection(i);
					break;
				}
			}
		}

		var keyChange = (FlxG.keys.justPressed.UP ? -1 : 0) + (FlxG.keys.justPressed.DOWN ? 1 : 0);
		if (keyChange != 0)
			changeSelection(curSelected + keyChange);
		if (FlxG.keys.justPressed.ENTER)
			confirm();
	}

	function changeSelection(index:Int)
	{
		curSelected = (index % options.length + options.length) % options.length;
		for (i => button in buttons)
			button.color = i == curSelected ? 0xFF4A6FD6 : 0xFF2A2A40;
		infoText.text = "Tap an option to select it, tap it again to confirm. You can change it later in Options > Mobile Options.";
	}

	function confirm()
	{
		var option = options[curSelected];
		if (option == StorageUtil.STORAGE_EXTERNAL && !StorageUtil.hasStoragePermission())
		{
			waitingPermission = true;
			permissionTimer = 0.5;
			infoText.text = "Allow \"All files access\" for this app, then come back. Tap External again to reopen the permission screen.";
			StorageUtil.requestStoragePermission();
			return;
		}
		apply(option);
	}

	function apply(option:String)
	{
		done = true;
		StorageUtil.setStorageType(option);
		StorageUtil.reload();
		if (StorageUtil.activeStorageType != option)
			funkin.mobile.MobileLog.write('[StorageSetup] Could not use $option, using ${StorageUtil.activeStorageType} instead');
		else if (StorageUtil.hasExtractedAssets())
			funkin.mobile.MobileLog.write('[StorageSetup] Found extracted assets in ${StorageUtil.storageDirectory}');
		if (CopyState.needsCopy())
			FlxG.switchState(new CopyState());
		else
			FlxG.switchState(new MainState());
	}
}
