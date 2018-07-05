$Date = Get-Date -Format "MM_dd_yyyy"
$ComputerName = hostname
$Version = (Get-CimInstance Win32_OperatingSystem).Version

If ([System.Environment]::Is64BitOperatingSystem) { # 64-bit System
    $File = $ComputerName + "_" + $Version + "_x64.raw"
} Else { # 32-bit  System
    $File = $ComputerName + "_" + $Version + "_x86.raw"
}

Try {
    CD "C:\Windows\Temp\"

    Start-Process -FilePath "winpmem.exe" -ArgumentList $File -Verb RunAs -WindowStyle Hidden -Wait
    Start-Sleep -S 10
    Return $File

} Catch {
    Return 0
}