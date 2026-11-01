# Arma Guatusa: lee las fuentes, guarda lo leido en datos/ y escribe el sitio en publico/.
#   En la PC:          powershell -NoProfile -ExecutionPolicy Bypass -File armar.ps1
#   En GitHub Actions: pwsh ./armar.ps1
#   -SinRed            no consulta internet: arma con lo que ya esta en datos/ (para probar el diseno)
param([switch]$SinRed)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
foreach ($parte in 'comun', 'fuentes', 'fichas', 'paginas', 'sitio') { . (Join-Path (Join-Path $raiz 'generador') "$parte.ps1") }

$ahora = Get-AhoraUtc
$dirDatos = Join-Ruta $raiz 'datos'
$dirContenido = Join-Ruta $raiz 'contenido'
$dirSalida = Join-Ruta $raiz 'publico'
$config = Read-Json (Join-Ruta $raiz 'config.json')
Write-Host "Guatusa: armando el sitio ($(Format-FechaLarga $ahora), $(Format-Hora $ahora) en Honduras)"

# ---------------------------------------------------------------- configuracion

$ingresos = Get-Prop $config 'ingresos'
$afiliados = Get-Prop $ingresos 'afiliados'
$script:Sitio = [ordered]@{
    url         = [string]$config.sitio.url
    repo        = [string]$config.sitio.repositorio
    brizna      = [string]$config.sitio.brizna
    paypal      = [string](Get-Prop $ingresos 'paypal' 'https://paypal.me/BriznaSoft')
    telegram    = [string](Get-Prop $ingresos 'telegram_canal' '')
    adsense     = ''
    afiliados   = [bool]($afiliados -and @($afiliados.PSObject.Properties).Count -gt 0)
    actualizado = $ahora
    version     = ''
}
$clienteAds = [string](Get-Prop $ingresos 'adsense_cliente' '')
if ($clienteAds -match '^ca-pub-\d{10,20}$') { $script:Sitio.adsense = $clienteAds }
elseif ($clienteAds) { Write-Warning "adsense_cliente no tiene la forma ca-pub-0000000000000000: no se ponen anuncios." }

# Numero corto que cambia cuando cambian los estilos o el script, para que el navegador no use una copia vieja
$sha = [Security.Cryptography.SHA256]::Create()
$bytes = [byte[]]([IO.File]::ReadAllBytes((Join-Ruta $raiz 'estatico' 'estilos.css')) + [IO.File]::ReadAllBytes((Join-Ruta $raiz 'estatico' 'guatusa.js')))
$script:Sitio.version = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').Substring(0, 10).ToLowerInvariant()

$fuentesCfg = Get-Prop $config 'fuentes'
$diasRegalos = [int](Get-Prop $fuentesCfg 'dias_regalos_terminados' 30)
$diasOfertas = [int](Get-Prop $fuentesCfg 'dias_ofertas_terminadas' 7)
$diasItch = [int](Get-Prop $fuentesCfg 'dias_itch_fuera_de_lista' 14)
$paginasItch = [int](Get-Prop $fuentesCfg 'paginas_itch' 2)

# ---------------------------------------------------------------- ayudas de este script

function Read-JsonLista([string]$Ruta) {
    $x = Read-Json $Ruta
    if ($null -eq $x) { return , @() }
    , @($x)
}

function ConvertTo-Tabla($Objeto) {
    $t = @{}
    if ($Objeto) { foreach ($p in $Objeto.PSObject.Properties) { $t[$p.Name] = $p.Value } }
    $t
}

function ConvertTo-Ordenado([hashtable]$Tabla) {
    $o = [ordered]@{}
    foreach ($k in ($Tabla.Keys | Sort-Object)) { $o[$k] = $Tabla[$k] }
    $o
}

$estado = [ordered]@{ actualizado = (Format-FechaIso $ahora); fuentes = [ordered]@{} }

# Corre una fuente. Devuelve la lista (aunque este vacia) o nada si fallo: entonces se usa lo guardado.
function Invoke-Fuente([string]$Nombre, [scriptblock]$Bloque) {
    if ($SinRed) { $estado.fuentes[$Nombre] = 'sin consultar'; return }
    try {
        $r = @(& $Bloque)
        $estado.fuentes[$Nombre] = "bien ($($r.Count))"
        Write-Paso "${Nombre}: $($r.Count)"
        return , $r
    } catch {
        $estado.fuentes[$Nombre] = 'falló'
        Write-Warning "${Nombre}: no se pudo leer ($($_.Exception.Message)). Se usa lo guardado."
    }
}

