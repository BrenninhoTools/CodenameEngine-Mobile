package org.codename.mobile;

import android.app.Activity;
import android.os.Build;
import android.view.DisplayCutout;
import android.view.View;
import android.view.WindowInsets;

import org.haxe.extension.Extension;

public class ScreenHelper {

	public static String getSafeInsets() {
		try {
			Activity activity = Extension.mainActivity;
			if (activity == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
				return "0,0,0,0";
			}
			View decor = activity.getWindow().getDecorView();
			WindowInsets insets = decor.getRootWindowInsets();
			if (insets == null) {
				return "0,0,0,0";
			}
			DisplayCutout cutout = insets.getDisplayCutout();
			if (cutout == null) {
				return "0,0,0,0";
			}
			return cutout.getSafeInsetLeft() + "," + cutout.getSafeInsetTop() + "," + cutout.getSafeInsetRight() + "," + cutout.getSafeInsetBottom();
		} catch (Exception exception) {
			return "0,0,0,0";
		}
	}
}
