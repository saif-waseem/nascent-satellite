---
name: msix-packer
description: Automates the MSIX installer build for the Flutter Windows app pos_app.
---

# MSIX Packer Skill

This skill automates the process of building a modern MSIX installer for the `pos_app` Flutter Windows application. It ensures all necessary dependencies, assets, and DLLs (including Firebase and Visual C++ Runtimes) are bundled correctly.

## Prerequisites
- Flutter SDK installed and in PATH.
- Windows development environment set up.
- Visual C++ 2015-2022 Redistributables installed on the build machine.

## Steps

1.  **Check Dependencies**:
    Ensure `msix` is in `dev_dependencies` in `pubspec.yaml`.
    // turbo
    `flutter pub add --dev msix`

2.  **Configuration**:
    The configuration is already set in `pubspec.yaml` under `msix_config`. Verify it matches your requirements.

3.  **Build Application**:
    Build the Windows app in release mode.
    // turbo
    `flutter build windows --release`

4.  **Collect System DLLs**:
    Copy the required Visual C++ Runtimes to the Release folder for bundling.
    // turbo
    `copy C:\Windows\System32\msvcp140.dll build\windows\x64\runner\Release\`
    // turbo
    `copy C:\Windows\System32\msvcp140_1.dll build\windows\x64\runner\Release\`
    // turbo
    `copy C:\Windows\System32\msvcp140_2.dll build\windows\x64\runner\Release\`
    // turbo
    `copy C:\Windows\System32\vcruntime140.dll build\windows\x64\runner\Release\`
    // turbo
    `copy C:\Windows\System32\vcruntime140_1.dll build\windows\x64\runner\Release\`

5.  **Create MSIX**:
    Generate the MSIX package. Respond 'N' to certificate installation if prompted (for local builds).
    // turbo
    `dart run msix:create`

6.  **Verify**:
    The generated MSIX file will be located at:
    `build\windows\x64\runner\Release\pos_app.msix`
