# Convierte los datos de cada fuente en fichas con texto propio en español.
# Una ficha es un [ordered] con lo que paginas.ps1 sabe mostrar (ver New-Ficha).

function New-Ficha([string]$Seccion, [string]$Slug, [string]$Titulo) {
    [ordered]@{
        seccion = $Seccion; slug = $Slug; ruta = "/$Seccion/$Slug/"; titulo = $Titulo; grupo = ''
        resumen = ''; parrafos = @(); portada = $null; insignias = @(); datos = @()
        requisitos = @(); titulo_requisitos = 'Requisitos'; nota_requisitos = ''
        pasos = @(); titulo_pasos = 'Cómo conseguirlo'; titulo_texto = 'Qué es'; aviso = ''
        boton = $null; otros_botones = @(); termina = $null; precio = $null; precio_normal = $null
        etiqueta_pie = ''; filtros = @{}; etiquetas = @(); etiquetas_texto = @(); fuente = $null
        terminado = $false; texto_terminado = ''; oculto = $false; orden = 0; fecha = $null; telegram = $null
        # Solo el contenido escrito a mano puede pedir acortador ("acortar": true) y nunca lo de Brizna Soft
        acortar = $false
    }
}

function New-Dato([string]$Etiqueta, $Valor, [string]$Url = '') { [ordered]@{ e = $Etiqueta; v = [string]$Valor; url = $Url } }
function New-Insignia([string]$Texto, [string]$Clase = '') { [ordered]@{ texto = $Texto; clase = $Clase } }
function New-Boton([string]$Texto, [string]$Url, [string]$Nota = '', [string]$Rel = 'noopener') { [ordered]@{ texto = $Texto; url = $Url; nota = $Nota; rel = $Rel } }

# Etiquetas para los filtros: "tienda:epic-games-store plataforma:windows"
function Complete-Etiquetas($Ficha) {
    $lista = New-Object System.Collections.Generic.List[string]
    $textos = New-Object System.Collections.Generic.List[string]
    foreach ($g in @($Ficha.filtros.Keys)) {
        foreach ($v in @($Ficha.filtros[$g])) {
            if (Test-Texto $v) { $lista.Add("${g}:$(Get-Slug $v)"); $textos.Add([string]$v) }
        }
    }
    $Ficha.etiquetas = @($lista)
    $Ficha.etiquetas_texto = @($textos)
    $Ficha
}

function Get-Minusculas([string[]]$Lista) { @($Lista | ForEach-Object { if ($_ -cmatch '^[A-ZÁÉÍÓÚÑ][a-záéíóúñ ]+$') { $_.ToLower() } else { $_ } }) }

# Frase sobre el juego con los datos de Steam: generos, quien lo hizo, ano e idiomas
function Get-FrasesSteam($Detalle) {
    if (-not $Detalle) { return @() }
    $frases = New-Object System.Collections.Generic.List[string]
    $partes = @()
    $generos = @(Get-Prop $Detalle 'generos' @()) | Select-Object -First 3
    if ($generos) { $partes += "es un juego de $(Join-Lista (Get-Minusculas $generos))" }
    $dev = @(Get-Prop $Detalle 'desarrollo' @()) | Select-Object -First 2
    if ($dev) { $partes += "hecho por $(Join-Lista $dev)" }
    if (Get-Prop $Detalle 'anio') { $partes += "salió en $($Detalle.anio)" }
    if ($partes) {
        $f = 'Según su ficha de Steam, ' + (Join-Lista $partes) + '.'
        $frases.Add($f)
    }
    $id = Get-Prop $Detalle 'idiomas'
    if ($id) {
        if ($id.texto_es -and $id.audio_es -and $id.latino) { $frases.Add('Viene en español, con voces en español latino.') }
        elseif ($id.texto_es -and $id.audio_es) { $frases.Add('Viene en español, también con voces en español.') }
        elseif ($id.texto_es) { $frases.Add('Tiene textos en español.') }
        else { $frases.Add('Ojo: según Steam, no trae español.') }
    }
    $edad = [int](Get-Prop $Detalle 'edad' 0)
    if ($edad -ge 16) { $frases.Add("Steam lo marca para mayores de $edad años.") }
    , $frases.ToArray()
}

