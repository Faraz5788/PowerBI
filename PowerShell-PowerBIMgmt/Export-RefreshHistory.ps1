<#
.SYNOPSIS
    Exports the latest refreshes for every refreshable dataset in the workspaces you belong to.
.DESCRIPTION
    Uses Invoke-PowerBIRestMethod against groups/{ws}/datasets/{ds}/refreshes,
    so you must be a member of each workspace (admin role not needed).
.EXAMPLE
    .\Export-RefreshHistory.ps1 -Top 20
#>
param(
    [int]$Top = 10,
    [string]$OutputFolder = '.\output'
)

Import-Module MicrosoftPowerBIMgmt
try { Get-PowerBIAccessToken | Out-Null } catch { Connect-PowerBIServiceAccount | Out-Null }

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$rows = foreach ($ws in Get-PowerBIWorkspace -All) {
    foreach ($ds in Get-PowerBIDataset -WorkspaceId $ws.Id | Where-Object IsRefreshable) {
        try {
            $url = "groups/$($ws.Id)/datasets/$($ds.Id)/refreshes?`$top=$Top"
            $refreshes = (Invoke-PowerBIRestMethod -Url $url -Method Get | ConvertFrom-Json).value
        } catch {
            Write-Warning "Skipped '$($ds.Name)' in '$($ws.Name)': $($_.Exception.Message)"
            continue
        }
        foreach ($r in $refreshes) {
            $duration = $null
            if ($r.startTime -and $r.endTime) {
                $duration = [math]::Round(([datetime]$r.endTime - [datetime]$r.startTime).TotalMinutes, 1)
            }
            [pscustomobject]@{
                WorkspaceName   = $ws.Name
                DatasetName     = $ds.Name
                DatasetId       = $ds.Id
                RefreshType     = $r.refreshType
                Status          = $r.status
                StartTime       = $r.startTime
                EndTime         = $r.endTime
                DurationMinutes = $duration
                Error           = $r.serviceExceptionJson
            }
        }
    }
}

$file = Join-Path $OutputFolder ("RefreshHistory_{0:yyyyMMdd}.csv" -f (Get-Date))
$rows | Export-Csv $file -NoTypeInformation -Encoding UTF8
Write-Host "Saved $($rows.Count) refreshes to $file"
$failed = @($rows | Where-Object Status -eq 'Failed')
if ($failed.Count) { Write-Warning "$($failed.Count) failed refreshes – check the Error column." }
