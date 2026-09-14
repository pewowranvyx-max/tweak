<#
=============================================================================================
   RANVYX - COMPACT INTERNET & FPS OPTIMIZER
=============================================================================================
#>

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
    if ($scriptFile -and (Test-Path $scriptFile)) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`""
        exit
    } else {
        $tempPath = Join-Path $env:TEMP "Ranvyx.ps1"
        $scriptContent = $MyInvocation.MyCommand.ScriptBlock.ToString()
        if (-not $scriptContent) {
            $defaultLoc = "$env:USERPROFILE\.gemini\antigravity-ide\scratch\ranvyx-optimizer\Ranvyx.ps1"
            if (Test-Path $defaultLoc) { $scriptContent = Get-Content $defaultLoc -Raw }
        }
        if ($scriptContent) {
            [System.IO.File]::WriteAllText($tempPath, $scriptContent, [System.Text.Encoding]::UTF8)
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempPath`""
            exit
        }
    }
}

# 2. Native Window Resizer API (Centers and resizes to compact window)
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

    public static void ResizeCompact() {
        try {
            IntPtr hWnd = GetConsoleWindow();
            if (hWnd != IntPtr.Zero) {
                int w = 450;
                int h = 320;
                int screenW = GetSystemMetrics(0);
                int screenH = GetSystemMetrics(1);
                int x = (screenW - w) / 2;
                int y = (screenH - h) / 2;
                MoveWindow(hWnd, x, y, w, h, true);
            }
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

# Resize window to compact size like in screenshot
try {
    [WinHelper]::ResizeCompact()
    mode con: cols=46 lines=15 *>$null
    $host.UI.RawUI.WindowTitle = "Ranvyx"
    $host.UI.RawUI.BackgroundColor = "Black"
    $host.UI.RawUI.ForegroundColor = "Cyan"
} catch {}

# Cyber Sound Helper
function Play-Beep {
    param([int]$type = 1)
    [System.Threading.ThreadPool]::QueueUserWorkItem([System.Threading.WaitCallback]{
        try {
            switch ($type) {
                1 { [Console]::Beep(1200, 60); [Console]::Beep(1800, 80) }
                2 { [Console]::Beep(900, 70); [Console]::Beep(600, 90) }
                3 { [Console]::Beep(1400, 80); [Console]::Beep(2000, 120) }
            }
        } catch {}
    }) | Out-Null
}

# ANSI Colors
$e = [char]27
$cReset  = "$e[0m$e[40m"
$cCyan   = "$e[38;2;0;240;255m$e[40m"
$cWhite  = "$e[38;2;255;255;255m$e[40m"
$cGreen  = "$e[38;2;16;185;129m$e[40m"
$cDark   = "$e[38;2;100;116;139m$e[40m"

# Smooth Progress Bar Animation
function Show-ProgressBar {
    param([string]$task, [int]$percent, [int]$width = 20)
    $filled = [math]::Round(($percent / 100) * $width)
    $empty = $width - $filled
    $bar = "$cCyan" + ("#" * $filled) + "$cDark" + ("-" * $empty) + "$cReset"
    Write-Host -NoNewline "`r  $bar $cCyan$percent%$cReset"
}

# Render Compact UI
function Render-UI {
    Clear-Host
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host "  $cCyan               RANVYX               $cReset"
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
    Write-Host "     $cWhite 1. START$cReset"
    Write-Host "     $cWhite 2. RESET$cReset"
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
}

# 1. START Function (Maximum Safe Tweaks)
function Start-Optimization {
    Play-Beep 1
    Clear-Host
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host "  $cCyan               RANVYX               $cReset"
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
    Write-Host "  $cWhite[1] STARTING OPTIMIZATION...$cReset"
    Write-Host ""

    $steps = @(
        { netsh int tcp set global autotuninglevel=normal | Out-Null },
        { netsh int tcp set heuristics disabled | Out-Null },
        { netsh int tcp set global rss=enabled | Out-Null },
        { netsh int tcp set global rsc=disabled 2>$null | Out-Null },
        { netsh int tcp set global dca=enabled 2>$null | Out-Null },
        { netsh int tcp set global netdma=enabled 2>$null | Out-Null },
        { netsh int tcp set global ecncapability=disabled | Out-Null },
        { netsh int tcp set global timestamps=disabled | Out-Null },
        { 
            netsh int tcp set supplemental template=custom congestionprovider=ctcp 2>$null | Out-Null
            netsh int tcp set supplemental template=custom congestionprovider=cubic 2>$null | Out-Null
            netsh int tcp set supplemental template=custom minrto=300 2>$null | Out-Null
        },
        {
            $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            Get-ChildItem $interfacesPath | ForEach-Object {
                $guid = $_.PSChildName
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        },
        {
            Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
                Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
                Enable-NetAdapterChecksumOffload -Name $_.Name -ErrorAction SilentlyContinue
                Enable-NetAdapterLso -Name $_.Name -IPv4 -ErrorAction SilentlyContinue
                Enable-NetAdapterLso -Name $_.Name -IPv6 -ErrorAction SilentlyContinue
            }
        },
        {
            $pschedPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
            if (-not (Test-Path $pschedPath)) { New-Item -Path $pschedPath -Force | Out-Null }
            Set-ItemProperty -Path $pschedPath -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force

            $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value ([Convert]::ToUInt32("ffffffff", 16)) -Type DWord -Force
            Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
        },
        {
            $dnsCachePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
            if (Test-Path $dnsCachePath) {
                Set-ItemProperty -Path $dnsCachePath -Name "MaxCacheTtl" -Value 86400 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $dnsCachePath -Name "MaxNegativeCacheTtl" -Value 5 -Type DWord -Force -ErrorAction SilentlyContinue
            }
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            ipconfig /flushdns | Out-Null
            arp -d * 2>$null | Out-Null
            nbtstat -R 2>$null | Out-Null
        },
        {
            $gfxPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
            if (Test-Path $gfxPath) { Set-ItemProperty -Path $gfxPath -Name "HwSchMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue }

            $gamesTask = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            if (-not (Test-Path $gamesTask)) { New-Item -Path $gamesTask -Force | Out-Null }
            Set-ItemProperty -Path $gamesTask -Name "Affinity" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $gamesTask -Name "Background Only" -Value "False" -Type String -Force
            Set-ItemProperty -Path $gamesTask -Name "Clock Rate" -Value 10000 -Type DWord -Force
            Set-ItemProperty -Path $gamesTask -Name "GPU Priority" -Value 8 -Type DWord -Force
            Set-ItemProperty -Path $gamesTask -Name "Priority" -Value 6 -Type DWord -Force
            Set-ItemProperty -Path $gamesTask -Name "Scheduling Category" -Value "High" -Type String -Force
            Set-ItemProperty -Path $gamesTask -Name "SFIO Priority" -Value "High" -Type String -Force
            Set-ItemProperty -Path $gamesTask -Name "Latency Sensitive" -Value "True" -Type String -Force -ErrorAction SilentlyContinue
        },
        {
            $gameConfig = "HKCU:\System\GameConfigStore"
            Set-ItemProperty -Path $gameConfig -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gameConfig -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gameConfig -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gameConfig -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

            $gameDvrApp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
            if (-not (Test-Path $gameDvrApp)) { New-Item -Path $gameDvrApp -Force | Out-Null }
            Set-ItemProperty -Path $gameDvrApp -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

            $gameDvrPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
            if (-not (Test-Path $gameDvrPol)) { New-Item -Path $gameDvrPol -Force | Out-Null }
            Set-ItemProperty -Path $gameDvrPol -Name "AllowGameDVR" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        },
        {
            try {
                $scheme = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
                if ($scheme -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
                    powercfg /setactive $matches[1]
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
        }
    )

    $total = $steps.Count
    for ($i = 0; $i -lt $total; $i++) {
        & $steps[$i]
        $pct = [int][math]::Round((($i + 1) / $total) * 100)
        Show-ProgressBar "Optimizing" $pct
        [System.Threading.Thread]::Sleep(60)
    }

    Write-Host ""
    Write-Host ""
    Write-Host "  $cGreen[OK] COMPLETE!$cReset"
    Play-Beep 3
    Write-Host ""
    Write-Host -NoNewline "  $cDark Press Any Key to Return... $cReset"
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 2. RESET Function (Windows Defaults)
function Start-Reset {
    Play-Beep 2
    Clear-Host
    Write-Host ""
    Write-Host "  $cCyan====================================$cReset"
    Write-Host "  $cCyan               RANVYX               $cReset"
    Write-Host "  $cCyan====================================$cReset"
    Write-Host ""
    Write-Host "  $cWhite[2] RESETTING TO DEFAULTS...$cReset"
    Write-Host ""

    $resetSteps = @(
        {
            netsh int tcp reset | Out-Null
            netsh int ip reset | Out-Null
            netsh winsock reset | Out-Null
            netsh int tcp set global autotuninglevel=normal | Out-Null
            netsh int tcp set global rss=enabled | Out-Null
            netsh int tcp set heuristics default 2>$null | Out-Null
        },
        {
            $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            Get-ChildItem $interfacesPath | ForEach-Object {
                $guid = $_.PSChildName
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpAckFrequency" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TCPNoDelay" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name "TcpDelAckTicks" -Force -ErrorAction SilentlyContinue
            }
        },
        {
            $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue
            $pschedPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
            Remove-ItemProperty -Path $pschedPath -Name "NonBestEffortLimit" -Force -ErrorAction SilentlyContinue
        },
        {
            powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null
            $gameConfig = "HKCU:\System\GameConfigStore"
            Set-ItemProperty -Path $gameConfig -Name "GameDVR_Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            bcdedit /deletevalue disabledynamictick 2>$null | Out-Null
            bcdedit /deletevalue useplatformclock 2>$null | Out-Null
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            ipconfig /flushdns | Out-Null
        }
    )

    $total = $resetSteps.Count
    for ($i = 0; $i -lt $total; $i++) {
        & $resetSteps[$i]
        $pct = [int][math]::Round((($i + 1) / $total) * 100)
        Show-ProgressBar "Resetting" $pct
        [System.Threading.Thread]::Sleep(80)
    }

    Write-Host ""
    Write-Host ""
    Write-Host "  $cGreen[OK] RESET COMPLETE!$cReset"
    Play-Beep 3
    Write-Host ""
    Write-Host -NoNewline "  $cDark Press Any Key to Return... $cReset"
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main Compact Loop
while ($true) {
    Render-UI
    Write-Host -NoNewline "  $cCyan>> Select [1 or 2] : $cReset"
    $choice = Read-Host

    switch ($choice) {
        "1" { Start-Optimization }
        "2" { Start-Reset }
    }
}
