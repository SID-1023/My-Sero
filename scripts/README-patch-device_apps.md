Patch for device_apps plugin

What this does
- Removes `package="fr.g123k.deviceapps"` from the plugin's AndroidManifest (if present).
- Inserts `namespace` and `compileSdk` into the plugin's `android/build.gradle` or `build.gradle.kts` if missing.
- Creates `.bak` backups beside modified files so you can revert.

How to use
1) In PowerShell (project root):
   .\scripts\patch_device_apps.ps1
2) Then run:
   flutter clean
   flutter pub get
   flutter run

Revert
- Restore the .bak files created in the plugin directory (copy *.bak over originals).

Notes
- This is a *temporary* local patch to unblock your build until the plugin is updated upstream.
- Best long-term fix: submit a small PR to the plugin that removes the `package` from AndroidManifest and adds `namespace` in the plugin `android/build.gradle`.
