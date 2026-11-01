# Avisa en el canal de Telegram las novedades que dejo armar.ps1 en telegram-pendientes.json.
# Necesita, como secretos o variables de GitHub (nunca en el codigo):
#   TELEGRAM_BOT_TOKEN  la clave del bot que da @BotFather; el bot tiene que ser administrador del canal
#   TELEGRAM_CANAL      el canal, por ejemplo @GuatusaGratis (si falta, se usa telegram_canal de config.json)
# La primera vez solo anota lo que ya hay, para no llenar el canal de golpe. Despues cada novedad sale una sola vez:
# se anota en datos/telegram.json apenas sale (o si no se sabe si salio), antes de pasar a la siguiente.
#   -Probar  muestra lo que mandaria, sin mandar nada ni guardar
param([switch]$Probar)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'comun.ps1')

$config = Read-Json (Join-Ruta $raiz 'config.json')
$cfg = Get-Prop $config 'telegram'
$maximo = [int](Get-Prop $cfg 'maximo_por_vez' 6)
$tipos = @(Get-Prop $cfg 'tipos' @('regalo', 'oferta', 'brizna'))
$descuentoMinimo = [int](Get-Prop $cfg 'descuento_minimo' 50)

$token = [string]$env:TELEGRAM_BOT_TOKEN
$canal = [string]$env:TELEGRAM_CANAL
if (-not $canal) {
    $nombre = [string](Get-Prop (Get-Prop $config 'ingresos') 'telegram_canal' '')
    if ($nombre) { $canal = '@' + $nombre.TrimStart('@') }
}
if (-not $Probar -and (-not $token -or -not $canal)) { Write-Host 'Telegram: falta la clave del bot o el canal; no se manda nada.'; return }

$rutaEstado = Join-Ruta $raiz 'datos' 'telegram.json'
$estado = Read-Json $rutaEstado
$primeraVez = $null -eq $estado
$enviados = @{}
if ($estado) { foreach ($p in $estado.enviados.PSObject.Properties) { $enviados[$p.Name] = $p.Value } }

# Read-Json devuelve la lista entera como un solo objeto: con @(Read-Json ...) quedaria anidada
$leidos = Read-Json (Join-Ruta $raiz 'telegram-pendientes.json')
$pendientes = if ($null -eq $leidos) { @() } else { @($leidos) }
$vigentes = @{}
foreach ($a in $pendientes) { if ($a) { $vigentes[[string]$a.clave] = $true } }

# Guarda el estado: cada clave se recuerda 120 dias, y siempre mientras el aviso siga vigente (por ejemplo,
# la version actual de un programa de Brizna Soft), para que nunca se repita
function Save-Estado {
    $ahora = Get-AhoraUtc
    $guardar = [ordered]@{}
    foreach ($k in ($enviados.Keys | Sort-Object)) {
        $f = Get-Fecha $enviados[$k]
        if ($vigentes.ContainsKey($k) -or ($f -and ($ahora - $f).TotalDays -le 120)) { $guardar[$k] = Format-FechaIso $(if ($f) { $f } else { $ahora }) }
    }
    Write-Json $rutaEstado ([ordered]@{ enviados = $guardar })
}

$candidatos = @($pendientes | Where-Object {
        $_ -and ($tipos -contains $_.tipo) -and -not $enviados.ContainsKey([string]$_.clave) -and
        ($_.tipo -ne 'oferta' -or [int]$_.descuento -ge $descuentoMinimo)
    })
# Primero los regalos que terminan antes, despues los programas de Brizna Soft y al final las ofertas mas grandes
$orden = @{ regalo = 0; brizna = 1; oferta = 2 }
$candidatos = @($candidatos | Sort-Object @{ Expression = { $orden[[string]$_.tipo] } },
    @{ Expression = { $f = Get-Fecha $_.termina; if ($f) { $f.UtcTicks } else { [long]::MaxValue } } },
    @{ Expression = { - [int]$_.descuento } })