function Get-DatosSteam($Detalle) {
    $d = New-Object System.Collections.Generic.List[object]
    if (-not $Detalle) { return , @() }
    $generos = @(Get-Prop $Detalle 'generos' @()) | Select-Object -First 3
    if ($generos) { $d.Add((New-Dato 'Género' ($generos -join ', '))) }
    $dev = @(Get-Prop $Detalle 'desarrollo' @()) | Select-Object -First 2
    if ($dev) { $d.Add((New-Dato 'Hecho por' ($dev -join ', '))) }
    if (Get-Prop $Detalle 'anio') { $d.Add((New-Dato 'Salió en' $Detalle.anio)) }
    $id = Get-Prop $Detalle 'idiomas'
    if ($id) {
        $es = if ($id.texto_es -and $id.audio_es -and $id.latino) { 'Sí, con voces en español latino' }
        elseif ($id.texto_es -and $id.audio_es) { 'Sí, con voces en español' }
        elseif ($id.texto_es) { 'Sí, en textos' } else { 'No' }
        $d.Add((New-Dato 'En español' $es))
    }
    # En Windows PowerShell 5.1, @() sobre una List[object] falla ("Los tipos de argumentos no coinciden"): se usa ToArray()
    , $d.ToArray()
}

function Add-RequisitosSteam($Ficha, $Detalle) {
    $req = @(Get-Prop $Detalle 'requisitos' @())
    if ($req.Count -eq 0) { return }
    $Ficha.requisitos = $req
    $Ficha.titulo_requisitos = 'Requisitos mínimos (PC)'
    $Ficha.nota_requisitos = 'Según la tienda de Steam. Sirven para saber si el juego corre en tu PC, aunque lo consigas en otra tienda.'
}

# ---------------------------------------------------------------- regalos (GamerPower)

$script:PlataformasRegalo = @{
    'PC' = 'PC'; 'Android' = 'Android'; 'iOS' = 'iPhone'; 'VR' = 'Realidad virtual'
    'Playstation 4' = 'PlayStation 4'; 'Playstation 5' = 'PlayStation 5'; 'Xbox One' = 'Xbox One'; 'Xbox Series X|S' = 'Xbox Series'; 'Nintendo Switch' = 'Nintendo Switch'
}

