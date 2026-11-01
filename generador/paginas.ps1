# Arma el HTML de Guatusa: la plantilla comun, las tarjetas, las fichas y las paginas fijas.
# Todo texto que viene de afuera pasa por Html (escapar) y todo enlace por Enlace (solo http/https o rutas del sitio).
# (No se llaman H ni U: "h" es un atajo de PowerShell para Get-History y gana sobre cualquier funcion.)
# Necesita $script:Sitio y $script:Secciones (los llena armar.ps1).

function Get-UrlAbsoluta([string]$Ruta) { ([string]$script:Sitio.url).TrimEnd('/') + $Ruta }

function Get-TextoBusqueda([string]$Texto) {
    $t = $Texto.Normalize([Text.NormalizationForm]::FormD)
    ([regex]::Replace($t, '\p{Mn}', '')).ToLowerInvariant() -replace '\s+', ' '
}

function Get-EnlaceTelegram {
    $canal = [string]$script:Sitio.telegram
    if ($canal -match '^[A-Za-z][A-Za-z0-9_]{4,31}$') { return "https://t.me/$canal" }
    ''
}

# ---------------------------------------------------------------- plantilla

function Get-Cabecera([string]$Activa) {
    $enlaces = foreach ($k in $script:Secciones.Keys) {
        $actual = if ($k -eq $Activa) { ' aria-current="page"' } else { '' }
        "        <a href=`"/$k/`"$actual>$(Html $script:Secciones[$k].menu)</a>"
    }
    @"
  <header class="cabecera">
    <div class="contenedor cabecera-fila">
      <a class="marca" href="/">
        <img src="/img/guatusa.svg" alt="" width="36" height="36">
        <span>Guatusa<small>de Brizna Soft</small></span>
      </a>
      <nav class="menu" aria-label="Secciones">
$($enlaces -join "`n")
      </nav>
    </div>
  </header>
"@
}

function Get-Pie {
    $act = $script:Sitio.actualizado
    $telegram = Get-EnlaceTelegram
    $enlaceTelegram = if ($telegram) { "`n        <a href=`"$(Enlace $telegram)`">Telegram</a>" } else { '' }
    @"
  <footer class="pie">
    <div class="contenedor pie-fila">
      <p>Guatusa es parte de <a href="$(Enlace $script:Sitio.brizna)">Brizna Soft</a> · Honduras</p>
      <nav class="redes" aria-label="Enlaces">
        <a href="/acerca/">Acerca de</a>
        <a href="/privacidad/">Privacidad</a>$enlaceTelegram
        <a href="$(Enlace $script:Sitio.repo)">GitHub</a>
        <a href="$(Enlace $script:Sitio.paypal)">Donar</a>
      </nav>
    </div>
    <div class="contenedor">
      <p class="creditos">Actualizado el $(Format-FechaLarga $act) a las $(Format-Hora $act) (hora de Honduras). Regalos: datos de <a href="https://www.gamerpower.com/">GamerPower</a>. Juegos gratis de <a href="https://itch.io/">itch.io</a>. Ofertas y requisitos: tienda de Steam. Las marcas, nombres y portadas son de sus dueños.</p>
    </div>
  </footer>
"@
}

function New-Pagina {
    param(
        [string]$Titulo, [string]$Descripcion, [string]$Ruta, [string]$Cuerpo, [string]$Seccion = '',
        [string]$Imagen = '', $Migas = $null, [switch]$NoIndexar
    )
    $abs = Get-UrlAbsoluta $Ruta
    if (-not $Imagen) { $Imagen = Get-UrlAbsoluta '/img/compartir.png' }
    $v = $script:Sitio.version
    $extra = New-Object System.Collections.Generic.List[string]
    if ($NoIndexar) { $extra.Add('  <meta name="robots" content="noindex">') }
    $cliente = [string]$script:Sitio.adsense
    if ($cliente -match '^ca-pub-\d{10,20}$') {
        $extra.Add("  <meta name=`"google-adsense-account`" content=`"$cliente`">")
        $extra.Add("  <script async src=`"https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$cliente`" crossorigin=`"anonymous`"></script>")
    }
    if ($Migas) {
        $pos = 0
        # $Migas: lista de @{ n = 'Nombre'; u = '/ruta/' }
        $elementos = foreach ($m in @($Migas)) {
            $pos++
            [ordered]@{ '@type' = 'ListItem'; 'position' = $pos; 'name' = $m.n; 'item' = (Get-UrlAbsoluta $m.u) }
        }
        $ld = [ordered]@{ '@context' = 'https://schema.org'; '@type' = 'BreadcrumbList'; 'itemListElement' = @($elementos) }
        # Ningun "<" dentro del script ("</script>" o "<!--" cambiarian como se lee la pagina). Se cambia por la
        # secuencia JSON barra-u-003c, armada con [char]92 para que ninguna herramienta la convierta de vuelta en "<"
        $menorQue = [string][char]92 + 'u003c'
        $json = (ConvertTo-Json -InputObject $ld -Depth 6 -Compress).Replace('<', $menorQue)
        $extra.Add("  <script type=`"application/ld+json`">$json</script>")
    }
    @"
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(Html $Titulo)</title>
  <meta name="description" content="$(Html $Descripcion)">
  <meta name="theme-color" content="#1D9E75">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <link rel="canonical" href="$(Html $abs)">
  <link rel="icon" href="/img/guatusa.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/estilos.css?v=$v">
  <link rel="alternate" type="application/rss+xml" title="Novedades de Guatusa" href="/novedades.xml">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Guatusa · Brizna Soft">
  <meta property="og:title" content="$(Html $Titulo)">
  <meta property="og:description" content="$(Html $Descripcion)">
  <meta property="og:url" content="$(Html $abs)">
  <meta property="og:image" content="$(Enlace $Imagen)">
  <meta property="og:locale" content="es_LA">
  <meta name="twitter:card" content="summary_large_image">
$($extra -join "`n")
</head>
<body>
  <a class="saltar" href="#contenido">Ir al contenido</a>

$(Get-Cabecera $Seccion)

  <main id="contenido">
$Cuerpo
  </main>

$(Get-Pie)

  <script src="/guatusa.js?v=$v" defer></script>
</body>
</html>
"@
}

# ---------------------------------------------------------------- piezas

function Get-Imagen($Item, [string]$Clase, [switch]$Grande) {
    $p = Get-Prop $Item 'portada'
    $url = Get-Prop $p 'url' '/img/sin-portada.svg'
    $ancho = Get-Entero (Get-Prop $p 'ancho') 640
    $alto = Get-Entero (Get-Prop $p 'alto') 360
    $ajuste = if ((Get-Prop $p 'ajuste') -eq 'contener') { ' contener' } else { '' }
    $alt = ''
    if ($Grande) { $alt = Get-Prop $p 'alt' "Portada de $($Item.titulo)" }
    $carga = if ($Grande) { 'eager' } else { 'lazy' }
    $clases = "$Clase$ajuste".Trim()
    $atributoClase = if ($clases) { " class=`"$clases`"" } else { '' }
    "<img$atributoClase src=`"$(Enlace $url)`" alt=`"$(Html $alt)`" width=`"$ancho`" height=`"$alto`" loading=`"$carga`" decoding=`"async`" referrerpolicy=`"no-referrer`" data-respaldo>"
}

function Get-Insignias($Item) {
    $partes = foreach ($i in @(Get-Prop $Item 'insignias' @())) {
        $clase = Get-Prop $i 'clase' ''
        $c = if ($clase) { " $clase" } else { '' }
        "<span class=`"insignia$c`">$(Html (Get-Prop $i 'texto'))</span>"
    }
    if (-not $partes) { return '' }
    "<div class=`"insignias`">$($partes -join '')</div>"
}

function Get-TextoTermina($Item) {
    $t = Get-Prop $Item 'termina'
    if (-not $t) { return '' }
    $f = [DateTimeOffset]$t
    "Termina el $(Format-FechaLarga $f -SinAnio)"
}

# Precio tachado y precio de ahora (0 = Gratis)
function Get-PrecioHtml($Item) {
    $normal = Get-Prop $Item 'precio_normal'
    $ahora = Get-Prop $Item 'precio'
    if ($null -eq $ahora) { return '' }
    $txtAhora = if ([double]$ahora -le 0) { 'Gratis' } else { Format-Dinero $ahora }
    $tachado = if ($null -ne $normal -and [double]$normal -gt [double]$ahora) { "<span class=`"tachado`">$(Format-Dinero $normal)</span> " } else { '' }
    "$tachado<strong>$txtAhora</strong>"
}

function Get-Tarjeta($Item) {
    $terminada = [bool](Get-Prop $Item 'terminado' $false)
    $clase = if ($terminada) { 'tarjeta terminada' } else { 'tarjeta' }
    $izq = Get-PrecioHtml $Item
    if (-not $izq) { $izq = Html (Get-Prop $Item 'etiqueta_pie' '') }
    $der = ''
    if ($terminada) { $der = 'Terminó' }
    elseif (Get-Prop $Item 'termina') {
        $der = "<span data-termina=`"$(Format-FechaIso ([DateTimeOffset]$Item.termina))`">$(Html (Get-TextoTermina $Item))</span>"
    }
    $texto = Get-TextoBusqueda ("$($Item.titulo) $(Get-Prop $Item 'resumen' '') $((@(Get-Prop $Item 'etiquetas_texto' @())) -join ' ')")
    $etiquetas = (@(Get-Prop $Item 'etiquetas' @())) -join ' '
    @"
        <li class="$clase" data-texto="$(Html $texto)" data-etiquetas="$(Html $etiquetas)">
          $(Get-Imagen $Item 'tarjeta-imagen')
          <div class="tarjeta-cuerpo">
            $(Get-Insignias $Item)
            <h3><a href="$(Enlace $Item.ruta)">$(Html $Item.titulo)</a></h3>
            <p class="resumen">$(Html (Get-Prop $Item 'resumen' ''))</p>
            <div class="tarjeta-pie"><span>$izq</span><span>$der</span></div>
          </div>
        </li>
"@
}

function Get-Rejilla($Items, [string]$Id = '') {
    $atributo = if ($Id) { " id=`"$Id`"" } else { '' }
    $tarjetas = foreach ($i in @($Items)) { Get-Tarjeta $i }
    "      <ul class=`"rejilla`"$atributo>`n$($tarjetas -join '')      </ul>"
}

# Botones para filtrar una lista; los nombres de cada grupo salen de $Item.filtros
function Get-Filtros($Items, [string]$IdLista, [string[]]$Grupos) {
    $nombres = @{ tienda = 'Tienda'; plataforma = 'Funciona en'; genero = 'Tipo'; categoria = 'Categoría' }
    $bloques = New-Object System.Collections.Generic.List[string]
    foreach ($g in $Grupos) {
        $cuenta = @{}
        foreach ($i in @($Items)) {
            foreach ($v in @((Get-Prop (Get-Prop $i 'filtros' @{}) $g @()))) {
                if (Test-Texto $v) { $cuenta[[string]$v] = 1 + [int](Get-Prop $cuenta ([string]$v) 0) }
            }
        }
        if ($cuenta.Count -lt 2) { continue }
        $valores = $cuenta.GetEnumerator() | Sort-Object @{ Expression = { $_.Value }; Descending = $true }, @{ Expression = { $_.Key } } | Select-Object -First 10
        $chips = foreach ($par in $valores) {
            "<button type=`"button`" class=`"chip`" data-grupo=`"$g`" data-etiqueta=`"$(Html "${g}:$(Get-Slug $par.Key)")`" aria-pressed=`"false`">$(Html $par.Key)</button>"
        }
        $bloques.Add("<span class=`"rotulo`">$(Html $nombres[$g]):</span> $($chips -join ' ')")
    }
    $buscar = "<input class=`"buscar`" type=`"search`" placeholder=`"Buscar por nombre...`" aria-label=`"Buscar en esta lista`">"
    "      <div class=`"filtros`" data-para=`"$IdLista`" hidden>$buscar $($bloques -join ' ')</div>"
}

function Get-ListaConFiltros($Items, [string]$Id, [string[]]$Grupos) {
    # Con pocas tarjetas el buscador estorba
    $filtros = if (@($Items).Count -ge 8) { Get-Filtros $Items $Id $Grupos } else { '' }
    @"
$filtros
$(Get-Rejilla $Items $Id)
      <p class="sin-resultados" data-para="$Id" hidden>No encontramos nada con esa búsqueda.</p>
"@
}

function Get-CajasApoyo {
    $telegram = Get-EnlaceTelegram
    $cajaTelegram = ''
    if ($telegram) {
        $cajaTelegram = @"

      <div class="caja">
        <div>
          <h2>Avisos en Telegram</h2>
          <p>Cada regalo y cada oferta nueva llega al canal apenas aparece, para que no se te pase ninguno.</p>
        </div>
        <div class="botones"><a class="boton telegram" href="$(Enlace $telegram)">Unirme al canal</a></div>
      </div>
"@
    }
    @"
    <section class="seccion" aria-label="Apoya a Guatusa">
      <div class="contenedor">
      <div class="caja">
        <div>
          <h2>Apoya a Guatusa</h2>
          <p>Guatusa es gratis y la hace Brizna Soft desde Honduras. Si te ahorró dinero, puedes ayudarnos con una donación por PayPal. Cualquier monto ayuda, y compartirla también.</p>
        </div>
        <div class="botones"><a class="boton paypal" href="$(Enlace $script:Sitio.paypal)">Donar con PayPal</a></div>
      </div>$cajaTelegram
      </div>
    </section>
"@
}

# ---------------------------------------------------------------- ficha

function Get-Ficha($Item, $Relacionados) {
    $seccion = $script:Secciones[$Item.seccion]
    $terminado = [bool](Get-Prop $Item 'terminado' $false)
    $boton = Get-Prop $Item 'boton'

    $precio = Get-PrecioHtml $Item
    $bloquePrecio = if ($precio) { "          <p class=`"precio`">$precio</p>`n" } else { '' }

    if ($terminado -or -not $boton) {
        $textoFin = Get-Prop $Item 'texto_terminado' 'Esta promoción ya terminó'
        $htmlBoton = "          <span class=`"boton grande desactivado`" aria-disabled=`"true`">$(Html $textoFin)</span>"
    } else {
        $rel = Get-Prop $boton 'rel' 'noopener'
        $htmlBoton = "          <a class=`"boton principal grande`" href=`"$(Enlace $boton.url)`" rel=`"$(Html $rel)`">$(Html $boton.texto)</a>"
        $nota = Get-Prop $boton 'nota'
        if ($nota) { $htmlBoton += "`n          <p class=`"nota-boton`">$(Html $nota)</p>" }
    }
    $extras = @(Get-Prop $Item 'otros_botones' @())
    if ($extras.Count -gt 0) {
        $enlaces = foreach ($b in $extras) { "<a href=`"$(Enlace $b.url)`" rel=`"$(Html (Get-Prop $b 'rel' 'noopener'))`">$(Html $b.texto)</a>" }
        $htmlBoton += "`n          <p class=`"botones-extra`">$($enlaces -join ' ')</p>"
    }

    $filas = foreach ($d in @(Get-Prop $Item 'datos' @())) {
        $valor = if (Get-Prop $d 'url') { "<a href=`"$(Enlace $d.url)`" rel=`"noopener`">$(Html $d.v)</a>" } else { Html $d.v }
        "            <dt>$(Html $d.e)</dt><dd>$valor</dd>"
    }
    $bloqueDatos = if ($filas) { "          <dl class=`"datos`">`n$($filas -join "`n")`n          </dl>" } else { '' }

    $credito = ''
    $p = Get-Prop $Item 'portada'
    if (Get-Prop $p 'credito') {
        $c = Html $p.credito
        if (Get-Prop $p 'credito_url') { $c = "<a href=`"$(Enlace $p.credito_url)`" rel=`"noopener`">$c</a>" }
        $credito = "`n          <figcaption>Imagen: $c</figcaption>"
    }

    $texto = New-Object System.Collections.Generic.List[string]
    $parrafos = @(Get-Prop $Item 'parrafos' @())
    if ($parrafos.Count -gt 0) {
        $texto.Add("        <h2>$(Html (Get-Prop $Item 'titulo_texto' 'Qué es'))</h2>")
        foreach ($x in $parrafos) { $texto.Add("        <p>$(Html $x)</p>") }
    }
    $req = @(Get-Prop $Item 'requisitos' @())
    if ($req.Count -gt 0) {
        $texto.Add("        <h2>$(Html (Get-Prop $Item 'titulo_requisitos' 'Requisitos'))</h2>")
        $texto.Add("        <ul class=`"lista`">$((@($req | ForEach-Object { "<li>$(Html $_)</li>" })) -join '')</ul>")
        $nr = Get-Prop $Item 'nota_requisitos'
        if ($nr) { $texto.Add("        <p class=`"fuente`">$(Html $nr)</p>") }
    }
    $pasos = @(Get-Prop $Item 'pasos' @())
    if ($pasos.Count -gt 0 -and -not $terminado) {
        $texto.Add("        <h2>$(Html (Get-Prop $Item 'titulo_pasos' 'Cómo conseguirlo'))</h2>")
        $texto.Add("        <ol class=`"pasos`">$((@($pasos | ForEach-Object { "<li>$(Html $_)</li>" })) -join '')</ol>")
    }
    $aviso = Get-Prop $Item 'aviso'
    if ($aviso) { $texto.Add("        <div class=`"aviso`"><p>$(Html $aviso)</p></div>") }
    $fuente = Get-Prop $Item 'fuente'
    if ($fuente) {
        $f = Html $fuente.texto
        if (Get-Prop $fuente 'url') { $f += " <a href=`"$(Enlace $fuente.url)`" rel=`"noopener`">$(Html (Get-Prop $fuente 'enlace' $fuente.url))</a>" }
        $texto.Add("        <p class=`"fuente`">$f</p>")
    }

    $masHtml = ''
    $rel = @($Relacionados)
    if ($rel.Count -gt 0) {
        $masHtml = @"

    <section class="seccion alterna">
      <div class="contenedor">
      <div class="titulo-seccion"><h2>Más en $(Html $seccion.menu)</h2><a class="enlace" href="/$($Item.seccion)/">Ver todo →</a></div>
$(Get-Rejilla $rel)
      </div>
    </section>
"@
    }

    @"
    <section class="seccion">
      <div class="contenedor">
        <p class="migas"><a href="/">Inicio</a> › <a href="/$($Item.seccion)/">$(Html $seccion.menu)</a></p>
        <article class="ficha">
          <figure class="ficha-portada">
          $(Get-Imagen $Item '' -Grande)$credito
          </figure>
          <div class="ficha-info">
          $(Get-Insignias $Item)
          <h1>$(Html $Item.titulo)</h1>
          <p class="entrada">$(Html (Get-Prop $Item 'resumen' ''))</p>
$bloquePrecio$htmlBoton
$bloqueDatos
          </div>
        </article>
        <div class="ficha-texto">
$($texto -join "`n")
        </div>
      </div>
    </section>$masHtml
$(Get-CajasApoyo)
"@
}
