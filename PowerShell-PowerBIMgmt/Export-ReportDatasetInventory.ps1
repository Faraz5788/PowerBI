<#
.SYNOPSIS
    Exports every report with its workspace, dataset and dataset owner.
.EXAMPLE
    .\Export-ReportDatasetInventory.ps1 -Scope Organization
#>
param(
    [ValidateSet('Individual', 'Organization')]
    [string]$Scope = 'Organization',
    [string]$OutputFolder = '.\output'
)

Import-Module MicrosoftPowerBIMgmt
try { Get-PowerBIAccessToken | Out-Null } catch { Connect-PowerBIServiceAccount | Out-Null }

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$workspaces = Get-PowerBIWorkspace -Scope $Scope -All

$rows = foreach ($ws in $workspaces) {
    try {
        $datasets = @{}
        Get-PowerBIDataset -Scope $Scope -WorkspaceId $ws.Id | ForEach-Object { $datasets[$_.Id.ToString()] = $_ }
        $reports = Get-PowerBIReport -Scope $Scope -WorkspaceId $ws.Id
    } catch {
        Write-Warning "Skipped workspace '$($ws.Name)': $($_.Exception.Message)"
        continue
    }

    foreach ($r in $reports) {
        $ds = $null
        if ($r.DatasetId) { $ds = $datasets[$r.DatasetId.ToString()] }
        [pscustomobject]@{
            WorkspaceName      = $ws.Name
            WorkspaceId        = $ws.Id
            ReportName         = $r.Name
            ReportId           = $r.Id
            ReportType         = $r.ReportType
            DatasetName        = $ds.Name
            DatasetId          = $r.DatasetId
            DatasetConfiguredBy = $ds.ConfiguredBy
            IsRefreshable      = $ds.IsRefreshable
            GatewayRequired    = $ds.IsOnPremGatewayRequired
            DatasetCreated     = $ds.CreatedDate
            WebUrl             = $r.WebUrl
        }
    }
}

$file = Join-Path $OutputFolder ("ReportDatasetInventory_{0:yyyyMMdd}.csv" -f (Get-Date))
$rows | Export-Csv $file -NoTypeInformation -Encoding UTF8
Write-Host "Saved $($rows.Count) reports to $file"