function New-FichaRegalo($R, $Tiendas, $Detalle, [DateTimeOffset]$Ahora) {
    $t = Get-Prop $Tiendas $R.tienda (Get-Prop $Tiendas 'otra')
    $tienda = if ($R.tienda -eq 'otra' -and (Test-Texto $R.tienda_texto)) { [string]$R.tienda_texto } else { [string]$t.nombre }
    $corto = if ($R.tienda -eq 'otra' -and (Test-Texto $R.tienda_texto)) { [string]$R.tienda_texto } else { [string]$t.corto }
    $f = New-Ficha 'regalos' $R.slug $R.nombre
    $termina = Get-Fecha $R.termina
    # Doce horas de margen porque GamerPower no dice la zona horaria
    $vencido = $termina -and $termina.AddHours(12) -lt $Ahora
    $f.terminado = (-not $R.vigente) -or $vencido
    $f.termina = if ($f.terminado) { $null } else { $termina }
    # Primero el que termina antes; los que no tienen fecha, al final
    $f.orden = if ($termina) { $termina.ToUnixTimeSeconds() } else { [long]4e9 }
    $f.precio_normal = $R.valor
    $f.precio = if ($f.terminado) { $null } else { 0 }
    $f.fecha = Get-Fecha $R.visto_primero

    $valor = if ($R.valor) { " Normalmente cuesta $(Format-Dinero $R.valor)." } else { '' }
    $p = New-Object System.Collections.Generic.List[string]
    if ($f.terminado) {
        $hasta = if ($termina) { " hasta el $(Format-FechaLarga $termina)" } else { '' }
        $f.resumen = "Estuvo gratis en $tienda$hasta. Esta promoción ya terminó."
        $p.Add("«$($R.nombre)» estuvo gratis por tiempo limitado en $tienda$hasta.$valor La promoción ya terminó: en la lista de regalos están los que siguen activos.")
    } else {
        $f.resumen = if ($R.es_paquete) { "Paquete de juegos gratis en $tienda por tiempo limitado.$valor" } else { "Gratis en $tienda por tiempo limitado.$valor" }
        $fin = if ($termina) { " La promoción termina el $(Format-FechaLarga $termina); es una fecha aproximada, así que mejor no lo dejes para el último día." }
               else { ' No tiene fecha de fin anunciada, así que puede terminar en cualquier momento.' }
        $p.Add("«$($R.nombre)» está gratis por tiempo limitado en $tienda.$valor$fin")
    }
    # Las funciones que devuelven ", @(lista)" se guardan primero en una variable (con @() quedaria anidada)
    $frases = Get-FrasesSteam $Detalle
    foreach ($x in $frases) { $p.Add($x) }
    if ($R.es_clave) { $p.Add("Este regalo es una clave (key) para activar en $tienda. Las claves se reparten hasta que se acaban, así que conviene pedirla pronto.") }
    if ($R.es_paquete) { $p.Add('Es un paquete con varios juegos. En la página del regalo ves cuáles trae y los reclamas uno por uno.') }
    if ($R.tienda -ne 'prime' -and -not $f.terminado) {
        $p.Add('Por lo general, lo que reclamas durante la promoción se queda en tu cuenta para siempre, aunque después vuelva a costar. Antes de reclamarlo, revisa las condiciones en la página de la tienda.')
    }
    $f.parrafos = @($p)
    $f.titulo_texto = 'Sobre este regalo'

    # GamerPower mezcla plataformas y tiendas ("PC, Steam"): aqui solo van las plataformas
    $tokens = @([string]$R.plataformas -split ',\s*')
    $plataformas = @($tokens | ForEach-Object { $script:PlataformasRegalo[$_] } | Where-Object { $_ } | Select-Object -Unique)
    if ($plataformas.Count -eq 0) { $plataformas = @('PC') }
    $datos = New-Object System.Collections.Generic.List[object]
    $datos.Add((New-Dato 'Tienda' $tienda))
    $datos.Add((New-Dato 'Plataforma' ($plataformas -join ', ')))
    if ($tokens -contains 'DRM-Free') { $datos.Add((New-Dato 'Sin DRM' 'Sí: se juega sin el programa de la tienda')) }
    if ($R.valor) { $datos.Add((New-Dato 'Precio normal' (Format-Dinero $R.valor))) }
    $rotuloFin = if ($f.terminado) { 'Terminó' } else { 'Termina' }
    $datos.Add((New-Dato $rotuloFin $(if ($termina) { "$(Format-FechaLarga $termina) (aproximado)" } else { 'Sin fecha anunciada' })))
    $datos.Add((New-Dato 'Necesitas' $t.requisito))
    $deSteam = Get-DatosSteam $Detalle
    foreach ($d in $deSteam) { $datos.Add($d) }
    $f.datos = $datos.ToArray()
    Add-RequisitosSteam $f $Detalle

    $pasos = if ($R.es_clave -and (Get-Prop $t 'pasos_clave')) { $t.pasos_clave } else { $t.pasos }
    $f.pasos = @($pasos)
    $f.titulo_pasos = 'Cómo reclamarlo gratis'
    $f.aviso = Get-Prop $t 'aviso' ''
    if (-not $f.terminado -and $termina -and $termina -lt $Ahora) { $f.aviso = 'La fecha de fin ya pasó: puede que este regalo ya no esté disponible.' }
    $f.boton = New-Boton "Ir al regalo en $corto" $R.url 'El enlace pasa por GamerPower, que te lleva a la página oficial del regalo.'
    $f.texto_terminado = 'Este regalo ya terminó'
    $f.portada = [ordered]@{ url = $R.imagen; ancho = 460; alto = 215 }
    $f.insignias = if ($f.terminado) { @((New-Insignia 'Terminado' 'terminado'), (New-Insignia $corto)) } else { @((New-Insignia 'Gratis por tiempo' 'tiempo'), (New-Insignia $corto)) }
    $f.filtros = @{ tienda = @($tienda) }
    $f.fuente = [ordered]@{ texto = 'Datos del regalo:'; url = $R.url_fuente; enlace = 'GamerPower' }
    $f.grupo = if ($f.terminado) { 'terminados' } else { 'activos' }
    $f.telegram = [ordered]@{ clave = $R.clave; tipo = 'regalo'; texto = "Gratis en ${tienda}: $($R.nombre)"; detalle = $f.resumen }
    Complete-Etiquetas $f
}

# ---------------------------------------------------------------- itch.io

