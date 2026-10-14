package funkin.options.categories;

import funkin.backend.utils.StorageUtil;

class MobileOptions extends TreeMenuScreen {
	public function new() {
		super('optionsTree.mobile-name', 'optionsTree.mobile-desc', 'MobileOptions.');

		add(new Checkbox(getNameID('invisibleHitbox'), getDescID('invisibleHitbox'), 'invisibleHitbox'));
		add(new Checkbox(getNameID('invisiblePauseButton'), getDescID('invisiblePauseButton'), 'invisiblePauseButton'));

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
