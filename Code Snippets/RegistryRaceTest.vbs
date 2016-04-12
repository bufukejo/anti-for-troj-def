Set shell = WScript.CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
Set hive = fs.GetFile("C:\Users\Alpha\NTUSER.DAT")
Dim flushtime
flushtime = hive.DateLastModified

shell.RegWrite "HKCU\Software\FindMe1", "Keyword1", "REG_SZ"
shell.RegWrite "HKCU\Software\FindMe2", "Keyword2", "REG_SZ"

WScript.Sleep 1000

shell.RegDelete "HKCU\Software\FindMe1"

Do While hive.DateLastModified = flushtime
        WScript.Sleep 1000
        Set hive = fs.GetFile("C:\Users\Alpha\NTUSER.DAT")
Loop
flushtime = hive.DateLastModified

shell.RegDelete "HKCU\Software\FindMe2"

Do While hive.DateLastModified = flushtime
        WScript.Sleep 1000
        Set hive = fs.GetFile("C:\Users\Alpha\NTUSER.DAT")
Loop
MsgBox "Take the snapshot now!"

