package funkin.options.categories;

import funkin.backend.utils.StorageUtil;

class MobileOptions extends TreeMenuScreen {
	public function new() {
		super('optionsTree.mobile-name', 'optionsTree.mobile-desc', 'MobileOptions.');

		add(new Checkbox(getNameID('invisibleHitbox'), getDescID('invisibleHitbox'), 'invisibleHitbox'));
		add(new NumOption(getNameID('hitboxOpacity'), getDescID('hitboxOpacity'), 0, 100, 5, 'hitboxOpacity'));
		add(new ArrayOption(getNameID('screenStyle'), getDescID('screenStyle'), ["Original", "Full"], ["Original", "Full"], 'screenStyle', (_) -> funkin.backend.system.FunkinRatioScaleMode.refresh()));
		add(new ArrayOption(getNameID('hitboxMode'), getDescID('hitboxMode'), funkin.mobile.Hitbox.MODES, funkin.mobile.Hitbox.MODES, 'hitboxMode'));
		add(new Checkbox(getNameID('invisiblePauseButton'), getDescID('invisiblePauseButton'), 'invisiblePauseButton'));
		add(new Checkbox(getNameID('antiCrash'), getDescID('antiCrash'), 'antiCrash'));
		add(new TextOption(getNameID('storageInfo'), getDescID('storageInfo'), () -> {
			funkin.backend.system.modules.AntiCrash.showNotice('Storage', StorageUtil.getStorageInfo());
		}));
		add(new TextOption(getNameID('reextractAssets'), getDescID('reextractAssets'), () -> {
			StorageUtil.requestReextract();
			funkin.backend.system.modules.AntiCrash.showNotice('Assets will be extracted again', 'Restart the game to apply.');
		}));
		add(new TextOption(getNameID('resetModFiles'), getDescID('resetModFiles'), () -> {
			var count = funkin.backend.assets.ModGuard.getBlocked().length;
			funkin.backend.assets.ModGuard.clearBlocked();
			funkin.backend.system.modules.AntiCrash.showNotice('Re-enabled $count mod files', null);
		}));

		#if android
		Options.storageType = StorageUtil.getStorageType();
		add(new ArrayOption(getNameID('storageType'), getDescID('storageType'), StorageUtil.STORAGE_TYPES, StorageUtil.STORAGE_TYPES, 'storageType', (value:String) -> {
			StorageUtil.setStorageType(value);
			if (StorageUtil.needsRestart())
				updateMenuDesc(TU.translate(getID('storageType-restart')));
		}));
		#end
	}
}
