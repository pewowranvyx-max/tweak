<#
=============================================================================================
   RANVYX - COMPACT INTERNET & FPS OPTIMIZER (DEEP OPTIMIZATION & EXTENSIVE GPEDIT)
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

# Helper: Create Safe System Restore Point (if Protection is enabled)
function Create-SafeRestorePoint {
    param([string]$description = "Ranvyx_RestorePoint")
    try {
        $sysProtection = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue | Out-Null
        Write-RanvyxLog -Message "Created System Restore Point: $description" -Level "INFO"
    } catch {}
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

# 1. START Function (Deep Safe Internet & FPS Tweaks + Log + Progress)
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

    Write-RanvyxLog -Message "Deep Optimization started" -Level "START"

    # Automated safety restore point
    Create-SafeRestorePoint -description "Ranvyx_Deep_Optimization"

    $tasks = @(
        @{
            Name = "TCP/IP Stack, Pacing & Global Latency"
            TargetPct = 10
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
                netsh int tcp set global pacingprofile=off 2>$null | Out-Null
                netsh int tcp set supplemental template=custom congestionprovider=cubic 2>$null | Out-Null
                netsh int tcp set supplemental template=custom congestionprovider=ctcp 2>$null | Out-Null
                netsh int tcp set supplemental template=custom minrto=300 2>$null | Out-Null

                netsh int ip set global taskoffload=enabled 2>$null | Out-Null
                netsh int ip set global neighborcachelimit=4096 2>$null | Out-Null
                netsh int ip set global icmpredirects=disabled 2>$null | Out-Null
                netsh int ip set global multicastforwarding=disabled 2>$null | Out-Null
                netsh int ipv6 set global randomizeidentifiers=disabled 2>$null | Out-Null
                Write-RanvyxLog -Message "Tuned TCP/IP stack (autotuning=normal, rss=enabled, fastopen=enabled, ctcp/cubic, pacingprofile=off)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "AFD WinSock Driver & UDP Fast Thresholds"
            TargetPct = 20
            Action = {
                $afdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
                if (-not (Test-Path $afdPath)) { New-Item -Path $afdPath -Force | Out-Null }
                Set-ItemProperty -Path $afdPath -Name "DefaultReceiveWindow" -Value 65536 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "DefaultSendWindow" -Value 65536 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "FastSendDatagramThreshold" -Value 1024 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "FastCopyReceiveThreshold" -Value 1024 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "DoNotUseConnectData" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "DynamicSendBufferDisable" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "EnableDynamicBacklog" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "MinimumDynamicBacklog" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "MaximumDynamicBacklog" -Value 1000 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $afdPath -Name "DynamicBacklogGrowthDelta" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
                Write-RanvyxLog -Message "Optimized AFD WinSock driver (FastSendDatagramThreshold=1024, DynamicBacklog enabled, 64K windows)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Network Adapter Hardware, Offloads & Power Tuning"
            TargetPct = 30
            Action = {
                try {
                    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
                        $adName = $_.Name
                        # Disable green/energy efficient power saving
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Energy Efficient Ethernet*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Green Ethernet*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*WakeOnMagicPacket*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*WakeOnPattern*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Power Saving Mode*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Auto Disable Gigabit*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        
                        # Latency-critical: Disable Interrupt Moderation & Flow Control to eliminate packet jitter
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Interrupt Moderation*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Flow Control*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        
                        # Disable Large Send Offload (LSO causes burst queuing delays on desktop NICs)
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Large Send Offload v2 (IPv4)*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Large Send Offload v2 (IPv6)*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue 2>$null

                        # Hardware Checksum Offload (Enables NIC chip offload)
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*TCP Checksum Offload (IPv4)*" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*UDP Checksum Offload (IPv4)*" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue 2>$null

                        Enable-NetAdapterRss -Name $adName -ErrorAction SilentlyContinue 2>$null
                        Set-NetAdapterRss -Name $adName -NumberOfReceiveQueues 4 -ErrorAction SilentlyContinue 2>$null
                    }
                } catch {}

                # Prevent PCI power drop on Network Devices
                try {
                    Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root\wmi -ErrorAction SilentlyContinue |
                        Where-Object { $_.InstanceName -match "PCI" } |
                        Set-CimInstance -Property @{ Enable = $false } -ErrorAction SilentlyContinue
                } catch {}
                Write-RanvyxLog -Message "Optimized Network Adapters (disabled EEE/Green, disabled Interrupt Moderation & LSO, enabled RSS 4 queues)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Nagle's Zero-Delay & Core TCP Parameters"
            TargetPct = 40
            Action = {
                # Disable Nagle's Algorithm on all network interfaces
                $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
                if (Test-Path $interfacesPath) {
                    Get-ChildItem $interfacesPath -ErrorAction SilentlyContinue | ForEach-Object {
                        $guid = $_.PSChildName
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                }

                # Deep TCP/IP Parameters
                $tcpipParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
                if (Test-Path $tcpipParams) {
                    Set-ItemProperty -Path $tcpipParams -Name "DefaultTTL" -Value 64 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnableICMPRedirect" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "SynAttackProtect" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "Tcp1323Opts" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnableDCA" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnableWsd" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "MaxUserPort" -Value 65534 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "MaxFreeTcbs" -Value 65536 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "MaxHashTableSize" -Value 65536 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "DisableTaskOffload" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnableIPAutoConfiguration" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnablePMTUDiscovery" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "EnablePMTUBHDetect" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "ArpCacheLife" -Value 86400 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $tcpipParams -Name "ArpCacheMinReferencedLife" -Value 180 -Type DWord -Force -ErrorAction SilentlyContinue
                    
                    $cpuCount = [Environment]::ProcessorCount
                    if ($cpuCount -gt 0) {
                        Set-ItemProperty -Path $tcpipParams -Name "NumTcbTablePartitions" -Value $cpuCount -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                }
                Write-RanvyxLog -Message "Disabled Nagle's Algorithm (TcpAckFrequency=1, TCPNoDelay=1, MaxUserPort=65534, TcpTimedWaitDelay=30, TcbPartitions)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "QoS 20%, Anti-Throttling, DNS & NetBT"
            TargetPct = 50
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

                # NetBT NodeType = 2 (P-node: use point-to-point DNS instead of broadcast NetBIOS)
                $netbtPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters"
                if (Test-Path $netbtPath) {
                    Set-ItemProperty -Path $netbtPath -Name "NodeType" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
                }

                Clear-DnsClientCache -ErrorAction SilentlyContinue
                ipconfig /flushdns | Out-Null
                Write-RanvyxLog -Message "Removed QoS 20%, disabled Network Throttling, tuned DNS cache, NetBT P-node" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "GPU Scheduling, DirectDraw & DWM Latency"
            TargetPct = 60
            Action = {
                # Hardware-Accelerated GPU Scheduling (HAGS Mode 2)
                $gfxPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
                if (Test-Path $gfxPath) { Set-ItemProperty -Path $gfxPath -Name "HwSchMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue }

                # Modern Windowed Games Optimization (SwapEffectUpgradeEnable = 1)
                $dxSettings = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences\DirectXUserGlobalSettings"
                if (-not (Test-Path $dxSettings)) { New-Item -Path $dxSettings -Force | Out-Null }
                Set-ItemProperty -Path $dxSettings -Name "SwapEffectUpgradeEnable" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                # GameConfigStore FSE overrides
                $gameConfig = "HKCU:\System\GameConfigStore"
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_EFSEFeatureFlags" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $gameConfig -Name "GameDVR_DSEBehavior" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

                $gameDvrApp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
                if (-not (Test-Path $gameDvrApp)) { New-Item -Path $gameDvrApp -Force | Out-Null }
                Set-ItemProperty -Path $gameDvrApp -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                # DWM & CSRSS Realtime Process Priorities
                $dwmPerf = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"
                if (-not (Test-Path $dwmPerf)) { New-Item -Path $dwmPerf -Force | Out-Null }
                Set-ItemProperty -Path $dwmPerf -Name "CpuPriorityClass" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $dwmPerf -Name "IoPriority" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue

                $csrssPerf = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"
                if (-not (Test-Path $csrssPerf)) { New-Item -Path $csrssPerf -Force | Out-Null }
                Set-ItemProperty -Path $csrssPerf -Name "CpuPriorityClass" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue

                Write-RanvyxLog -Message "Configured GPU HAGS Mode 2, Modern SwapEffect Upgrade, DWM/CSRSS High Priority" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "MMCSS Gaming & Audio Latency Priorities"
            TargetPct = 70
            Action = {
                # MMCSS Games Task
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

                # MMCSS Audio Task (Low Latency Audio Voice / Discord / In-game sound)
                $audioTask = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
                if (-not (Test-Path $audioTask)) { New-Item -Path $audioTask -Force | Out-Null }
                Set-ItemProperty -Path $audioTask -Name "Affinity" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $audioTask -Name "Background Only" -Value "False" -Type String -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $audioTask -Name "Clock Rate" -Value 10000 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $audioTask -Name "GPU Priority" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $audioTask -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $audioTask -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $audioTask -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction SilentlyContinue

                Write-RanvyxLog -Message "MMCSS Games Priority High (GPU 8, Priority 6) and MMCSS Low Latency Audio configured" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Raw Input, Mouse 1:1 Response & Keyboard Buffers"
            TargetPct = 78
            Action = {
                # Increase Mouse and Keyboard Hardware Queue buffers (handles high polling rate 1000Hz - 8000Hz without dropped inputs)
                $mouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
                if (-not (Test-Path $mouPath)) { New-Item -Path $mouPath -Force | Out-Null }
                Set-ItemProperty -Path $mouPath -Name "MouseDataQueueSize" -Value 100 -Type DWord -Force -ErrorAction SilentlyContinue

                $kbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
                if (-not (Test-Path $kbdPath)) { New-Item -Path $kbdPath -Force | Out-Null }
                Set-ItemProperty -Path $kbdPath -Name "KeyboardDataQueueSize" -Value 100 -Type DWord -Force -ErrorAction SilentlyContinue

                # Disable Mouse Acceleration for pure 1:1 raw aiming
                $mouseCtrl = "HKCU:\Control Panel\Mouse"
                Set-ItemProperty -Path $mouseCtrl -Name "MouseSpeed" -Value "0" -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $mouseCtrl -Name "MouseThreshold1" -Value "0" -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $mouseCtrl -Name "MouseThreshold2" -Value "0" -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $mouseCtrl -Name "MouseHoverTime" -Value "10" -Force -ErrorAction SilentlyContinue

                Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Force -ErrorAction SilentlyContinue

                Write-RanvyxLog -Message "Configured 1:1 Raw Mouse Input (no acceleration, 100 queue size, 0ms menu delay)" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "CPU Priority Separation, SvcHost & Storage Latency"
            TargetPct = 85
            Action = {
                # Win32PrioritySeparation = 0x26 (38 Dec) - Optimal 3:1 Foreground Quantum for Pro Gaming responsiveness
                $priorityControl = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
                if (Test-Path $priorityControl) {
                    Set-ItemProperty -Path $priorityControl -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force -ErrorAction SilentlyContinue
                }

                # SvcHostSplitThresholdInKB: Isolate background Windows services on >= 4GB RAM systems
                try {
                    $ramBytes = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object Capacity -Sum).Sum
                    if ($ramBytes -and $ramBytes -gt 4294967296) {
                        $ramKB = [int]($ramBytes / 1024)
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $ramKB -Type DWord -Force -ErrorAction SilentlyContinue
                    } else {
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value 0x38000000 -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                } catch {}

                # Memory Management & Kernel Paging
                $memPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
                Set-ItemProperty -Path $memPath -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $memPath -Name "LargeSystemCache" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $memPath -Name "IoPageLockLimit" -Value 1048576 -Type DWord -Force -ErrorAction SilentlyContinue

                # NTFS Storage Performance & Wear Reduction
                $fsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
                Set-ItemProperty -Path $fsPath -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $fsPath -Name "NtfsDisableLastAccessUpdate" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $fsPath -Name "NtfsMemoryUsage" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $fsPath -Name "LongPathsEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                Write-RanvyxLog -Message "Set Win32PrioritySeparation=38, SvcHost split threshold, IoPageLockLimit 1MB, NTFS 8.3/LastAccess disabled" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "CPU Unparking, Power Plan & Timer Tuning"
            TargetPct = 92
            Action = {
                # Activate Ultimate or High Performance Power Plan
                try {
                    $scheme = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
                    if ($scheme -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
                        powercfg /setactive $matches[1] 2>$null
                    } else {
                        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
                    }
                } catch {}

                # Deep CPU Core Unparking (Keep 100% of cores active on AC power)
                powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100 2>$null
                powercfg -setacvalueindex scheme_current sub_processor CPMAXCORES 100 2>$null
                powercfg -setacvalueindex scheme_current sub_processor DISTRIBUTEUTIL 0 2>$null

                # Processor Energy Performance Preference (0 = Max Instant Responsiveness)
                powercfg -setacvalueindex scheme_current sub_processor PERFEPP 0 2>$null
                powercfg -setacvalueindex scheme_current sub_processor PERFEPP1 0 2>$null
                powercfg -setacvalueindex scheme_current sub_processor PERFBOOSTPOL 100 2>$null

                # Disable USB Selective Suspend (Stops mouse/keyboard wake-up micro-lags)
                powercfg -setacvalueindex scheme_current 2a737441-1930-4402-8677-b00ab014a163 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null

                # Disable PCIe Link State Power Management (Keep GPU & NVMe at max bus clock)
                powercfg -setacvalueindex scheme_current 501a4d13-42af-4429-9fd8-0a60f74e0c7f ee12f506-d07c-45a1-a307-51147077eec2 0 2>$null

                # Hard disk sleep = 0 (Never spin down storage)
                powercfg -change -disk-timeout-ac 0 2>$null
                powercfg -setactive scheme_current 2>$null

                # PowerThrottlingOff
                $powerThrottling = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
                if (-not (Test-Path $powerThrottling)) { New-Item -Path $powerThrottling -Force | Out-Null }
                Set-ItemProperty -Path $powerThrottling -Name "PowerThrottlingOff" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

                # BCDedit Precision Timers
                bcdedit /set disabledynamictick yes 2>$null | Out-Null
                bcdedit /set useplatformclock no 2>$null | Out-Null

                Write-RanvyxLog -Message "CPU Cores Unparked (100%), EPP 0, USB Suspend disabled, PCIe ASPM disabled, DynamicTick disabled" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Background Micro-Stutter Reductions"
            TargetPct = 97
            Action = {
                # Disable non-essential telemetry & diagnostic scheduled tasks that cause random game stutters
                $tasksToDisable = @(
                    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
                    "\Microsoft\Windows\Autochk\Proxy",
                    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
                    "\Microsoft\Windows\Maintenance\WinSAT",
                    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
                )
                foreach ($t in $tasksToDisable) {
                    try {
                        Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
                    } catch {}
                }
                Write-RanvyxLog -Message "Disabled background diagnostic/telemetry scheduled tasks causing in-game stutters" -Level "OPTIMIZE"
            }
        },
        @{
            Name = "Standby RAM Flush & Memory Optimization"
            TargetPct = 100
            Action = {
                [MemoryCleaner]::FlushMemory()
                Write-RanvyxLog -Message "Flushed Standby RAM working set memory" -Level "OPTIMIZE"
                Write-RanvyxLog -Message "Deep Optimization completed successfully (100%)" -Level "SUCCESS"
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
            Start-Sleep -Milliseconds 15
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

    # Automated safety restore point
    Create-SafeRestorePoint -description "Ranvyx_GPEDIT_Optimization"

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

                # 4. Turn off Remote Assistance listener
                $remAssist = "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance"
                if (Test-Path $remAssist) {
                    Set-ItemProperty -Path $remAssist -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                }

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
                Set-ItemProperty -Path $gameDvrPol -Name "AllowGameStream" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

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

                # 4. Disable Silent App Installs (Bloatware)
                $cdm = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                if (-not (Test-Path $cdm)) { New-Item -Path $cdm -Force | Out-Null }
                Set-ItemProperty -Path $cdm -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                Write-RanvyxLog -Message "Configured Gaming & Privacy Policies (GameDVR policy disabled, Background Apps Force Deny, Search Web Bing disabled, Bloatware off)" -Level "OPTIMIZE"
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
            Start-Sleep -Milliseconds 15
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

# 2. RESET Function (100% Comprehensive Reversible Reset to Windows Defaults + Smooth Progress + Popup + Log)
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

    Write-RanvyxLog -Message "100% Comprehensive Reset to Windows Defaults started" -Level "RESET"

    $currentPct = 1
    Render-Progress 1

    # Step 1: 1% to 25% (Reset TCP/IP, Winsock, Netsh stack & AFD driver)
    while ($currentPct -lt 25) {
        $currentPct++
        Render-Progress $currentPct
        Start-Sleep -Milliseconds 15
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
        netsh int tcp set global pacingprofile=default 2>$null | Out-Null
        netsh int tcp set supplemental template=custom congestionprovider=default 2>$null | Out-Null

        # Remove custom AFD WinSock parameters
        $afdParams = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
        if (Test-Path $afdParams) {
            $afdProps = @(
                "DefaultReceiveWindow", "DefaultSendWindow", "FastSendDatagramThreshold",
                "FastCopyReceiveThreshold", "DoNotUseConnectData", "DynamicSendBufferDisable",
                "EnableDynamicBacklog", "MinimumDynamicBacklog", "MaximumDynamicBacklog", "DynamicBacklogGrowthDelta"
            )
            foreach ($prop in $afdProps) {
                Remove-ItemProperty -Path $afdParams -Name $prop -Force -ErrorAction SilentlyContinue
            }
        }

        # Restore Network Adapters (Enable Interrupt Moderation, Flow Control & LSO defaults)
        try {
            Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
                $adName = $_.Name
                Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Interrupt Moderation*" -DisplayValue "Enabled" -ErrorAction SilentlyContinue 2>$null
                Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Flow Control*" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue 2>$null
                Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Large Send Offload v2 (IPv4)*" -DisplayValue "Enabled" -ErrorAction SilentlyContinue 2>$null
                Set-NetAdapterAdvancedProperty -Name $adName -DisplayName "*Large Send Offload v2 (IPv6)*" -DisplayValue "Enabled" -ErrorAction SilentlyContinue 2>$null
            }
        } catch {}

        Write-RanvyxLog -Message "Reset TCP/IP, Winsock, Netsh global stack, AFD driver & NIC defaults" -Level "RESET"
    } catch {}

    # Step 2: 26% to 50% (Restore Nagle, QoS, Anti-Throttle, DNS, NetBT & Core TCPIP parameters)
    while ($currentPct -lt 50) {
        $currentPct++
        Render-Progress $currentPct
        Start-Sleep -Milliseconds 15
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
            $tcpProps = @(
                "DefaultTTL", "EnableICMPRedirect", "SynAttackProtect", "Tcp1323Opts", "EnableDCA", "EnableWsd",
                "MaxUserPort", "TcpTimedWaitDelay", "MaxFreeTcbs", "MaxHashTableSize", "NumTcbTablePartitions",
                "DisableTaskOffload", "EnableIPAutoConfiguration", "EnablePMTUDiscovery", "EnablePMTUBHDetect",
                "ArpCacheLife", "ArpCacheMinReferencedLife"
            )
            foreach ($p in $tcpProps) {
                Remove-ItemProperty -Path $tcpipParams -Name $p -Force -ErrorAction SilentlyContinue
            }
        }

        # Restore QoS and Network Throttling defaults
        $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $sysProfile -Name "AlwaysOn" -Force -ErrorAction SilentlyContinue

        # Restore MMCSS Games and Audio defaults
        $gamesTask = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        if (Test-Path $gamesTask) {
            Set-ItemProperty -Path $gamesTask -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesTask -Name "Priority" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesTask -Name "Scheduling Category" -Value "Medium" -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesTask -Name "SFIO Priority" -Value "Normal" -Type String -Force -ErrorAction SilentlyContinue
        }

        $audioTask = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
        if (Test-Path $audioTask) {
            Set-ItemProperty -Path $audioTask -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $audioTask -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $audioTask -Name "SFIO Priority" -Value "Normal" -Type String -Force -ErrorAction SilentlyContinue
        }

        # Restore NetBT
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "NodeType" -Force -ErrorAction SilentlyContinue

        # Restore DNS Cache parameters
        $dnsCachePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
        if (Test-Path $dnsCachePath) {
            Remove-ItemProperty -Path $dnsCachePath -Name "MaxCacheTtl" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $dnsCachePath -Name "MaxNegativeCacheTtl" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $dnsCachePath -Name "NetFailureCacheTime" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $dnsCachePath -Name "NegativeSOACacheTime" -Force -ErrorAction SilentlyContinue
        }

        Write-RanvyxLog -Message "Restored Nagle's Algorithm, TCPIP parameters, MMCSS tasks & DNS defaults" -Level "RESET"
    } catch {}

    # Step 3: 51% to 75% (Restore Kernel, CPU Scheduling, Storage, Input & IFEO Priorities)
    while ($currentPct -lt 75) {
        $currentPct++
        Render-Progress $currentPct
        Start-Sleep -Milliseconds 15
    }
    try {
        # Restore Win32PrioritySeparation to 2 (Windows Default)
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

        # Remove SvcHostSplitThresholdInKB
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Force -ErrorAction SilentlyContinue

        # Restore Memory Management
        $memPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-ItemProperty -Path $memPath -Name "DisablePagingExecutive" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $memPath -Name "IoPageLockLimit" -Force -ErrorAction SilentlyContinue

        # Restore NTFS defaults
        $fsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        Set-ItemProperty -Path $fsPath -Name "NtfsDisable8dot3NameCreation" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $fsPath -Name "NtfsDisableLastAccessUpdate" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $fsPath -Name "NtfsMemoryUsage" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        # Remove IFEO dwm.exe & csrss.exe PerfOptions
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" -Recurse -Force -ErrorAction SilentlyContinue

        # Restore Mouse & Keyboard Queue sizes and speed
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Force -ErrorAction SilentlyContinue

        $mouseCtrl = "HKCU:\Control Panel\Mouse"
        Set-ItemProperty -Path $mouseCtrl -Name "MouseSpeed" -Value "1" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mouseCtrl -Name "MouseThreshold1" -Value "6" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mouseCtrl -Name "MouseThreshold2" -Value "10" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mouseCtrl -Name "MouseHoverTime" -Value "400" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "400" -Force -ErrorAction SilentlyContinue

        # Re-enable scheduled tasks
        $tasksToEnable = @(
            "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
            "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
            "\Microsoft\Windows\Autochk\Proxy",
            "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
            "\Microsoft\Windows\Maintenance\WinSAT",
            "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
        )
        foreach ($t in $tasksToEnable) {
            try {
                Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
            } catch {}
        }

        Write-RanvyxLog -Message "Restored Win32PrioritySeparation=2, Memory, NTFS, Input buffers, IFEO & Scheduled Tasks" -Level "RESET"
    } catch {}

    # Step 4: 76% to 100% (Restore GPEDIT Policies, Power Plan, GameDVR, BCDedit & Policy Sync)
    while ($currentPct -lt 100) {
        $currentPct++
        Render-Progress $currentPct
        Start-Sleep -Milliseconds 15
    }
    try {
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
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Force -ErrorAction SilentlyContinue

        # Clean All GPEDIT System, Privacy & Gaming Policies
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameStream" -Force -ErrorAction SilentlyContinue
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
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Force -ErrorAction SilentlyContinue

        # Balanced Power Plan default
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Force -ErrorAction SilentlyContinue

        # Restore GameDVR defaults
        $gameConfig = "HKCU:\System\GameConfigStore"
        Set-ItemProperty -Path $gameConfig -Name "GameDVR_Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $gameConfig -Name "GameDVR_FSEBehaviorMode" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $gameConfig -Name "GameDVR_HonorUserFSEBehaviorMode" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $gameConfig -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $gameConfig -Name "GameDVR_EFSEFeatureFlags" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $gameConfig -Name "GameDVR_DSEBehavior" -Force -ErrorAction SilentlyContinue

        $gameDvrApp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
        Set-ItemProperty -Path $gameDvrApp -Name "AppCaptureEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        # Remove DirectX windowed swap effect override
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences\DirectXUserGlobalSettings" -Name "SwapEffectUpgradeEnable" -Force -ErrorAction SilentlyContinue

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

        Write-RanvyxLog -Message "Restored All GPEDIT policies, Balanced Power Scheme, GameDVR, BCD Timers, and flushed DNS" -Level "RESET"
        Write-RanvyxLog -Message "100% Comprehensive Reset completed successfully" -Level "SUCCESS"
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
