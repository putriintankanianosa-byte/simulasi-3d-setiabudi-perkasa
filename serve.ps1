$port = 8089
$root = $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Prefixes.Add("http://127.0.0.1:$port/")

try {
    $listener.Start()
    Write-Output "HTTP Server running at http://localhost:$port/ and http://127.0.0.1:$port/"

    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            # Support COOP/COEP for multithreaded SIMD WASM and ONNX runtime
            $response.AddHeader("Cross-Origin-Opener-Policy", "same-origin")
            $response.AddHeader("Cross-Origin-Embedder-Policy", "credentialless")
            $response.AddHeader("Access-Control-Allow-Origin", "*")

            $localPath = $request.Url.LocalPath.TrimStart('/')
            if ([string]::IsNullOrEmpty($localPath)) {
                $localPath = "index.html"
            }
            $localPath = $localPath -replace '/', '\'
            
            $filePath = Join-Path $root $localPath
            if (-not (Test-Path $filePath -PathType Leaf)) {
                # Fallback to public folder for static assets (logos, models, wasm)
                $pubPath = Join-Path $root (Join-Path "public" $localPath)
                if (Test-Path $pubPath -PathType Leaf) {
                    $filePath = $pubPath
                }
            }

            if (Test-Path $filePath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                $contentType = switch ($ext) {
                    ".html" { "text/html; charset=utf-8" }
                    ".css"  { "text/css; charset=utf-8" }
                    ".js"   { "application/javascript; charset=utf-8" }
                    ".mjs"  { "application/javascript; charset=utf-8" }
                    ".json" { "application/json; charset=utf-8" }
                    ".wasm" { "application/wasm" }
                    ".onnx" { "application/octet-stream" }
                    ".png"  { "image/png" }
                    ".jpg"  { "image/jpeg" }
                    ".jpeg" { "image/jpeg" }
                    ".svg"  { "image/svg+xml" }
                    ".ico"  { "image/x-icon" }
                    default { "application/octet-stream" }
                }
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $response.ContentType = $contentType
                $response.ContentLength64 = $bytes.Length
                if ($request.HttpMethod -ne "HEAD") {
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
            } else {
                $response.StatusCode = 404
                $msg = [System.Text.Encoding]::UTF8.GetBytes("Not Found: $localPath")
                $response.ContentLength64 = $msg.Length
                if ($request.HttpMethod -ne "HEAD") {
                    $response.OutputStream.Write($msg, 0, $msg.Length)
                }
            }
            $response.Close()
        } catch {
            # Catch client disconnects gracefully
        }
    }
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
}
