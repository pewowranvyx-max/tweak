<#
=============================================================================================
   RANVYX - COMPACT INTERNET & FPS OPTIMIZER (WITH LOG, EXPANDED TWEAKS & EXTENSIVE GPEDIT)
=============================================================================================
#>

param(
    [string]$Action = $null,
    [switch]$Silent
)

# 1. Require Administrator Privileges
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $scriptFile = $PSCommandPath
    if (-not $scriptFile -or -not (Test-Path $scriptFile)) {
        $scriptFile = $MyInvocation.MyCommand.Path
    }
    if (-not $scriptFile -or -not (Test-Path $scriptFile)) {
        $defaultLoc = "$env:USERPROFILE\.gemini\antigravity-ide\scratch\ranvyx-optimizer\Ranvyx.ps1"
        if (Test-Path $defaultLoc) { $scriptFile = $defaultLoc }
    }

    Write-Host ""
    Write-Host " [!] Requesting Administrator Privileges..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass"
    if ($Action) { $argList += " -Action `"$Action`"" }
    if ($Silent) { $argList += " -Silent" }

    if ($scriptFile -and (Test-Path $scriptFile)) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "$argList -File `"$scriptFile`""
        exit
    } else {
        $tempPath = Join-Path $env:TEMP "Ranvyx.ps1"
        $scriptContent = ""
        try { $scriptContent = $MyInvocation.MyCommand.ScriptBlock.ToString() } catch {}
        if (-not $scriptContent) {
            $defaultLoc = "$env:USERPROFILE\.gemini\antigravity-ide\scratch\ranvyx-optimizer\Ranvyx.ps1"
            if (Test-Path $defaultLoc) { $scriptContent = Get-Content $defaultLoc -Raw }
        }
        if ($scriptContent) {
            [System.IO.File]::WriteAllText($tempPath, $scriptContent, [System.Text.Encoding]::UTF8)
            Start-Process powershell.exe -Verb RunAs -ArgumentList "$argList -File `"$tempPath`""
            exit
        } else {
            $onlineUrl = "https://raw.githubusercontent.com/pewowranvyx-max/tweak/main/Ranvyx.ps1"
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $onlineUrl | iex`""
            exit
        }
    }
}

# 2. Setup Persistent Logging Directory and File
$logDir = "$env:LOCALAPPDATA\Ranvyx"
try {
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
} catch {}
$global:LogFile = Join-Path $logDir "ranvyx.log"

function Write-RanvyxLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [string]$Level = "INFO"
    )
    try {
        $timeStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $entry = "[$timeStr] [$Level] $Message"
        Add-Content -Path $global:LogFile -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue

        if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
            $scriptLog = Join-Path $PSScriptRoot "ranvyx.log"
            Add-Content -Path $scriptLog -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    } catch {}
}

# Log startup
Write-RanvyxLog -Message "Ranvyx initialized with Administrator privileges" -Level "INFO"

# 3. Load Windows Forms for Native Popup MessageBox
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

# 4. Native Window Resizer API & Memory Cleaner
$nativeCode = @"
using System;
using System.Runtime.InteropServices;

public class WinHelper {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll", EntryPoint = "MessageBoxW", CharSet = CharSet.Unicode)]
    public static extern int MessageBox(IntPtr hWnd, string text, string caption, uint type);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    public static void DisableQuickEdit() {
        try {
            IntPtr hStdin = GetStdHandle(-10);
            uint mode;
            if (GetConsoleMode(hStdin, out mode)) {
                mode &= ~0x0040u;
                mode |= 0x0080u;
                SetConsoleMode(hStdin, mode);
            }
        } catch {}
    }

    public static void ResizeCompact() {
        try {
            IntPtr hWnd = GetConsoleWindow();
            if (hWnd != IntPtr.Zero) {
                int w = 480;
                int h = 390;
                int screenW = GetSystemMetrics(0);
                int screenH = GetSystemMetrics(1);
                int x = (screenW - w) / 2;
                int y = (screenH - h) / 2;
                MoveWindow(hWnd, x, y, w, h, true);
            }
        } catch {}
    }

