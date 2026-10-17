param(
    [string]$Godot = 'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [switch]$Release
)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskSdk = Join-Path $taskRoot '.godot/android-sdk'
$taskKey = Join-Path $taskRoot '.godot/android-debug.keystore'
foreach ($taskFile in @($Godot, (Join-Path $taskSdk 'build-tools/35.0.1/apksigner.bat'), (Join-Path $taskSdk 'platforms/android-35/android.jar'), $taskKey)) {
    if (-not (Test-Path -LiteralPath $taskFile)) { throw "Missing Android build dependency: $taskFile" }
}
$env:JAVA_HOME = 'C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot'
# Steam's self-contained editor keeps its own SDK settings beside the executable.
$taskSettingsRoot = Join-Path (Split-Path -Parent $Godot) 'editor_data'
$taskSettingsFile = Get-ChildItem -LiteralPath $taskSettingsRoot -Filter 'editor_settings-4*.tres' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $taskSettingsFile) { throw 'Godot editor settings were not found' }
$taskSettings = [System.IO.File]::ReadAllText($taskSettingsFile.FullName)
foreach ($taskSetting in @{'java_sdk_path' = $env:JAVA_HOME; 'android_sdk_path' = $taskSdk}.GetEnumerator()) {
    $taskLine = 'export/android/' + $taskSetting.Key + ' = "' + $taskSetting.Value.Replace('\', '/') + '"'
    $taskPattern = '(?m)^export/android/' + $taskSetting.Key + ' = [^\r\n]*'
    if ($taskSettings -match $taskPattern) {
        $taskSettings = [regex]::Replace($taskSettings, $taskPattern, $taskLine)
    } else { $taskSettings += "`n" + $taskLine + "`n" }
}
[System.IO.File]::WriteAllText($taskSettingsFile.FullName, $taskSettings, [System.Text.UTF8Encoding]::new($false))
$env:ANDROID_HOME = $taskSdk
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $taskKey
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
# Pre-alpha release exports keep the existing local test certificate for updates.
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $taskKey
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'androiddebugkey'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = 'android'
New-Item -ItemType Directory -Force -Path (Join-Path $taskRoot 'builds') | Out-Null
$taskExportFlag = if ($Release) { '--export-release' } else { '--export-debug' }
$taskProcess = Start-Process -FilePath $Godot -WorkingDirectory $taskRoot -ArgumentList ('--headless --path . ' + $taskExportFlag + ' Android builds/StillSurve-Android.apk --log-file .godot/android-export.log') -PassThru -WindowStyle Hidden
$taskProcess.WaitForExit()
Get-Content -LiteralPath (Join-Path $taskRoot '.godot/android-export.log') -Tail 30
if ($taskProcess.ExitCode -ne 0) { throw "Godot Android export failed: $($taskProcess.ExitCode)" }
Get-Item -LiteralPath (Join-Path $taskRoot 'builds/StillSurve-Android.apk') | Select-Object FullName, Length
