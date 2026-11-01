# Fuentes de datos de Guatusa:
#  - GamerPower: juegos regalados por tiempo limitado (API gratis, pide un enlace activo a GamerPower.com).
#  - itch.io: lista RSS de juegos gratis.
#  - Tienda de Steam: ofertas con precios para Honduras (cc=hn) y datos de cada juego (requisitos, idiomas).
#  - GitHub: la ultima version de cada programa.
# Si una fuente falla, la funcion lanza un error y armar.ps1 sigue con lo que tenia guardado.

$script:ApiSteam = 'https://store.steampowered.com/api'

# ---------------------------------------------------------------- GamerPower

# Tienda de un regalo segun el texto entre parentesis del titulo y la lista de plataformas
$script:PatronesTienda = [ordered]@{
    epic        = '(?i)\bepic\b'
    steam       = '(?i)\bsteam\b'
    gog         = '(?i)\bgog\b'
    itch        = '(?i)\bitch'
    indiegala   = '(?i)indie\s*gala'
    prime       = '(?i)prime\s*gaming|amazon'
    ubisoft     = '(?i)ubisoft|uplay'
    ea          = '(?i)\bea\b|\borigin\b'
    stove       = '(?i)\bstove\b'
    battlenet   = '(?i)battle\.net'
    xbox        = '(?i)xbox'
    playstation = '(?i)playstation|\bps[45]\b'
    nintendo    = '(?i)nintendo|\bswitch\b'
    movil       = '(?i)mobile|android|\bios\b'
    vr          = '(?i)\brift\b|\bquest\b|\bvr\b'
}

function Get-TiendaRegalo([string]$TextoTienda, [string]$Plataformas) {
    foreach ($texto in @($TextoTienda, $Plataformas)) {
        if (-not $texto) { continue }
        foreach ($k in $script:PatronesTienda.Keys) { if ($texto -match $script:PatronesTienda[$k]) { return $k } }
    }
    'otra'
}

function Get-RegalosGamerPower {
    $lista = Get-Json 'https://www.gamerpower.com/api/giveaways?type=game&sort-by=date'
    foreach ($g in @($lista)) {
        if ((Get-Prop $g 'status') -ne 'Active') { continue }
        $titulo = ([string]$g.title).Trim()
        $textoTienda = ''
        if ($titulo -match '\(([^()]+)\)\s*(?:key\s+)?giveaway\s*$') { $textoTienda = $Matches[1] }
        $nombre = $titulo -replace '(?i)\s*\([^()]+\)\s*(key\s+)?giveaway\s*$', '' -replace '(?i)\s+(key\s+)?giveaway\s*$', ''
        $valor = $null
        if ([string]$g.worth -match '^\$?(\d+(?:\.\d+)?)$') { $valor = [double]::Parse($Matches[1], $script:Inv) }
        $termina = $null
        # GamerPower no dice la zona horaria: se toma como hora de Honduras y la ficha avisa que es aproximada
        if ((Get-Prop $g 'end_date') -and [string]$g.end_date -ne 'N/A') { $termina = Get-FechaHonduras $g.end_date }
        $publicado = Get-FechaHonduras $g.published_date
        [pscustomobject][ordered]@{
            clave        = "gp-$($g.id)"
            id           = [int]$g.id
            nombre       = $nombre.Trim()
            tienda       = Get-TiendaRegalo $textoTienda ([string]$g.platforms)
            tienda_texto = $textoTienda
            plataformas  = [string]$g.platforms
            valor        = $valor
            imagen       = [string](Get-Prop $g 'image' (Get-Prop $g 'thumbnail' ''))
            url          = [string]$g.open_giveaway_url
            url_fuente   = [string]$g.gamerpower_url
            publicado    = if ($publicado) { Format-FechaIso $publicado } else { $null }
            termina      = if ($termina) { Format-FechaIso $termina } else { $null }
            es_clave     = [bool]($titulo -match '(?i)\bkey\b')
            es_paquete   = [bool]($titulo -match '(?i)\bbundle\b')
        }
    }
}

# ---------------------------------------------------------------- itch.io

$script:GenerosItch = @{
    'Action' = 'Acción'; 'Adventure' = 'Aventura'; 'Card Game' = 'Cartas'; 'Educational' = 'Educativo'
    'Fighting' = 'Peleas'; 'Interactive Fiction' = 'Ficción interactiva'; 'Platformer' = 'Plataformas'
    'Puzzle' = 'Rompecabezas'; 'Racing' = 'Carreras'; 'Rhythm' = 'Ritmo'; 'Role Playing' = 'Rol'
    'Shooter' = 'Disparos'; 'Simulation' = 'Simulación'; 'Sports' = 'Deportes'; 'Strategy' = 'Estrategia'
    'Survival' = 'Supervivencia'; 'Visual Novel' = 'Novela visual'; 'Other' = 'Otro'
}
$script:PlataformasItch = [ordered]@{ windows = 'Windows'; osx = 'macOS'; linux = 'Linux'; android = 'Android'; html = 'Navegador' }

