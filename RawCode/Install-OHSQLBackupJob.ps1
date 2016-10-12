

$SQLServer = 'jeffb-sql01.stratuslivedemo.com'

#$BackupDir = "\\vaslnas.stratuslivedemo.com\SL_SQL_Backups"
$BackupDir = "\\vaslnas.stratuslivedemo.com\SL_SQL_Backups"
$CleanUpTime = 24

$Cred = Get-Credential


#--------------------------------------------------------------------------------



Function Install-OHSQLBackupJob {

<#
    .Synopsis
        Installs Ola Hallengren's SQL Backup scripts

    .Link
        Thanks to Andre Kamman for doing most of the work developing this script.

        http://cloud-dba.eu/blog/

    .Link
        https://ola.hallengren.com/  
#>

    [CmdletBinding(SupportsShouldProcess = $true)] 
    Param(
	    [parameter(Mandatory = $true, ValueFromPipeline = $true)]
	    [string[]]$SqlServer,

        [Parameter (Mandatory = $True)]
        [string]$BackupDir,

        [int]$CleanupTime,

        [string]$OlaScriptPath = "$(split-path $SCRIPT:MyInvocation.MyCommand.Path)\maintenancesolution.sql",

        [PSCredential]$Credential
	)

    Begin {
         # ----- load script if it exists.  If not download and then load.

        Write-Verbose "Checking for scripts at $OlaScriptPath"
        if ( -Not ( Test-path -Path $OlaScriptPath ) ) {
            Throw "Install-OHSQLBackupJob : MaintenanceSolution.sql not found at $OlaScriptPath.  Please download Ola Hallengrens's script from https://ola.hallengren.com/scripts/MaintenanceSolution.sql"
        } 

        $MaintenanceSolution = Get-Content $OlaScriptPath


        Write-Verbose "Updating script with parameter data"
        if ( $BackupDir ) { $MaintenanceSolution = $MaintenanceSolution.replace( "SET @BackupDirectory     = N'C:\Backup'","SET @BackupDirectory     = N'$BackupDir'" ) }
        if ( $CleanUptime ) { $MaintenanceSolution = $MaintenanceSolution.Replace( "SET @CleanupTime         = NULL","SET @CleanupTime         = $CleanUpTime" ) }

        $MaintenanceSolution | Set-Content c:\temp\OLAScriptsInstall.sql 
        
    }

    
    Process {
        Try {
                foreach ( $S in $SQLServer ) {
                    $out = "Installing Maintenancesolution on server: {0}" -f $S
                    Write-Verbose $out

                    if ( -Not ( Test-Connection -ComputerName $S -Quiet -Count 1 ) ) { Write-Error "$S does not exist or is not online"; Continue }

                        If ( $Credential ) {
                            if ( $Credential.UserName -match '\\' ) {
                                    # ----- Username has domain name so using windows auth
                                    Write-verbose "Running with Windows Auth"
                                    # ----- Copy sql script to remote server
                                    copy-item c:\temp\olascriptsinstall.sql \\$S\c$\temp -ErrorAction Stop
                                    invoke-command -ComputerName $S -Credential $Credential -ArgumentList $S -ScriptBlock { 
                                        Param (
                                            [String]$C
                                        )

                                        Invoke-Sqlcmd -ServerInstance $C -Database Master -InputFile c:\temp\olascriptsinstall.sql
                                    }
                                }
                                Else {
                                    # ----- Username does not have domain name so SQL Auth
                                    Write-Verbose "Running with SQL auth"
                                    Invoke-Sqlcmd -ServerInstance $S -Database Master -InputFile c:\temp\olascriptsinstall.sql -Username $($Credential.UserName) -Password $($Credential.GetNetworkCredential().Password)
                            }
                        }
                        else {
                            Write-Verbose "Running under current logged in user"
                            Invoke-Sqlcmd -ServerInstance $S -Database Master -InputFile c:\temp\olascriptsinstall.sql
                    }   
                } 
             }
            Catch {
                Throw "Install-OHSQLBackupJob : $($_.Exception.Message)"
        }       
    }    
}


