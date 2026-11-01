# Avisa en el canal de Telegram las novedades que dejo armar.ps1 en telegram-pendientes.json.
# Necesita, como secretos o variables de GitHub (nunca en el codigo):
#   TELEGRAM_BOT_TOKEN  la clave del bot que da @BotFather; el bot tiene que ser administrador del canal
#   TELEGRAM_CANAL      el canal, por ejemplo @GuatusaGratis (si falta, se usa telegram_canal de config.json)
# La primera vez solo anota lo que ya hay, para no llenar el canal de golpe. Despues cada novedad sale una sola vez.
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

$pendientes = Read-Json (Join-Ruta $raiz 'telegram-pendientes.json')
$candidatos = @(@($pendientes) | Where-Object {
        $_ -and ($tipos -contains $_.tipo) -and -not $enviados.ContainsKey([string]$_.clave) -and
        ($_.tipo -ne 'oferta' -or [int]$_.descuento -ge $descuentoMinimo)
    })
# Primero los regalos que terminan antes, despues los programas de Brizna Soft y al final las ofertas mas grandes
$orden = @{ regalo = 0; brizna = 1; oferta = 2 }
$candidatos = @($candidatos | Sort-Object @{ Expression = { $orden[[string]$_.tipo] } },
    @{ Expression = { $f = Get-Fecha $_.termina; if ($f) { $f.UtcTicks } else { [long]::MaxValue } } },
    @{ Expression = { - [int]$_.descuento } })

function Send-Telegram([string]$Metodo, $Cuerpo) {
    $json = ConvertTo-Json -InputObject $Cuerpo -Depth 8 -Compress
    $contenido = New-Object System.Net.Http.StringContent -ArgumentList $json, $script:Utf8, 'application/json'
    $r = (Get-ClienteHttp).PostAsync("https://api.telegram.org/bot$token/$Metodo", $contenido).GetAwaiter().GetResult()
    $texto = $r.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    # El mensaje de error nunca lleva la direccion, porque la direccion lleva la clave del bot
    if (-not $r.IsSuccessStatusCode) { throw "Telegram respondió $([int]$r.StatusCode): $texto" }
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
} else {
    $mandados = 0
    foreach ($c in ($candidatos | Select-Object -First $maximo)) {
        $botones = @{ inline_keyboard = @(, @(@{ text = 'Ver en Guatusa'; url = [string]$c.url })) }
        $texto = Get-TextoAviso $c
        $imagen = [string]$c.imagen
        if ($Probar) { Write-Host "[prueba] $($c.tipo): $($c.texto) -> $($c.url)"; continue }
        try {
            if ($imagen -match '^https://\S+\.(jpg|jpeg|png)(\?\S*)?$') {
                try {
                    Send-Telegram 'sendPhoto' @{ chat_id = $canal; photo = $imagen; caption = $texto; parse_mode = 'HTML'; reply_markup = $botones }
                } catch {
                    # Si Telegram no puede bajar la imagen, va solo el texto
                    Send-Telegram 'sendMessage' @{ chat_id = $canal; text = $texto; parse_mode = 'HTML'; reply_markup = $botones }
                }
            } else {
                Send-Telegram 'sendMessage' @{ chat_id = $canal; text = $texto; parse_mode = 'HTML'; reply_markup = $botones }
            }
            $enviados[[string]$c.clave] = Format-FechaIso (Get-AhoraUtc)
            $mandados++
            Start-Sleep -Seconds 3
        } catch {
            Write-Warning "Telegram: no salió «$($c.texto)» ($($_.Exception.Message))"
        }
    }
    Write-Host "Telegram: $mandados avisos mandados; quedan $([Math]::Max(0, $candidatos.Count - $mandados)) para la próxima vez."
}

if ($Probar) { return }
# Se recuerda cada aviso 120 dias
$ahora = Get-AhoraUtc
$guardar = [ordered]@{}
foreach ($k in ($enviados.Keys | Sort-Object)) {
    $f = Get-Fecha $enviados[$k]
    if ($f -and ($ahora - $f).TotalDays -le 120) { $guardar[$k] = Format-FechaIso $f }
}
Write-Json $rutaEstado ([ordered]@{ enviados = $guardar })
