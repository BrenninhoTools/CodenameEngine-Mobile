package funkin.options.categories;

class MobileOptions extends TreeMenuScreen {
	public function new() {
		super('optionsTree.mobile-name', 'optionsTree.mobile-desc', 'MobileOptions.');

		add(new Checkbox(getNameID('invisibleHitbox'), getDescID('invisibleHitbox'), 'invisibleHitbox'));
	}
}
