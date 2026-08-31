# Injects data.json into template.html -> index.html (single self-contained file)
$root = "C:\Users\nikam\Documents\BOligsiden App"
$enc  = New-Object System.Text.UTF8Encoding($false)
$tpl  = [System.IO.File]::ReadAllText("$root\template.html", [System.Text.Encoding]::UTF8)
$data = [System.IO.File]::ReadAllText("$root\data.json",     [System.Text.Encoding]::UTF8)
$data = $data.Trim([char]0xFEFF, ' ', "`t", "`r", "`n")
# keep the embedded JSON from breaking out of the <script> tag
$data = $data -replace '<', '\u003c' -replace '>', '\u003e'
[System.IO.File]::WriteAllText("$root\index.html", $tpl.Replace('__DATA__', $data), $enc)
Write-Host "Wrote index.html ($((Get-Item "$root\index.html").Length) bytes)"
