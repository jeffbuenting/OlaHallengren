<#
    Powershell module to install and configure OLA Halegreen backup scripts on a SQL Server
#>

#-------------------------------------------------------------------------------------

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

#-------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------