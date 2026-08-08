' KFAI - Abre o AionUi com router + ollama ligados em segundo plano.
' Sem janela de console preta: o script roda escondido e o AionUi abre na frente.
' Clique duplo neste arquivo = pronto.
Option Explicit
Dim fso, sh, dir, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\kfai-launch.ps1"" -App aionui"
sh.Run cmd, 0, False
