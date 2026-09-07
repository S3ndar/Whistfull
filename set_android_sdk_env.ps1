# PowerShell script to set Android SDK environment variables for Flutter
# ---------------------------------------------------------------
# Path where the Android SDK lives (contains platform-tools, build-tools, cmdline-tools)
$androidSdkRoot = "C:\Users\sande\AppData\Local\Android\sdk"

# Set environment variables for current session
$env:ANDROID_HOME = $androidSdkRoot
$env:ANDROID_SDK_ROOT = $androidSdkRoot

# Persist user‑level environment variables
[System.Environment]::SetEnvironmentVariable('ANDROID_HOME', $androidSdkRoot, [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $androidSdkRoot, [System.EnvironmentVariableTarget]::User)

# Add cmdline‑tools and platform‑tools to PATH
# 1) cmdline‑tools that you extracted at C:\cmdline-tools (standard layout)
$cmdlineToolsBin = "C:\cmdline-tools\latest\bin"
# 2) cmdline‑tools inside the SDK (if present) – will be added only if the folder exists
$sdkCmdlineTools = Join-Path $androidSdkRoot "cmdline-tools\latest\bin"
$platformTools   = Join-Path $androidSdkRoot "platform-tools"

# Build a list of paths to prepend (avoid duplicates)
$pathsToAdd = @()
if (Test-Path $cmdlineToolsBin) { $pathsToAdd += $cmdlineToolsBin }
if (Test-Path $sdkCmdlineTools) { $pathsToAdd += $sdkCmdlineTools }
if (Test-Path $platformTools)   { $pathsToAdd += $platformTools }

# Update the current session PATH
$env:Path = ($pathsToAdd -join ";") + ";" + $env:Path

# Persist the updated PATH for future sessions (prepend if not already present)
$oldPath = [System.Environment]::GetEnvironmentVariable('Path',[System.EnvironmentVariableTarget]::User)
foreach ($p in $pathsToAdd) {
    if (-not ($oldPath -like "*$p*") ) {
        $oldPath = "$p;$oldPath"
    }
}
[System.Environment]::SetEnvironmentVariable('Path',$oldPath,[System.EnvironmentVariableTarget]::User)

Write-Host "✅ Android SDK environment variables configured."
