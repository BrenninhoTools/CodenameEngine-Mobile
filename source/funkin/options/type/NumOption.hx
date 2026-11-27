package funkin.options.type;

/**
 * Option type that allows stepping through a number.
**/
class NumOption extends TextOption {
	public var changedCallback:Float->Void;

	public var min:Float;
	public var max:Float;
	public var step:Float;

	public var currentValue(default, set):Float;

	public var parent:Dynamic;
	public var optionName:String;

	var __number:Alphabet;

	function set_currentValue(v:Float):Float {
		if (__number != null && v != currentValue) __number.text = TextOption.OPTION_VALUE_PREFIX + formatValue(v);
		return currentValue = v;
	}

	override function set_text(v:String):String {
		super.set_text(v);
		__number.x = __text.x + __text.width + 12;
		return v;
	}

	public function new(text:String, desc:String, min:Float, max:Float, step:Float = 1, ?optionName:String, ?changedCallback:Float->Void = null, ?parent:Dynamic) {
		this.changedCallback = changedCallback;
		this.min = min;
		this.max = max;
		this.step = step;
		this.optionName = optionName;
		this.parent = parent = parent != null ? parent : Options;

		if (Reflect.field(parent, optionName) != null) currentValue = Reflect.field(parent, optionName);
		__number = new Alphabet(0, 20, TextOption.OPTION_VALUE_PREFIX + formatValue(currentValue), 'bold');
		super(text, desc);
		add(__number);
	}

	override function changeSelection(change:Int):Void {
		if (locked) return;
		if (currentValue == (currentValue = roundToStep(FlxMath.bound(currentValue + change * step, min, max)))) return;

		Reflect.setField(parent, optionName, currentValue);
		if (changedCallback != null) changedCallback(currentValue);

		CoolUtil.playMenuSFX(SCROLL);
	}

	override function select() {}

	function stepDecimals():Int {
		var decimals = 0;
		var value = Math.abs(step);
		while (decimals < 6 && Math.abs(value - Math.round(value)) > 0.0000001) {
			value *= 10;
			decimals++;
		}
		return decimals;
	}

	function roundToStep(v:Float):Float {
		var factor = Math.pow(10, stepDecimals());
		return Math.round(v * factor) / factor;
	}

	function formatValue(v:Float):String {
		var decimals = stepDecimals();
		if (decimals == 0) return Std.string(v);
		var text = Std.string(roundToStep(v));
		var dot = text.indexOf(".");
		if (dot < 0) text += "." + StringTools.lpad("", "0", decimals);
		else if (text.length - dot - 1 < decimals) text += StringTools.lpad("", "0", decimals - (text.length - dot - 1));
		return text;
	}
}