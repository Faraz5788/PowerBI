# MicrosoftPowerBIMgmt – what you can do with it

Notes and ready-to-run scripts for the `MicrosoftPowerBIMgmt` PowerShell module.

```powershell
Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser
Update-Module  -Name MicrosoftPowerBIMgmt
```

The module is a roll-up of: **Profile** (sign-in, REST), **Workspaces**, **Reports**, **Data**, **Capacities** and **Admin**.

> **Scope matters.** Most cmdlets take `-Scope Individual` (default – only what you're a member of) or
> `-Scope Organization` (whole tenant – needs the Fabric / Power BI Administrator role).

---

## 1. Audit who has access to which workspace

Handy for sensitive data (e.g. HR) governance.

```powershell
Connect-PowerBIServiceAccount
Get-PowerBIWorkspace -Scope Organization -Include All -All |
  ForEach-Object { $ws = $_; $_.Users |
    Select-Object @{n='Workspace';e={$ws.Name}}, Identifier, AccessRight, PrincipalType } |
  Export-Csv ws_access.csv -NoTypeInformation
```

Script: [`Export-WorkspaceAccess.ps1`](Export-WorkspaceAccess.ps1)

## 2. See who is actually viewing reports (activity log)

`Get-PowerBIActivityEvent` returns tenant audit events. Only **30 days** of history are kept and each call
must stay within **one UTC day**, so loop day by day.

```powershell
Get-PowerBIActivityEvent -StartDateTime '2026-11-19T00:00:00' -EndDateTime '2026-11-19T23:59:59' `
  -ActivityType ViewReport | ConvertFrom-Json
```

Join this with a report inventory to find reports nobody opens, and who opens the sensitive ones.

Script: [`Export-ActivityLog.ps1`](Export-ActivityLog.ps1) – downloads one CSV per day and skips days already
saved, so scheduling it daily builds history beyond the 30-day limit.

## 3. Inventory reports, datasets and owners

`Get-PowerBIReport`, `Get-PowerBIDataset`, `Get-PowerBIDashboard`, `Get-PowerBIDatasource` – which report sits
on which dataset, who configured it, what it connects to.

Script: [`Export-ReportDatasetInventory.ps1`](Export-ReportDatasetInventory.ps1)

## 4. Call any REST API endpoint

`Invoke-PowerBIRestMethod` calls `https://api.powerbi.com/v1.0/myorg/<Url>` with your signed-in token –
anything the REST API can do: refresh history, trigger refreshes, take over datasets, refresh schedules.

```powershell
Invoke-PowerBIRestMethod -Url "groups/<workspaceId>/datasets/<datasetId>/refreshes?`$top=10" -Method Get |
  ConvertFrom-Json
```

Script: [`Export-RefreshHistory.ps1`](Export-RefreshHistory.ps1)

## 5. Manage content

| Task | Cmdlet |
|---|---|
| Download a report as .pbix | `Export-PowerBIReport -WorkspaceId <id> -Id <reportId> -OutFile report.pbix` |
| Publish a .pbix | `New-PowerBIReport -Path report.pbix -WorkspaceId <id>` |
| Delete a report | `Remove-PowerBIReport -WorkspaceId <id> -Id <reportId>` |
| Add a workspace user | `Add-PowerBIWorkspaceUser -Id <wsId> -UserPrincipalName a@b.com -AccessRight Viewer` |
| Remove a workspace user | `Remove-PowerBIWorkspaceUser -Id <wsId> -UserPrincipalName a@b.com` |

## Troubleshooting

```powershell
Resolve-PowerBIError -Last   # shows the real error behind a failed cmdlet
```

## Scripts in this folder

| Script | Output | Needs admin? |
|---|---|---|
| `Export-WorkspaceAccess.ps1` | Workspace → user → access right | For whole tenant (`-Scope Organization`) |
| `Export-ActivityLog.ps1` | One CSV per day of audit events | Yes |
| `Export-ReportDatasetInventory.ps1` | Report → dataset → owner | For whole tenant |
| `Export-RefreshHistory.ps1` | Last N refreshes per dataset | No (workspaces you belong to) |

All scripts sign you in if you aren't already, and write CSVs to `.\output` by default.
