package org.codename.mobile;

import android.app.Activity;
import android.os.Build;
import android.view.DisplayCutout;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;

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

	public static void applyImmersive() {
		final Activity activity = Extension.mainActivity;
		if (activity == null) {
			return;
		}
		activity.runOnUiThread(new Runnable() {
			@Override
			public void run() {
				try {
					Window window = activity.getWindow();
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
						WindowManager.LayoutParams params = window.getAttributes();
						if (params.layoutInDisplayCutoutMode != WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES) {
							params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
							window.setAttributes(params);
						}
					}
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
						WindowInsetsController controller = window.getInsetsController();
						if (controller != null) {
							controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
							controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
						}
					} else {
						window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN
							| View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
							| View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
							| View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
							| View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
							| View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
					}
				} catch (Exception exception) {
				}
			}
		});
	}
}
