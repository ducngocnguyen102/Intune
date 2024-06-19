<#
.SYNOPSIS
    Getting access token for Graph API using MSAL.PS
    Update device primary user using Microsoft Graph REST API
.LINK
    https://bonguides.com/how-to-get-an-access-token-for-microsoft-graph-powershell-api/
    https://scripting.up-in-the.cloud/powershell/i-want-more-the-graph-result-limit-of-100-999.html
#>

#Requires -Modules MSAL.PS
#Requires -Modules Microsoft.Powershell.SecretStore
#Requires -Modules Microsoft.PowerShell.SecretManagement

#Decrypt SecretStore
Unlock-SecretStore -Password ((Import-Clixml C:\Windows\CSOD\Key\Automation.xml) | ConvertTo-SecureString)

# Declare Variables
$date = Get-Date -Format yyyy-MM-dd-hh-mm-ss
$filename = "Update-PrimayUser_" + $date
$error_log = @()
$clientId = "78a202bc-7de5-45ef-b8df-167d1544f012"
$tenantId = "7f943f02-1859-4b47-a7fc-f910aaa46cf7"
$secureSecret = Get-Secret -Name IntuneAutomation

# Getting Access Token
$msalToken = Get-MsalToken -ClientId $clientId -TenantId $tenantId -ClientSecret $secureSecret
$authToken = @{
    Authorization = "Bearer $($msalToken.AccessToken)"
}

# Getting all managed devices
# ===========================
$graph_version = "Beta"
$resource = "deviceManagement/managedDevices"
$top = 999 #result size
$uri_list_manageddevices = "https://graph.microsoft.com/$graph_version/$resource"+"?`$top=$top"

$all_manageddevices = @()
While ($uri_list_manageddevices -ne $Null) {
    $data = Invoke-RestMethod -Method GET -Headers $authToken -Uri $uri_list_manageddevices
    $all_manageddevices += $data.Value
    $uri_list_manageddevices = $data.'@Odata.NextLink'  #@odata.nextLink is just the URL that you use in the looped next query. Do this until @odata.nextLink is empty
}

# Apply filters
# ==================================
$all_windows = $all_manageddevices | Where-Object {$_.OperatingSystem -eq "Windows"}
$primaryuser_notassigned_list = $all_windows | Where-Object {$_.userPrincipalName -eq ""} 
$primaryuser_notassigned_list | Select usersLoggedOn


$primaryuser_notassigned_list | ForEach-Object {

    #Declar Variables
    $DeviceName = $_.deviceName
    $IntuneDeviceId = $_.id
    $userid = ($_.usersLoggedOn | Select-Object -Last 1).userId #Intune might capture multiple users signed in. Select the recent one that signed in.
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref" #
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    $userUri = "https://graph.microsoft.com/$graphApiVersion/users/" + $userId
    $id = "@odata.id"
    $JSON = @{ $id="$userUri" } | ConvertTo-Json -Compress

    

    Try {
        Write-Output "[$DeviceName] setting primary user as $userid"
        Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType "application/json"
    }
    Catch {
        $error_log += Write-Output "[$DeviceName] $($_.Exception.Message)"
        
    }

}

$error_log | Out-File "C:\Windows\CSOD\Code\Logs\$filename.txt" -Append -Force