function Get-JuegosItch([int]$Paginas = 1, [string[]]$Bloqueos = @()) {
    $vistos = @{}
    $orden = 0
    for ($p = 1; $p -le $Paginas; $p++) {
        $url = if ($p -eq 1) { 'https://itch.io/games/free.xml' } else { "https://itch.io/games/free.xml?page=$p" }
        $xml = [xml](Get-Texto $url)
        foreach ($it in @($xml.rss.channel.item)) {
            $enlace = [string]$it.link
            if ($enlace -notmatch '^https://([a-z0-9-]+)\.itch\.io/[A-Za-z0-9_-]+/?$' -or $vistos.ContainsKey($enlace)) { continue }
            $autor = $Matches[1]
            $vistos[$enlace] = $true
            $nombre = ([string]$it.plainTitle).Trim()
            $completo = [string]$it.title
            if (-not $nombre -or [string]$it.price -notmatch '^\$?0(\.0+)?$') { continue }
            $bloqueado = $false
            foreach ($b in $Bloqueos) { if ("$nombre $completo" -match $b) { $bloqueado = $true; break } }
            if ($bloqueado) { continue }
            $genero = ''
            foreach ($m in [regex]::Matches($completo, '\[([^\]]+)\]')) {
                $g = $m.Groups[1].Value
                if ($script:GenerosItch.ContainsKey($g)) { $genero = $script:GenerosItch[$g]; break }
            }
            $plataformas = @()
            if ($it.platforms) {
                foreach ($n in @($it.platforms.ChildNodes)) {
                    if ($script:PlataformasItch.Contains($n.Name)) { $plataformas += $script:PlataformasItch[$n.Name] }
                }
            }
            $creado = Get-Fecha ([string]$it.createDate)
            $orden++
            [pscustomobject][ordered]@{
                clave       = 'itch-' + (Get-Slug ($enlace -replace '^https://', '') 120)
                nombre      = $nombre
                autor       = $autor
                url         = $enlace
                imagen      = [string]$it.imageurl
                genero      = $genero
                plataformas = @($plataformas)
                creado      = if ($creado) { Format-FechaIso $creado } else { $null }
                orden       = $orden
            }
        }
    }
}

# ---------------------------------------------------------------- Steam

function Get-OfertasSteam {
    $d = Get-Json "$script:ApiSteam/featuredcategories?cc=hn&l=spanish"
    $candidatos = @($d.specials.items) + @(@($d.top_sellers.items) | Where-Object { $_.discounted })
    $vistos = @{}
    foreach ($i in $candidatos) {
        if ($null -eq $i -or [int](Get-Prop $i 'type' 1) -ne 0 -or $vistos.ContainsKey([int]$i.id)) { continue }
        if ([int](Get-Prop $i 'discount_percent' 0) -le 0 -or [int](Get-Prop $i 'final_price' 0) -le 0) { continue }
        $vistos[[int]$i.id] = $true
        $plataformas = @()
        if ($i.windows_available) { $plataformas += 'Windows' }
        if ($i.mac_available) { $plataformas += 'macOS' }
        if ($i.linux_available) { $plataformas += 'Linux' }
        $termina = $null
        if ([long](Get-Prop $i 'discount_expiration' 0) -gt 0) { $termina = Format-FechaIso (ConvertFrom-Unix ([long]$i.discount_expiration)) }
        [pscustomobject][ordered]@{
            clave         = "steam-$($i.id)"
            appid         = [int]$i.id
            nombre        = ([string]$i.name).Trim()
            descuento     = [int]$i.discount_percent
            precio_normal = [double]$i.original_price / 100
            precio        = [double]$i.final_price / 100
            moneda        = [string]$i.currency
            imagen        = ([string](Get-Prop $i 'header_image' '')) -replace '\?t=\d+$', ''
            plataformas   = @($plataformas)
            termina       = $termina
        }
    }
}

