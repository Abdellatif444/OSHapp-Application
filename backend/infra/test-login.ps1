param(
  [string]$BaseUrl = "http://localhost:8081"
)

function Invoke-Login($Email, $Password) {
  $bodyObj = @{ email = $Email; password = $Password }
  $json = $bodyObj | ConvertTo-Json -Depth 3 -Compress
  try {
    $resp = Invoke-WebRequest -Method Post -Uri "$BaseUrl/api/v1/auth/login" -ContentType 'application/json' -Body $json -UseBasicParsing
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
}

Write-Host "Testing disabled user (should be 403 ACCOUNT_NOT_ACTIVATED)" -ForegroundColor Cyan
$result1 = Invoke-Login 'gourri.abdellatif@gmail.com' 'abdellatif12345678'
$result1 | Format-List

Write-Host "\nTesting admin (should be 200 and return JWT)" -ForegroundColor Cyan
$result2 = Invoke-Login 'admin@oshapp.com' 'admin12345678'
$result2 | Format-List

Write-Host "\nTesting wrong password (should be 401 UNAUTHORIZED)" -ForegroundColor Cyan
$result3 = Invoke-Login 'admin@oshapp.com' 'wrongpass'
$result3 | Format-List