# Junta lo que llego ahora con lo guardado. Lo que ya no viene queda con vigente = false unos dias
# (asi siguen funcionando los enlaces viejos, por ejemplo los de Telegram) y despues se borra.
# Si la fuente fallo ($Actuales = $null), todo queda como estaba.
function Merge-Historial($Guardados, $Actuales, [int]$Dias) {
    $previos = @{}
    foreach ($g in $Guardados) { if ($g) { $previos[[string]$g.clave] = $g } }
    $salida = New-Object System.Collections.Generic.List[object]
    # En Windows PowerShell 5.1, @() sobre una List[object] falla: siempre ToArray()
    if ($null -eq $Actuales) { foreach ($g in $Guardados) { if ($g) { $salida.Add($g) } }; return , $salida.ToArray() }
    $vistos = @{}
    foreach ($a in $Actuales) {
        $p = $previos[[string]$a.clave]
        $primero = if ($p -and (Get-Fecha $p.visto_primero)) { Format-FechaIso (Get-Fecha $p.visto_primero) } else { Format-FechaIso $ahora }
        $slug = if ($p) { Get-Prop $p 'slug' } else { $null }
        $a | Add-Member -NotePropertyName vigente -NotePropertyValue $true -Force
        $a | Add-Member -NotePropertyName visto_primero -NotePropertyValue $primero -Force
        $a | Add-Member -NotePropertyName visto_ultimo -NotePropertyValue (Format-FechaIso $ahora) -Force
        $a | Add-Member -NotePropertyName fin_visto -NotePropertyValue $null -Force
        $a | Add-Member -NotePropertyName slug -NotePropertyValue $slug -Force
        $salida.Add($a)
        $vistos[[string]$a.clave] = $true
    }
    foreach ($g in $Guardados) {
        if (-not $g -or $vistos.ContainsKey([string]$g.clave)) { continue }
        if ($g.vigente) {
            $g.vigente = $false
            $g | Add-Member -NotePropertyName fin_visto -NotePropertyValue (Format-FechaIso $ahora) -Force
        }
        $fin = Get-Fecha $g.fin_visto
        if ($fin -and ($ahora - $fin).TotalDays -le $Dias) { $salida.Add($g) }
    }
    , $salida.ToArray()
}

# Nombre de pagina estable para cada registro; los de $Reservados (contenido escrito a mano) ganan
function Set-Slugs($Registros, [hashtable]$Reservados) {
    $usados = @{}
    foreach ($k in $Reservados.Keys) { $usados[$k] = $true }
    foreach ($r in $Registros) {
        if ($r.slug -and -not $usados.ContainsKey([string]$r.slug)) { $usados[[string]$r.slug] = $true } else { $r.slug = $null }
    }
    foreach ($r in $Registros) {
        if ($r.slug) { continue }
        $base = Get-Slug ([string]$r.nombre)
        $s = $base
        $n = 2
        while ($usados.ContainsKey($s)) { $s = "$base-$n"; $n++ }
        $r.slug = $s
        $usados[$s] = $true
    }
}

# ---------------------------------------------------------------- contenido escrito a mano

$tiendas = Read-Json (Join-Ruta $dirContenido 'tiendas.json')
$bloqueosJson = Read-Json (Join-Ruta $dirContenido 'bloqueos.json')
$bloqueos = @(@($bloqueosJson.adultos) + @($bloqueosJson.marcas_ajenas) | ForEach-Object { "(?i)$_" })
$juegosLibres = Read-JsonLista (Join-Ruta $dirContenido 'juegos-libres.json')
$programas = Read-JsonLista (Join-Ruta $dirContenido 'programas.json')
$brizna = Read-JsonLista (Join-Ruta $dirContenido 'brizna.json')
$cine = Read-JsonLista (Join-Ruta $dirContenido 'cine.json')
$servicios = Read-JsonLista (Join-Ruta $dirContenido 'servicios.json')
# Textos escritos a mano para fichas automaticas (regalos, itch.io, ofertas), por nombre comparable
$descripciones = ConvertTo-Tabla (Get-Prop (Read-Json (Join-Ruta $dirContenido 'descripciones.json')) 'textos')

