Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "D:\Tools\omnix-shield"
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""D:\Tools\omnix-shield\tray.ps1"" -Port 20129", 0, False
