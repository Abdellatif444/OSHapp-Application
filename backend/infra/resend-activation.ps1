param(
  [string]$BaseUrl = "http://localhost:8081",
  [Parameter(Mandatory=$true)][string]$Email
)

$ErrorActionPreference = 'Stop'
$body = @{ email = $Email } | ConvertTo-Json -Compress
try {
  $resp = Invoke-WebRequest -Method Post -Uri "$BaseUrl/api/v1/account/resend-activation" -ContentType 'application/json' -Body $body -UseBasicParsing
  [pscustomobject]@{ Status = [int]$resp.StatusCode; Body = $resp.Content }
} catch {
  if ($_.Exception.Response) {
    $r = $_.Exception.Response
    $reader = New-Object System.IO.StreamReader($r.GetResponseStream())
    $content = $reader.ReadToEnd()
    $reader.Close()
    [pscustomobject]@{ Status = [int]$r.StatusCode; Body = $content }
  } else {
    throw
  }
}
