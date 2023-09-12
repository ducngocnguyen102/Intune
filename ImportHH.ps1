[System.Net.ServicePointManager]::SecurityProtocol = 'TLS12'
 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force -Confirm:$false 
Install-PackageProvider -Name NuGet -force  
Install-Script -Name Get-WindowsAutoPilotInfo -Force -Confirm:$False 
Get-WindowsAutoPilotInfo -Online 
