package org.codename.mobile;

import android.content.Context;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;

import org.haxe.extension.Extension;

public class HapticHelper {

	private static Vibrator vibrator;
	private static boolean resolved = false;

	private static Vibrator getVibrator() {
		if (resolved) {
			return vibrator;
		}
		resolved = true;
		try {
			Context context = Extension.mainContext;
			if (context == null) {
				resolved = false;
				return null;
			}
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
				VibratorManager manager = (VibratorManager) context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
				if (manager != null) {
					vibrator = manager.getDefaultVibrator();
				}
			} else {
				vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
			}
			if (vibrator != null && !vibrator.hasVibrator()) {
				vibrator = null;
			}
		} catch (Exception exception) {
			vibrator = null;
		}
		return vibrator;
	}

	public static boolean isSupported() {
		return getVibrator() != null;
	}

	public static void vibrate(int duration, int amplitude) {
		Vibrator target = getVibrator();
		if (target == null || duration <= 0) {
			return;
		}
		try {
			int strength = Math.max(1, Math.min(255, amplitude));
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				if (target.hasAmplitudeControl()) {
					target.vibrate(VibrationEffect.createOneShot(duration, strength));
				} else {
					target.vibrate(VibrationEffect.createOneShot(Math.max(1, duration * strength / 255), VibrationEffect.DEFAULT_AMPLITUDE));
				}
			} else {
				target.vibrate(Math.max(1, duration * strength / 255));
			}
		} catch (Exception exception) {
		}
	}

	public static void cancel() {
		Vibrator target = getVibrator();
		if (target == null) {
			return;
		}
		try {
			target.cancel();
		} catch (Exception exception) {
		}
	}
}
