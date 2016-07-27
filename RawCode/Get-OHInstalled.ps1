import-module F:\GitHub\sql\sql.psd1 -force -DisableNameChecking

$Cred = get-Credential stratuslivedemo\administrator

$Exclude = 'SL-TS1.stratuslivedemo.com','SL-JeffB.stratuslivedemo.com','sl-JimFunari.stratuslivedemo.com','jpatterson-pc.stratuslivedemo.com','jeffb-SQL01.stratuslivedemo.com','jeffb-SQL02.stratuslivedemo.com','jeffb-SQL03.stratuslivedemo.com','vadataconv01.stratuslivedemo.com','vadataconv02.stratuslivedemo.com'


#$Servers = 'supportsql.stratuslivedemo.com'
$Servers = get-adcomputer -filter * -Searchbase "ou=Servers,DC=Stratuslivedemo,DC=com" -SearchScope Subtree | where { $_.DNSHostName.tolower() -notin $Exclude } | Select-Object -ExpandProperty DNSHostname 



$SQLServers =@()
$ServerOlaJobs = @()

Foreach ( $S in $Servers ) {
    
    "Checking $S"

    # ----- Check if SQL is installed
    if ( -Not (Get-Service -ComputerName $S| where { ($_.DisplayName -Like "SQL Server (*" ) -and ($_.Status -eq "Running") } )  ) { Continue }
    
    # ----- Save a list of SQL servers
    $SQLServers += $S

    $OLAJobs = get-sqljob -SQLInstance $S -Credential $Cred -Force | where Description -like '*ola.hallengren.com' 

    # ----- Show warning if the OLA backup jobs are missing and move to next Server
    if ( -Not $OLAJobs ) {
        Write-Warning "$S is missing the OLA backup jobs"

        $NoJobs = New-Object -TypeName PsCustomObject -Property @{
            SQLInstance = $S
            Name = ''
            Schedule_Name = ''
        }

        $ServerOLAJobs += $NoJobs

        Continue
    }

    # ----- Check Jobs for correct Schedule
    $OLAJobs | Select-Object @{N='SQLInstance';E = {$S}},Name,Schedule_Name | Format-Table 

    $ServerOlaJobs += $OLAJobs | Select-Object @{N='SQLInstance';E = {$S}},Name,Schedule_Name
}

# ----- Save SQL Servers
$SQLServers | Out-file c:\temp\SQLServers.txt

$ServerOlaJobs | select-object SQLInstance,Name | Out-GridView 