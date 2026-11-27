package funkin.backend.assets;

#if (mobile && MOD_SUPPORT)
import lime.app.Future;
import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;
import lime.utils.AssetLibrary as LimeAssetLibrary;
import lime.utils.Bytes;

using StringTools;

class EmbeddedAssetsLibrary extends ModsFolderLibrary {
	public var source:LimeAssetLibrary;

	var files:Map<String, Array<String>> = new Map();
	var folders:Map<String, Array<String>> = new Map();
	var indexed:Bool = false;

	public function new(source:LimeAssetLibrary, libName:String = "assets") {
		this.source = source;
		super("./assets", libName, libName);
	}

	override function toString():String {
		return '(EmbeddedAssetsLibrary: $modName)';
	}

	inline function sourceId():String
		return 'assets/$_parsedAsset';

	function buildIndex() {
		if (indexed) return;
		indexed = true;
		var ids:Array<String> = null;
		try {
			ids = source.list(null);
		} catch (e:Dynamic) {}
		if (ids == null) return;
		for (id in ids) {
			if (!id.startsWith("assets/")) continue;
			var relative = id.substr("assets/".length);
			var slash = relative.lastIndexOf("/");
			var folder = slash >= 0 ? relative.substr(0, slash + 1) : "";
			var list = files.get(folder);
			if (list == null) files.set(folder, list = []);
			list.push(relative.substr(slash + 1));
			while (folder.length > 0) {
				var trimmed = folder.substr(0, folder.length - 1);
				var parentSlash = trimmed.lastIndexOf("/");
				var parent = parentSlash >= 0 ? trimmed.substr(0, parentSlash + 1) : "";
				var children = folders.get(parent);
				if (children == null) folders.set(parent, children = []);
				var name = trimmed.substr(parentSlash + 1);
				if (children.contains(name)) break;
				children.push(name);
				folder = parent;
			}
		}
	}

	function isFolder(relative:String):Bool {
		buildIndex();
		if (!relative.endsWith("/")) relative += "/";
		return files.exists(relative) || folders.exists(relative);
	}

	override public function __getFiles(folder:String, folders:Bool = false):Array<String> {
		if (!folder.endsWith("/")) folder += "/";
		if (!__parseAsset(folder)) return [];
		buildIndex();
		var result = folders ? this.folders.get(_parsedAsset) : files.get(_parsedAsset);
		return result == null ? [] : result.copy();
	}

	override public function exists(asset:String, type:String):Bool {
		if (!__parseAsset(asset)) return false;
		if (asset.endsWith("/")) return isFolder(_parsedAsset);
		try {
			if (source.exists(sourceId(), null)) return true;
		} catch (e:Dynamic) {}
		return isFolder(_parsedAsset);
	}

	override public function getPath(id:String):String {
		if (!__parseAsset(id)) return null;
		return source.getPath(sourceId());
	}

	override public function getBytes(id:String):Bytes {
		if (!__parseAsset(id)) return null;
		return source.getBytes(sourceId());
	}

	override public function getText(id:String):String {
		if (!__parseAsset(id)) return null;
		return source.getText(sourceId());
	}

	override public function getImage(id:String):Image {
		if (!__parseAsset(id)) return null;
		return source.getImage(sourceId());
	}

	override public function getFont(id:String):Font {
		if (!__parseAsset(id)) return null;
		return source.getFont(sourceId());
	}

	override public function getAudioBuffer(id:String):AudioBuffer {
		if (!__parseAsset(id)) return null;
		return source.getAudioBuffer(sourceId());
	}

	override public function isLocal(id:String, type:String):Bool
		return true;

	override public function loadBytes(id:String):Future<Bytes>
		return __parseAsset(id) ? source.loadBytes(sourceId()) : cast Future.withValue(null);

	override public function loadText(id:String):Future<String>
		return __parseAsset(id) ? source.loadText(sourceId()) : cast Future.withValue(null);

	override public function loadImage(id:String):Future<Image>
		return __parseAsset(id) ? source.loadImage(sourceId()) : cast Future.withValue(null);

	override public function loadFont(id:String):Future<Font>
		return __parseAsset(id) ? source.loadFont(sourceId()) : cast Future.withValue(null);

	override public function loadAudioBuffer(id:String):Future<AudioBuffer>
		return __parseAsset(id) ? source.loadAudioBuffer(sourceId()) : cast Future.withValue(null);

	override public function list(type:String):Array<String> {
		var result:Array<String> = [];
		try {
			for (id in source.list(type))
				if (id.startsWith("assets/"))
					result.push(prefix + id.substr("assets/".length));
		} catch (e:Dynamic) {}
		return result;
	}

	override private function __isCacheValid(cache:Map<String, Dynamic>, asset:String, isLocalCache:Bool = false) {
		if (!isLocalCache) asset = '$libName:$asset';
		return cache.exists(asset) && cache[asset] != null;
	}
}
#end