# Devuelve ok y el codigo HTTP (0 = no se sabe: se corto la red o no hubo respuesta).
# Ningun mensaje lleva la direccion, porque la direccion lleva la clave del bot.
function Send-Telegram([string]$Metodo, $Cuerpo) {
    $json = ConvertTo-Json -InputObject $Cuerpo -Depth 8 -Compress
    $contenido = New-Object System.Net.Http.StringContent -ArgumentList $json, $script:Utf8, 'application/json'
    try {
        $r = (Get-ClienteHttp).PostAsync("https://api.telegram.org/bot$token/$Metodo", $contenido).GetAwaiter().GetResult()
        $texto = $r.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        return [pscustomobject]@{ ok = [bool]$r.IsSuccessStatusCode; codigo = [int]$r.StatusCode; texto = $texto }
    } catch {
        return [pscustomobject]@{ ok = $false; codigo = 0; texto = 'sin respuesta de Telegram' }
    } finally {
        $contenido.Dispose()
    }
}

function Get-TextoAviso($Aviso) {
    $t = "<b>$(Html $Aviso.texto)</b>`n$(Html $Aviso.detalle)"
    $fin = Get-Fecha $Aviso.termina
    if ($fin) { $t += "`nTermina el $(Format-FechaLarga $fin -SinAnio)." }
    $t
}

if ($primeraVez) {
    foreach ($c in $candidatos) { $enviados[[string]$c.clave] = Format-FechaIso (Get-AhoraUtc) }
    Write-Host "Telegram: primera vez, se anotan $($candidatos.Count) novedades sin mandarlas."
    if (-not $Probar) { Save-Estado }
    return
}

$mandados = 0
foreach ($c in ($candidatos | Select-Object -First $maximo)) {
    if ($Probar) { Write-Host "[prueba] $($c.tipo): $($c.texto) -> $($c.url)"; continue }
    $botones = @{ inline_keyboard = @(, @(@{ text = 'Ver en Guatusa'; url = [string]$c.url })) }
    $texto = Get-TextoAviso $c
    $imagen = [string]$c.imagen
    if ($imagen -match '^https://\S+\.(jpg|jpeg|png)(\?\S*)?$') {
        $r = Send-Telegram 'sendPhoto' @{ chat_id = $canal; photo = $imagen; caption = $texto; parse_mode = 'HTML'; reply_markup = $botones }
        # Solo si Telegram rechazo la imagen (400) va el aviso sin foto; si no hubo respuesta, quiza ya salio
        if (-not $r.ok -and $r.codigo -eq 400) {
            $r = Send-Telegram 'sendMessage' @{ chat_id = $canal; text = $texto; parse_mode = 'HTML'; reply_markup = $botones }
        }
    } else {
        $r = Send-Telegram 'sendMessage' @{ chat_id = $canal; text = $texto; parse_mode = 'HTML'; reply_markup = $botones }
    }
    if ($r.ok) {
        $mandados++
    } elseif ($r.codigo -eq 0) {
        # No se sabe si salio: se anota igual, mejor perder un aviso que repetirlo
        Write-Warning "Telegram: no se sabe si salió «$($c.texto)»; no se repite."
    } elseif ($r.codigo -eq 429) {
        Write-Warning 'Telegram pidió esperar (429); lo que falta sale la próxima vez.'
        break
    } else {
        Write-Warning "Telegram: no salió «$($c.texto)» (HTTP $($r.codigo): $($r.texto)); se intenta la próxima vez."
        continue
    }
    $enviados[[string]$c.clave] = Format-FechaIso (Get-AhoraUtc)
    Save-Estado
    Start-Sleep -Seconds 3
}
if (-not $Probar) {
    Save-Estado
    Write-Host "Telegram: $mandados avisos mandados; quedan $([Math]::Max(0, $candidatos.Count - $mandados)) para la próxima vez."
}
