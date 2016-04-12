Dim ie
Set cmd = WScript.CreateObject("WScript.Shell")

Do
        Set ie = CreateObject("InternetExplorer.Application")
        ie.Visible = True
        ie.Resizable = True
        
        For count = 0 to 60
                ie.Navigate "http://en.wikipedia.org/wiki/Special:Random", 1
                WScript.Sleep 30000
        Next
        
        cmd.Run("taskkill /F /IM iexplore.exe")
        WScript.Sleep 2000
Loop