# ---------------------------------------------------------------- fuentes

$regalosLeidos = Invoke-Fuente 'GamerPower' { Get-RegalosGamerPower }
$regalos = Merge-Historial (Read-JsonLista (Join-Ruta $dirDatos 'regalos.json')) $regalosLeidos $diasRegalos
Set-Slugs $regalos @{}

$itchLeidos = Invoke-Fuente 'itch.io' { Get-JuegosItch -Paginas $paginasItch -Bloqueos $bloqueos }
$itch = Merge-Historial (Read-JsonLista (Join-Ruta $dirDatos 'itch.json')) $itchLeidos $diasItch
$reservados = @{}
foreach ($j in $juegosLibres) { $reservados[[string]$j.slug] = $true }
Set-Slugs $itch $reservados

$ofertasLeidas = Invoke-Fuente 'Steam' { Get-OfertasSteam }
$ofertas = Merge-Historial (Read-JsonLista (Join-Ruta $dirDatos 'ofertas.json')) $ofertasLeidas $diasOfertas
Set-Slugs $ofertas @{}

# Datos de Steam (generos, idiomas, requisitos), guardados 30 dias para no preguntar de mas
$steamGuardado = Read-Json (Join-Ruta $dirDatos 'steam.json')
$apps = ConvertTo-Tabla (Get-Prop $steamGuardado 'apps')
$nombres = ConvertTo-Tabla (Get-Prop $steamGuardado 'nombres')
$script:PedidosSteam = 0
$maxPedidosSteam = 60

function Test-Fresco($Registro, [double]$Horas) {
    $leido = if ($Registro) { Get-Fecha (Get-Prop $Registro 'leido') } else { $null }
    $leido -and ($ahora - $leido).TotalHours -lt $Horas
}

function Get-Detalle([int]$AppId) {
    if ($AppId -le 0) { return }
    $c = $apps[[string]$AppId]
    if ((Test-Fresco $c 720) -or $SinRed -or $script:PedidosSteam -ge $maxPedidosSteam) { return $c }
    try {
        $script:PedidosSteam++
        Start-Sleep -Milliseconds 350
        $d = Get-DetallesSteam $AppId
        if ($d) { $apps[[string]$AppId] = $d; return $d }
    } catch { Write-Warning "Steam no dio los datos de $AppId ($($_.Exception.Message))" }
    $c
}

function Find-App([string]$Nombre) {
    $k = Get-NombreComparable $Nombre
    if (-not $k) { return 0 }
    $c = $nombres[$k]
    if ((Test-Fresco $c 720) -or $SinRed -or $script:PedidosSteam -ge $maxPedidosSteam) { if ($c) { return [int]$c.appid }; return 0 }
    try {
        $script:PedidosSteam++
        Start-Sleep -Milliseconds 350
        $id = Find-AppSteam $Nombre
        $nombres[$k] = [pscustomobject][ordered]@{ appid = $id; leido = (Format-FechaIso $ahora) }
        return $id
    } catch { Write-Warning "Steam no respondió la búsqueda de «$Nombre» ($($_.Exception.Message))" }
    if ($c) { return [int]$c.appid }
    0
}

# Versiones de GitHub, guardadas 6 horas
$githubGuardado = ConvertTo-Tabla (Read-Json (Join-Ruta $dirDatos 'github.json'))
$repos = @(@($brizna | ForEach-Object { $_.repo }) + @($juegosLibres + $programas | ForEach-Object { Get-Prop $_ 'github' } | Where-Object { $_ })) | Select-Object -Unique
$versiones = @{}
$fallosGitHub = 0
foreach ($repo in $repos) {
    $c = $githubGuardado[$repo]
    if (-not (Test-Fresco $c 6) -and -not $SinRed -and $fallosGitHub -lt 3) {
        try { $c = Get-UltimaVersionGitHub $repo; $githubGuardado[$repo] = $c }
        catch {
            # Un 404 es solo ese repositorio (no publica versiones); con 3 fallas de otro tipo (red, limite) se deja de preguntar
            if ($_.Exception.Message -notmatch 'HTTP 404') { $fallosGitHub++ }
            Write-Warning "GitHub no dio la versión de $repo ($($_.Exception.Message))"
        }
    }
    if ($c) { $versiones[$repo] = $c }
}
$estado.fuentes['GitHub'] = "$($versiones.Count) de $(@($repos).Count) versiones"
Write-Paso "GitHub: $($versiones.Count) de $(@($repos).Count) versiones"

