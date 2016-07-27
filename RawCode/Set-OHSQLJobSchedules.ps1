import-module F:\GitHub\sql\sql.psd1 -force -DisableNameChecking

$Cred = get-Credential stratuslivedemo\administrator

$SqlServer = 'qa4sql.stratuslivedemo.com'


$OLAJobs = get-sqljob -SQLInstance $Sqlserver -Credential $Cred -Force -verbose | where Description -like '*ola.hallengren.com'

# ----- Midnight Scheduled jobs
Write-Output "-----Update Midnight jobs"
if ( -Not ( Get-SQLSchedule -SQLInstance $SQLServer -Name Midnight -credential $Cred ) ) { New-SQLSchedule -SQLInstance $SQLServer -Name Midnight -Frequency Daily -StartTime 000000 -Credential $Cred }
$OlaJobs | where { $_.Name -like "DatabaseBackup*" -and ( $_.Schedule_Name -eq "Midnight Daily" -or $_.Schedule_Name -eq "Daily Midnight" -or $_.Schedule_Name -eq "midnight" )  } | foreach {
    $_
    Set-SQLJob -SQLInstance $SQLServer -SQLJob $_ -ScheduleName Midnight -AttachSchedule -Credential $Cred
    Set-SQLJob -SQLInstance $SQLServer -SQLJob $_ -ScheduleName $_.Schedule_Name -DetachSchedule -Credential $Cred
}

# ----- 10pm Jobs
Write-Output "------Update 10pm Jobs"
if ( -Not ( Get-SQLSchedule -SQLInstance $SQLServer -Name "10pm" -credential $Cred ) ) { New-SQLSchedule -SQLInstance $SQLServer -Name "10pm" -Frequency Daily -StartTime 220000 -Credential $Cred }
$OlaJobs | where { $_.Name -like "DatabaseIntegrityCheck*" -and $_.Schedule_Name -ne "10pm"  } | foreach {
    $_
    Set-SQLJob -SQLInstance $SQLServer -SQLJob $_ -ScheduleName 10pm -AttachSchedule -Credential $Cred
    Set-SQLJob -SQLInstance $SQLServer -SQLJob $_ -ScheduleName $_.Schedule_Name -DetachSchedule -Credential $Cred
}

# ----- 2am Jobs
Write-Output "------Update 2am Jobs"
if ( -Not ( Get-SQLSchedule -SQLInstance $SQLServer -Name "2am" -credential $Cred ) ) { New-SQLSchedule -SQLInstance $SQLServer -Name "2am" -Frequency Daily -StartTime 020000 -Credential $Cred }
$OlaJobs | where { $_.Name -like "IndexOptimize*" -and $_.Schedule_Name -ne "2am"  } | foreach {
    $_
    Set-SQLJob -SQLInstance $SQLServer -SQLJob $_ -ScheduleName 2am -AttachSchedule -Credential $Cred
    Set-SQLJob -SQLInstance $SQLServer -SQLJob $_ -ScheduleName $_.Schedule_Name -DetachSchedule -Credential $Cred
}

# ----- Sunday Midnight
Write-Output "------Update Sunday Midnight Jobs"
if ( -Not ( Get-SQLSchedule -SQLInstance $SQLServer -Name "Sunday Midnight" -credential $Cred ) ) { New-SQLSchedule -SQLInstance $SQLServer -Name "Sunday Midnight" -Frequency Weekly -FreqInterval 1 -StartTime 000000 -Credential $Cred }
$OlaJobs | where { $_.Schedule_Name -ne "Midnight Sunday"  } | foreach {
    $_
    Set-SQLJob -SQLInstance $SQLServer -SQLJob $_ -ScheduleName "Sunday Midnight" -AttachSchedule -Credential $Cred
    Set-SQLJob -SQLInstance $SQLServer -SQLJob $_ -ScheduleName $_.Schedule_Name -DetachSchedule -Credential $Cred
}
