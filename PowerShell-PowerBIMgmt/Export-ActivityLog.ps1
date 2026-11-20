<#
.SYNOPSIS
    Downloads the Power BI activity log, one CSV per UTC day.
.DESCRIPTION
    The service keeps 30 days of history and each call must stay within one UTC day.
    Days already saved are skipped, so run this daily (Task Scheduler) to keep history
    beyond 30 days. Requires the Fabric / Power BI Administrator role.
.EXAMPLE
    .\Export-ActivityLog.ps1                       # last 30 complete days
    .\Export-ActivityLog.ps1 -Days 7 -ActivityType ViewReport
#>
param(
    [ValidateRange(1, 30)]
    [int]$Days = 30,
    [string]$ActivityType,
    [string]$OutputFolder = '.\output\ActivityLog'
)

Import-Module MicrosoftPowerBIMgmt
try { Get-PowerBIAccessToken | Out-Null } catch { Connect-PowerBIServiceAccount | Out-Null }

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

# Fixed columns so every daily file has the same shape
$columns = 'Id', 'CreationTime', 'UserId', 'Activity', 'Operation', 'ItemName',
           'WorkspaceName', 'WorkspaceId', 'ReportName', 'ReportId', 'DatasetName', 'DatasetId',
           'DashboardName', 'ConsumptionMethod', 'DistributionMethod', 'ClientIP', 'UserAgent'

$todayUtc = (Get-Date).ToUniversalTime().Date

for ($i = $Days; $i -ge 1; $i--) {
    $day  = $todayUtc.AddDays(-$i)
    $file = Join-Path $OutputFolder ("ActivityLog_{0:yyyyMMdd}.csv" -f $day)
    if (Test-Path $file) { Write-Host "Skip $($day.ToString('yyyy-MM-dd')) (already saved)"; continue }

    $params = @{
        StartDateTime = $day.ToString('yyyy-MM-ddT00:00:00')
        EndDateTime   = $day.ToString('yyyy-MM-ddT23:59:59')
    }
    if ($ActivityType) { $params.ActivityType = $ActivityType }

    try {
        $events = Get-PowerBIActivityEvent @params | ConvertFrom-Json
    } catch {
        Write-Warning "Failed for $($day.ToString('yyyy-MM-dd')): $($_.Exception.Message)"
        continue
    }

    @($events) | Select-Object $columns | Export-Csv $file -NoTypeInformation -Encoding UTF8
    Write-Host "Saved $(@($events).Count) events for $($day.ToString('yyyy-MM-dd'))"
}