# ---------------------------------------------------------------- fichas

$fichas = New-Object System.Collections.Generic.List[object]
foreach ($r in $regalos) {
    $detalle = $null
    # Solo en las tiendas grandes: ahi los nombres son unicos. En itch.io o IndieGala hay muchos nombres
    # repetidos y podrian salir los datos de otro juego.
    if ($r.vigente -and $r.tienda -in @('epic', 'steam', 'gog', 'prime', 'ubisoft', 'ea') -and -not $r.es_paquete) { $detalle = Get-Detalle (Find-App $r.nombre) }
    $fichas.Add((New-FichaRegalo $r $tiendas $detalle $ahora))
}
foreach ($r in $itch) { $fichas.Add((New-FichaItch $r)) }
foreach ($r in $ofertas) {
    $detalle = if ($r.vigente) { Get-Detalle $r.appid } else { $apps[[string]$r.appid] }
    $fichas.Add((New-FichaOferta $r $detalle $ahora))
}
foreach ($e in $juegosLibres) { $fichas.Add((New-FichaJuegoLibre $e $versiones)) }
foreach ($e in $brizna) { $fichas.Add((New-FichaBrizna $e $versiones)) }
foreach ($e in $programas) { $fichas.Add((New-FichaPrograma $e $versiones)) }
foreach ($e in $cine) { $fichas.Add((New-FichaCine $e)) }
foreach ($e in $servicios) { $fichas.Add((New-FichaServicio $e)) }
Write-Paso "Steam: $script:PedidosSteam consultas nuevas"

# Enlaces de afiliado (config.json > ingresos > afiliados: { "dominio": "plantilla con {url}" }) y
# acortador (solo en contenido marcado "acortar": true; nunca en Brizna Soft ni en tiendas)
$acortador = [string](Get-Prop $ingresos 'acortador' '')
foreach ($f in $fichas) {
    if (-not $f.fecha) { $f.fecha = $ahora }
    if ($f.seccion -in @('regalos', 'ofertas') -or $f.grupo -eq 'itch') {
        $propio = $descripciones[(Get-NombreComparable $f.titulo)]
        if ($propio) { $f.parrafos = @($propio) + @($f.parrafos) }
    }
    # Las descargas de Brizna Soft siempre son directas: ni afiliados ni acortador
    if (-not $f.boton -or $f.grupo -eq 'brizna') { continue }
    $anfitrion = ''
    try { $anfitrion = ([uri]$f.boton.url).Host } catch { }
    $plantilla = if ($afiliados -and $anfitrion) { Get-Prop $afiliados $anfitrion } else { $null }
    if ($plantilla -and $plantilla -match '\{url\}') {
        $f.boton.url = $plantilla.Replace('{url}', [uri]::EscapeDataString($f.boton.url))
        $f.boton.rel = 'sponsored noopener'
        $f.boton.nota = 'Enlace de afiliado: si compras, la tienda nos da una comisión y a ti no te cuesta más.'
    } elseif ($f.acortar -and $acortador -match '\{url\}') {
        $f.boton.url = $acortador.Replace('{url}', [uri]::EscapeDataString($f.boton.url))
        $f.boton.nota = 'Este enlace pasa por un acortador con anuncios, que nos ayuda a mantener Guatusa. El archivo es el oficial.'
    }
}

# Portadas de texto para lo que no tiene imagen propia (por ejemplo, los servicios)
function Get-SvgPortada([string]$Titulo, [string]$Subtitulo, [string]$Color) {
    if ($Color -notmatch '^#[0-9A-Fa-f]{6}$') { $Color = '#157A5A' }
    $tam = if ($Titulo.Length -gt 14) { 48 } else { 64 }
    @"
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
  <rect width="640" height="360" fill="$Color"/>
  <text x="320" y="185" text-anchor="middle" font-family="Segoe UI, system-ui, -apple-system, Roboto, Arial, sans-serif" font-size="$tam" font-weight="700" fill="#FFFFFF">$(Html $Titulo)</text>
  <text x="320" y="238" text-anchor="middle" font-family="Segoe UI, system-ui, -apple-system, Roboto, Arial, sans-serif" font-size="26" fill="#FFFFFF" fill-opacity="0.85">$(Html $Subtitulo)</text>
</svg>
"@
}

