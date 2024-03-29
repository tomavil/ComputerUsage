[System.Threading.Thread]::CurrentThread.CurrentCulture = New-Object "System.Globalization.CultureInfo" "en-US"

$machinename = [Environment]::MachineName; $Osversion =[System.Environment]::OSVersion.Version
	
$regexa = '.+Domain="(.+)",Name="(.+)"$'
$regexd = '.+LogonId="(\d+)"$'

#TechNet "Checking remote terminal server users"
$logontype = @{
  "0"="Local System"
  "2"="Interactive" #(Local logon)
  "3"="Network" # (Remote logon)
  "4"="Batch" # (Scheduled task)
  "5"="Service" # (Service account logon)
  "7"="Unlock" #(Screen saver)
  "8"="NetworkCleartext" # (Cleartext network logon)
  "9"="NewCredentials" #(RunAs using alternate credentials)
  "10"="RemoteInteractive" #(RDP\TS\RemoteAssistance)
  "11"="CachedInteractive" #(Local w\cached credentials)
}

$logon_sessions = @(gwmi win32_logonsession)
$logon_users = @(gwmi win32_loggedonuser)

$session_user = @{}

$logon_users |% {
  $_.antecedent -match $regexa > $nul
  $username = $matches[1] + "\" + $matches[2]
  $_.dependent -match $regexd > $nul
  $session = $matches[1]
  $session_user[$session] += $username
}


$logons = $logon_sessions |%{
  $starttime =  '{0:yyyyMMddmmss}' -f [management.managementdatetimeconverter]::todatetime($_.starttime)

  $loggedonuser = New-Object -TypeName psobject
  $loggedonuser | Add-Member -MemberType NoteProperty -Name "Session" -Value $_.logonid
  $loggedonuser | Add-Member -MemberType NoteProperty -Name "User" -Value $session_user[$_.logonid]
  $loggedonuser | Add-Member -MemberType NoteProperty -Name "Type" -Value $logontype[$_.logontype.tostring()]
  $loggedonuser | Add-Member -MemberType NoteProperty -Name "Auth" -Value $_.authenticationpackage
  $loggedonuser | Add-Member -MemberType NoteProperty -Name "StartTime" -Value $starttime

  $loggedonuser
}

#Select only most recent logon
$logon = ($logons | Where-Object {($_.Type -eq "Network") -or ($_.Type -eq "Interactive")} | Sort-Object -Property StartTime -Descending | Select -First 1)
If ($logon -eq $NULL) {
  Exit 1
}

#Obfuscate user identity at least somewhat
$logonSID = (New-Object System.Security.Principal.NTAccount($logon).User).Translate([System.Security.Principal.SecurityIdentifier]).value
$us = $logonSID[-5..-1] -join ''

$type = $logon.Type
Invoke-WebRequest -Uri "https://computerlog.local:8443/logon?cn=$machinename,user=$us,time=$starttime,type=$type"


	
