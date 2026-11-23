package funkin.mobile;

#if ios
@:cppFileCode('#include <AudioToolbox/AudioToolbox.h>')
#end
class Haptics
{
	public static inline var MIN_INTERVAL:Float = 0.035;

	public static var enabled(get, never):Bool;
	public static var intensity(get, never):Float;

	static var lastTime:Float = -1;

	static function get_enabled():Bool
		return #if mobile Options.haptics && Options.hapticsIntensity > 0 #else false #end;

	static function get_intensity():Float
		return #if mobile Math.max(0, Math.min(1, Options.hapticsIntensity / 100)) #else 0 #end;

	public static function light()
		vibrate(12, 0.45);

	public static function medium()
		vibrate(22, 0.7);

	public static function heavy()
		vibrate(45, 1);

	public static function select()
		vibrate(8, 0.35);

	public static function confirm()
		vibrate(28, 0.8);

	public static function miss()
		vibrate(35, 0.85);

	public static function death()
		vibrate(180, 1, true);

	public static function vibrate(duration:Int, strength:Float = 1, force:Bool = false)
	{
		if (!enabled || duration <= 0)
			return;
		var now = haxe.Timer.stamp();
		if (!force && lastTime >= 0 && now - lastTime < MIN_INTERVAL)
			return;
		lastTime = now;
		var amount = Math.max(0, Math.min(1, strength)) * intensity;
		if (amount <= 0)
			return;
		play(duration, amount);
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
