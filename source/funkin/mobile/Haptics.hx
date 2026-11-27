package funkin.mobile;

#if ios
@:cppFileCode('#include <AudioToolbox/AudioToolbox.h>')
#end
class Haptics
{
	public static inline var MIN_INTERVAL:Float = 0.035;

	public static inline var MODE_NONE:String = "None";
	public static inline var MODE_NOTES:String = "Only Notes";
	public static inline var MODE_ALL:String = "All";
	public static var MODES:Array<String> = [MODE_NONE, MODE_NOTES, MODE_ALL];

	public static inline var MIN_INTENSITY:Float = 0.1;
	public static inline var MAX_INTENSITY:Float = 5;

	public static var enabled(get, never):Bool;
	public static var notesEnabled(get, never):Bool;
	public static var menusEnabled(get, never):Bool;
	public static var intensity(get, never):Float;

	static var lastTime:Float = -1;

	static function get_enabled():Bool
		return #if mobile Options.hapticsMode != MODE_NONE #else false #end;

	static function get_notesEnabled():Bool
		return #if mobile Options.hapticsMode == MODE_NOTES || Options.hapticsMode == MODE_ALL #else false #end;

	static function get_menusEnabled():Bool
		return #if mobile Options.hapticsMode == MODE_ALL #else false #end;

	static function get_intensity():Float
		return #if mobile Math.max(MIN_INTENSITY, Math.min(MAX_INTENSITY, Options.hapticsIntensity)) #else 0 #end;

	public static function light()
		menu(12, 0.45);

	public static function medium()
		menu(22, 0.7);

	public static function heavy()
		menu(45, 1);

	public static function select()
		menu(8, 0.35);

	public static function confirm()
		menu(28, 0.8);

	public static function noteHit()
		note(10, 0.3);

	public static function miss()
		note(35, 0.85);

	public static function death()
		if (notesEnabled)
			vibrate(180, 1, true);

	public static function menu(duration:Int, strength:Float = 1)
		if (menusEnabled)
			vibrate(duration, strength);

	public static function note(duration:Int, strength:Float = 1)
		if (notesEnabled)
			vibrate(duration, strength);

	public static function vibrate(duration:Int, strength:Float = 1, force:Bool = false)
	{
		if (!enabled || duration <= 0)
			return;
		var now = haxe.Timer.stamp();
		if (!force && lastTime >= 0 && now - lastTime < MIN_INTERVAL)
			return;
		lastTime = now;
		var amount = Math.max(0, strength) * intensity;
		if (amount <= 0)
			return;
		var scaledDuration = Std.int(Math.min(duration * Math.max(1, Math.sqrt(amount)), duration * 3));
		play(scaledDuration, Math.min(1, amount));
	}

	public static function preview()
		vibrate(40, 1, true);

	public static function cancel()
	{
		#if android
		try
		{
			androidmanager.os.Vibrator.cancel();
		}
		catch (_:Dynamic) {}
		#end
	}

	static function play(duration:Int, amount:Float)
	{
		#if android
		try
		{
			if (!androidmanager.os.Vibrator.hasVibrator)
				return;
			var strength = Std.int(Math.max(1, Math.min(255, Math.round(amount * 255))));
			if (androidmanager.os.Vibrator.hasAmplitudeControl)
				androidmanager.os.Vibrator.vibrate(duration, strength);
			else
				androidmanager.os.Vibrator.vibrate(Std.int(Math.max(1, duration * amount)), -1);
		}
		catch (_:Dynamic) {}
		#elseif ios
		playIOS(amount >= 0.75 || duration >= 120 ? (duration >= 120 ? 4095 : 1520) : 1519);
		#end
	}

	#if ios
	static function playIOS(soundID:Int)
		untyped __cpp__('AudioServicesPlaySystemSound((SystemSoundID){0})', soundID);
	#end
}
