# Set Android SDK environment variables for Flutter
# Path where you extracted the command‑line tools
$androidSdkRoot = "C:\cmdline-tools"

# Export for the current session
$env:ANDROID_SDK_ROOT = $androidSdkRoot

# Persist to user environment (so new terminals inherit it)
[System.Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $androidSdkRoot, [System.EnvironmentVariableTarget]::User)

# Build PATH entries for cmdline‑tools and platform‑tools
$cmdlineToolsBin = Join-Path $androidSdkRoot "cmdline-tools\latest\bin"
$platformTools = Join-Path $androidSdkRoot "platform-tools"

# Update the current session PATH
$env:Path = "$cmdlineToolsBin;$platformTools;$env:Path"

# Persist the updated PATH for future sessions (prepend if not already present)
$oldPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
if (-not ($oldPath -like "*$cmdlineToolsBin*$")) {
    $newPath = "$cmdlineToolsBin;$platformTools;$oldPath"
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, [System.EnvironmentVariableTarget]::User)
}

Write-Host "Android SDK environment variables configured."
