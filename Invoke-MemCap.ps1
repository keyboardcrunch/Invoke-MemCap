<#
.SYNOPSIS
    Deploys winpmem to run memory capture on a remote machine.

.DESCRIPTION
    Deploys winpmem to run memory capture on a remote machine. Forensic data is archived to the SOC share.

.PARAMETER ComputerName
    The device to investigate.

.EXAMPLE
    Invoke-MemCap -ComputerName WIN10ETL

.NOTES
    File Name: Invoke-MemCap.ps1
    Author: keyboardcrunch
    Date Created: 01/03/18
#>

param (
    [string]$ComputerName = $(throw "-ComputerName is required.")
)

# Script Settings
$Archive = "\\soc.corp.com\Incident Response\EVIDENCE\"
$WinPMem = "\\soc.corp.com\Incident Response\Tools\winpmem.exe"
$ImageScript = "\\soc.corp.com\Incident Response\Tools\ExecuteWinpmem.ps1"
$email_to = "soc@corp.com"
$email_from = "soc@corp.com"
$email_server = "mail.corp.com"

$Banner = "
  _____                 _                                      ___            
  \_   \_ ____   _____ | | _____        /\/\   ___ _ __ ___   / __\__ _ _ __  
   / /\/ '_ \ \ / / _ \| |/ / _ \_____ /    \ / _ \ '_ ` _ \ / /  / _` | '_ \ 
/\/ /_ | | | \ V / (_) |   <  __/_____/ /\/\ \  __/ | | | | / /__| (_| | |_) |
\____/ |_| |_|\_/ \___/|_|\_\___|     \/    \/\___|_| |_| |_\____/\__,_| .__/ 
                                                                       |_|    
"

#Clear-Host
Write-Host $Banner -ForegroundColor Cyan

If ( Test-Connection -ComputerName $ComputerName -Count 3 -Quiet ) { 
    # Copy winpmem to remote
    Write-Host "Deploying winpmem to $ComputerName..." -ForegroundColor White
    Copy-Item -Path $WinPMem -Destination "\\$ComputerName\C$\Windows\Temp\" -Force
        
    # Execute Redline
    Try {
        Write-Host "Executing winpmem. Grab a coffee?" -ForegroundColor White
        $Job = Invoke-Command -ComputerName $ComputerName -FilePath $ImageScript

        If ($Job -eq 0) {
            $Subject = "$Computername - Memory Capture Task Failure"
            $Message = "Memory Capture from $ComputerName has been archived at `n$Archive"
            Send-MailMessage -To $email_to -From $email_from -Subject $Subject -Body $Message -SmtpServer $email_server
        } Else {
            Copy-Item -Path "\\$ComputerName\C$\Windows\Temp\$Job" -Destination $Archive -Force
            $Subject = "$Computername - Memory Capture Task Success"
            $Message = "Memory Capture from $ComputerName has been archived at `n$SessionArchive"
            Send-MailMessage -To $email_to -From $email_from -Subject $Subject -Body $Message -SmtpServer $email_server
        }
        
        Write-Host "Completed." -ForegroundColor Green
        Remove-Item "\\$ComputerName\C$\Windows\Temp\winpmem.exe" -Force | Out-Null

    } Catch {
        Write-Host "Failed to execute memory capture!" -ForegroundColor Red
    }
} Else { 
    Write-Host "$ComputerName is offline or unreachable." -ForegroundColor Red
}
