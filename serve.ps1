# serve.ps1 — minimal static file server (no Node/Python required)
# Usage: powershell -ExecutionPolicy Bypass -File serve.ps1 [-Port 8090]
param([int]$Port = 8090)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.png'  = 'image/png'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$Port/  (Ctrl+C to stop)"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $path = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
        if ($path -eq '/') { $path = '/index.html' }
        $file = Join-Path $root ($path -replace '/', '\')
        $full = [System.IO.Path]::GetFullPath($file)
        if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $full -PathType Leaf)) {
            $ctx.Response.StatusCode = 404
            $msg = [Text.Encoding]::UTF8.GetBytes('404 Not Found')
            $ctx.Response.ContentLength64 = $msg.Length
            $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
        } else {
            $ext = [System.IO.Path]::GetExtension($full).ToLower()
            $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
            $bytes = [System.IO.File]::ReadAllBytes($full)
            $ctx.Response.ContentLength64 = $bytes.Length
            if ($ctx.Request.HttpMethod -ne 'HEAD') {
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        }
        $ctx.Response.Close()
    }
} finally {
    $listener.Stop()
}
