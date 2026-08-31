# Fetches fresh data from api.boligsiden.dk and writes data.json
. "$PSScriptRoot\bs-core.ps1"

Write-Host "Henter data fra api.boligsiden.dk ..."
$out = Get-BoligData
Write-Host ("  solgt:  Frederiksberg {0}, 1799 {1}" -f $out.sold.frederiksberg.Count, $out.sold.zip1799.Count)
Write-Host ("  til salg: Frederiksberg {0}, 1799 {1}" -f $out.forSale.frederiksberg.Count, $out.forSale.zip1799.Count)

$dest = "$PSScriptRoot\data.json"
$json = $out | ConvertTo-Json -Depth 8 -Compress
[System.IO.File]::WriteAllText($dest, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Skrev $dest ($((Get-Item $dest).Length) bytes)"
