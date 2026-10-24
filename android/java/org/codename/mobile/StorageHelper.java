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
import java.io.FileInputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
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

	private static final AtomicInteger batchCompleted = new AtomicInteger(0);
	private static final AtomicInteger batchTotal = new AtomicInteger(0);
	private static volatile boolean batchRunning = false;
	private static final List<String> batchFailed = Collections.synchronizedList(new ArrayList<String>());
	private static final Set<String> createdDirectories = Collections.newSetFromMap(new ConcurrentHashMap<String, Boolean>());

	public static boolean startBatchCopy(String jobs, int threads) {
		if (batchRunning || jobs == null) {
			return false;
		}

		final String[] lines = jobs.split("\n");
		batchCompleted.set(0);
		batchTotal.set(lines.length);
		batchFailed.clear();
		createdDirectories.clear();
		batchRunning = true;

		final int poolSize = Math.max(1, Math.min(threads, Runtime.getRuntime().availableProcessors()));
		new Thread(new Runnable() {
			@Override
			public void run() {
				ExecutorService pool = Executors.newFixedThreadPool(poolSize);
				for (final String line : lines) {
					pool.execute(new Runnable() {
						@Override
						public void run() {
							boolean ok = false;
							try {
								String[] parts = line.split("\t");
								if (parts.length == 3) {
									ok = parts[0].equals("A") ? copyAssetFast(parts[1], parts[2]) : copyFileFast(parts[1], parts[2]);
								}
							} catch (Exception ignored) {
							}
							if (!ok) {
								batchFailed.add(line);
							}
							batchCompleted.incrementAndGet();
						}
					});
				}
				pool.shutdown();
				try {
					pool.awaitTermination(1, TimeUnit.HOURS);
				} catch (InterruptedException ignored) {
				}
				batchRunning = false;
			}
		}).start();
		return true;
	}

	public static int getBatchCompleted() {
		return batchCompleted.get();
	}

	public static boolean isBatchRunning() {
		return batchRunning;
	}

	public static String getBatchFailed() {
		synchronized (batchFailed) {
			StringBuilder builder = new StringBuilder();
			for (String line : batchFailed) {
				if (builder.length() > 0) {
					builder.append('\n');
				}
				builder.append(line);
			}
			return builder.toString();
		}
	}

	private static boolean ensureParent(File target) {
		File parent = target.getParentFile();
		if (parent == null) {
			return true;
		}
		String key = parent.getAbsolutePath();
		if (createdDirectories.contains(key)) {
			return true;
		}
		if (parent.exists() || parent.mkdirs() || parent.exists()) {
			createdDirectories.add(key);
			return true;
		}
		return false;
	}

	private static boolean streamToFile(InputStream input, File target) {
		File temp = new File(target.getAbsolutePath() + ".tmp");
		OutputStream output = null;
		try {
			output = new java.io.BufferedOutputStream(new FileOutputStream(temp), 262144);
			byte[] buffer = new byte[262144];
			int read;
			while ((read = input.read(buffer)) != -1) {
				output.write(buffer, 0, read);
			}
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
				input.close();
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

	private static boolean copyAssetFast(String assetPath, String targetPath) {
		if (Extension.mainContext == null) {
			return false;
		}
		File target = new File(targetPath);
		if (!ensureParent(target)) {
			return false;
		}
		try {
			return streamToFile(Extension.mainContext.getAssets().open(assetPath), target);
		} catch (Exception exception) {
			return false;
		}
	}

	private static boolean copyFileFast(String sourcePath, String targetPath) {
		File target = new File(targetPath);
		if (!ensureParent(target)) {
			return false;
		}
		try {
			return streamToFile(new FileInputStream(sourcePath), target);
		} catch (Exception exception) {
			return false;
		}
	}
}
