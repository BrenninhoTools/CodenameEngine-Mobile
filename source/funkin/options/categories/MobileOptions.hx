package funkin.options.categories;

import funkin.backend.utils.StorageUtil;

class MobileOptions extends TreeMenuScreen {
	public function new() {
		super('optionsTree.mobile-name', 'optionsTree.mobile-desc', 'MobileOptions.');

		add(new ArrayOption(getNameID('hitboxMode'), getDescID('hitboxMode'), funkin.mobile.Hitbox.MODES, funkin.mobile.Hitbox.MODES, 'hitboxMode'));
		add(new Checkbox(getNameID('invisibleHitbox'), getDescID('invisibleHitbox'), 'invisibleHitbox'));
		add(new Checkbox(getNameID('invisiblePauseButton'), getDescID('invisiblePauseButton'), 'invisiblePauseButton'));
		add(new ArrayOption(getNameID('hapticsMode'), getDescID('hapticsMode'), funkin.mobile.Haptics.MODES, funkin.mobile.Haptics.MODES, 'hapticsMode', (_) -> funkin.mobile.Haptics.preview()));
		add(new NumOption(getNameID('hapticsIntensity'), getDescID('hapticsIntensity'), funkin.mobile.Haptics.MIN_INTENSITY, funkin.mobile.Haptics.MAX_INTENSITY, 0.1, 'hapticsIntensity', (_) -> funkin.mobile.Haptics.preview()));
		add(new ArrayOption(getNameID('screenStyle'), getDescID('screenStyle'), ["Original", "Full"], ["Original", "Full"], 'screenStyle', (_) -> funkin.backend.system.FunkinRatioScaleMode.refresh()));

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
