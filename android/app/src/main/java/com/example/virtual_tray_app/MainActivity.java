package com.example.virtual_tray_app;

import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import android.util.Log;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String INSTALL_CHANNEL = "com.example.virtual_tray_app/install";
    private static final String INFO_CHANNEL = "com.example.virtual_tray_app/info";
    private static final String LAUNCH_CHANNEL = "com.example.virtual_tray_app/launch";
    private static final int REQUEST_UNKNOWN_APP_SOURCES = 1001;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Install or Uninstall APK
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), INSTALL_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "installApk": {
                            Log.d("VT", "INSTALL_CHANNEL: method = installApk");
                            String apkPath = call.argument("apkPath");
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                    !getPackageManager().canRequestPackageInstalls()) {
                                Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:" + getPackageName()));
                                startActivityForResult(intent, REQUEST_UNKNOWN_APP_SOURCES);
                                result.error("PERMISSION", "Request installation permission", null);
                            } else {
                                installApk(apkPath);
                                result.success(null);
                            }
                            break;
                        }

                        case "uninstallApp": {
                            Log.d("VT", "INSTALL_CHANNEL: method = uninstallApp");
                            String packageName = call.argument("packageName");
                            uninstallApp(packageName);
                            result.success(null);
                            break;
                        }

                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Extract APK metadata
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), INFO_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("getApkInfo".equals(call.method)) {
                        String apkPath = call.argument("apkPath");
                        result.success(getApkMetadata(apkPath));
                    } else {
                        result.notImplemented();
                    }
                });

        // Launch installed app
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), LAUNCH_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("launchApp".equals(call.method)) {
                        String packageName = call.argument("packageName");
                        PackageManager pm = getPackageManager();
                        Intent launchIntent = pm.getLaunchIntentForPackage(packageName);
                        if (launchIntent != null) {
                            launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(launchIntent);
                            result.success(true);
                        } else {
                            result.error("NOT_FOUND", "Cannot find app: " + packageName, null);
                        }
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private void installApk(String apkPath) {
        File apkFile = new File(apkPath);
        Uri apkUri = FileProvider.getUriForFile(
                this,
                getApplicationContext().getPackageName() + ".fileprovider",
                apkFile
        );

        Intent intent = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(apkUri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);

        startActivity(intent);
    }

    private void uninstallApp(String packageName) {
        Log.d("VT", "→ uninstallApp: " + packageName);

        try {
            Intent intent = new Intent(Intent.ACTION_DELETE);
            intent.setData(Uri.parse("package:" + packageName));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);

            if (intent.resolveActivity(getPackageManager()) != null) {
                startActivity(intent);
            } else {
                // Fallback: open app details page if uninstall doesn't work (e.g. on MIUI)
                Intent fallbackIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                fallbackIntent.setData(Uri.parse("package:" + packageName));
                fallbackIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(fallbackIntent);
            }
        } catch (Exception e) {
            Log.e("VT", "Uninstall error: " + e.getMessage());
            Intent fallbackIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            fallbackIntent.setData(Uri.parse("package:" + packageName));
            fallbackIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(fallbackIntent);
        }
    }

    private Map<String, String> getApkMetadata(String apkPath) {
        Map<String, String> info = new HashMap<>();
        try {
            PackageManager pm = getPackageManager();
            PackageInfo pkgInfo = pm.getPackageArchiveInfo(
                    apkPath,
                    PackageManager.GET_META_DATA |
                            PackageManager.GET_ACTIVITIES |
                            PackageManager.GET_SIGNATURES
            );

            if (pkgInfo != null && pkgInfo.applicationInfo != null) {
                ApplicationInfo appInfo = pkgInfo.applicationInfo;
                appInfo.sourceDir = apkPath;
                appInfo.publicSourceDir = apkPath;

                info.put("App Name", pm.getApplicationLabel(appInfo).toString());
                info.put("Package Name", pkgInfo.packageName);
                info.put("Version Name", pkgInfo.versionName);
                info.put("Version Code", String.valueOf(pkgInfo.versionCode));
                info.put("Min SDK", String.valueOf(appInfo.minSdkVersion));
                info.put("Target SDK", String.valueOf(appInfo.targetSdkVersion));
            }
        } catch (Exception e) {
            info.put("Error", e.getMessage());
        }
        return info;
    }
}
