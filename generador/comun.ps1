# Ayudas comunes del generador de Guatusa: red, JSON, HTML, fechas y nombres de pagina.
# Funciona igual en Windows PowerShell 5.1 (la PC) y en PowerShell 7 (GitHub Actions, Linux).
# Regla para listas: quien llama envuelve con @(...) antes de recorrerlas.

$script:Utf8 = New-Object Text.UTF8Encoding $false
$script:Inv = [Globalization.CultureInfo]::InvariantCulture
$script:Meses = @('enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre')
# Honduras no cambia la hora en el año: siempre UTC-6
$script:HoraHonduras = [TimeSpan]::FromHours(-6)

if ($PSVersionTable.PSVersion.Major -lt 6) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}
Add-Type -AssemblyName System.Net.Http

function Write-Paso([string]$Texto) { Write-Host "  $Texto" }

# ---------------------------------------------------------------- red

$script:ClienteHttp = $null
function Get-ClienteHttp {
    if (-not $script:ClienteHttp) {
        $manejador = New-Object System.Net.Http.HttpClientHandler
        $manejador.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
        $cliente = New-Object System.Net.Http.HttpClient -ArgumentList $manejador
        $cliente.Timeout = [TimeSpan]::FromSeconds(30)
        [void]$cliente.DefaultRequestHeaders.UserAgent.TryParseAdd('Guatusa/1.0 (+https://github.com/Brizna-Soft/guatusa)')
        $script:ClienteHttp = $cliente
    }
    $script:ClienteHttp
}

# Baja un texto (UTF-8). Reintenta en errores de red, 408, 429 y 5xx; con otro 4xx se rinde enseguida.
function Get-Texto {
    param([Parameter(Mandatory = $true)][string]$Url, [hashtable]$Cabeceras = @{}, [int]$Intentos = 3)
    $cliente = Get-ClienteHttp
    $ultimo = ''
    for ($i = 1; $i -le $Intentos; $i++) {
        $pedido = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Url)
        foreach ($k in $Cabeceras.Keys) { [void]$pedido.Headers.TryAddWithoutValidation($k, [string]$Cabeceras[$k]) }
        $codigo = 0
        try {
            $respuesta = $cliente.SendAsync($pedido).GetAwaiter().GetResult()
            $codigo = [int]$respuesta.StatusCode
            $bytes = $respuesta.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            if ($respuesta.IsSuccessStatusCode) { return $script:Utf8.GetString($bytes).TrimStart([char]0xFEFF) }
            $ultimo = "HTTP $codigo"
        } catch {
            $ultimo = $_.Exception.GetBaseException().Message
        } finally {
            $pedido.Dispose()
        }
        if ($codigo -ge 400 -and $codigo -lt 500 -and $codigo -ne 408 -and $codigo -ne 429) { break }
        if ($i -lt $Intentos) { Start-Sleep -Seconds (3 * $i) }
    }
    throw "No se pudo leer $Url ($ultimo)"
}

# Una lista JSON sale entera como un solo objeto, igual en 5.1 y en 7 (en 7 hace falta -NoEnumerate)
function ConvertFrom-JsonTexto([string]$Texto) {
    if ($PSVersionTable.PSVersion.Major -ge 7) { , ($Texto | ConvertFrom-Json -NoEnumerate) }
    else { , ($Texto | ConvertFrom-Json) }
}

function Get-Json {
    param([Parameter(Mandatory = $true)][string]$Url, [hashtable]$Cabeceras = @{})
    ConvertFrom-JsonTexto (Get-Texto -Url $Url -Cabeceras $Cabeceras)
}

# ---------------------------------------------------------------- archivos

function Read-Json([string]$Ruta) {
    if (-not (Test-Path -LiteralPath $Ruta)) { return }
    $texto = [IO.File]::ReadAllText($Ruta, $script:Utf8)
    if ([string]::IsNullOrWhiteSpace($texto)) { return }
    ConvertFrom-JsonTexto $texto
}

function Write-Texto([string]$Ruta, [string]$Texto) {
    $carpeta = Split-Path -Parent $Ruta
    if ($carpeta -and -not (Test-Path -LiteralPath $carpeta)) { New-Item -ItemType Directory -Force -Path $carpeta | Out-Null }
    [IO.File]::WriteAllText($Ruta, ($Texto -replace "`r`n", "`n"), $script:Utf8)
}

function Write-Json([string]$Ruta, $Objeto) {
    Write-Texto $Ruta ((ConvertTo-Json -InputObject $Objeto -Depth 20) + "`n")
}

function Join-Ruta([string]$Base) {
    # Une partes con el separador del sistema (Join-Path de 5.1 solo acepta dos)
    $partes = @($Base) + @($args | ForEach-Object { [string]$_ })
    [IO.Path]::Combine([string[]]$partes)
}

# ---------------------------------------------------------------- objetos

# Lee una propiedad que puede faltar (ConvertFrom-Json no crea las que no vienen)
function Get-Prop($Objeto, [string]$Nombre, $PorDefecto = $null) {
    if ($null -eq $Objeto) { return $PorDefecto }
    if ($Objeto -is [System.Collections.IDictionary]) {
        if ($Objeto.Contains($Nombre) -and $null -ne $Objeto[$Nombre]) { return $Objeto[$Nombre] }
        return $PorDefecto
    }
    $p = $Objeto.PSObject.Properties[$Nombre]
    if ($p -and $null -ne $p.Value) { return $p.Value }
    $PorDefecto
}

function Test-Texto($Valor) { -not [string]::IsNullOrWhiteSpace([string]$Valor) }

