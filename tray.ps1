param([int]$NodePid = 0, [int]$Port = 20129)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Shield
$notify.Text = "OMNIX-Shield (Port $Port)"
$notify.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Title item
$menuTitle = $contextMenu.Items.Add("OMNIX-Shield (Port $Port)")
$menuTitle.Enabled = $false
$menuTitle.Font = New-Object System.Drawing.Font($menuTitle.Font, [System.Drawing.FontStyle]::Bold)

$contextMenu.Items.Add("-")

# Open Dashboard
$menuOpen = $contextMenu.Items.Add("Open Dashboard")
$menuOpen.add_Click({
    [System.Diagnostics.Process]::Start("http://127.0.0.1:$Port/ui")
})

# Copy Base URL
$menuCopy = $contextMenu.Items.Add("Copy Base URL")
$menuCopy.add_Click({
    [System.Windows.Forms.Clipboard]::SetText("http://127.0.0.1:$Port/v1")
    $notify.ShowBalloonTip(2000, "OMNIX-Shield", "Base URL copied!", [System.Windows.Forms.ToolTipIcon]::Info)
})

$contextMenu.Items.Add("-")

# Autostart toggle
$startupDir = [System.Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupDir "OMNIX-Shield.lnk"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$menuAutostart = $contextMenu.Items.Add("Auto-start Enabled")
$menuAutostart.CheckOnClick = $true
$menuAutostart.Checked = (Test-Path $shortcutPath)

$menuAutostart.add_Click({
    $startupDir = [System.Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startupDir "OMNIX-Shield.lnk"
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    if ($menuAutostart.Checked) {
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($shortcutPath)
        $sc.TargetPath = "powershell.exe"
        $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -Command `"cd '$scriptDir'; node start.js tray`""
        $sc.WorkingDirectory = $scriptDir
        $sc.Description = "OMNIX-Shield Proxy"
        $sc.Save()
        $notify.ShowBalloonTip(2000, "OMNIX-Shield", "Auto-start enabled", [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }
        $notify.ShowBalloonTip(2000, "OMNIX-Shield", "Auto-start disabled", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})

$contextMenu.Items.Add("-")

# Quit
$menuExit = $contextMenu.Items.Add("Quit")
$menuExit.add_Click({
    $notify.Visible = $false
    if ($NodePid -gt 0) {
        Stop-Process -Id $NodePid -Force -ErrorAction SilentlyContinue
    }
    [System.Windows.Forms.Application]::Exit()
})

$notify.ContextMenuStrip = $contextMenu

$notify.add_DoubleClick({
    [System.Diagnostics.Process]::Start("http://127.0.0.1:$Port/ui")
})

$notify.ShowBalloonTip(2500, "OMNIX-Shield Active", "Proxy running on port $Port. Double-click to open dashboard.", [System.Windows.Forms.ToolTipIcon]::Info)

# Monitor Node process
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_Tick({
    if ($NodePid -gt 0) {
        $proc = Get-Process -Id $NodePid -ErrorAction SilentlyContinue
        if (-not $proc) {
            $notify.Visible = $false
            [System.Windows.Forms.Application]::Exit()
        }
    }
})
$timer.Start()

[System.Windows.Forms.Application]::Run()
