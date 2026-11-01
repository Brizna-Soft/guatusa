# Paginas del sitio entero: portada, una por seccion, Acerca de, Privacidad, 404 y los archivos
# para buscadores y servidores (sitemap.xml, robots.txt, ads.txt, novedades.xml y _headers).

$script:Secciones = [ordered]@{
    'regalos'       = @{
        menu = 'Regalos'; titulo = 'Juegos gratis por tiempo limitado'
        h1 = 'Juegos de pago, <span>gratis por unos días</span>'
        entrada = 'Las tiendas regalan juegos de pago por tiempo limitado. Si los reclamas a tiempo, por lo general quedan en tu cuenta para siempre. Aquí están los que siguen activos y la fecha en que terminan.'
        descripcion = 'Juegos de pago gratis por tiempo limitado en Epic, Steam, GOG, itch.io y más, con la fecha en que termina cada regalo y cómo reclamarlo.'
        grupos = @(
            @{ id = 'activos'; titulo = 'Gratis ahora'; intro = 'Ordenados por el que termina primero.'; filtros = @('tienda') }
            @{ id = 'terminados'; titulo = 'Ya terminaron'; intro = 'Los dejamos unos días por si llegas desde un enlace viejo.'; filtros = @() }
        )
    }
    'juegos-gratis' = @{
        menu = 'Juegos gratis'; titulo = 'Juegos gratis para siempre'
        h1 = 'Juegos <span>gratis para siempre</span>'
        entrada = 'Juegos que sus autores regalan: de código abierto y los más jugados de itch.io. Cada botón lleva a la descarga oficial.'
        descripcion = 'Juegos gratis para siempre y legales: de código abierto y los más populares de itch.io, con descarga oficial y requisitos.'
        grupos = @(
            @{ id = 'codigo-abierto'; titulo = 'De código abierto'; intro = 'Su código es público y los hace una comunidad: gratis para siempre, sin anuncios ni cobros escondidos.'; filtros = @('plataforma') }
            @{ id = 'itch'; titulo = 'Lo más jugado de itch.io'; intro = 'Los juegos gratis más populares de itch.io en estos días. Esta lista se actualiza sola.'; filtros = @('plataforma', 'genero') }
        )
    }
    'ofertas'       = @{
        menu = 'Ofertas'; titulo = 'Ofertas de juegos'
        h1 = 'Ofertas de juegos, <span>con precio de Honduras</span>'
        entrada = 'Juegos de pago con descuento en tiendas legales. Los precios son los de Steam para Honduras, en dólares, con la hora en que termina cada oferta.'
        descripcion = 'Ofertas de juegos en Steam con precios para Honduras, la hora en que termina cada descuento y los requisitos para tu PC.'
        grupos = @(
            @{ id = 'steam'; titulo = 'En Steam'; intro = 'Las ofertas destacadas de Steam. Guatusa no cobra comisión por estos enlaces.'; filtros = @('genero') }
            @{ id = 'terminadas'; titulo = 'Ya terminaron'; intro = 'Las dejamos unos días por si llegas desde un enlace viejo.'; filtros = @() }
        )
    }
    'programas'     = @{
        menu = 'Programas'; titulo = 'Programas gratis'
        h1 = 'Programas gratis, <span>sin trampas</span>'
        entrada = 'Los programas de Brizna Soft y otros buenos programas gratis para tu PC, siempre con su descarga oficial.'
        descripcion = 'Programas gratis y de código abierto para Windows, con su descarga oficial: los de Brizna Soft y otros como VLC, LibreOffice y 7-Zip.'
        grupos = @(
            @{ id = 'brizna'; titulo = 'Hechos por Brizna Soft'; intro = 'Nuestros programas: gratis, sin publicidad, sin recoger tus datos y con la descarga directa, sin acortadores.'; filtros = @() }
            @{ id = 'otros'; titulo = 'Buenos programas de otros'; intro = 'No son nuestros, pero los recomendamos: gratis y casi todos de código abierto. Bájalos siempre de su página oficial.'; filtros = @('categoria') }
        )
    }
    'cine'          = @{
        menu = 'Cine'; titulo = 'Películas y series gratis y legales'
        h1 = 'Películas y series <span>gratis y legales</span>'
        entrada = 'Películas con licencia libre, clásicos de dominio público y servicios gratis que funcionan en Honduras. Nada pirata.'
        descripcion = 'Películas y series que se pueden ver gratis y legalmente: cine libre de Blender, clásicos de dominio público y servicios gratis en Honduras.'
        grupos = @(
            @{ id = 'libre'; titulo = 'Cine con licencia libre'; intro = 'Sus autores las regalan con una licencia Creative Commons: se pueden ver, bajar y compartir dando crédito.'; filtros = @() }
            @{ id = 'dominio-publico'; titulo = 'Clásicos de dominio público'; intro = 'Películas tan antiguas que ya no tienen dueño: son de todos. Las escogimos con cuidado para que lo sean también en Honduras.'; filtros = @() }
            @{ id = 'servicios'; titulo = 'Servicios gratis que funcionan en Honduras'; intro = 'Ven películas y series gratis a cambio de anuncios, de forma legal. Comprobamos que funcionen en Honduras.'; filtros = @() }
        )
    }
}

