# Shared core: fetches + assembles the dataset from api.boligsiden.dk.
# Dot-sourced by fetch.ps1 (writes data.json) and serve.ps1 (serves /live.json).

$script:BS_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36"
$ProgressPreference = "SilentlyContinue"

function Get-AllAddresses($url) {
    $page = 1; $acc = @(); $total = $null
    while ($true) {
        $j = Invoke-RestMethod "$url&per_page=1000&page=$page" -UserAgent $script:BS_UA
        $total = $j.totalHits
        if ($j.addresses) { $acc += $j.addresses }
        if (-not $j.addresses -or $j.addresses.Count -lt 1000 -or $acc.Count -ge $total) { break }
        $page++
    }
    [pscustomobject]@{ total = $total; items = $acc }
}
function Get-AllCases($url) {
    $page = 1; $acc = @(); $total = $null
    while ($true) {
        $j = Invoke-RestMethod "$url&per_page=1000&page=$page" -UserAgent $script:BS_UA
        $total = $j.totalHits
        if ($j.cases) { $acc += $j.cases }
        if (-not $j.cases -or $j.cases.Count -lt 1000 -or $acc.Count -ge $total) { break }
        $page++
    }
    [pscustomobject]@{ total = $total; items = $acc }
}

function ConvertTo-SoldRow($a) {
    $r0 = @($a.registrations) | Where-Object { $_ -ne $null } | Sort-Object { $_.date } -Descending | Select-Object -First 1
    $saleArea = if ($r0.livingArea) { $r0.livingArea } elseif ($r0.area) { $r0.area } else { $null }
    $m2 = $r0.perAreaPrice
    if (-not $m2 -and $r0.amount -and $saleArea) { $m2 = [math]::Round($r0.amount / $saleArea) }
    $m2calc = $null
    if ($r0.amount -and $a.livingArea) { $m2calc = [math]::Round($r0.amount / $a.livingArea) }
    [pscustomobject]@{
        addr     = ("{0} {1}{2}{3}" -f $a.roadName, $a.houseNumber, $(if ($a.floor) { ", $($a.floor)." } else { "" }), $(if ($a.door) { " $($a.door)" } else { "" })).Trim()
        zip = $a.zipCode; city = $a.cityName; area = $a.livingArea
        price = $r0.amount; saleArea = $saleArea; m2 = $m2; m2calc = $m2calc
        date = $r0.date; type = $r0.type
        lat = $a.coordinates.lat; lon = $a.coordinates.lon; slug = $a.slugAddress
    }
}
function ConvertTo-CaseRow($c) {
    $a = $c.address
    $area = if ($c.housingArea) { $c.housingArea } else { $a.livingArea }
    $dom = $null
    if ($c.daysOnMarket -and $null -ne $c.daysOnMarket.days) { $dom = $c.daysOnMarket.days }
    elseif ($c.daysOnMarket -and $c.daysOnMarket.current) { $dom = $c.daysOnMarket.current.days }
    elseif ($c.daysListed) { $dom = $c.daysListed }
    elseif ($c.timeOnMarket -and $c.timeOnMarket.current) { $dom = $c.timeOnMarket.current.days }
    [pscustomobject]@{
        addr = ("{0} {1}{2}{3}" -f $a.roadName, $a.houseNumber, $(if ($a.floor) { ", $($a.floor)." } else { "" }), $(if ($a.door) { " $($a.door)" } else { "" })).Trim()
        zip = if ($a.zipCode) { $a.zipCode } else { $c.zipCode }
        city = $a.cityName; area = $area
        price = $c.priceCash; m2 = $c.perAreaPrice
        rooms = $c.numberOfRooms; yearBuilt = $c.yearBuilt; energy = $c.energyLabel
        daysOnMarket = $dom; priceChangePct = $c.priceChangePercentage
        lat = $c.coordinates.lat; lon = $c.coordinates.lon
        slug = if ($c.slugAddress) { $c.slugAddress } else { $a.slugAddress }
    }
}

function Get-BoligData {
    $yr = (Get-Date).Year
    $soldBase = "https://api.boligsiden.dk/search/list/addresses?addressTypes=condo&sold=true&sortBy=soldDate&sortAscending=false&yearSoldFrom=2025&yearSoldTo=$yr&areaMin=100"
    $saleBase = "https://api.boligsiden.dk/search/cases?addressTypes=condo&areaMin=100&sortBy=price&sortAscending=true"

    $sf = Get-AllAddresses "$soldBase&municipalities=Frederiksberg"
    $sz = Get-AllAddresses "$soldBase&zipCodes=1799"
    $ff = Get-AllCases     "$saleBase&municipalities=frederiksberg"
    $fz = Get-AllCases     "$saleBase&zipCodes=1799"

    [pscustomobject]@{
        generated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        source    = "boligsiden.dk (api.boligsiden.dk)"
        criteria  = [pscustomobject]@{ addressType = "ejerlejlighed (condo)"; minLivingArea = 100; soldFrom = "2025-01-01" }
        sold      = [pscustomobject]@{
            frederiksberg = @($sf.items | ForEach-Object { ConvertTo-SoldRow $_ })
            zip1799       = @($sz.items | ForEach-Object { ConvertTo-SoldRow $_ })
        }
        forSale   = [pscustomobject]@{
            frederiksberg = @($ff.items | ForEach-Object { ConvertTo-CaseRow $_ })
            zip1799       = @($fz.items | ForEach-Object { ConvertTo-CaseRow $_ })
        }
    }
}