# Entero positivo o el valor por defecto (para atributos como width y height, que no se escapan)
function Get-Entero($Valor, [int]$PorDefecto) {
    $n = $Valor -as [int]
    if ($null -ne $n -and $n -gt 0) { return $n }
    $PorDefecto
}

# ---------------------------------------------------------------- HTML

# Escapa texto para HTML (solo los cinco caracteres peligrosos; los acentos quedan tal cual)
function Html($Texto) {
    if ($null -eq $Texto) { return '' }
    ([string]$Texto).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&#39;')
}

# Solo deja pasar enlaces http(s); cualquier otra cosa (javascript:, data:...) se vuelve "#"
function Enlace($Url) {
    $u = [string]$Url
    if ($u -match '^https?://[^\s<>"]+$') { return (Html $u) }
    if ($u -match '^/[^\s<>"]*$' -and $u -notmatch '^//') { return (Html $u) }
    '#'
}

# Quita etiquetas HTML de un texto externo y deja solo texto plano
function ConvertTo-TextoPlano([string]$Html) {
    if (-not $Html) { return '' }
    $t = $Html -replace '(?i)<br\s*/?>', ' ' -replace '<[^>]+>', ' '
    $t = [Net.WebUtility]::HtmlDecode($t)
    ($t -replace '\s+', ' ').Trim()
}

# ---------------------------------------------------------------- nombres

function Get-Slug([string]$Texto, [int]$Largo = 60) {
    if (-not $Texto) { return 'sin-nombre' }
    $t = $Texto.Normalize([Text.NormalizationForm]::FormD)
    $t = [regex]::Replace($t, '\p{Mn}', '')
    $t = $t.ToLowerInvariant() -replace '&', ' y ' -replace "['’]", '' -replace '[^a-z0-9]+', '-'
    $t = $t.Trim('-')
    if ($t.Length -gt $Largo) { $t = $t.Substring(0, $Largo).TrimEnd('-') }
    if (-not $t) { $t = 'sin-nombre' }
    $t
}

# Para comparar nombres de juegos entre tiendas: minusculas, sin acentos, sin simbolos
function Get-NombreComparable([string]$Texto) {
    if (-not $Texto) { return '' }
    $t = $Texto -replace '[™®©]', ''
    (Get-Slug $t 200) -replace '-', ''
}

# ---------------------------------------------------------------- fechas

function Get-AhoraUtc { [DateTimeOffset]::UtcNow }

function ConvertTo-Honduras([DateTimeOffset]$Fecha) { $Fecha.ToOffset($script:HoraHonduras) }

# Convierte una fecha a DateTimeOffset venga como venga: texto ISO o RFC 1123 (5.1) o DateTime
# (PowerShell 7 convierte solo los textos con forma de fecha al leer JSON). Sin fecha: no devuelve nada.
function Get-Fecha($Valor) {
    if ($null -eq $Valor) { return }
    if ($Valor -is [DateTimeOffset]) { return $Valor }
    if ($Valor -is [DateTime]) {
        if ($Valor.Kind -eq [DateTimeKind]::Unspecified) { $Valor = [DateTime]::SpecifyKind($Valor, [DateTimeKind]::Utc) }
        return [DateTimeOffset]::new($Valor.ToUniversalTime(), [TimeSpan]::Zero)
    }
    $texto = [string]$Valor
    if (-not $texto) { return }
    $f = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($texto, $script:Inv, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$f)) { return $f }
}

# Fecha sin zona que en realidad es hora de Honduras (por ejemplo "2026-11-08 23:59:00")
function Get-FechaHonduras($Valor) {
    if ($Valor -is [DateTime]) {
        return [DateTimeOffset]::new([DateTime]::SpecifyKind($Valor, [DateTimeKind]::Unspecified), $script:HoraHonduras)
    }
    $d = [DateTime]::MinValue
    if ([DateTime]::TryParseExact([string]$Valor, 'yyyy-MM-dd HH:mm:ss', $script:Inv, [Globalization.DateTimeStyles]::None, [ref]$d)) {
        return [DateTimeOffset]::new($d, $script:HoraHonduras)
    }
}

function ConvertFrom-Unix([long]$Segundos) { [DateTimeOffset]::FromUnixTimeSeconds($Segundos) }

function Format-FechaIso([DateTimeOffset]$Fecha) { $Fecha.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", $script:Inv) }

# "8 de noviembre de 2026" (en hora de Honduras)
function Format-FechaLarga([DateTimeOffset]$Fecha, [switch]$SinAnio) {
    $f = ConvertTo-Honduras $Fecha
    $texto = '{0} de {1}' -f $f.Day, $script:Meses[$f.Month - 1]
    if (-not $SinAnio) { $texto += " de $($f.Year)" }
    $texto
}

# "3:15 p. m."
function Format-Hora([DateTimeOffset]$Fecha) {
    $f = ConvertTo-Honduras $Fecha
    $h = $f.Hour % 12
    if ($h -eq 0) { $h = 12 }
    $sufijo = if ($f.Hour -lt 12) { 'a. m.' } else { 'p. m.' }
    '{0}:{1:00} {2}' -f $h, $f.Minute, $sufijo
}

function Format-Dinero([double]$Monto) { 'US$' + $Monto.ToString('0.00', $script:Inv) }

# Junta una lista en español: "a, b y c"
function Join-Lista($Partes, [string]$Ultimo = 'y') {
    $p = @($Partes | Where-Object { Test-Texto $_ })
    if ($p.Count -eq 0) { return '' }
    if ($p.Count -eq 1) { return [string]$p[0] }
    (($p[0..($p.Count - 2)]) -join ', ') + " $Ultimo " + $p[-1]
}
