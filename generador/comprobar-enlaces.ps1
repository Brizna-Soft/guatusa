# Revisa que funcionen todos los enlaces escritos a mano en contenido/*.json (descargas, imagenes, paginas).
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File generador\comprobar-enlaces.ps1
# Al final dice cuales fallaron. YouTube y algunos sitios no dejan revisar con HEAD: se prueba con GET.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'comun.ps1')

$urls = New-Object System.Collections.Generic.List[string]
foreach ($archivo in Get-ChildItem (Join-Ruta $raiz 'contenido') -Filter *.json) {
    $texto = [IO.File]::ReadAllText($archivo.FullName, $script:Utf8)
    foreach ($m in [regex]::Matches($texto, '"(https?://[^"\s]+)"')) { if (-not $urls.Contains($m.Groups[1].Value)) { $urls.Add($m.Groups[1].Value) } }
}

$cliente = Get-ClienteHttp
$fallas = 0
foreach ($u in $urls) {
    $codigo = 0
    foreach ($metodo in 'HEAD', 'GET') {
        $pedido = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($metodo), $u)
        try {
            $r = $cliente.SendAsync($pedido, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            $codigo = [int]$r.StatusCode
            $r.Dispose()
        } catch { $codigo = -1 } finally { $pedido.Dispose() }
        if ($codigo -ge 200 -and $codigo -lt 400) { break }
    }
    if ($codigo -ge 200 -and $codigo -lt 400) { Write-Host "  bien  $u" }
    else { Write-Host "  FALLA ($codigo)  $u"; $fallas++ }
    Start-Sleep -Milliseconds 200
}
Write-Host "Revisados: $($urls.Count). Con falla: $fallas."
if ($fallas -gt 0) { exit 1 }
