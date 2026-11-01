# Muestra Guatusa en la PC, en http://localhost:8787/ (solo esta PC puede entrar).
# Sirve la carpeta publico/ como lo hace Cloudflare Pages: /seccion/ abre /seccion/index.html,
# lo que no existe da la pagina 404 y se aplican las cabeceras de publico/_headers.
param([int]$Puerto = 8787, [string]$Carpeta = (Join-Path $PSScriptRoot 'publico'))

$ErrorActionPreference = 'Stop'
$raiz = [IO.Path]::GetFullPath($Carpeta).TrimEnd('\') + '\'
$tipos = @{
    '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'
    '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.webp' = 'image/webp'; '.ico' = 'image/x-icon'
    '.xml' = 'application/xml; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8'; '.json' = 'application/json; charset=utf-8'
}

# Cabeceras del bloque "/*" de _headers
$cabeceras = @{}
$archivoCabeceras = Join-Path $raiz '_headers'
if (Test-Path $archivoCabeceras) {
    foreach ($linea in Get-Content $archivoCabeceras -Encoding UTF8) {
        if ($linea -match '^\s+([A-Za-z-]+):\s*(.+)$') { $cabeceras[$Matches[1]] = $Matches[2] }
    }
}

$oyente = New-Object System.Net.HttpListener
$oyente.Prefixes.Add("http://localhost:$Puerto/")
$oyente.Start()
Write-Host "Guatusa en http://localhost:$Puerto/ (Ctrl+C para cerrar)"
try {
    while ($oyente.IsListening) {
        $ctx = $oyente.GetContext()
        $res = $ctx.Response
        try {
            $ruta = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
            if ($ruta.EndsWith('/')) { $ruta += 'index.html' }
            $archivo = [IO.Path]::GetFullPath((Join-Path $raiz $ruta.TrimStart('/')))
            $codigo = 200
            # Nada fuera de la carpeta publico/
            if (-not $archivo.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $archivo -PathType Leaf)) {
                $dentro = Join-Path $archivo 'index.html'
                if ($archivo.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $dentro -PathType Leaf)) {
                    $res.StatusCode = 308
                    $res.RedirectLocation = $ctx.Request.Url.AbsolutePath + '/'
                    $res.ContentLength64 = 0
                    continue
                }
                $archivo = Join-Path $raiz '404.html'
                $codigo = 404
            }
            $bytes = [IO.File]::ReadAllBytes($archivo)
            $ext = [IO.Path]::GetExtension($archivo).ToLowerInvariant()
            $res.StatusCode = $codigo
            $res.ContentType = if ($tipos.ContainsKey($ext)) { $tipos[$ext] } else { 'application/octet-stream' }
            foreach ($k in $cabeceras.Keys) { $res.Headers[$k] = $cabeceras[$k] }
            $res.Headers['Cache-Control'] = 'no-store'
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host "$codigo $($ctx.Request.Url.AbsolutePath)"
        } catch {
            $res.StatusCode = 500
            Write-Host "500 $($ctx.Request.Url.AbsolutePath): $($_.Exception.Message)"
        } finally {
            $res.Close()
        }
    }
} finally {
    $oyente.Stop()
}