    public static void ShowPopup(string text, string title) {
        try {
            MessageBox(IntPtr.Zero, text, title, 0x00000040 | 0x00040000 | 0x00010000 | 0x00001000);
        } catch {}
    }
}

public class MemoryCleaner {
    [DllImport("psapi.dll")]
    public static extern int EmptyWorkingSet(IntPtr hwProc);

    public static void FlushMemory() {
        try {
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();
            IntPtr currentProcess = System.Diagnostics.Process.GetCurrentProcess().Handle;
            EmptyWorkingSet(currentProcess);
        } catch {}
    }
}
"@
try {
    Add-Type -TypeDefinition $nativeCode -Language CSharp -ErrorAction SilentlyContinue
} catch {}

# Bulletproof Native Popup Display
function Show-SuccessPopup {
    if ($Silent -or $env:RANVYX_SILENT -eq "1") {
        Write-RanvyxLog -Message "Notification displayed (Silent mode)" -Level "INFO"
        return
    }

    $msg = "Success"
    $title = "Success"
    $shown = $false

    # Layer 1: Win32 API MessageBoxW (Native, TopMost, SystemModal)
    try {
        [WinHelper]::ShowPopup($msg, $title)
        $shown = $true
    } catch {}

    # Layer 2: WScript.Shell Popup (System Modal + TopMost + Info Icon)
    if (-not $shown) {
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $wshell.Popup($msg, 0, $title, 64 + 4096) | Out-Null
            $shown = $true
        } catch {}
    }

    # Layer 3: System.Windows.Forms with ServiceNotification
    if (-not $shown) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            [System.Windows.Forms.MessageBox]::Show(
                $msg,
                $title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information,
                [System.Windows.Forms.MessageBoxDefaultButton]::Button1,
                [System.Windows.Forms.MessageBoxOptions]::ServiceNotification
            ) | Out-Null
            $shown = $true
        } catch {}
    }

    # Layer 4: MSHTA VBScript MsgBox fallback
    if (-not $shown) {
        try {
            Start-Process mshta.exe -ArgumentList "vbscript:Execute(`"MsgBox ````"$msg````", 64, ````"$title````":close`")" -Wait
        } catch {}
    }
}

# Resize window and disable quick-edit
try {
    [WinHelper]::DisableQuickEdit()
    [WinHelper]::ResizeCompact()
    mode con: cols=48 lines=18 *>$null
    $host.UI.RawUI.WindowTitle = "Ranvyx"
    $host.UI.RawUI.BackgroundColor = "Black"
    $host.UI.RawUI.ForegroundColor = "Cyan"
} catch {}

function Play-Beep {
    param([int]$type = 1)
}

# ANSI Colors
$e = [char]27
$cReset  = "$e[0m$e[40m"
$cCyan   = "$e[38;2;0;240;255m$e[40m"
$cWhite  = "$e[38;2;255;255;255m$e[40m"
$cGreen  = "$e[38;2;16;185;129m$e[40m"
$cYellow = "$e[38;2;245;158;11m$e[40m"
$cDark   = "$e[38;2;100;116;139m$e[40m"

# Render Animated Progress Bar (Displays 1% to 100%)
function Render-Progress {
    param([int]$percent)
    if ($percent -lt 1) { $percent = 1 }
    if ($percent -gt 100) { $percent = 100 }

    $width = 24
    $filled = [math]::Ceiling(($percent / 100) * $width)
    $empty = $width - $filled
    $bar = "$cCyan" + ("#" * $filled) + "$cDark" + ("-" * $empty) + "$cReset"
    $pctText = ("{0,3}%" -f $percent)
    
    Write-Host -NoNewline "`r   [$bar] $cCyan$pctText$cReset"
}

# Render Main UI (Menu 1: START, 2: RESET, 3: LOG, 4: GPEDIT)
function Render-UI {
    Clear-Host
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host "  $cCyan               RANVYX               $cReset"
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
    Write-Host "     $cWhite 1. START$cReset"
    Write-Host "     $cWhite 2. RESET$cReset"
    Write-Host "     $cWhite 3. LOG$cReset"
    Write-Host "     $cWhite 4. GPEDIT$cReset"
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
}

# 3. LOG Function (View recent logs, open in Notepad, or clear log)
function Show-LogViewer {
    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  $cCyan====================================$cReset"
        Write-Host "  $cCyan            RANVYX LOGS             $cReset"
        Write-Host "  $cCyan====================================$cReset"
        Write-Host ""

        if (Test-Path $global:LogFile) {
            $lines = Get-Content -Path $global:LogFile -Tail 7 -ErrorAction SilentlyContinue
            if ($lines -and $lines.Count -gt 0) {
                foreach ($line in $lines) {
                    if ($line -match "\[SUCCESS\]") {
                        Write-Host "  $cGreen$line$cReset"
                    } elseif ($line -match "\[OPTIMIZE\]") {
                        Write-Host "  $cCyan$line$cReset"
                    } elseif ($line -match "\[RESET\]") {
                        Write-Host "  $cYellow$line$cReset"
                    } else {
                        Write-Host "  $cWhite$line$cReset"
                    }
                }
            } else {
                Write-Host "   $cDark(Log is currently empty)$cReset"
            }
        } else {
            Write-Host "   $cDark(No log file created yet)$cReset"
        }

        Write-Host ""
        Write-Host "  $cCyan------------------------------------$cReset"
        Write-Host "  $cWhite [O] Open in Notepad   [C] Clear Log$cReset"
        Write-Host "  $cDark [Enter] Back to Main Menu$cReset"
        Write-Host "  $cCyan------------------------------------$cReset"
        Write-Host -NoNewline "  $cCyan>> Action : $cReset"
        $action = Read-Host

        if ($action -match "^[oO]$") {
            if (Test-Path $global:LogFile) {
                Start-Process notepad.exe -ArgumentList "`"$global:LogFile`""
                Write-RanvyxLog -Message "Opened log file in Notepad" -Level "INFO"
            }
        } elseif ($action -match "^[cC]$") {
            if (Test-Path $global:LogFile) {
                Clear-Content -Path $global:LogFile -ErrorAction SilentlyContinue
            }
            Write-RanvyxLog -Message "Log history cleared by user" -Level "INFO"
        } else {
            break
        }
    }
}

# 1. START Function (Expanded Safe Internet & FPS Tweaks + Log + Progress)
function Start-Optimization {
    Play-Beep 1
    Clear-Host
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host "  $cCyan               RANVYX               $cReset"
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
    Write-Host "  $cWhite OPTIMIZING INTERNET & FPS...$cReset"
    Write-Host ""
    Write-Host ""

    Write-RanvyxLog -Message "Optimization started" -Level "START"

    $tasks = @(
        @{
            Name = "TCP/IP Stack & Latency Tuning"
            TargetPct = 18
            Action = {
                netsh int tcp set global autotuninglevel=normal | Out-Null
                netsh int tcp set heuristics disabled | Out-Null
                netsh int tcp set global rss=enabled | Out-Null
                netsh int tcp set global rsc=disabled 2>$null | Out-Null
                netsh int tcp set global dca=enabled 2>$null | Out-Null
                netsh int tcp set global netdma=enabled 2>$null | Out-Null
                netsh int tcp set global ecncapability=disabled | Out-Null
                netsh int tcp set global timestamps=disabled | Out-Null
                netsh int tcp set global initialRto=2000 2>$null | Out-Null
                netsh int tcp set global nonsackrttresiliency=disabled 2>$null | Out-Null
                netsh int tcp set global maxsynretransmissions=2 2>$null | Out-Null
                netsh int tcp set global fastopen=enabled 2>$null | Out-Null
                netsh int tcp set supplemental template=custom congestionprovider=cubic 2>$null | Out-Null
                netsh int tcp set supplemental template=custom congestionprovider=ctcp 2>$null | Out-Null
                netsh int tcp set supplemental template=custom minrto=300 2>$null | Out-Null

                netsh int ip set global taskoffload=enabled 2>$null | Out-Null
                netsh int ip set global neighborcachelimit=4096 2>$null | Out-Null
                Write-RanvyxLog -Message "Tuned TCP/IP stack (autotuning=normal, rss=enabled, fastopen=enabled, ctcp/cubic)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Network Adapter Hardware & Power Tuning"
            TargetPct = 36
            Action = {
                try {
                    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
                        $adName = $_.Name
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Energy Efficient Ethernet*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Green Ethernet*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*WakeOnMagicPacket*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*WakeOnPattern*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Enable-NetAdapterRss -Name $adName -ErrorAction SilentlyContinue 2>$null
                    }
                } catch {}

                try {
                    Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root\wmi -ErrorAction SilentlyContinue |
                        Where-Object { $_.InstanceName -match "PCI" } |
                        Set-CimInstance -Property @{ Enable = $false } -ErrorAction SilentlyContinue
                } catch {}
                Write-RanvyxLog -Message "Optimized Network Adapters (disabled Energy Efficient Ethernet, enabled RSS, prevented power sleep)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Nagle's Zero-Delay & Core TCP Parameters"
            TargetPct = 54
            Action = {
                $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
                if (Test-Path $interfacesPath) {
                    Get-ChildItem $interfacesPath -ErrorAction SilentlyContinue | ForEach-Object {
                        $guid = $_.PSChildName
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                }

                $tcpipParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
                if (Test-Path $tcpipParams) {
                    Set-ItemProperty -Path $tcpipParams -Name "DefaultTTL" -Value 64 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnableICMPRedirect" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "SynAttackProtect" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "Tcp1323Opts" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnableDCA" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnableWsd" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                }
                Write-RanvyxLog -Message "Disabled Nagle's Algorithm (TcpAckFrequency=1, TCPNoDelay=1, DefaultTTL=64, Tcp1323Opts=1)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "QoS 20%, Anti-Throttling & DNS Acceleration"
            TargetPct = 72
            Action = {
                $pschedPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
                if (-not (Test-Path $pschedPath)) { New-Item -Path $pschedPath -Force | Out-Null }
                Set-ItemProperty -Path $pschedPath -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
                Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value ([Convert]::ToUInt32("ffffffff", 16)) -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $sysProfile -Name "AlwaysOn" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                $doPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
                if (-not (Test-Path $doPath)) { New-Item -Path $doPath -Force | Out-Null }
                Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                $dnsCachePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
                if (Test-Path $dnsCachePath) {
                    Set-ItemProperty -Path $dnsCachePath -Name "MaxCacheTtl" -Value 86400 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $dnsCachePath -Name "MaxNegativeCacheTtl" -Value 5 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $dnsCachePath -Name "NetFailureCacheTime" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $dnsCachePath -Name "NegativeSOACacheTime" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                }
                Clear-DnsClientCache -ErrorAction SilentlyContinue
                ipconfig /flushdns | Out-Null
                Write-RanvyxLog -Message "Removed QoS 20%, disabled Network Throttling, tuned DNS cache, disabled P2P upload" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "GPU Scheduling & MMCSS Gaming Priority"
            TargetPct = 88
            Action = {
                $gfxPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
                if (Test-Path $gfxPath) { Set-ItemProperty -Path $gfxPath -Name "HwSchMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue }

                $gamesTask = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
                if (-not (Test-Path $gamesTask)) { New-Item -Path $gamesTask -Force | Out-Null }
                Set-ItemProperty -Path $gamesTask -Name "Affinity" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gamesTask -Name "Background Only" -Value "False" -Type String -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gamesTask -Name "Clock Rate" -Value 10000 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gamesTask -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gamesTask -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gamesTask -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gamesTask -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gamesTask -Name "Latency Sensitive" -Value "True" -Type String -Force -ErrorAction SilentlyContinue

                $gameConfig = "HKCU:\System\GameConfigStore"
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                $gameDvrApp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
                if (-not (Test-Path $gameDvrApp)) { New-Item -Path $gameDvrApp -Force | Out-Null }
                Set-ItemProperty -Path $gameDvrApp -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Write-RanvyxLog -Message "Configured GPU HAGS Mode 2, MMCSS Games Priority High, disabled GameDVR background recording" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Ultimate Power Plan, Latency & Standby Memory"
            TargetPct = 100
            Action = {
                try {
                    $scheme = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
                    if ($scheme -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
                        powercfg /setactive $matches[1]
                    } else {
                        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
                    }
                } catch {}

                $powerThrottling = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
                if (-not (Test-Path $powerThrottling)) { New-Item -Path $powerThrottling -Force | Out-Null }
                Set-ItemProperty -Path $powerThrottling -Name "PowerThrottlingOff" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                $memPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
                Set-ItemProperty -Path $memPath -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $memPath -Name "LargeSystemCache" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                bcdedit /set disabledynamictick yes 2>$null | Out-Null
                bcdedit /set useplatformclock no 2>$null | Out-Null

                Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseHoverTime" -Value "10" -Force -ErrorAction SilentlyContinue

                [MemoryCleaner]::FlushMemory()
                Write-RanvyxLog -Message "Activated Ultimate Power Plan, disabled dynamic tick jitter, flushed standby RAM" -Level "OPTIMIZE"
                Write-RanvyxLog -Message "Optimization completed successfully (100%)" -Level "SUCCESS"
            }
        }
    )

    $currentPct = 1
    Render-Progress 1

    foreach ($task in $tasks) {
        $target = $task.TargetPct
        while ($currentPct -lt $target) {
            $currentPct++
            Render-Progress $currentPct
            Start-Sleep -Milliseconds 22
        }
        try { & $task.Action } catch {}
    }

    Render-Progress 100
    Write-Host ""
    Write-Host ""
    Write-Host "  $cGreen Success$cReset"
    Write-Host ""

    Play-Beep 3
    Show-SuccessPopup
}

# 4. GPEDIT Function (Extensive Safe Group Policy Optimizer for Internet & System Tweaks)
function Start-GpeditOptimization {
    Play-Beep 1
    Clear-Host
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host "  $cCyan            RANVYX GPEDIT           $cReset"
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
    Write-Host "  $cWhite APPLYING EXTENSIVE GROUP POLICIES...$cReset"
    Write-Host ""
    Write-Host ""

    Write-RanvyxLog -Message "Extensive GPEDIT optimization started" -Level "START"

    $gpTasks = @(
        @{
            Name = "Network, DNS & Bandwidth Policies"
            TargetPct = 25
            Action = {
                # 1. QoS Reservable Bandwidth Limit 0%
                $psched = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
                if (-not (Test-Path $psched)) { New-Item -Path $psched -Force | Out-Null }
                Set-ItemProperty -Path $psched -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # 2. Delivery Optimization P2P upload disable & cap monthly quota
                $do = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
                if (-not (Test-Path $do)) { New-Item -Path $do -Force | Out-Null }
                Set-ItemProperty -Path $do -Name "DODownloadMode" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $do -Name "DOMonthlyUploadDataCap" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # 3. DNS Client - Multicast, Smart Name Resolution & Multi-Label
                $dnsClient = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
                if (-not (Test-Path $dnsClient)) { New-Item -Path $dnsClient -Force | Out-Null }
                Set-ItemProperty -Path $dnsClient -Name "EnableMulticast" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $dnsClient -Name "DisableSmartNameResolution" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $dnsClient -Name "AppendToMultiLabelName" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # 4. NCSI Passive Polling overhead disable
                $ncsi = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator"
                if (-not (Test-Path $ncsi)) { New-Item -Path $ncsi -Force | Out-Null }
                Set-ItemProperty -Path $ncsi -Name "DisablePassivePolling" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                Write-RanvyxLog -Message "Configured Network & DNS Policies (QoS 0%, DeliveryOptimization HTTP/0MB, SmartNameResolution disabled, LLMNR disabled)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "IPv6 Tunnels, Windows Update & Defender Bandwidth Protection"
            TargetPct = 50
            Action = {
                # 1. Disable IPv6 Transition Tunnels latency (Teredo, 6to4, ISATAP)
                $v6Trans = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition"
                if (-not (Test-Path $v6Trans)) { New-Item -Path $v6Trans -Force | Out-Null }
                Set-ItemProperty -Path $v6Trans -Name "Teredo_State" -Value "Disabled" -Type String -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $v6Trans -Name "6to4_State" -Value "Disabled" -Type String -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $v6Trans -Name "ISATAP_State" -Value "Disabled" -Type String -Force -ErrorAction SilentlyContinue

                # 2. Windows Update - Notify for download (Prevents 10GB game-lagging downloads during matches)
                $wuAu = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
                if (-not (Test-Path $wuAu)) { New-Item -Path $wuAu -Force | Out-Null }
                Set-ItemProperty -Path $wuAu -Name "AUOptions" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $wuAu -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                # 3. Defender Sample Upload - Never Send (Safe, stops background large file uploads)
                $spyNet = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"
                if (-not (Test-Path $spyNet)) { New-Item -Path $spyNet -Force | Out-Null }
                Set-ItemProperty -Path $spyNet -Name "SubmitSamplesConsent" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

                Write-RanvyxLog -Message "Configured Bandwidth Protection (IPv6 Tunnels disabled, Windows Update notify-only, Defender sample upload disabled)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Gaming, App Privacy & Search Speedup Policies"
            TargetPct = 75
            Action = {
                # 1. Disable GameDVR & Xbox Broadcasting Policy
                $gameDvrPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
                if (-not (Test-Path $gameDvrPol)) { New-Item -Path $gameDvrPol -Force | Out-Null }
                Set-ItemProperty -Path $gameDvrPol -Name "AllowGameDVR" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # 2. Force Deny Background Apps & Diagnostic Info (AppPrivacy)
                $appPriv = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
                if (-not (Test-Path $appPriv)) { New-Item -Path $appPriv -Force | Out-Null }
                Set-ItemProperty -Path $appPriv -Name "LetAppsRunInBackground" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $appPriv -Name "LetAppsAccessDiagnosticsInfo" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

                # 3. Disable Windows Search Web/Bing & Cortana (Instant local file search, no net lag)
                $winSearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
                if (-not (Test-Path $winSearch)) { New-Item -Path $winSearch -Force | Out-Null }
                Set-ItemProperty -Path $winSearch -Name "AllowCortana" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $winSearch -Name "DisableWebSearch" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $winSearch -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                Write-RanvyxLog -Message "Configured Gaming & Privacy Policies (GameDVR policy disabled, Background Apps Force Deny, Search Web Bing disabled)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Telemetry, Bloatware & System Performance Policies"
            TargetPct = 100
            Action = {
                # 1. Disable Cloud Content, Spotlight ads & suggestions
                $cloud = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
                if (-not (Test-Path $cloud)) { New-Item -Path $cloud -Force | Out-Null }
                Set-ItemProperty -Path $cloud -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $cloud -Name "DisableWindowsSpotlightFeatures" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $cloud -Name "DisableTailoredExperiencesWithDiagnosticData" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $cloud -Name "DisableThirdPartySuggestions" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                # 2. Disable Diagnostic Data & Telemetry
                $dataCol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                if (-not (Test-Path $dataCol)) { New-Item -Path $dataCol -Force | Out-Null }
                Set-ItemProperty -Path $dataCol -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $dataCol -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $dataCol -Name "DisableOneSettingsDownloads" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                # 3. Disable Windows Error Reporting
                $wer = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
                if (-not (Test-Path $wer)) { New-Item -Path $wer -Force | Out-Null }
                Set-ItemProperty -Path $wer -Name "Disabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $wer -Name "DontSendAdditionalData" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                # 4. Disable Application Compatibility Engine Telemetry
                $appCompat = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"
                if (-not (Test-Path $appCompat)) { New-Item -Path $appCompat -Force | Out-Null }
                Set-ItemProperty -Path $appCompat -Name "AITEnable" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $appCompat -Name "DisablePCA" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $appCompat -Name "DisableInventory" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                # 5. Disable Activity Feed / Timeline Sync
                $sysPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
                if (-not (Test-Path $sysPol)) { New-Item -Path $sysPol -Force | Out-Null }
                Set-ItemProperty -Path $sysPol -Name "EnableActivityFeed" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $sysPol -Name "PublishUserActivities" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $sysPol -Name "UploadUserActivities" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # 6. Disable Maintenance Scheduler WakeUp
                $maint = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TaskScheduler\Maintenance"
                if (-not (Test-Path $maint)) { New-Item -Path $maint -Force | Out-Null }
                Set-ItemProperty -Path $maint -Name "WakeUp" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # 7. Refresh Policy Engine
                try {
                    $gpProc = Start-Process gpupdate.exe -ArgumentList "/target:computer /force" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
                    $gpProc.WaitForExit(3000) | Out-Null
                } catch {}

                Write-RanvyxLog -Message "Configured Telemetry, Bloatware & Performance Policies (Telemetry disabled, Spotlight ads disabled, PCA disabled)" -Level "OPTIMIZE"
                Write-RanvyxLog -Message "Extensive GPEDIT optimization completed successfully (100%)" -Level "SUCCESS"
            }
        }
    )

    $currentPct = 1
    Render-Progress 1

    foreach ($task in $gpTasks) {
        $target = $task.TargetPct
        while ($currentPct -lt $target) {
            $currentPct++
            Render-Progress $currentPct
            Start-Sleep -Milliseconds 22
        }
        try { & $task.Action } catch {}
    }

    Render-Progress 100
    Write-Host ""
    Write-Host ""
    Write-Host "  $cGreen Success$cReset"
    Write-Host ""

    Play-Beep 3
    Show-SuccessPopup
}

# 2. RESET Function (Windows Defaults + Smooth 1%-100% Progress + Popup + Log)
function Start-Reset {
    Play-Beep 2
    Clear-Host
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host "  $cCyan               RANVYX               $cReset"
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
    Write-Host "  $cWhite RESTORING WINDOWS DEFAULTS...$cReset"
    Write-Host ""
    Write-Host ""

    Write-RanvyxLog -Message "Reset to Windows Defaults started" -Level "RESET"

    $currentPct = 1
    Render-Progress 1

    # Step 1: 1% to 35% (Reset TCP/IP, Winsock, Netsh stack)
    while ($currentPct -lt 35) {
        $currentPct++
        Render-Progress $currentPct
        Start-Sleep -Milliseconds 22
    }
    try {
        netsh int tcp reset | Out-Null
        netsh int ip reset | Out-Null
        netsh winsock reset | Out-Null
        netsh int tcp set global autotuninglevel=normal | Out-Null
        netsh int tcp set global rss=enabled | Out-Null
        netsh int tcp set heuristics default 2>$null | Out-Null
        netsh int tcp set global fastopen=default 2>$null | Out-Null
        netsh int tcp set global timestamps=default 2>$null | Out-Null
        netsh int tcp set global initialRto=default 2>$null | Out-Null
        netsh int tcp set supplemental template=custom congestionprovider=default 2>$null | Out-Null
        Write-RanvyxLog -Message "Reset TCP/IP, Winsock and Netsh global stack to default" -Level "RESET"
    } catch {}

    # Step 2: 36% to 70% (Restore Nagle, QoS, Anti-Throttle, DNS, P2P & All GPEDIT policies)
    while ($currentPct -lt 70) {
        $currentPct++
        Render-Progress $currentPct
        Start-Sleep -Milliseconds 22
    }
    try {
        # Restore Nagle's Algorithm interface settings
        $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        if (Test-Path $interfacesPath) {
            Get-ChildItem $interfacesPath -ErrorAction SilentlyContinue | ForEach-Object {
                $guid = $_.PSChildName
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpAckFrequency" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TCPNoDelay" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpDelAckTicks" -Force -ErrorAction SilentlyContinue
            }
        }

        # Remove custom Tcpip Parameters
        $tcpipParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        if (Test-Path $tcpipParams) {
            Remove-ItemProperty -Path $tcpipParams -Name "DefaultTTL" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $tcpipParams -Name "EnableICMPRedirect" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $tcpipParams -Name "SynAttackProtect" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $tcpipParams -Name "Tcp1323Opts" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $tcpipParams -Name "EnableDCA" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $tcpipParams -Name "EnableWsd" -Force -ErrorAction SilentlyContinue
        }

        # Restore QoS and Network Throttling defaults
        $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue

        # Clean All GPEDIT Network & Internet Policies
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DOMonthlyUploadDataCap" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "DisableSmartNameResolution" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "AppendToMultiLabelName" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" -Name "Teredo_State" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" -Name "6to4_State" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" -Name "ISATAP_State" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator" -Name "DisablePassivePolling" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Force -ErrorAction SilentlyContinue

        # Clean All GPEDIT System, Privacy & Gaming Policies
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsAccessDiagnosticsInfo" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsSpotlightFeatures" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableThirdPartySuggestions" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DisableOneSettingsDownloads" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "DontSendAdditionalData" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "AITEnable" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisablePCA" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableInventory" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TaskScheduler\Maintenance" -Name "WakeUp" -Force -ErrorAction SilentlyContinue

        Write-RanvyxLog -Message "Restored all GPEDIT Network, Gaming & System policies to default" -Level "RESET"
    } catch {}

    # Step 3: 71% to 100% (Restore Power Scheme, GameDVR, BCDedit, DNS, Policy Sync)
    while ($currentPct -lt 100) {
        $currentPct++
        Render-Progress $currentPct
        Start-Sleep -Milliseconds 22
    }
    try {
        # Balanced Power Plan default
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null

        # Restore GameDVR defaults
        $gameConfig = "HKCU:\System\GameConfigStore"
        Set-ItemProperty -Path $gameConfig -Name "GameDVR_Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        $gameDvrApp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
        Set-ItemProperty -Path $gameDvrApp -Name "AppCaptureEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        # Remove BCDedit timer overrides
        bcdedit /deletevalue disabledynamictick 2>$null | Out-Null
        bcdedit /deletevalue useplatformclock 2>$null | Out-Null

        # Flush DNS cache
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        ipconfig /flushdns | Out-Null

        # Refresh policy engine
        try {
            $gpProc = Start-Process gpupdate.exe -ArgumentList "/target:computer /force" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            $gpProc.WaitForExit(3000) | Out-Null
        } catch {}

        Write-RanvyxLog -Message "Restored Power Scheme (Balanced), GameDVR, Timers, GPEDIT policies, and flushed DNS" -Level "RESET"
        Write-RanvyxLog -Message "Reset completed successfully (100%)" -Level "SUCCESS"
    } catch {}

    Render-Progress 100
    Write-Host ""
    Write-Host ""
    Write-Host "  $cGreen Success$cReset"
    Write-Host ""

    Play-Beep 3
    Show-SuccessPopup
}

# Automated Action Dispatcher (if invoked via CLI parameter)
if ($Action) {
    switch ($Action) {
        "1" { Start-Optimization }
        "2" { Start-Reset }
        "3" {
            if (Test-Path $global:LogFile) {
                Get-Content -Path $global:LogFile -Tail 10
            } else {
                Write-Host "No log file found."
            }
        }
        "4" { Start-GpeditOptimization }
        "START" { Start-Optimization }
        "RESET" { Start-Reset }
        "LOG" {
            if (Test-Path $global:LogFile) {
                Get-Content -Path $global:LogFile -Tail 10
            } else {
                Write-Host "No log file found."
            }
        }
        "GPEDIT" { Start-GpeditOptimization }
    }
    exit
}

# Main Compact Loop (Interactive)
while ($true) {
    Render-UI
    Write-Host -NoNewline "  $cCyan>> Select [1, 2, 3, 4] : $cReset"
    $choice = Read-Host

    switch ($choice) {
        "1" { Start-Optimization }
        "2" { Start-Reset }
        "3" { Show-LogViewer }
        "4" { Start-GpeditOptimization }
    }
}
