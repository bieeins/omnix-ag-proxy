
param([int]$NodePid = 0, [int]$Port = 20129)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Shield
$notify.Text = "AG-Shield Proxy (:$Port)"
$notify.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$menuOpen = $contextMenu.Items.Add("Open Dashboard")
$menuOpen.Font = New-Object System.Drawing.Font($menuOpen.Font, [System.Drawing.FontStyle]::Bold)
$menuOpen.add_Click({
    [System.Diagnostics.Process]::Start("http://127.0.0.1:$Port/ui")
})

$menuCopy = $contextMenu.Items.Add("Copy Base URL (v1)")
$menuCopy.add_Click({
    [System.Windows.Forms.Clipboard]::SetText("http://127.0.0.1:$Port/v1")
    $notify.ShowBalloonTip(2000, "AG-Shield", "Base URL copied to clipboard!", [System.Windows.Forms.ToolTipIcon]::Info)
})

$contextMenu.Items.Add("-")

$menuStatus = $contextMenu.Items.Add("Status: Running")
$menuStatus.Enabled = $false

$contextMenu.Items.Add("-")

$menuExit = $contextMenu.Items.Add("Exit AG-Shield")
$menuExit.add_Click({
    $notify.Visible = $false
    if ($NodePid -gt 0) {
        Stop-Process -Id $NodePid -Force -ErrorAction SilentlyContinue
    }
    [System.Windows.Forms.Application]::Exit()
})

$notify.ContextMenuStrip = $contextMenu

# Double click opens dashboard
$notify.add_DoubleClick({
    [System.Diagnostics.Process]::Start("http://127.0.0.1:$Port/ui")
})

# Show balloon notification on startup
$notify.ShowBalloonTip(2500, "AG-Shield Active", "Shield proxy running on http://127.0.0.1:$Port/v1`nDouble-click to open dashboard.", [System.Windows.Forms.ToolTipIcon]::Info)

# Monitor parent Node process; if it dies, exit tray
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