# Idiomas: "Inglés<strong>*</strong>, Español de Hispanoamérica, ...". El asterisco marca audio.
function Get-IdiomasSteam([string]$Texto) {
    $r = [ordered]@{ texto_es = $false; audio_es = $false; latino = $false }
    if (-not $Texto) { return [pscustomobject]$r }
    $limpio = $Texto -replace '(?i)<br\s*/?>.*$', ''
    foreach ($parte in ($limpio -split ',')) {
        $nombre = ConvertTo-TextoPlano ($parte -replace '\*', '')
        if ($nombre -notmatch '^Español') { continue }
        $r.texto_es = $true
        if ($nombre -match 'Hispanoamérica') { $r.latino = $true }
        if ($parte -match '\*') { $r.audio_es = $true }
    }
    [pscustomobject]$r
}

# Requisitos minimos para PC como lista de textos ("Memoria: 6 GB de RAM")
function Get-RequisitosSteam($Requisitos) {
    if ($null -eq $Requisitos -or $Requisitos -is [array]) { return @() }
    $html = [string](Get-Prop $Requisitos 'minimum' '')
    if (-not $html) { return @() }
    $partes = if ($html -match '(?i)<li') { [regex]::Split($html, '(?i)<li[^>]*>') } else { [regex]::Split($html, '(?i)<br\s*/?>') }
    $lista = foreach ($p in $partes) {
        $t = ConvertTo-TextoPlano $p
        $t = $t -replace '^(Mínimo|Minimum|Requisitos mínimos)\s*:?\s*', '' -replace '\s*\*\s*:', ':' -replace '\s*:\s*', ': ' -replace ': $', ''
        if ($t -and $t.Length -le 200) { $t }
    }
    , @($lista | Select-Object -First 10)
}

function Get-DetallesSteam([int]$AppId) {
    $r = Get-Json "$script:ApiSteam/appdetails?appids=$AppId&cc=hn&l=spanish"
    $e = $r."$AppId"
    if (-not $e -or -not $e.success) { return }
    $d = $e.data
    $anio = $null
    if ([string](Get-Prop $d.release_date 'date' '') -match '(\d{4})') { $anio = [int]$Matches[1] }
    [pscustomobject][ordered]@{
        appid      = $AppId
        nombre     = [string]$d.name
        tipo       = [string]$d.type
        gratis     = [bool](Get-Prop $d 'is_free' $false)
        generos    = @(@(Get-Prop $d 'genres' @()) | ForEach-Object { [string]$_.description })
        desarrollo = @(@(Get-Prop $d 'developers' @()) | ForEach-Object { [string]$_ })
        anio       = $anio
        idiomas    = Get-IdiomasSteam ([string](Get-Prop $d 'supported_languages' ''))
        requisitos = Get-RequisitosSteam (Get-Prop $d 'pc_requirements')
        edad       = [int](Get-Prop $d 'required_age' 0)
        leido      = Format-FechaIso (Get-AhoraUtc)
    }
}

# Busca un juego por nombre exacto en la tienda de Steam. Devuelve 0 si no hay ninguno con ese nombre
# o si hay mas de uno (nombres comunes como "Wordle": mejor sin datos que con los de otro juego).
function Find-AppSteam([string]$Nombre) {
    $r = Get-Json ("$script:ApiSteam/storesearch/?term=" + [uri]::EscapeDataString($Nombre) + '&l=spanish&cc=hn')
    $buscado = Get-NombreComparable $Nombre
    $iguales = @(@(Get-Prop $r 'items' @()) | Where-Object { $_.type -eq 'app' -and (Get-NombreComparable $_.name) -eq $buscado })
    if ($iguales.Count -eq 1) { return [int]$iguales[0].id }
    0
}

# ---------------------------------------------------------------- GitHub

function Get-UltimaVersionGitHub([string]$Repo) {
    $cabeceras = @{ 'Accept' = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28' }
    if ($env:GITHUB_TOKEN) { $cabeceras['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
    $r = Get-Json "https://api.github.com/repos/$Repo/releases/latest" -Cabeceras $cabeceras
    $fecha = Get-Fecha $r.published_at
    # Las etiquetas vienen como "v1.2.3", "Audacity-4.0.1" o "26.05": se toma el numero
    $etiqueta = [string]$r.tag_name
    $version = if ($etiqueta -match '(\d+(?:\.\d+)+)') { $Matches[1] } else { $etiqueta -replace '^[vV]', '' }
    [pscustomobject][ordered]@{
        repo     = $Repo
        etiqueta = $etiqueta
        version  = $version
        fecha    = if ($fecha) { Format-FechaIso $fecha } else { $null }
        url      = [string]$r.html_url
        archivos = @(@($r.assets) | Where-Object { $_ } | ForEach-Object {
                [pscustomobject][ordered]@{ nombre = [string]$_.name; url = [string]$_.browser_download_url; tamano = [long]$_.size }
            })
        leido    = Format-FechaIso (Get-AhoraUtc)
    }
}
