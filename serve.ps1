# Local preview server for index.html on http://localhost:8791/
# Also serves /live.json  -> fresh data fetched live from api.boligsiden.dk
# (cached in-memory for 5 min so repeated page opens don't hammer the API).
. "$PSScriptRoot\bs-core.ps1"

$port = 8791
$root = $PSScriptRoot
$types = @{ ".html"="text/html; charset=utf-8"; ".json"="application/json; charset=utf-8";
           ".js"="text/javascript; charset=utf-8"; ".css"="text/css; charset=utf-8" }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$port/  (live data at /live.json)"

$liveCache = $null
$liveAt = [datetime]::MinValue

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart("/"))
    $ctx.Response.Headers.Add("Access-Control-Allow-Origin", "*")
    try {
        if ($path -eq "live.json" -or $path -eq "api/live") {
            if (-not $liveCache -or ((Get-Date) - $liveAt).TotalMinutes -gt 5) {
                Write-Host "  fetching live data ..."
                $liveCache = (Get-BoligData | ConvertTo-Json -Depth 8 -Compress)
                $liveAt = Get-Date
            }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($liveCache)
            $ctx.Response.ContentType = "application/json; charset=utf-8"
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        else {
            if ($path -eq "") { $path = "index.html" }
            $file = Join-Path $root $path
            if (Test-Path $file -PathType Leaf) {
                $bytes = [System.IO.File]::ReadAllBytes($file)
                $ext = [System.IO.Path]::GetExtension($file).ToLower()
                $ctx.Response.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $ctx.Response.StatusCode = 404
                $b = [System.Text.Encoding]::UTF8.GetBytes("not found: $path")
                $ctx.Response.OutputStream.Write($b, 0, $b.Length)
            }
        }
    } catch {
        $ctx.Response.StatusCode = 500
        $b = [System.Text.Encoding]::UTF8.GetBytes("error: $($_.Exception.Message)")
        try { $ctx.Response.OutputStream.Write($b, 0, $b.Length) } catch {}
    }
    $ctx.Response.OutputStream.Close()
}
