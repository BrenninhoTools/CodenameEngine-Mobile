package org.codename.mobile;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;

import java.io.File;

import org.haxe.extension.Extension;

public class StorageHelper {

	public static final int PERMISSION_REQUEST_CODE = 4810;

	public static String getExternalStorageDirectory() {
		File directory = Environment.getExternalStorageDirectory();
		return directory == null ? "" : directory.getAbsolutePath();
	}

	public static boolean hasStoragePermission() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
			return Environment.isExternalStorageManager();
		}

		Activity activity = Extension.mainActivity;
		if (activity == null) {
			return false;
		}

		return activity.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
			&& activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
	}

	public static void requestStoragePermission() {
		final Activity activity = Extension.mainActivity;
		if (activity == null || hasStoragePermission()) {
			return;
		}

		activity.runOnUiThread(new Runnable() {
			@Override
			public void run() {
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
					try {
						Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
						intent.setData(Uri.parse("package:" + activity.getPackageName()));
						activity.startActivity(intent);
					} catch (Exception exception) {
						try {
							activity.startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
						} catch (Exception ignored) {
						}
					}
				} else {
					activity.requestPermissions(new String[] {
						Manifest.permission.READ_EXTERNAL_STORAGE,
						Manifest.permission.WRITE_EXTERNAL_STORAGE
					}, PERMISSION_REQUEST_CODE);
				}
			}
		});
	}

	public static boolean createDirectory(String path) {
		File directory = new File(path);
		return directory.exists() || directory.mkdirs();
	}
}
