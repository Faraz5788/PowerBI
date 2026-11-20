<#
.SYNOPSIS
    Exports every workspace user and their access right to CSV.
.EXAMPLE
    .\Export-WorkspaceAccess.ps1 -Scope Organization
#>
param(
    [ValidateSet('Individual', 'Organization')]
    [string]$Scope = 'Organization',
    [string]$OutputFolder = '.\output'
)

Import-Module MicrosoftPowerBIMgmt
try { Get-PowerBIAccessToken | Out-Null } catch { Connect-PowerBIServiceAccount | Out-Null }

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

if ($Scope -eq 'Organization') {
    $workspaces = Get-PowerBIWorkspace -Scope Organization -Include All -All
} else {
    $workspaces = Get-PowerBIWorkspace -All
}

$rows = foreach ($ws in $workspaces) {
    $users = $ws.Users
    if (-not $users -and $Scope -eq 'Individual') {
        # Individual scope does not populate Users; ask the REST API instead
        try {
            $users = (Invoke-PowerBIRestMethod -Url "groups/$($ws.Id)/users" -Method Get | ConvertFrom-Json).value |
                ForEach-Object { [pscustomobject]@{
                    Identifier    = $_.identifier
                    AccessRight   = $_.groupUserAccessRight
                    PrincipalType = $_.principalType } }
        } catch { $users = @() }
    }
    foreach ($u in $users) {
        [pscustomobject]@{
            WorkspaceName = $ws.Name
            WorkspaceId   = $ws.Id
            WorkspaceType = $ws.Type
            State         = $ws.State
            User          = $u.Identifier
            AccessRight   = $u.AccessRight
            PrincipalType = $u.PrincipalType
        }
    }
}

$file = Join-Path $OutputFolder ("WorkspaceAccess_{0:yyyyMMdd}.csv" -f (Get-Date))
$rows | Export-Csv $file -NoTypeInformation -Encoding UTF8
Write-Host "Saved $($rows.Count) rows to $file"