function New-FichaItch($R) {
    $f = New-Ficha 'juegos-gratis' $R.slug $R.nombre
    $plataformas = @($R.plataformas)
    $navegador = $plataformas.Count -eq 1 -and $plataformas[0] -eq 'Navegador'
    $genero = [string]$R.genero
    $deGenero = if ($genero -and $genero -ne 'Otro') { " de $($genero.ToLower())" } else { '' }
    $f.resumen = "Juego gratis$deGenero en itch.io" + $(if ($navegador) { ' que se juega en el navegador.' } else { '.' })
    $f.parrafos = @(
        "«$($R.nombre)» es un juego gratis$deGenero hecho por $($R.autor) y publicado en itch.io, la tienda de juegos independientes. Está entre los juegos gratis más populares de itch.io en estos días."
        $(if ($navegador) { 'Se juega en el navegador, sin instalar nada.' } elseif ($plataformas.Count) { "Funciona en $(Join-Lista $plataformas)." } else { 'Su página dice para qué sistemas está.' })
        'Su autor lo regala: si te gusta, en su página puedes dejarle una donación voluntaria, pero no es obligatoria. Muchos juegos de itch.io solo están en inglés; los idiomas de cada uno salen en su página.'
    )
    $f.titulo_texto = 'Sobre este juego'
    $f.datos = @(
        (New-Dato 'Tienda' 'itch.io')
        (New-Dato 'Hecho por' $R.autor "https://$($R.autor).itch.io/")
        (New-Dato 'Tipo' $(if ($genero) { $genero } else { 'Sin indicar' }))
        (New-Dato 'Funciona en' $(if ($plataformas.Count) { $plataformas -join ', ' } else { 'Ver su página' }))
        (New-Dato 'Precio' 'Gratis')
    )
    if ($navegador) {
        $f.requisitos = @('Un navegador al día, como Chrome, Edge o Firefox.')
        $f.pasos = @(
            'Pulsa el botón verde: abre la página del juego en itch.io.',
            'Pulsa «Run game» para empezar a jugar.',
            'Si el juego tiene botón de pantalla completa, úsalo para verlo mejor.'
        )
        $f.titulo_pasos = 'Cómo jugarlo'
        $f.boton = New-Boton 'Jugar en itch.io' $R.url 'Es la página oficial del juego en itch.io.'
    } else {
        if ($plataformas.Count) { $f.requisitos = @("Sistema: $(Join-Lista $plataformas 'o').") }
        $f.pasos = @(
            'Pulsa el botón verde: abre la página del juego en itch.io.',
            'Pulsa «Download». Si sale el cuadro para pagar lo que quieras, elige «No thanks, just take me to the downloads» para bajarlo gratis.',
            'Baja el archivo de tu sistema (por ejemplo, el de Windows) y descomprímelo.',
            'Pásale el antivirus y abre el juego.'
        )
        $f.titulo_pasos = 'Cómo bajarlo'
        $f.boton = New-Boton 'Ir a la descarga en itch.io' $R.url 'Es la página oficial del juego en itch.io.'
    }
    $f.portada = [ordered]@{ url = $R.imagen; ancho = 315; alto = 250 }
    $f.insignias = @((New-Insignia 'Gratis siempre' 'libre'))
    if ($genero) { $f.insignias += New-Insignia $genero }
    $f.etiqueta_pie = $plataformas -join ' · '
    $f.filtros = @{ plataforma = $plataformas; genero = @($genero) }
    $f.fuente = [ordered]@{ texto = 'Sale de la lista de juegos gratis de'; url = 'https://itch.io/games/free'; enlace = 'itch.io' }
    $f.grupo = 'itch'
    $f.orden = [int]$R.orden
    $f.fecha = Get-Fecha $R.visto_primero
    # Si sale de la lista de populares sigue siendo gratis: la ficha queda, pero ya no se muestra en la lista
    $f.oculto = -not $R.vigente
    $f.telegram = [ordered]@{ clave = $R.clave; tipo = 'itch'; texto = "Juego gratis en itch.io: $($R.nombre)"; detalle = $f.resumen }
    Complete-Etiquetas $f
}

# ---------------------------------------------------------------- ofertas (Steam)