# ---------------------------------------------------------------- orden

$porSeccion = [ordered]@{}
foreach ($k in $script:Secciones.Keys) {
    $grupos = @($script:Secciones[$k].grupos | ForEach-Object { $_.id })
    $porSeccion[$k] = @($fichas | Where-Object { $_.seccion -eq $k } | Sort-Object `
            @{ Expression = { $i = [array]::IndexOf($grupos, $_.grupo); if ($i -lt 0) { 99 } else { $i } } },
            @{ Expression = { [double]$_.orden } },
            @{ Expression = { $_.titulo } })
}

# ---------------------------------------------------------------- escribir el sitio

if (Test-Path -LiteralPath $dirSalida) { Remove-Item -LiteralPath $dirSalida -Recurse -Force }
New-Item -ItemType Directory -Force -Path $dirSalida | Out-Null
Copy-Item -Path (Join-Ruta $raiz 'estatico' '*') -Destination $dirSalida -Recurse -Force

$sufijos = @{ 'regalos' = ' gratis por tiempo limitado'; 'juegos-gratis' = ', juego gratis'; 'ofertas' = ' en oferta'; 'programas' = ', programa gratis'; 'cine' = ', gratis y legal' }
$paginas = New-Object System.Collections.Generic.List[object]

foreach ($k in $porSeccion.Keys) {
    $lista = @($porSeccion[$k])
    $visibles = @($lista | Where-Object { -not $_.oculto })
    foreach ($f in $lista) {
        $p = $f.portada
        if ($p -and (Get-Prop $p 'texto')) {
            Write-Texto (Join-Ruta $dirSalida 'img' 'portadas' "$($f.slug).svg") (Get-SvgPortada $f.titulo (Get-Prop $p 'subtitulo' 'Gratis y legal') (Get-Prop $p 'color' ''))
            $p.url = "/img/portadas/$($f.slug).svg"
            $p.ancho = 640
            $p.alto = 360
        }
    }
    foreach ($f in $lista) {
        $mismos = @($visibles | Where-Object { $_.ruta -ne $f.ruta -and -not $_.terminado -and $_.grupo -eq $f.grupo } | Select-Object -First 4)
        if ($mismos.Count -lt 4) {
            $mismos += @($visibles | Where-Object { $_.ruta -ne $f.ruta -and -not $_.terminado -and $_.grupo -ne $f.grupo } | Select-Object -First (4 - $mismos.Count))
        }
        $imagen = ''
        $url = [string](Get-Prop $f.portada 'url' '')
        if ($url -match '^https?://' -and $url -notmatch '\.svg($|\?)') { $imagen = $url }
        $html = New-Pagina -Titulo "$($f.titulo)$($sufijos[$k]) · Guatusa" -Descripcion $f.resumen -Ruta $f.ruta `
            -Cuerpo (Get-Ficha $f $mismos) -Seccion $k -Imagen $imagen -NoIndexar:([bool]($f.terminado -or $f.oculto)) `
            -Migas @(@{ n = 'Inicio'; u = '/' }, @{ n = $script:Secciones[$k].menu; u = "/$k/" }, @{ n = $f.titulo; u = $f.ruta })
        Write-Texto (Join-Ruta $dirSalida $k $f.slug 'index.html') $html
        if (-not $f.terminado -and -not $f.oculto) { $paginas.Add([pscustomobject]@{ ruta = $f.ruta; fecha = $f.fecha }) }
    }
    Write-Texto (Join-Ruta $dirSalida $k 'index.html') (Get-PaginaSeccion $k $visibles)
    $paginas.Add([pscustomobject]@{ ruta = "/$k/"; fecha = $ahora })
}

# Portada con las cifras del dia
$activos = @($porSeccion['regalos'] | Where-Object { $_.grupo -eq 'activos' })
$valor = 0.0
foreach ($f in $activos) { if ($f.precio_normal) { $valor += [double]$f.precio_normal } }
$cuenta = { param($k) @($porSeccion[$k] | Where-Object { -not $_.terminado -and -not $_.oculto }).Count }
$cifras = @("<strong>$($activos.Count)</strong> juegos regalados ahora")
if ($valor -gt 0) { $cifras += "que valen <strong>$(Format-Dinero $valor)</strong>" }
$cifras += "<strong>$(& $cuenta 'juegos-gratis')</strong> juegos gratis para siempre"
$cifras += "<strong>$(& $cuenta 'ofertas')</strong> ofertas"
$cifras += "<strong>$(& $cuenta 'programas')</strong> programas"
$cifras += "<strong>$(& $cuenta 'cine')</strong> películas, series y servicios"
$vistasInicio = [ordered]@{}
foreach ($k in $porSeccion.Keys) { $vistasInicio[$k] = @($porSeccion[$k] | Where-Object { -not $_.oculto }) }
Write-Texto (Join-Ruta $dirSalida 'index.html') (Get-PaginaInicio $vistasInicio $cifras)
Write-Texto (Join-Ruta $dirSalida 'acerca' 'index.html') (Get-PaginaAcerca)
Write-Texto (Join-Ruta $dirSalida 'privacidad' 'index.html') (Get-PaginaPrivacidad)
Write-Texto (Join-Ruta $dirSalida '404.html') (Get-Pagina404)
foreach ($r in '/', '/acerca/', '/privacidad/') { $paginas.Add([pscustomobject]@{ ruta = $r; fecha = $ahora }) }

Write-Texto (Join-Ruta $dirSalida 'sitemap.xml') (Get-Sitemap ($paginas | Sort-Object ruta))
Write-Texto (Join-Ruta $dirSalida 'robots.txt') (Get-Robots)
Write-Texto (Join-Ruta $dirSalida '_headers') (Get-Cabeceras)
$ads = Get-AdsTxt
if ($ads) { Write-Texto (Join-Ruta $dirSalida 'ads.txt') $ads }
$recientes = @($fichas | Where-Object { $_.telegram -and -not $_.terminado -and -not $_.oculto -and $_.telegram.tipo -ne 'contenido' } | Sort-Object @{ Expression = { (Get-Fecha $_.fecha).UtcTicks }; Descending = $true })
Write-Texto (Join-Ruta $dirSalida 'novedades.xml') (Get-Novedades $recientes)

# ---------------------------------------------------------------- guardar datos y avisos para Telegram

Write-Json (Join-Ruta $dirDatos 'regalos.json') @($regalos)
Write-Json (Join-Ruta $dirDatos 'itch.json') @($itch)
Write-Json (Join-Ruta $dirDatos 'ofertas.json') @($ofertas)
# Solo se guardan los datos de Steam usados en los ultimos 60 dias
$usadas = @{}
foreach ($r in $ofertas) { $usadas[[string]$r.appid] = $true }
foreach ($v in $nombres.Values) { if ($v.appid) { $usadas[[string]$v.appid] = $true } }
foreach ($k in @($apps.Keys)) { if (-not $usadas.ContainsKey($k) -and -not (Test-Fresco $apps[$k] 1440)) { $apps.Remove($k) } }
foreach ($k in @($nombres.Keys)) { if (-not (Test-Fresco $nombres[$k] 1440)) { $nombres.Remove($k) } }
Write-Json (Join-Ruta $dirDatos 'steam.json') ([ordered]@{ apps = (ConvertTo-Ordenado $apps); nombres = (ConvertTo-Ordenado $nombres) })
Write-Json (Join-Ruta $dirDatos 'github.json') (ConvertTo-Ordenado $githubGuardado)
Write-Json (Join-Ruta $dirDatos 'estado.json') $estado

$avisos = @(foreach ($f in $fichas) {
        if (-not $f.telegram -or $f.terminado -or $f.oculto) { continue }
        [ordered]@{
            clave = $f.telegram.clave; tipo = $f.telegram.tipo; texto = $f.telegram.texto; detalle = $f.telegram.detalle
            descuento = [int](Get-Prop $f.telegram 'descuento' 0); url = (Get-UrlAbsoluta $f.ruta)
            imagen = [string](Get-Prop $f.portada 'url' ''); termina = if ($f.termina) { Format-FechaIso ([DateTimeOffset]$f.termina) } else { $null }
        }
    })
Write-Json (Join-Ruta $raiz 'telegram-pendientes.json') $avisos

$total = 0
foreach ($k in $porSeccion.Keys) { $total += @($porSeccion[$k]).Count }
Write-Host "Listo: $total fichas en $dirSalida"
