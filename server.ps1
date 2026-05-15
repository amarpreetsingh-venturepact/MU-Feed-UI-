$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), 4173)
$listener.Start()

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = [System.IO.StreamReader]::new($stream)
      $requestLine = $reader.ReadLine()
      while ($true) {
        $line = $reader.ReadLine()
        if ([string]::IsNullOrEmpty($line)) { break }
      }

      $requestPath = "index.html"
      if ($requestLine -match "^GET\s+(/[^\s?]*)") {
        $requestPath = $Matches[1].TrimStart("/")
        if ([string]::IsNullOrWhiteSpace($requestPath)) {
          $requestPath = "index.html"
        }
      }

      $file = Join-Path $root $requestPath
      if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        $status = "404 Not Found"
        $contentType = "text/plain; charset=utf-8"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("Not found")
      } else {
        $status = "200 OK"
        $extension = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
        $contentType = switch ($extension) {
          ".html" { "text/html; charset=utf-8" }
          ".css" { "text/css; charset=utf-8" }
          ".js" { "text/javascript; charset=utf-8" }
          ".png" { "image/png" }
          ".jpg" { "image/jpeg" }
          ".jpeg" { "image/jpeg" }
          ".svg" { "image/svg+xml" }
          default { "application/octet-stream" }
        }
        $bytes = [System.IO.File]::ReadAllBytes($file)
      }

      $header = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
      $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
      $stream.Write($headerBytes, 0, $headerBytes.Length)
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Flush()
    } catch {
      Write-Host $_
    } finally {
      $client.Close()
    }
  }
} finally {
  $listener.Stop()
}