function New-FichaOferta($R, $Detalle, [DateTimeOffset]$Ahora) {
    $f = New-Ficha 'ofertas' $R.slug $R.nombre
    $termina = Get-Fecha $R.termina
    $f.terminado = (-not $R.vigente) -or ($termina -and $termina -lt $Ahora)
    $f.orden = -[int]$R.descuento
    $f.termina = if ($f.terminado) { $null } else { $termina }
    $f.precio_normal = [double]$R.precio_normal
    $f.precio = [double]$R.precio
    $f.fecha = Get-Fecha $R.visto_primero
    # Ojo: en PowerShell $ahora y $Ahora son la misma variable (el parametro de fecha)
    $antes = Format-Dinero $R.precio_normal
    $conDescuento = Format-Dinero $R.precio
    $f.resumen = "$($R.descuento) % menos en Steam: de $antes a $conDescuento."
    $p = New-Object System.Collections.Generic.List[string]
    $p.Add("«$($R.nombre)» tiene $($R.descuento) % de descuento en Steam: baja de $antes a $conDescuento. Son los precios de Steam para Honduras, en dólares.")
    if ($termina) { $p.Add("La oferta termina el $(Format-FechaLarga $termina) a las $(Format-Hora $termina) (hora de Honduras).") }
    $frases = Get-FrasesSteam $Detalle
    foreach ($x in $frases) { $p.Add($x) }
    $p.Add('Antes de comprar, revisa los requisitos de abajo para saber si corre en tu PC.')
    $f.parrafos = @($p)
    $f.titulo_texto = 'Sobre esta oferta'
    $datos = New-Object System.Collections.Generic.List[object]
    $datos.Add((New-Dato 'Tienda' 'Steam'))
    $datos.Add((New-Dato 'Descuento' "$($R.descuento) %"))
    $datos.Add((New-Dato 'Precio' "$conDescuento (antes $antes)"))
    if ($termina) { $datos.Add((New-Dato 'Termina' "$(Format-FechaLarga $termina), $(Format-Hora $termina)")) }
    if (@($R.plataformas).Count) { $datos.Add((New-Dato 'Funciona en' (@($R.plataformas) -join ', '))) }
    $deSteam = Get-DatosSteam $Detalle
    foreach ($d in $deSteam) { $datos.Add($d) }
    $f.datos = $datos.ToArray()
    Add-RequisitosSteam $f $Detalle
    $f.pasos = @(
        'Pulsa el botón verde: abre el juego en la tienda oficial de Steam.',
        'Revisa que el precio con descuento siga ahí: la oferta termina a la hora indicada.',
        'Agrégalo al carro y paga con el método que uses en Steam.',
        'Instálalo desde tu biblioteca de Steam.'
    )
    $f.titulo_pasos = 'Cómo comprarlo'
    $url = "https://store.steampowered.com/app/$($R.appid)/"
    $f.boton = New-Boton 'Ver la oferta en Steam' $url 'Se abre la tienda oficial de Steam.'
    $f.texto_terminado = 'Esta oferta ya terminó'
    $f.portada = [ordered]@{ url = $R.imagen; ancho = 460; alto = 215 }
    $f.insignias = @((New-Insignia "-$($R.descuento) %" 'descuento'), (New-Insignia 'Steam'))
    if ($f.terminado) { $f.insignias = @((New-Insignia 'Terminada' 'terminado'), (New-Insignia 'Steam')) }
    $generos = @()
    if ($Detalle) { $generos = @(Get-Prop $Detalle 'generos' @()) | Select-Object -First 3 }
    $f.filtros = @{ genero = @($generos) }
    $f.fuente = [ordered]@{ texto = 'Precios y datos de la'; url = $url; enlace = 'tienda de Steam' }
    $f.grupo = if ($f.terminado) { 'terminadas' } else { 'steam' }
    $finClave = if ($termina) { Format-FechaIso $termina } else { 'sin-fin' }
    $f.telegram = [ordered]@{ clave = "$($R.clave)-$finClave"; tipo = 'oferta'; texto = "Oferta en Steam: $($R.nombre) a $conDescuento"; detalle = $f.resumen; descuento = [int]$R.descuento }
    Complete-Etiquetas $f
}

# ---------------------------------------------------------------- contenido escrito a mano

function Get-PortadaContenido($Entrada, [string]$Ajuste = 'cubrir') {
    $p = Get-Prop $Entrada 'portada'
    if (-not $p) { return [ordered]@{ url = '/img/sin-portada.svg'; ancho = 640; alto = 360; ajuste = 'cubrir' } }
    # "texto": true pide una portada hecha con el nombre (la escribe armar.ps1), con "color" y "subtitulo"
    [ordered]@{
        url = (Get-Prop $p 'url' '/img/sin-portada.svg'); ancho = (Get-Prop $p 'ancho' 640); alto = (Get-Prop $p 'alto' 360)
        ajuste = (Get-Prop $p 'ajuste' $Ajuste); alt = (Get-Prop $p 'alt' "Imagen de $(Get-Prop $Entrada 'nombre' (Get-Prop $Entrada 'titulo'))")
        credito = (Get-Prop $p 'credito' ''); credito_url = (Get-Prop $p 'credito_url' '')
        texto = [bool](Get-Prop $p 'texto' $false); color = (Get-Prop $p 'color' ''); subtitulo = (Get-Prop $p 'subtitulo' '')
    }
}

# Version de GitHub si el contenido dice de que repositorio sale; si no, la que esta escrita
function Get-VersionContenido($Entrada, $Versiones) {
    $repo = Get-Prop $Entrada 'github'
    if ($repo -and $Versiones -and $Versiones.ContainsKey($repo)) { return $Versiones[$repo] }
    $v = Get-Prop $Entrada 'version'
    if ($v) { return [pscustomobject]@{ version = $v; fecha = (Get-Prop $Entrada 'fecha_version'); url = '' } }
}

