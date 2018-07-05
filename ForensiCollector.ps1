<#
.SYNOPSIS
    Collects forensic information from a remote machine.

.DESCRIPTION
    Collects forensic information from a remote machine. Forensic data is archived to the SOC share.

.PARAMETER ComputerName
    The device to investigate.

.PARAMETER Collect
    Data to collect. Image, Events, SystemInfo, Full.

.PARAMETER Save
    Optional. Location to save forensic data.

.EXAMPLE
    ForensiCollector.ps1 -ComputerName WIN10ETL -Collect Full

.EXAMPLE
    ForensiCollector.ps1 -ComputerName WIN10ETL -Collect Events

.NOTES
    File Name: ForensiCollector.ps1
    Author: keyboardcrunch
#>

param (
    [string]$ComputerName = $(throw "-ComputerName is required."),
    [ValidateSet('Image','Events','Full','SysInfo')]
    [string]$Collect = $(throw "-collect is required."),
    [string]$Save
)

$ErrorActionPreference = "Continue"

$Job = 0
$Date = (Get-Date -Format MM-dd-yy)
$Share = "\\soc.corp.com\Incident Response\EVIDENCE\"
$WinPMem = "\\soc.corp.com\Incident Response\Tools\winpmem.exe"
$ImageScript = "\\soc.corp.com\Incident Response\Tools\ExecuteWinpmem.ps1"
$email_to = "soc@corp.com"
$email_from = "soc@corp.com"
$email_server = "mail.corp.com"

If ( $Save ) {
    Try { # Check save permissions
        New-Item -Path $Save -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } Catch {
        Write-Host 'Failed to write to archive path.' -ForegroundColor Red
        Write-Host $Save -ForegroundColor Red
        Exit 1
    }
    $Archive = "$Save\$ComputerName\$Date\"
} Else {
    $Archive = "$Share\$ComputerName\$Date\"
}

$Banner = "
                                                               
 _____                     _ _____     _ _         _           
|   __|___ ___ ___ ___ ___|_|     |___| | |___ ___| |_ ___ ___ 
|   __| . |  _| -_|   |_ -| |   --| . | | | -_|  _|  _| . |  _|
|__|  |___|_| |___|_|_|___|_|_____|___|_|_|___|___|_| |___|_|  
"

Write-Host $Banner -ForegroundColor Cyan
Get-Date

Function ImageCapture {
    Write-Host "Deploying winpmem to $ComputerName..." -ForegroundColor White
    Copy-Item -Path $WinPMem -Destination "\\$ComputerName\C$\Windows\Temp\" -Force
    Try {
        Write-Host "`tExecuting winpmem. Grab a coffee?" -ForegroundColor Yellow
        $Image = Invoke-Command -ComputerName $ComputerName -FilePath $ImageScript
        Write-Host "Completed." -ForegroundColor Green
        Remove-Item "\\$ComputerName\C$\Windows\Temp\winpmem.exe" -Force | Out-Null
        Move-Item -Path "\\$ComputerName\C$\Windows\Temp\$Image" -Destination $Archive -Force | Out-Null
    } Catch {
        Write-Host "`tFailed to execute memory capture!" -ForegroundColor Red
        $Job = $Job++
    }
}

Function EventCapture {
    # Dump Eventlogs - need to add powershell logs
    Write-Host "`tDumping event logs..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process -FilePath "wevtutil" -ArgumentList "epl System C:\Windows\Temp\System.evtx" -Verb RunAs -Wait }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process -FilePath "wevtutil" -ArgumentList "epl Application C:\Windows\Temp\Application.evtx" -Verb RunAs -Wait }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process -FilePath "wevtutil" -ArgumentList "epl Security C:\Windows\Temp\Security.evtx" -Verb RunAs -Wait }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process -FilePath "wevtutil" -ArgumentList 'epl "Windows PowerShell" C:\Windows\Temp\PowerShell.evtx' -Verb RunAs -Wait }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process -FilePath "wevtutil" -ArgumentList 'epl "Microsoft-Windows-TaskScheduler/Operational" C:\Windows\Temp\Microsoft-Windows-TaskScheduler.evtx' -Verb RunAs -Wait }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process -FilePath "wevtutil" -ArgumentList 'epl "Microsoft-Windows-Windows Firewall With Advanced Security/Firewall" C:\Windows\Temp\Firewall.evtx' -Verb RunAs -Wait }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process -FilePath "wevtutil" -ArgumentList 'epl "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" C:\Windows\Temp\Microsoft-Windows-TerminalServices-LocalSessionManager.evtx' -Verb RunAs -Wait }
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process -FilePath "wevtutil" -ArgumentList 'epl "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" C:\Windows\Temp\Microsoft-Windows-TerminalServices-RemoteConnectionManager.evtx' -Verb RunAs -Wait }

    Move-Item -Path "\\$ComputerName\C$\Windows\Temp\System.evtx" -Destination $Archive -Force | Out-Null
    Move-Item -Path "\\$ComputerName\C$\Windows\Temp\Application.evtx" -Destination $Archive -Force | Out-Null
    Move-Item -Path "\\$ComputerName\C$\Windows\Temp\Security.evtx" -Destination $Archive -Force | Out-Null
    Move-Item -Path "\\$ComputerName\C$\Windows\Temp\PowerShell.evtx" -Destination $Archive -Force | Out-Null
    Move-Item -Path "\\$ComputerName\C$\Windows\Temp\Microsoft-Windows-TaskScheduler.evtx" -Destination $Archive -Force | Out-Null
    Move-Item -Path "\\$ComputerName\C$\Windows\Temp\Firewall.evtx" -Destination $Archive -Force | Out-Null
    Move-Item -Path "\\$ComputerName\C$\Windows\Temp\Microsoft-Windows-TerminalServices-LocalSessionManager.evtx" -Destination $Archive -Force | Out-Null
    Move-Item -Path "\\$ComputerName\C$\Windows\Temp\Microsoft-Windows-TerminalServices-RemoteConnectionManager.evtx" -Destination $Archive -Force | Out-Null
}

