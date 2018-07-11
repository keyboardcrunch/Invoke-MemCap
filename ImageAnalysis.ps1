param (
    [alias('Image')]
    [string]$ImagePath = $(throw "-ImagePath is required.")
)

If ( -Not (Test-Path -Path $ImagePath) ) {
    Write-Host "$ImagePath Not Found!" -ForegroundColor Red
    Exit 0
}

$Volatility = "volatility.exe"
$LogPath = Split-Path $ImagePath -Parent
$ImageName = Split-Path $ImagePath -Leaf

# Determine Profile from image name
# https://github.com/volatilityfoundation/volatility/wiki/2.6-Win-Profiles
Switch -Wildcard ( $ImageName ) {
    '*6.1.7601_x86*' { $profile = "Win7SP1x86" }
    '*6.1.7601_x64*' { $profile = "Win7SP1x64" }
    '*10.0.14393_x64*' { $profile = "Win10x64_14393" }
    '*10.0.16299_x64*' { $profile = "unsupported" }
    default { $profile = "unknown" }
}

$Plugins = @("dlllist", "pstree", "envars", "privs", "driverscan", "filescan", "netscan", "shimcache")

If ( $profile -eq "unsupported" ) {
    Write-Host "OS for this memory capture is unsupported!" -ForegroundColor Red 
    Exit 0
} ElseIf ( $profile -eq "unknown" ) {
    Write-Host "Unknown OS. Running without profile..." -ForegroundColor Yellow
    ForEach ($Plugin in $Plugins) {
        # build commandline without --profile
        Write-Host "Running $Plugin..." -ForegroundColor White
        Start-Process -FilePath $Volatility -ArgumentList "-f $ImagePath $Plugin" -Wait -WindowStyle Hidden -RedirectStandardOutput "$LogPath\$Plugin.txt" -RedirectStandardError "$LogPath\volatility_errors.txt"
        Write-Host "Done." -ForegroundColor Green
    }
} Else {
    Write-Host "Using profile $profile for analysis..." -ForegroundColor Yellow
    ForEach ($Plugin in $Plugins) {
        # build commandline with --profile=$profile
        Write-Host "Running $Plugin..." -ForegroundColor White
        Start-Process -FilePath $Volatility -ArgumentList "-f $ImagePath --profile=$profile $Plugin" -Wait -WindowStyle Hidden -RedirectStandardOutput "$LogPath\$Plugin.txt" -RedirectStandardError "$LogPath\volatility_errors.txt"
        Write-Host "Done." -ForegroundColor Green
    }
}
    