function New-FichaJuegoLibre($E, $Versiones) {
    $f = New-Ficha 'juegos-gratis' $E.slug $E.nombre
    $f.resumen = $E.resumen
    $f.parrafos = @($E.descripcion)
    $f.titulo_texto = 'Sobre este juego'
    $v = Get-VersionContenido $E $Versiones
    $datos = New-Object System.Collections.Generic.List[object]
    $datos.Add((New-Dato 'Tipo' $E.genero))
    $datos.Add((New-Dato 'Funciona en' (@($E.plataformas) -join ', ')))
    if ($v) { $datos.Add((New-Dato 'Versión' $(if (Get-Fecha $v.fecha) { "$($v.version), del $(Format-FechaLarga (Get-Fecha $v.fecha))" } else { $v.version }))) }
    $datos.Add((New-Dato 'Licencia' $E.licencia))
    if (Get-Prop $E 'espanol') { $datos.Add((New-Dato 'En español' $E.espanol)) }
    $datos.Add((New-Dato 'Precio' 'Gratis para siempre'))
    $datos.Add((New-Dato 'Página oficial' (([uri]$E.web).Host -replace '^www\.', '') $E.web))
    $f.datos = $datos.ToArray()
    $f.requisitos = @(Get-Prop $E 'requisitos' @())
    $f.titulo_requisitos = 'Requisitos'
    $f.pasos = @(Get-Prop $E 'pasos' @(
            'Pulsa el botón verde: abre la página oficial de descargas.',
            'Elige la versión para tu sistema (por ejemplo, Windows).',
            'Instálalo o descomprímelo y ábrelo. Es gratis para siempre: no pide pagos ni suscripciones.'
        ))
    $f.titulo_pasos = 'Cómo bajarlo'
    $f.boton = New-Boton 'Descargar desde la página oficial' $E.descarga 'Es la descarga oficial del proyecto: gratis y sin trampas.'
    $f.portada = Get-PortadaContenido $E
    $f.insignias = @((New-Insignia 'Gratis siempre' 'libre'), (New-Insignia 'Código abierto'))
    $f.etiqueta_pie = (@($E.plataformas) | Select-Object -First 3) -join ' · '
    $f.filtros = @{ plataforma = @($E.plataformas); genero = @($E.genero) }
    $f.fuente = [ordered]@{ texto = 'Datos comprobados en su página oficial:'; url = $E.web; enlace = (([uri]$E.web).Host -replace '^www\.', '') }
    $f.grupo = 'codigo-abierto'
    $f.orden = [int](Get-Prop $E 'orden' 0)
    $f.acortar = [bool](Get-Prop $E 'acortar' $false)
    $f.telegram = [ordered]@{ clave = "libre-$($E.slug)"; tipo = 'contenido'; texto = "Juego gratis para siempre: $($E.nombre)"; detalle = $E.resumen }
    Complete-Etiquetas $f
}

function New-FichaPrograma($E, $Versiones) {
    $f = New-Ficha 'programas' $E.slug $E.nombre
    $f.resumen = $E.resumen
    $f.parrafos = @($E.descripcion)
    $f.titulo_texto = 'Para qué sirve'
    $v = Get-VersionContenido $E $Versiones
    $datos = New-Object System.Collections.Generic.List[object]
    $datos.Add((New-Dato 'Categoría' $E.categoria))
    if ($v) { $datos.Add((New-Dato 'Versión' $(if (Get-Fecha $v.fecha) { "$($v.version), del $(Format-FechaLarga (Get-Fecha $v.fecha))" } else { $v.version }))) }
    $datos.Add((New-Dato 'Funciona en' (@($E.plataformas) -join ', ')))
    $datos.Add((New-Dato 'Licencia' $E.licencia))
    if (Get-Prop $E 'espanol') { $datos.Add((New-Dato 'En español' $E.espanol)) }
    $datos.Add((New-Dato 'Precio' 'Gratis'))
    $datos.Add((New-Dato 'Página oficial' (([uri]$E.web).Host -replace '^www\.', '') $E.web))
    $f.datos = $datos.ToArray()
    $f.requisitos = @(Get-Prop $E 'requisitos' @())
    $f.pasos = @(Get-Prop $E 'pasos' @(
            'Pulsa el botón verde: abre la página oficial de descargas.',
            'Baja el instalador para Windows (o el de tu sistema).',
            'Ábrelo y sigue los pasos. Si el instalador ofrece programas de más, no los aceptes.'
        ))
    $f.titulo_pasos = 'Cómo instalarlo'
    $f.boton = New-Boton 'Descargar desde la página oficial' $E.descarga 'Bájalo siempre de su página oficial: así no te llega con virus.'
    $f.portada = Get-PortadaContenido $E 'contener'
    $f.insignias = @((New-Insignia 'Gratis' 'libre'), (New-Insignia $E.categoria))
    $f.etiqueta_pie = if ($v) { "Versión $($v.version)" } else { $E.categoria }
    $f.filtros = @{ categoria = @($E.categoria) }
    $f.fuente = [ordered]@{ texto = 'Datos comprobados en su página oficial:'; url = $E.web; enlace = (([uri]$E.web).Host -replace '^www\.', '') }
    $f.grupo = 'otros'
    $f.orden = [int](Get-Prop $E 'orden' 0)
    $f.acortar = [bool](Get-Prop $E 'acortar' $false)
    $f.telegram = [ordered]@{ clave = "programa-$($E.slug)"; tipo = 'contenido'; texto = "Programa gratis: $($E.nombre)"; detalle = $E.resumen }
    Complete-Etiquetas $f
}

