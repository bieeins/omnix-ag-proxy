Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "D:\Tools\omnix-shield"
WshShell.Run "node.exe ""D:\Tools\omnix-shield\index.js"" --port 20129", 0, False
