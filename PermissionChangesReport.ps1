function Parse-PermissionsFile{
    param($FilePath)
    $permissions = @{}
    $currentPath = ""

    foreach($line in Get-Content $FilePath){
        $trimmedLine = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmedLine)){continue}

        if ($trimmedLine -match "^[A-Z]:\\"){
        $currentPath = $trimmedLine
        $permissions[$currentPath] = @()
        }
       
        elseif ($currentPath) {
            # Add permission line to current folder
            $permissions[$currentPath] += $trimmedLine
        }

    }
    return $permissions
}


function Compare-Permissions{
param (
        [string]$OldFile,
        [string]$NewFile,
        [string]$HtmlOutput = "PermissionChangesReport.html"
    )

    $oldPerms = Parse-PermissionsFile -FilePath $OldFile
    $newPerms = Parse-PermissionsFile -FilePath $NewFile
    $allPaths = $oldPerms.Keys + $newPerms.Keys | Sort-Object -Unique
    $results = @()

foreach($path in $allPaths){
    $old = $oldPerms[$path] 
    $new = $newPerms[$path]

    
    if (-not $old) {
        $results +=[PSCustomObject]@{
        Path = $path
        ChangeType = "New Folder"
        Changes = $new | Sort-Object | ForEach-Object{
                    @{ Type = "Added"; Permission = $_ }
                }

        }
        #Write-Host "`nNew folder detected: $path"
        #Write-Host "Permissions: $new"
    }
    elseif (-not $new){
        $results += [PSCustomObject]@{
                Path = $path
                ChangeType = "Removed Folder"
                Changes = $old | Sort-Object | ForEach-Object {
                    @{ Type = "Removed"; Permission = $_ }
                }
        #Write-Host "`nRemoved folder: $path"
        #Write-Host "Previous permissions: $old"
        }
        }
    else{
    $oldSorted = $old | Sort-Object
    $newSorted = $new | Sort-Object
    
    if (($oldSorted -join "`n") -ne ($newSorted -join "`n")) {
            #Write-Host "`nPermissions changed in: $path"

            $diff = Compare-Object -ReferenceObject $oldSorted -DifferenceObject $newSorted
            $changes = @()

            foreach ($change in $diff) {
                $changeType = if ($change.SideIndicator -eq '=>') { "Added" } else { "Removed" }
                $changes += @{ Type = $changeType; Permission = $change.InputObject }
            }
             $results += [PSCustomObject]@{
                    Path = $path
                    ChangeType = "Permissions Changed"
                    Changes = $changes}

        }
    }
    }
     # Group results by ChangeType
    $grouped = $results | Group-Object -Property ChangeType
        # Generate HTML
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Folder Permission Changes Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2F4F4F; }
        h2 { color: #4B0082; margin-top: 40px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 30px; }
        th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .added { color: green; }
        .removed { color: red; }
    </style>
</head>
<body>
    <h1>Folder Permission Changes Report</h1>
"@

    foreach ($group in $grouped) {
        $html += "<h2>$($group.Name)</h2>`n"
        foreach ($entry in $group.Group) {
            $html += "<h3>$($entry.Path)</h3>`n"
            $html += "<table><tr><th>Change Type</th><th>Permission</th></tr>`n"
            foreach ($change in $entry.Changes) {
                $cssClass = if ($change.Type -eq "Added") { "added" } else { "removed" }
                $html += "<tr><td class='$cssClass'>$($change.Type)</td><td>$($change.Permission)</td></tr>`n"
            }
            $html += "</table>`n"
        }
    }

    $html += "</body></html>"
    $html | Out-File -FilePath $HtmlOutput -Encoding UTF8
    Write-Host "✅ HTML report saved to: $HtmlOutput"
}

