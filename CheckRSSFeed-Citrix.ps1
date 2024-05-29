param (
    [string]$latestUpdateDateParam
)

$keywords = @("ADC", "Netscaler", "Gateway")

function Parse-Date($dateString) {
    try {
        $cultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo("de-DE")
        $latestUpdateDate = [DateTime]::ParseExact($dateString, "dd.MM.yyyy HH:mm:ss", $cultureInfo)
        return $latestUpdateDate
    }
    catch {
        $errorMessage = "Ungueltiges Datumsformat angegeben. Bitte geben Sie ein gueltiges Datum im Format tt.MM.jjjj HH:mm:ss an."
        $result = @{
            prtg = @{
                error = 1
                text  = $errorMessage
            }
        }

        $result = $result | Convertto-Json
        Write-Output $result
        exit 1
    }
}

function checkTitleKeywords {
    param (
        [string]$title_,
        [string[]]$keywords_
    )
    foreach ($keyword in $keywords_) {
        if ($title_ -like "*$keyword*") {
            return $true
        }
    }
    return $false
}

$latestUpdateDate = Parse-Date $latestUpdateDateParam

# Convert the input date to UTC
$latestUpdateDateUtc = [System.TimeZoneInfo]::ConvertTimeToUtc($latestUpdateDate, [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Europe Standard Time"))

$rssFeedUrl = "https://support.citrix.com/feed/products/all/securitybulletins.rss"
function Get-LatestEntry($url) {
    try {
        [xml]$rss = Invoke-WebRequest -Uri $url -UseBasicParsing
        $latestEntry = $rss.rss.channel.item[0]
        return $latestEntry
    }
    catch {
        $errorMessage = "Error retrieving the RSS feed from $url"
        $result = @{
            prtg = @{
                error = 1
                text  = $errorMessage
            }
        }
        $result = $result | Convertto-Json
        Write-Output $result
        exit 1
    }
}

try {
    $latestEntry = Get-LatestEntry $rssFeedUrl
    $latestEntryDate = [DateTime]::Parse($latestEntry.pubDate)

    # Convert the latest entry date to UTC
    $latestEntryDateUtc = [System.TimeZoneInfo]::ConvertTimeToUtc($latestEntryDate)

    $latestEntryLink = $latestEntry.link
    $latestEntryTitle = [string]$latestEntry.title

    if (($latestEntryDateUtc -gt $latestUpdateDateUtc) -and (checkTitleKeywords -title_ $latestEntryTitle -keywords_ $keywords)) {
        $errorMessage = "Es wurden neue Sicherheitsluecken fuer Citrix-Produkte veroeffentlicht. Titel: $latestEntryTitle Link: $latestEntryLink"
        $result = @{
            prtg = @{
                error = 1
                text  = $errorMessage
            }
        }
        $result = $result | ConvertTo-Json
        Write-Output $result 
    }
    else {
        $message = "Aktuell keine Sicherheitsluecken bei Citrix-Produkten"
        $result = @{
            prtg = @{
                text   = $message
                result = @(
                    @{
                        channel = "Citrix Security Bulletin"
                        value   = 0
                    }
                )
        
            }
        }
        $result = $result | ConvertTo-Json -depth 3
        Write-Output $result 
    }
}
catch {
    $currentError = $_ | Out-String 
    <#Do this if a terminating exception happens#>
    $result = @{
        prtg = @{
            error = 1
            text  = $currentError
        }
    }
    $result = $result | ConvertTo-Json -depth 3
    Write-Output $result 
}
