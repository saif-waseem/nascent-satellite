import 'dart:io';

void main() async {
  print('Starting comprehensive build and installation process...');

  // 1. Install Dar Landan User App
  print('\n=== Building Dar Landan User App ===');
  await buildAndInstallUserApp(
    tenantId: 'landan',
    appName: 'متجر لندن',
    appPackage: 'com.nascent.darlandan',
  );

  // 2. Install Aniqa Madinati User App
  print('\n=== Building Aniqa Madinati User App ===');
  await buildAndInstallUserApp(
    tenantId: 'anegmadenty',
    appName: 'انيقة مدينتي',
    appPackage: 'com.nascent.anegmadenty',
  );

  // 3. Install Standard Store Admin
  print('\n=== Building Standard Store Admin ===');
  await buildAndInstall(
    appPath: 'apps/store_admin',
    appName: 'لوحة الأدمن',
    appPackage: 'com.saas.ecommerce.store_admin',
  );

  // 4. Install Standard Super Admin
  print('\n=== Building Standard Super Admin ===');
  await buildAndInstall(
    appPath: 'apps/super_admin',
    appName: 'Super Admin',
    appPackage: 'com.saas.ecommerce.super_admin',
  );

  print('\nAll processes completed!');
}

Future<void> buildAndInstallUserApp({
  required String tenantId,
  required String appName,
  required String appPackage,
}) async {
  final appPath = 'apps/user_app';
  final configFile = File('$appPath/lib/core/config/app_config.dart');
  final buildGradleFile = File('$appPath/android/app/build.gradle.kts');
  final androidManifestFile = File('$appPath/android/app/src/main/AndroidManifest.xml');

  final originalConfig = await configFile.readAsString();
  final originalBuildGradle = await buildGradleFile.readAsString();
  final originalManifest = await androidManifestFile.readAsString();

  try {
    // Update config
    await configFile.writeAsString(originalConfig.replaceAll(
      RegExp(r"static const String tenantId = '.*';"),
      "static const String tenantId = '$tenantId';",
    ));

    // Update gradle
    await buildGradleFile.writeAsString(originalBuildGradle.replaceAll(
      RegExp(r'applicationId\s*=\s*".*"'),
      'applicationId = "$appPackage"',
    ));

    // Update manifest label
    await androidManifestFile.writeAsString(originalManifest.replaceAll(
      RegExp(r'android:label="[^"]*"'),
      'android:label="$appName"',
    ));

    print('Building APK for $appPackage...');
    await runCommand('flutter', ['clean'], appPath);
    await runCommand('flutter', ['pub', 'get'], appPath);
    await runCommand('flutter', ['build', 'apk', '--debug'], appPath);

    print('Installing APK...');
    final apkFile = File('$appPath/build/app/outputs/flutter-apk/app-debug.apk');
    if (apkFile.existsSync()) {
      await runCommand('adb', ['install', '-r', apkFile.path], '.');
    }
  } finally {
    print('Restoring User App files...');
    await configFile.writeAsString(originalConfig);
    await buildGradleFile.writeAsString(originalBuildGradle);
    await androidManifestFile.writeAsString(originalManifest);
  }
}

Future<void> buildAndInstall({
  required String appPath,
  required String appName,
  required String appPackage,
}) async {
  final buildGradleFile = File('$appPath/android/app/build.gradle.kts');
  final androidManifestFile = File('$appPath/android/app/src/main/AndroidManifest.xml');

  final originalBuildGradle = await buildGradleFile.readAsString();
  final originalManifest = await androidManifestFile.readAsString();

  try {
    await buildGradleFile.writeAsString(originalBuildGradle.replaceAll(
      RegExp(r'applicationId\s*=\s*".*"'),
      'applicationId = "$appPackage"',
    ));

    await androidManifestFile.writeAsString(originalManifest.replaceAll(
      RegExp(r'android:label="[^"]*"'),
      'android:label="$appName"',
    ));

    print('Building APK for $appPackage...');
    await runCommand('flutter', ['clean'], appPath);
    await runCommand('flutter', ['pub', 'get'], appPath);
    await runCommand('flutter', ['build', 'apk', '--debug'], appPath);

    print('Installing APK...');
    final apkFile = File('$appPath/build/app/outputs/flutter-apk/app-debug.apk');
    if (apkFile.existsSync()) {
      await runCommand('adb', ['install', '-r', apkFile.path], '.');
    }
  } finally {
    print('Restoring $appPath files...');
    await buildGradleFile.writeAsString(originalBuildGradle);
    await androidManifestFile.writeAsString(originalManifest);
  }
}

Future<void> runCommand(String cmd, List<String> args, String cwd) async {
  final result = await Process.run(cmd, args, workingDirectory: cwd, runInShell: true);
  if (result.exitCode != 0) {
    print('Error running $cmd ${args.join(' ')}: ${result.stderr}');
  } else {
    print(result.stdout);
  }
}