function Get-PortadaSeccion([string]$Clave, $Cifras) {
    $s = $script:Secciones[$Clave]
    @"
    <section class="portada">
      <div class="contenedor">
        <h1>$($s.h1)</h1>
        <p class="entrada">$(Html $s.entrada)</p>
      </div>
    </section>
"@
}

function Get-PaginaSeccion([string]$Clave, $Fichas) {
    $s = $script:Secciones[$Clave]
    $bloques = New-Object System.Collections.Generic.List[string]
    $primero = $true
    foreach ($g in $s.grupos) {
        $del = @($Fichas | Where-Object { $_.grupo -eq $g.id })
        if ($del.Count -eq 0) { continue }
        $id = "lista-$($g.id)"
        $clase = if ($primero) { 'seccion' } else { 'seccion alterna' }
        $primero = $false
        $bloques.Add(@"
    <section class="$clase" aria-labelledby="t-$($g.id)">
      <div class="contenedor">
      <div class="titulo-seccion"><h2 id="t-$($g.id)">$(Html $g.titulo)</h2><span class="nota">$($del.Count) en total</span></div>
      <p class="intro">$(Html $g.intro)</p>
$(Get-ListaConFiltros $del $id ([string[]]$g.filtros))
      </div>
    </section>
"@)
    }
    if ($bloques.Count -eq 0) {
        $bloques.Add("    <section class=`"seccion`"><div class=`"contenedor`"><p class=`"intro`">Ahora mismo no hay nada en esta sección. Vuelve pronto: se actualiza sola varias veces al día.</p></div></section>")
    }
    $cuerpo = (Get-PortadaSeccion $Clave) + "`n" + ($bloques -join "`n") + "`n" + (Get-CajasApoyo)
    New-Pagina -Titulo "$($s.titulo) · Guatusa" -Descripcion $s.descripcion -Ruta "/$Clave/" -Cuerpo $cuerpo -Seccion $Clave `
        -Migas @(@{ n = 'Inicio'; u = '/' }, @{ n = $s.menu; u = "/$Clave/" })
}

function Get-PaginaInicio($PorSeccion, $Cifras) {
    $vistas = New-Object System.Collections.Generic.List[string]
    $alterna = $false
    foreach ($k in $script:Secciones.Keys) {
        $s = $script:Secciones[$k]
        $muestra = @($PorSeccion[$k] | Where-Object { -not $_.terminado } | Select-Object -First 8)
        if ($muestra.Count -eq 0) { continue }
        $clase = if ($alterna) { 'seccion alterna' } else { 'seccion' }
        $alterna = -not $alterna
        $vistas.Add(@"
    <section class="$clase" aria-labelledby="t-$k">
      <div class="contenedor">
      <div class="titulo-seccion"><h2 id="t-$k">$(Html $s.titulo)</h2><a class="enlace" href="/$k/">Ver todo →</a></div>
$(Get-Rejilla $muestra)
      </div>
    </section>
"@)
    }
    $lista = foreach ($c in $Cifras) { "          <li>$c</li>" }
    $act = $script:Sitio.actualizado
    $cuerpo = @"
    <section class="portada">
      <div class="contenedor">
        <p class="etiqueta">De Brizna Soft · Hecho en Honduras</p>
        <h1>Lo gratis y legal, <span>en un solo lugar.</span></h1>
        <p class="entrada">Juegos que las tiendas regalan por tiempo limitado, juegos gratis para siempre, ofertas, programas y cine que se puede ver sin pagar. Cada botón lleva a la tienda o a la descarga oficial.</p>
        <ul class="cifras">
$($lista -join "`n")
        </ul>
        <p class="nota">Se actualiza sola varias veces al día. Última vez: $(Format-FechaLarga $act -SinAnio), $(Format-Hora $act) (hora de Honduras).</p>
      </div>
    </section>

$($vistas -join "`n")

    <section class="seccion alterna" aria-labelledby="t-regla">
      <div class="contenedor">
        <h2 id="t-regla">Nuestra regla: solo lo legal</h2>
        <ul class="regla">
          <li><strong>Solo lo oficial</strong><span>Cada botón lleva a la tienda o a la descarga oficial. No volvemos a subir archivos de nadie.</span></li>
          <li><strong>Nada pirata</strong><span>Ni cracks, ni repacks, ni juegos, películas o programas de pago sin permiso de su dueño.</span></li>
          <li><strong>Gratis de verdad</strong><span>Si un regalo te pide tarjeta o pagar, no es el regalo. Avísanos y lo revisamos.</span></li>
        </ul>
      </div>
    </section>
$(Get-CajasApoyo)
"@
    New-Pagina -Titulo 'Guatusa · Juegos, programas y cine gratis y legales' `
        -Descripcion 'Juegos gratis por tiempo limitado, juegos libres, ofertas con precio de Honduras, programas gratis y cine legal, en español y en un solo lugar. Se actualiza sola.' `
        -Ruta '/' -Cuerpo $cuerpo
}

function Get-PaginaAcerca {
    $anuncios = if ($script:Sitio.adsense) { 'Mostramos anuncios de Google AdSense.' } else { 'Por ahora no hay anuncios; cuando los haya, serán de Google AdSense.' }
    $afiliados = if ($script:Sitio.afiliados) { 'Algunos enlaces a tiendas son de afiliado: si compras por ellos, la tienda nos paga una pequeña comisión y a ti no te cuesta más. Esos botones lo dicen.' } else { 'Por ahora no usamos enlaces de afiliado: ninguna tienda nos paga por los botones.' }
    $telegram = Get-EnlaceTelegram
    $contactoTelegram = if ($telegram) { " o en nuestro <a href=`"$(Enlace $telegram)`">canal de Telegram</a>" } else { '' }
    $cuerpo = @"
    <section class="seccion">
      <div class="contenedor texto-largo">
        <h1>Acerca de Guatusa</h1>
        <p class="entrada">Guatusa junta en un solo lugar, y en español, lo que se puede tener gratis y de forma legal: juegos, programas, películas y series.</p>

        <h2>Por qué se llama así</h2>
        <p>La guatusa es un animalito de nuestros montes que junta semillas y las guarda para después. Aquí hacemos lo mismo con lo gratis: lo buscamos, lo revisamos y lo guardamos para que lo encuentres fácil.</p>

        <h2>Cómo se arma</h2>
        <ul class="lista">
          <li>Varias veces al día, un programa lee los regalos de <a href="https://www.gamerpower.com/">GamerPower</a>, la lista de juegos gratis de <a href="https://itch.io/games/free">itch.io</a> y las ofertas de la tienda de Steam, y arma las páginas solo.</li>
          <li>Los juegos libres, los programas y las películas los escogemos a mano. Comprobamos en su página oficial que sean gratis y legales, y les escribimos su descripción.</li>
          <li>El código de Guatusa es abierto y está en <a href="$(Enlace $script:Sitio.repo)">GitHub</a>.</li>
        </ul>

        <h2>Nuestra regla</h2>
        <p>Solo enlazamos a tiendas y descargas oficiales. Nunca ponemos cracks, repacks ni copias de juegos, películas o programas de pago. Si ves algo que no debería estar, avísanos y lo quitamos.</p>

        <h2>Cómo nos sostenemos</h2>
        <ul class="lista">
          <li>$anuncios</li>
          <li>$afiliados</li>
          <li>Donaciones por <a href="$(Enlace $script:Sitio.paypal)">PayPal</a>, si quieres apoyar.</li>
          <li>Los programas de Brizna Soft siguen sin publicidad y se bajan directo, sin acortadores.</li>
        </ul>

        <h2>Reportar un problema</h2>
        <p>¿Un enlace roto, un regalo que ya no sirve o algo que no debería estar? Avísanos con el formulario de <a href="$(Enlace "$($script:Sitio.repo)/issues/new/choose")">GitHub</a>$contactoTelegram. Ahí también puedes sugerir algo gratis y legal que falte.</p>

        <h2>Créditos</h2>
        <p>Datos de los regalos: <a href="https://www.gamerpower.com/">GamerPower</a>. Juegos de <a href="https://itch.io/">itch.io</a>. Precios, requisitos e imágenes de ofertas: tienda de Steam. Las imágenes de películas y programas dicen su autor y licencia en cada ficha. Las marcas, nombres y portadas son de sus dueños; Guatusa no es parte de ninguna tienda.</p>
        <p>Guatusa es parte de <a href="$(Enlace $script:Sitio.brizna)">Brizna Soft</a>, un estudio de Honduras.</p>
      </div>
    </section>
"@
    New-Pagina -Titulo 'Acerca de Guatusa' -Descripcion 'Qué es Guatusa, cómo se arma, cómo se sostiene y cómo reportar un problema.' -Ruta '/acerca/' -Cuerpo $cuerpo `
        -Migas @(@{ n = 'Inicio'; u = '/' }, @{ n = 'Acerca de'; u = '/acerca/' })
}

function Get-PaginaPrivacidad {
    $cuerpo = @"
    <section class="seccion">
      <div class="contenedor texto-largo">
        <h1>Privacidad</h1>
        <p class="entrada">En corto: Guatusa no te pide cuenta ni datos. Aquí te contamos lo que sí pasa cuando la visitas, sobre todo con los anuncios de Google.</p>

        <h2>Lo que no hacemos</h2>
        <ul>
          <li>No hay cuentas, formularios ni comentarios en Guatusa.</li>
          <li>No usamos estadísticas propias ni vendemos datos de nadie.</li>
          <li>El buscador y los filtros funcionan dentro de tu navegador: lo que escribes no sale de tu equipo.</li>
        </ul>

        <h2>Anuncios de Google (AdSense) y cookies</h2>
        <p>Guatusa se sostiene en parte con anuncios de Google AdSense. Cuando hay anuncios en la página:</p>
        <ul>
          <li>Google y otros proveedores usan cookies para mostrarte anuncios según tus visitas a esta página y a otros sitios de internet.</li>
          <li>Las cookies de publicidad le permiten a Google y a sus socios mostrarte anuncios basados en lo que visitas aquí y en otros sitios. Más detalles en <a href="https://policies.google.com/technologies/partner-sites?hl=es">cómo usa Google la información de los sitios que usan sus servicios</a>.</li>
          <li>Puedes desactivar los anuncios personalizados en la <a href="https://www.google.com/settings/ads">Configuración de anuncios de Google</a>.</li>
          <li>En la página también pueden salir anuncios de otros proveedores y redes de publicidad que trabajan con Google. Su lista está en <a href="https://support.google.com/adsense/answer/9931967?hl=es">los proveedores de tecnología publicitaria de Google</a>, y cada uno explica en su sitio cómo desactivar sus cookies. Para que no usen cookies de publicidad personalizada, también puedes entrar a <a href="https://www.aboutads.info/choices/">www.aboutads.info/choices</a>.</li>
          <li>Si nos visitas desde el Espacio Económico Europeo, el Reino Unido o Suiza, Google te muestra primero un aviso para que elijas si aceptas esas cookies.</li>
          <li>También puedes borrar o bloquear las cookies en la configuración de tu navegador.</li>
        </ul>

        <h2>Imágenes y enlaces de otros sitios</h2>
        <ul>
          <li>Las portadas se cargan desde los sitios oficiales: Steam, itch.io, GamerPower, Wikimedia Commons y GitHub. Como cualquier servidor, ven tu dirección IP. Le pedimos a tu navegador que no les diga desde qué página vienes.</li>
          <li>Al pulsar un botón sales a la tienda o al sitio oficial, que tiene su propia política de privacidad. Los botones de los regalos pasan antes por GamerPower, que te lleva a la tienda.</li>
          <li>Algunos enlaces a tiendas pueden ser de afiliado: si compras, la tienda nos paga una comisión y puede guardar una cookie para saber que llegaste desde aquí. Esos botones lo dicen.</li>
        </ul>

        <h2>Alojamiento</h2>
        <p>Guatusa está alojada en Cloudflare Pages. Como cualquier servidor, Cloudflare puede registrar tu dirección IP por seguridad; eso lo cubre la <a href="https://www.cloudflare.com/es-es/privacypolicy/">política de privacidad de Cloudflare</a>.</p>

        <h2>Telegram y donaciones</h2>
        <p>Si te unes a nuestro canal de Telegram, tus datos los maneja Telegram; en un canal, nosotros no vemos tu número. Las donaciones pasan por PayPal: nosotros solo vemos lo que PayPal muestra de cada donación (por ejemplo, el nombre y el monto).</p>

        <h2>Los programas de Brizna Soft</h2>
        <p>Nada de esto cambia los programas: siguen sin publicidad, sin estadísticas y sin recoger tus datos. Lo explica la <a href="https://brizna-soft.github.io/privacidad.html">política de privacidad de Brizna Soft</a>.</p>

        <h2>Dudas</h2>
        <p>Escríbenos en <a href="$(Enlace "$($script:Sitio.repo)/issues")">GitHub</a>. No pongas ahí datos personales: lo que se escribe en GitHub es público.</p>

        <p class="nota">Última actualización: 1 de noviembre de 2026.</p>
      </div>
    </section>
"@
    New-Pagina -Titulo 'Privacidad · Guatusa' -Descripcion 'Qué pasa con tus datos en Guatusa: sin cuentas ni formularios; cookies de los anuncios de Google y cómo desactivarlas.' -Ruta '/privacidad/' -Cuerpo $cuerpo `
        -Migas @(@{ n = 'Inicio'; u = '/' }, @{ n = 'Privacidad'; u = '/privacidad/' })
}

function Get-Pagina404 {
    $enlaces = foreach ($k in $script:Secciones.Keys) { "<a class=`"boton`" href=`"/$k/`">$(Html $script:Secciones[$k].menu)</a>" }
    $cuerpo = @"
    <section class="portada">
      <div class="contenedor">
        <h1>No encontramos <span>esa página</span></h1>
        <p class="entrada">Si llegaste desde un regalo o una oferta vieja, puede que ya haya terminado. Esto es lo que hay ahora:</p>
        <div class="botones">$($enlaces -join ' ')</div>
      </div>
    </section>
"@
    New-Pagina -Titulo 'No encontramos esa página · Guatusa' -Descripcion 'Esta página no existe o ya terminó.' -Ruta '/404.html' -Cuerpo $cuerpo -NoIndexar
}

# ---------------------------------------------------------------- archivos para buscadores y servidores

function Get-Sitemap($Entradas) {
    $urls = foreach ($e in $Entradas) {
        "  <url><loc>$(Html (Get-UrlAbsoluta $e.ruta))</loc><lastmod>$((Get-Fecha $e.fecha).ToUniversalTime().ToString('yyyy-MM-dd', $script:Inv))</lastmod></url>"
    }
    "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n$($urls -join "`n")`n</urlset>`n"
}

function Get-Robots { "User-agent: *`nAllow: /`n`nSitemap: $(Get-UrlAbsoluta '/sitemap.xml')`n" }

function Get-AdsTxt {
    $cliente = [string]$script:Sitio.adsense
    if ($cliente -notmatch '^ca-(pub-\d{10,20})$') { return '' }
    "google.com, $($Matches[1]), DIRECT, f08c47fec0942fa0`n"
}

function Get-Novedades($Fichas) {
    $items = foreach ($f in @($Fichas | Select-Object -First 40)) {
        $fecha = (Get-Fecha $f.fecha).ToUniversalTime().ToString('r', $script:Inv)
        $url = Get-UrlAbsoluta $f.ruta
        # El identificador es la clave del aviso (cambia con cada version o promocion), no la direccion de la ficha:
        # asi un lector de RSS no da por vista una version nueva de un programa o un regalo que vuelve
        $titulo = if ($f.telegram) { $f.telegram.texto } else { $f.titulo }
        $guid = if ($f.telegram) { "guatusa-$($f.telegram.clave)" } else { $url }
        "    <item><title>$(Html $titulo)</title><link>$(Html $url)</link><guid isPermaLink=`"false`">$(Html $guid)</guid><pubDate>$fecha</pubDate><description>$(Html $f.resumen)</description></item>"
    }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Guatusa · novedades</title>
    <link>$(Html (Get-UrlAbsoluta '/'))</link>
    <description>Juegos gratis por tiempo limitado, ofertas, programas y cine legal, en español.</description>
    <language>es</language>
$($items -join "`n")
  </channel>
</rss>
"@
}

# Cabeceras de seguridad para Cloudflare Pages. Con AdSense no se puede limitar de donde salen los
# scripts (Google carga desde muchos dominios y pide CSP con nonce, que un sitio estatico no tiene).
function Get-Cabeceras {
    $csp = if ($script:Sitio.adsense) {
        "object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'self'; upgrade-insecure-requests"
    } else {
        "default-src 'self'; img-src 'self' https: data:; style-src 'self'; script-src 'self'; connect-src 'self'; font-src 'self'; frame-src 'none'; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'self'; upgrade-insecure-requests"
    }
    @"
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  X-Frame-Options: SAMEORIGIN
  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(), usb=()
  Content-Security-Policy: $csp
"@
}