# Programas de Brizna Soft: la descarga es directa al .zip de GitHub, sin acortadores
function New-FichaBrizna($E, $Versiones) {
    $f = New-Ficha 'programas' $E.slug $E.nombre
    $v = $null
    if ($Versiones -and $Versiones.ContainsKey($E.repo)) { $v = $Versiones[$E.repo] }
    $zip = $null
    if ($v) { $zip = @($v.archivos) | Where-Object { $_.nombre -match $E.patron_zip } | Select-Object -First 1 }
    $f.resumen = $E.resumen
    $f.parrafos = @($E.descripcion)
    $f.titulo_texto = 'Para qué sirve'
    $datos = New-Object System.Collections.Generic.List[object]
    $datos.Add((New-Dato 'Hecho por' 'Brizna Soft' $script:Sitio.brizna))
    $datos.Add((New-Dato 'Categoría' $E.categoria))
    if ($v) { $datos.Add((New-Dato 'Versión' $(if (Get-Fecha $v.fecha) { "$($v.version), del $(Format-FechaLarga (Get-Fecha $v.fecha))" } else { $v.version }))) }
    $datos.Add((New-Dato 'Funciona en' $E.plataforma))
    if ($zip) { $datos.Add((New-Dato 'Tamaño' ('{0:0.0} MB' -f ($zip.tamano / 1MB)).Replace(',', '.'))) }
    $datos.Add((New-Dato 'Licencia' 'MIT (código abierto)'))
    $datos.Add((New-Dato 'Precio' 'Gratis, sin publicidad'))
    $f.datos = $datos.ToArray()
    $f.requisitos = @($E.requisitos)
    $f.pasos = @($E.pasos)
    $f.titulo_pasos = 'Cómo usarlo'
    $urlDescarga = if ($zip) { $zip.url } else { "https://github.com/$($E.repo)/releases/latest" }
    $texto = if ($v) { "Descargar $($E.nombre) $($v.version)" } else { "Descargar $($E.nombre)" }
    $f.boton = New-Boton $texto $urlDescarga 'Descarga directa desde GitHub: sin acortadores ni publicidad.'
    $f.otros_botones = @(
        [ordered]@{ texto = 'Más detalles en Brizna Soft'; url = $E.pagina; rel = 'noopener' }
        [ordered]@{ texto = 'Código'; url = "https://github.com/$($E.repo)"; rel = 'noopener' }
        [ordered]@{ texto = 'Reportar un problema'; url = "https://github.com/$($E.repo)/issues/new/choose"; rel = 'noopener' }
    )
    $f.portada = [ordered]@{ url = $E.captura; ancho = $E.captura_ancho; alto = $E.captura_alto; ajuste = 'contener'; alt = $E.captura_alt }
    $f.insignias = @((New-Insignia 'De Brizna Soft' 'libre'), (New-Insignia 'Código abierto'))
    $f.etiqueta_pie = if ($v) { "Versión $($v.version)" } else { $E.categoria }
    $f.filtros = @{ categoria = @($E.categoria) }
    $f.fuente = [ordered]@{ texto = 'Versión leída de'; url = "https://github.com/$($E.repo)/releases"; enlace = 'GitHub' }
    $f.grupo = 'brizna'
    $f.orden = [int](Get-Prop $E 'orden' 0)
    $f.fecha = if ($v) { Get-Fecha $v.fecha } else { $null }
    if ($v) { $f.telegram = [ordered]@{ clave = "brizna-$($E.slug)-$($v.version)"; tipo = 'brizna'; texto = "$($E.nombre) $($v.version), de Brizna Soft"; detalle = $E.resumen } }
    Complete-Etiquetas $f
}

