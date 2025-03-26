# Set execution policy to bypass restrictions
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

# Requires running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    exit
}

# Define the resolution-setting function using Windows API
$code = @"
using System;
using System.Runtime.InteropServices;

public class DisplaySettings2025
{
    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE
    {
        private const int CCHDEVICENAME = 32;
        private const int CCHFORMNAME = 32;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHDEVICENAME)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHFORMNAME)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
    }

    public static bool SetResolution(int width, int height, int refreshRate = 60)
    {
        DEVMODE devMode = new DEVMODE();
        devMode.dmSize = (short)Marshal.SizeOf(devMode);
        EnumDisplaySettings(null, -1, ref devMode);
        devMode.dmPelsWidth = width;
        devMode.dmPelsHeight = height;
        devMode.dmDisplayFrequency = refreshRate;
        devMode.dmFields = 0x00040000 | 0x00080000 | 0x00100000; // Width, Height, Frequency
        int result = ChangeDisplaySettings(ref devMode, 0);
        return result == 0;
    }
}
"@

# Load the type, handling if it already exists, silently
try {
    Add-Type -TypeDefinition $code -Language CSharp -ErrorAction SilentlyContinue > $null
} catch {
    if ($_.Exception.Message -notlike "*already exists*") {
        exit
    }
}

# Function to check if HDMI is connected, suppressing output
function Is-HDMIConnected {
    $monitors = Get-CimInstance -Namespace "root\WMI" -ClassName WmiMonitorConnectionParams -ErrorAction SilentlyContinue
    $activeMonitors = ($monitors | Where-Object { $_.Active }).Count
    [void]($activeMonitors -gt 1)  # Suppress the boolean output
    return $activeMonitors -gt 1
}

# Function to check if in extend mode, suppressing output
function Is-ExtendMode {
    $displays = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
    if ($displays.Count -gt 1) {
        $positions = Get-CimInstance -ClassName Win32_DesktopMonitor -ErrorAction SilentlyContinue | Select-Object ScreenWidth, ScreenHeight, DesktopMonitorID
        $videoControllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
        $result = ($videoControllers.Count -gt 1) -and ($displays[0].CurrentHorizontalResolution -ne $displays[1].CurrentHorizontalResolution -or 
                $displays[0].CurrentVerticalResolution -ne $displays[1].CurrentVerticalResolution -or 
                ($positions.Count -gt 1 -and ($positions[1].DesktopMonitorID -ne $positions[0].DesktopMonitorID)))
        [void]$result  # Suppress the boolean output
        return $result
    }
    [void]$false  # Suppress the boolean output
    return $false
}

# Function to set duplicate mode (only called on initial connect)
function Set-DuplicateMode {
    & "C:\Windows\System32\DisplaySwitch.exe" /clone *>$null
    Start-Sleep -Milliseconds 1000
}

# Main logic
$initialHDMIConnect = $false
while ($true) {
    $hdmiConnected = Is-HDMIConnected
    $isExtend = Is-ExtendMode
    $currentRes = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1 CurrentHorizontalResolution, CurrentVerticalResolution

    if ($hdmiConnected) {
        if (-not $initialHDMIConnect) {
            if ($currentRes.CurrentHorizontalResolution -ne 1920 -or $currentRes.CurrentVerticalResolution -ne 1080) {
                Set-DuplicateMode
                [DisplaySettings2025]::SetResolution(1920, 1080, 60) > $null
            }
            $initialHDMIConnect = $true
        } elseif ($isExtend) {
            if ($currentRes.CurrentHorizontalResolution -ne 1920 -or $currentRes.CurrentVerticalResolution -ne 1200) {
                [DisplaySettings2025]::SetResolution(1920, 1200, 60) > $null
            }
        } else {
            if ($currentRes.CurrentHorizontalResolution -ne 1920 -or $currentRes.CurrentVerticalResolution -ne 1080) {
                [DisplaySettings2025]::SetResolution(1920, 1080, 60) > $null
            }
        }
    } else {
        if ($currentRes.CurrentHorizontalResolution -ne 1920 -or $currentRes.CurrentVerticalResolution -ne 1200) {
            [DisplaySettings2025]::SetResolution(1920, 1200, 60) > $null
        }
        $initialHDMIConnect = $false
    }

    Start-Sleep -Seconds 5
}
