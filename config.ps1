# Define paths
$folderPath = "C:\Program Files\FixResolution"
$exePath = "$folderPath\resolution.exe"
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\resolution.lnk"

# Ensure the folder exists
if (!(Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath -Force
}

# Copy resolution.exe to the folder (Assuming it's in the same directory as the script)
$sourceExe = ".\resolution.exe"  # Change this path if necessary
Copy-Item -Path $sourceExe -Destination $exePath -Force

# Create a shortcut in the Startup folder
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $exePath
$Shortcut.WorkingDirectory = $folderPath
$Shortcut.Save()

# Create a scheduled task to run with admin rights at logon
$taskName = "FixResolutionTask"
$taskAction = New-ScheduledTaskAction -Execute $exePath
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn

# Get the currently logged-in user
$loggedInUser = "$env:USERNAME"
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $loggedInUser -LogonType Interactive -RunLevel Highest

$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

$task = New-ScheduledTask -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force  
