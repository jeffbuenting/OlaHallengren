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
	    [string]$SqlServer,

        [string]$BackupDir,

        [int]$CleanupTime,

        [string]$Schedule,

        [string]$OlaScriptPath = "$(split-path $SCRIPT:MyInvocation.MyCommand.Path)\maintenancesolution.sql"
	)

    Begin {
         # ----- load script if it exists.  If not download and then load.
        if ( -Not ( Test-path -Path $OlaScriptPath ) ) {
            Throw "Install-OHSQLBackupJob : MaintenanceSolution.sql not found at $OlaScriptPath.  Please download Ola Hallengrens's script from https://ola.hallengren.com/scripts/MaintenanceSolution.sql"
        } 

        $MaintenanceSolution = Get-Content $OlaScriptPath

        # ----- Modifying script to work outside of SMSS (removing GO lines).  and with the passed parameters

        $script = @()
        [string]$scriptpart

        foreach($line in $MaintenanceSolution)
        {   
            if ($line -ne "GO")
            {
                if ($BackupDir -and $line -match "Specify the backup root directory")
                {
                    $line = $line.Replace("C:\Backup", $BackupDir)
                }
                if ($CleanupTime -and $line -match "Time in hours, after which backup files are deleted")
                {
                    $line = $line.Replace("NULL", $CleanupTime)
                }

                $scriptpart += $line + "`n"
            }
            else
            {
                $properties = @{Scriptpart = $scriptpart}
                $newscript = New-Object PSObject -Property $properties
                $script += $newscript
                $scriptpart = ""
                $newscrpt = $null
            }
        }
    }

    PROCESS
    {
        $out = "Installing Maintenancesolution on server: {0}" -f $SqlServer
        Write-Verbose $out

        $ConnectionString = "Server = $SqlServer ; Database = master; Integrated Security = True;"
        $Connection = New-Object System.Data.SQLClient.SQLConnection 
        $Connection.ConnectionString = $ConnectionString      
        $Connection.Open();
        $Command = New-Object System.Data.SQLClient.SQLCommand 
        $Command.Connection = $Connection


        foreach ($scriptpart in $script)
        {
            $Command.CommandText = $($scriptpart.scriptpart)
            $niks = $Command.ExecuteNonQuery();           
        }
        if ($Schedule)
        {
            $Command.CommandText = get-content $Schedule
            $niks = $Command.ExecuteNonQuery();
        }

        $Connection.Close();            
    }
}


Install-OHSQLBackupJob -Verbose