Function Notify {
    Write-Host "`tSending notifications..." -ForegroundColor Yellow
    If ($Job -gt 1) {
        $Subject = "$Computername - Forensic Capture Task Failure"
        $Message = "Forensic Capture from $ComputerName has been archived at `n$Archive"
        Send-MailMessage -To $email_to -From $email_from -Subject $Subject -Body $Message -SmtpServer $email_server
    } Else {
        $Subject = "$Computername - Forensic Capture Task Success"
        $Message = "Forensic Capture from $ComputerName has been archived at `n$Archive"
        Send-MailMessage -To $email_to -From $email_from -Subject $Subject -Body $Message -SmtpServer $email_server
    }
}

Function OtherCapture {
    # Other forensic Data
    Write-Host "`tDumping Local Admins..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { # Local Administrators
        & net localgroup administrators | Select-Object -Skip 6 | ? {
            $_ -and $_ -notmatch "The command completed successfully" 
        } | % {
            $o = "" | Select-Object Account
            $o.Account = $_
            $o
        }
    } | Out-File -FilePath "$Archive\Admins.txt" -Force -ErrorAction SilentlyContinue

    Write-Host "`tDumping Shares list..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        if (Get-Command Get-SmbShare) {
            Get-SmbShare
        } Else { Invoke-Command -ScriptBlock { get-wmiobject win32_share | where-object { $_.Description -ne "" } } }
    } | Out-File -FilePath "$Archive\Shares.txt" -Force -ErrorAction SilentlyContinue

    Write-Host "`tDumping Patch List..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-HotFix | Sort-Object InstalledOn } | Out-File -FilePath "$Archive\patches.txt" -Force -ErrorAction SilentlyContinue

    Write-Host "`tDumping Certs list..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        Set-Location Cert:
        ls -r * | Select-Object PSParentPath,FriendlyName,NotAfter,NotBefore,SerialNumber,Thumbprint,Issuer,Subject
    } | Out-File -FilePath "$Archive\Certs.txt" -Force -ErrorAction SilentlyContinue

    # CCM Recent Apps - Enabled at Branches but not on OPs machines??
    Write-Host "`tDumping CCM Recent Apps..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-WmiObject -Namespace "root\CCM\SoftwareMeteringAgent" -Query "Select * from CCM_RecentlyUsedApps" } | Out-File -FilePath "$Archive\RecentApps.txt" -Force

    Write-Host "`tDumping Prefetch..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        $pfconf = (Get-ItemProperty "hklm:\system\currentcontrolset\control\session manager\memory management\prefetchparameters").EnablePrefetcher 
        Switch -Regex ($pfconf) {
            "[1-3]" {
                $o = "" | Select-Object FullName, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc
                ls $env:windir\Prefetch\*.pf | % {
                    $o.FullName = $_.FullName;
                    $o.CreationTimeUtc = Get-Date($_.CreationTimeUtc) -format o;
                    $o.LastAccesstimeUtc = Get-Date($_.LastAccessTimeUtc) -format o;
                    $o.LastWriteTimeUtc = Get-Date($_.LastWriteTimeUtc) -format o;
                    $o
                }
            }
            default {
                Write-Output "Prefetch not enabled on ${env:COMPUTERNAME}."
            }
        }
    } | Out-File -FilePath "$Archive\prefetch.txt" -Force -ErrorAction SilentlyContinue
}




If ( Test-Connection -ComputerName $ComputerName -Count 3 -Quiet ) { 
    Try { # Check archive permissions
        New-Item -Path $Archive -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } Catch {
        Write-Host 'Failed to write to archive path.' -ForegroundColor Red
        Write-Host $Archive -ForegroundColor Red
        Exit 1
    }

    # System Info
    Write-Host "`tGrabbing system information..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $ComputerName -ScriptBlock { & systeminfo /fo list } | Out-File -FilePath "$Archive\SystemInfo.txt" -Force

    Switch ( $Collect ) {
        "Image" { ImageCapture }
        "Events" { EventCapture }
        "Full" {
            ImageCapture
            EventCapture
            OtherCapture
            Notify
        }
        "SysInfo" { Continue }
    }
    Get-Date
    Write-Host "Completed!" -ForegroundColor Green
} Else { 
    Write-Host "$ComputerName is offline or unreachable." -ForegroundColor Red
}
