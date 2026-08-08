' KFAI - Abre o opencode (terminal) com router + ollama ligados em segundo plano.
' O opencode eh um programa de terminal, entao precisa de uma janela de console.
' Usa o Windows Terminal se existir; senao, abre um PowerShell normal.
Option Explicit
Dim fso, sh, dir, cmd, wt
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
wt = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Microsoft\WindowsApps\wt.exe"
If fso.FileExists(wt) Then
  cmd = "cmd /c start """" wt.exe -d """ & dir & """ powershell -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\kfai-launch.ps1"" -App opencode"
Else
  cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\kfai-launch.ps1"" -App opencode"
End If
sh.Run cmd, 1, False
