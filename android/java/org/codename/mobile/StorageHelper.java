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
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

import org.haxe.extension.Extension;

public class StorageHelper {

	public static final int PERMISSION_REQUEST_CODE = 4810;

	public static String getExternalStorageDirectory() {
		File directory = Environment.getExternalStorageDirectory();
		return directory == null ? "" : directory.getAbsolutePath();
	}

	public static String getExternalMediaDirectory() {
		if (Extension.mainContext == null) {
			return "";
		}

		File[] directories = Extension.mainContext.getExternalMediaDirs();
		if (directories != null) {
			for (File directory : directories) {
				if (directory != null) {
					if (!directory.exists()) {
						directory.mkdirs();
					}
					return directory.getAbsolutePath();
				}
			}
		}
		return "";
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

	public static boolean copyAsset(String assetPath, String targetPath) {
		if (Extension.mainContext == null || assetPath == null || targetPath == null) {
			return false;
		}

		File target = new File(targetPath);
		File parent = target.getParentFile();
		if (parent != null && !parent.exists() && !parent.mkdirs()) {
			return false;
		}

		File temp = new File(targetPath + ".tmp");
		InputStream input = null;
		OutputStream output = null;
		try {
			input = Extension.mainContext.getAssets().open(assetPath);
			output = new FileOutputStream(temp);
			byte[] buffer = new byte[65536];
			int read;
			while ((read = input.read(buffer)) != -1) {
				output.write(buffer, 0, read);
			}
			output.flush();
			output.close();
			output = null;
			if (target.exists() && !target.delete()) {
				temp.delete();
				return false;
			}
			return temp.renameTo(target);
		} catch (Exception exception) {
			temp.delete();
			return false;
		} finally {
			try {
				if (input != null) {
					input.close();
				}
			} catch (Exception ignored) {
			}
			try {
				if (output != null) {
					output.close();
				}
			} catch (Exception ignored) {
			}
		}
	}

	public static double getFreeSpace(String path) {
		try {
			File file = new File(path);
			while (file != null && !file.exists()) {
				file = file.getParentFile();
			}
			return file == null ? -1 : (double) file.getUsableSpace();
		} catch (Exception exception) {
			return -1;
		}
	}
}
