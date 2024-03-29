[System.Threading.Thread]::CurrentThread.CurrentCulture = New-Object "System.Globalization.CultureInfo" "en-US"

$machinename = [Environment]::MachineName; $Osversion =[System.Environment]::OSVersion.Version

#Script is triggered on logout event but also on restart so previous logout might be some time ago
$ELogs = Get-WinEvent -FilterHashtable @{ProviderName= "Microsoft-Windows-WinLogon";ID = 7002; LogName = "System"; StartTime = (Get-Date).AddHours(-168)} -ea 0 | Select -First 1
ForEach ($Event in $ELogs)
{ 
  $logouttime =  '{0:yyyyMMddmmss}' -f $Event.TimeCreated
  $eventXML = [xml]$Event.ToXml()
  $userSID = ($eventXML.Event.EventData.Data | Where-Object {$_.name -eq "UserSID"})."#text"

  #Obfuscate user identity at least somewhat
  $us = $userSID[-5..-1] -join ''

  Invoke-WebRequest -Uri "https://computerlog.local:8443/logout?cn=$machinename,user=$us,time=$logouttime,type=logout"
}