import-module F:\GitHub\sql\sql.psd1 -force

Try {
        Foreach ( $server in $SQLServer ) {
    
            # ----- Install OLA Backup Scripts
            Install-OHSQLBackupJob -SqlServer $Server -BackupDir $BackupDir -CleanupTime $CleanUpTime -Credential $Cred  -Verbose -ErrorAction Stop

            # ----- Create SQL Job Schedules
            if ( -Not ( Get-SQLSchedule -SQLInstance $Server -Name Midnight -credential $Cred -Force ) ) { New-SQLSchedule -SQLInstance $Server -Name Midnight -Frequency Daily -StartTime 000000 -Credential $Cred -Force -verbose }
            if ( -Not ( Get-SQLSchedule -SQLInstance $Server -Name "10pm" -credential $Cred ) ) { New-SQLSchedule -SQLInstance $Server -Name "10pm" -Frequency Daily -StartTime 220000 -Credential $Cred -Force -verbose }
            if ( -Not ( Get-SQLSchedule -SQLInstance $Server -Name "2am" -credential $Cred ) ) { New-SQLSchedule -SQLInstance $Server -Name "2am" -Frequency Daily -StartTime 020000 -Credential $Cred -force -verbose }
            if ( -Not ( Get-SQLSchedule -SQLInstance $Server -Name "Sunday Midnight" -credential $Cred ) ) { New-SQLSchedule -SQLInstance $Server -Name "Sunday Midnight" -Frequency Weekly -FreqInterval 1 -StartTime 000000 -Credential $Cred -Force -verbose }

            # ----- Assign schedule to Job
            # ----- Misc Jobs
            Get-SQLJob -SQLInstance $Server -Name 'sp_delete_backuphistory'  | Set-SQLJob -SQLInstance $Server -ScheduleName "Sunday Midnight" -AttachSchedule -Credential $Cred
            Get-SQLJob -SQLInstance $Server -Name 'CommandLog Cleanup' | Set-SQLJob -SQLInstance $Server -ScheduleName "Sunday Midnight" -AttachSchedule -Credential $Cred
            Get-SQLJob -SQLInstance $Server -Name 'sp_purge_jobhistory' | Set-SQLJob -SQLInstance $Server -ScheduleName "Sunday Midnight" -AttachSchedule -Credential $Cred
            Get-SQLJob -SQLInstance $Server -Name 'Output File Cleanup' | Set-SQLJob -SQLInstance $Server -ScheduleName "Sunday Midnight" -AttachSchedule -Credential $Cred

            # ----- Full Backups
            Get-SQLJob -SQLInstance $Server -Name 'DatabaseBackup - USER_DATABASES - LOG' | Set-SQLJob -SQLInstance $Server -ScheduleName "Midnight" -AttachSchedule -Credential $Cred
            Get-SQLJob -SQLInstance $Server -Name 'DatabaseBackup - USER_DATABASES - FULL' | Set-SQLJob -SQLInstance $Server -ScheduleName "Midnight" -AttachSchedule -Credential $Cred
            Get-SQLJob -SQLInstance $Server -Name 'DatabaseBackup - SYSTEM_DATABASES - FULL' | Set-SQLJob -SQLInstance $Server -ScheduleName "Midnight" -AttachSchedule -Credential $Cred

            # ----- Integrity Checks
            Get-SQLJob -SQLInstance $Server -Name 'DatabaseIntegrityCheck - USER_DataBASES' | Set-SQLJob -SQLInstance $Server -ScheduleName "10pm" -AttachSchedule -Credential $Cred
            Get-SQLJob -SQLInstance $Server -Name 'DatabaseIntegrityCheck - SYSTEM_DataBASES' | Set-SQLJob -SQLInstance $Server -ScheduleName "10pm" -AttachSchedule -Credential $Cred

            # ----- Optimize
            Get-SQLJob -SQLInstance $Server -Name 'IndexOptimize - USER_DATABASES' | Set-SQLJob -SQLInstance $Server -ScheduleName "2am" -AttachSchedule -Credential $Cred
        }
    }
    catch {
        Throw "Oops Error.  $($_.Exception.Message)"
}


