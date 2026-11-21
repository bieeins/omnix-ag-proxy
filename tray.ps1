param([int]$Port = 20129)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Single Instance Protection
$mutexName = "Local\OMNIX-Shield-Tray-$Port"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
try {
    $hasMutex = $mutex.WaitOne(300, $false)
} catch [System.Threading.AbandonedMutexException] {
    $hasMutex = $true
} catch {
    $hasMutex = $false
}

if (-not $hasMutex) {
    exit 0
}

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $scriptDir) {
    $scriptDir = "D:\Tools\omnix-shield"
}

function Start-ProxyProcess {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($conn) { return }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "node.exe"
    $psi.Arguments = "`"$scriptDir\index.js`" --port $Port --no-tray"
    $psi.WorkingDirectory = $scriptDir
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    [System.Diagnostics.Process]::Start($psi) | Out-Null
}

function Stop-ProxyProcess {
    try {
        $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        foreach ($c in $conns) {
            if ($c.OwningProcess -gt 4) {
                Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
    Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*omnix-shield*index.js*" } | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

# 1. Pastikan node proxy jalan di background jika belum aktif
Start-ProxyProcess
Start-Sleep -Seconds 1

# 2. Setup NotifyIcon
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Shield
$notify.Text = "OMNIX-Shield (Port $Port)"
$notify.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Header Title
$menuTitle = $contextMenu.Items.Add("OMNIX-Shield (Port $Port)")
$menuTitle.Enabled = $false
$menuTitle.Font = New-Object System.Drawing.Font($menuTitle.Font, [System.Drawing.FontStyle]::Bold)

$null = $contextMenu.Items.Add("-")

# Open Dashboard
$menuOpen = $contextMenu.Items.Add("Open Dashboard")
$menuOpen.add_Click({
    [System.Diagnostics.Process]::Start("http://127.0.0.1:$Port/ui")
})

# Copy Base URL
$menuCopy = $contextMenu.Items.Add("Copy Base URL")
$menuCopy.add_Click({
    [System.Windows.Forms.Clipboard]::SetText("http://127.0.0.1:$Port/v1")
    $notify.ShowBalloonTip(2000, "OMNIX-Shield", "Base URL copied: http://127.0.0.1:$Port/v1", [System.Windows.Forms.ToolTipIcon]::Info)
})

# View Traffic Log
$menuLog = $contextMenu.Items.Add("View Traffic Log")
$menuLog.add_Click({
    $logFile = Join-Path $scriptDir "traffic.log"
    if (Test-Path $logFile) {
        [System.Diagnostics.Process]::Start("notepad.exe", $logFile)
    } else {
        [System.Windows.Forms.MessageBox]::Show("Log file empty or not created yet.", "OMNIX-Shield")
    }
})

$null = $contextMenu.Items.Add("-")

# Autostart toggle
$startupDir = [System.Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupDir "OMNIX-Shield.lnk"

$menuAutostart = $contextMenu.Items.Add("Auto-start on Boot")
$menuAutostart.CheckOnClick = $true
$menuAutostart.Checked = (Test-Path $shortcutPath)

$menuAutostart.add_Click({
    $startupDir = [System.Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startupDir "OMNIX-Shield.lnk"
    
    if ($menuAutostart.Checked) {
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($shortcutPath)
        $sc.TargetPath = "wscript.exe"
        $sc.Arguments = "`"$scriptDir\start-hidden.vbs`""
        $sc.WorkingDirectory = $scriptDir
        $sc.Description = "OMNIX-Shield Proxy"
        $sc.Save()
        $notify.ShowBalloonTip(2000, "OMNIX-Shield", "Auto-start enabled on Windows boot", [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }
        $notify.ShowBalloonTip(2000, "OMNIX-Shield", "Auto-start disabled", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})

# Restart Proxy
$menuRestart = $contextMenu.Items.Add("Restart Proxy")
$menuRestart.add_Click({
    Stop-ProxyProcess
    Start-Sleep -Seconds 1
    Start-ProxyProcess
    $notify.ShowBalloonTip(2000, "OMNIX-Shield", "Proxy restarted successfully", [System.Windows.Forms.ToolTipIcon]::Info)
})

$null = $contextMenu.Items.Add("-")

# Quit
$menuExit = $contextMenu.Items.Add("Quit & Stop Proxy")
$menuExit.add_Click({
    $notify.Visible = $false
    $notify.Dispose()
    Stop-ProxyProcess
    if ($mutex) {
        try { $mutex.ReleaseMutex(); $mutex.Dispose() } catch {}
    }
    [System.Windows.Forms.Application]::Exit()
    Stop-Process -Id $PID -Force
})

$notify.ContextMenuStrip = $contextMenu

# Double click: Open Dashboard
$notify.add_DoubleClick({
    [System.Diagnostics.Process]::Start("http://127.0.0.1:$Port/ui")
})

$notify.ShowBalloonTip(2500, "OMNIX-Shield Active", "Proxy running on port $Port. Double-click to open dashboard.", [System.Windows.Forms.ToolTipIcon]::Info)

# Watchdog Timer: auto-restart node if died, refresh icon heartbeat
$tickCount = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.add_Tick({
    try {
        $script:tickCount++

        # Heartbeat: every 60s re-assert icon visibility
        if ($script:tickCount % 12 -eq 0) {
            $notify.Visible = $true
        }

        # Watchdog: restart node if port is not listening
        $listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if (-not $listening) {
            Start-ProxyProcess
        }
    } catch {}
})
$timer.Start()

[System.Windows.Forms.Application]::Run()
