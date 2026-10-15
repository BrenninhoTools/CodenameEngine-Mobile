package funkin.options.categories;

import funkin.backend.utils.StorageUtil;

class MobileOptions extends TreeMenuScreen {
	public function new() {
		super('optionsTree.mobile-name', 'optionsTree.mobile-desc', 'MobileOptions.');

		add(new Checkbox(getNameID('invisibleHitbox'), getDescID('invisibleHitbox'), 'invisibleHitbox'));
		add(new ArrayOption(getNameID('hitboxMode'), getDescID('hitboxMode'), funkin.mobile.Hitbox.MODES, funkin.mobile.Hitbox.MODES, 'hitboxMode'));
		add(new Checkbox(getNameID('invisiblePauseButton'), getDescID('invisiblePauseButton'), 'invisiblePauseButton'));
		add(new Checkbox(getNameID('antiCrash'), getDescID('antiCrash'), 'antiCrash'));
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