function New-FichaCine($E) {
    $f = New-Ficha 'cine' $E.slug $E.titulo
    $tipo = switch ($E.tipo) { 'serie' { 'Serie' } 'corto' { 'Cortometraje' } default { 'Película' } }
    $f.resumen = $E.resumen
    $f.parrafos = @($E.descripcion)
    $f.titulo_texto = switch ($E.tipo) { 'serie' { 'Sobre esta serie' } 'corto' { 'Sobre este corto' } default { 'Sobre esta película' } }
    $datos = New-Object System.Collections.Generic.List[object]
    $datos.Add((New-Dato 'Tipo' $tipo))
    if (Get-Prop $E 'anio') { $datos.Add((New-Dato 'Año' $E.anio)) }
    if (Get-Prop $E 'duracion') { $datos.Add((New-Dato 'Duración' $E.duracion)) }
    if (Get-Prop $E 'direccion') { $datos.Add((New-Dato 'Dirección' $E.direccion)) }
    if (Get-Prop $E 'pais') { $datos.Add((New-Dato 'País' $E.pais)) }
    if (Get-Prop $E 'idioma') { $datos.Add((New-Dato 'Idioma' $E.idioma)) }
    $datos.Add((New-Dato 'Licencia' $E.licencia (Get-Prop $E 'licencia_url' '')))
    $f.datos = $datos.ToArray()
    $f.boton = New-Boton $E.ver.texto $E.ver.url (Get-Prop $E.ver 'nota' 'Es el sitio oficial: gratis y legal.')
    # "otros": enlaces oficiales de mas (YouTube del autor, descarga, subtitulos)
    $f.otros_botones = @(@(Get-Prop $E 'otros' @()) | ForEach-Object { [ordered]@{ texto = $_.texto; url = $_.url; rel = 'noopener' } })
    $f.pasos = @(Get-Prop $E 'pasos' @())
    $f.titulo_pasos = 'Cómo verla'
    $f.aviso = Get-Prop $E 'aviso' ''
    $f.portada = Get-PortadaContenido $E
    $etiqueta = if ($E.grupo -eq 'dominio-publico') { 'Dominio público' } else { 'Licencia libre' }
    $f.insignias = @((New-Insignia $etiqueta 'libre'), (New-Insignia $tipo))
    $pie = @()
    if (Get-Prop $E 'anio') { $pie += [string]$E.anio }
    if (Get-Prop $E 'duracion') { $pie += [string]$E.duracion }
    $f.etiqueta_pie = $pie -join ' · '
    $f.filtros = @{ genero = @($tipo) }
    $f.fuente = [ordered]@{ texto = (Get-Prop $E 'fuente_texto' 'Licencia comprobada en:'); url = (Get-Prop $E 'fuente_url' $E.ver.url); enlace = (Get-Prop $E 'fuente_enlace' 'página oficial') }
    $f.grupo = $E.grupo
    $f.orden = [int](Get-Prop $E 'orden' 0)
    $f.acortar = [bool](Get-Prop $E 'acortar' $false)
    $f.telegram = [ordered]@{ clave = "cine-$($E.slug)"; tipo = 'contenido'; texto = "$tipo gratis y legal: $($E.titulo)"; detalle = $E.resumen }
    Complete-Etiquetas $f
}

function New-FichaServicio($E) {
    $f = New-Ficha 'cine' $E.slug $E.nombre
    $f.resumen = $E.resumen
    $f.parrafos = @($E.descripcion)
    $f.titulo_texto = 'Qué es'
    $datos = New-Object System.Collections.Generic.List[object]
    $datos.Add((New-Dato 'Precio' $E.precio))
    $datos.Add((New-Dato 'Cuenta' $E.cuenta))
    $datos.Add((New-Dato 'En español' $E.espanol))
    $datos.Add((New-Dato 'Funciona en' (@($E.plataformas) -join ', ')))
    $datos.Add((New-Dato 'En Honduras' $E.honduras (Get-Prop $E 'evidencia' '')))
    $f.datos = $datos.ToArray()
    $f.boton = New-Boton "Abrir $($E.nombre)" $E.url 'Es el sitio oficial del servicio.'
    $f.aviso = 'Entra siempre desde el enlace oficial: hay páginas falsas que copian el nombre de estos servicios para llenarte de anuncios o pedirte datos.'
    $f.portada = Get-PortadaContenido $E
    $f.insignias = @((New-Insignia 'Gratis y legal' 'libre'), (New-Insignia 'Servicio'))
    $f.etiqueta_pie = $E.precio
    $f.fuente = [ordered]@{ texto = 'Disponibilidad comprobada en:'; url = (Get-Prop $E 'evidencia' $E.url); enlace = (Get-Prop $E 'evidencia_texto' 'su página oficial') }
    $f.grupo = 'servicios'
    $f.orden = [int](Get-Prop $E 'orden' 0)
    Complete-Etiquetas $f
}
