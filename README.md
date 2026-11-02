# Guatusa

Lo gratis y legal, en un solo lugar y en español: juegos que las tiendas regalan por tiempo limitado, juegos gratis para siempre, ofertas con precio de Honduras, programas gratis y cine legal. Es una sección de [Brizna Soft](https://brizna-soft.github.io).

La guatusa es un animalito de nuestros montes que junta semillas y las guarda para después. Aquí hacemos lo mismo con lo gratis.

## La regla

- Cada botón lleva a la tienda o a la descarga oficial. No volvemos a subir archivos de nadie.
- Nada de cracks, repacks ni copias de juegos, películas o programas de pago sin permiso de su dueño.
- Los acortadores solo van en archivos que tenemos derecho a compartir, y nunca en los programas de Brizna Soft.

## Cómo funciona

`armar.ps1` lee las fuentes, guarda lo leído en `datos/` y escribe el sitio en `publico/`. En GitHub corre solo cada 6 horas (`.github/workflows/actualizar.yml`), lo publica en Cloudflare Pages y avisa las novedades en Telegram.

| Fuente | Para qué | Condiciones |
|---|---|---|
| [GamerPower](https://www.gamerpower.com/api-read) | Juegos regalados por tiempo limitado | Gratis, también para uso comercial, con un enlace activo a GamerPower.com. Máximo 10 pedidos por segundo. |
| [itch.io](https://itch.io/games/free.xml) | Los juegos gratis más jugados | Lista RSS pública. |
| Tienda de Steam | Ofertas con precio de Honduras, géneros, idiomas y requisitos | Pocos pedidos por vez; los datos se guardan 30 días. |
| GitHub | La última versión de cada programa | Con la clave de GitHub Actions no hay límite práctico. |

**Por qué no CheapShark:** su API prohíbe usar enlaces de afiliado propios en cualquier tienda que ellos siguen. Para poder cobrar comisiones algún día, las ofertas salen de Steam (que no tiene afiliados) y después de los catálogos de las tiendas con programa de afiliados.

Lo escrito a mano, en español y comprobado en la página oficial de cada cosa, está en `contenido/`:

- `juegos-libres.json`: juegos de código abierto.
- `programas.json`: buenos programas gratis de otros.
- `brizna.json`: los programas de Brizna Soft. Su descarga es directa al .zip de GitHub, sin acortadores.
- `cine.json` y `servicios.json`: películas con licencia libre, clásicos de dominio público y servicios gratis que funcionan en Honduras.
- `descripciones.json`: textos propios para los regalos, los juegos de itch.io y las ofertas, que se ponen antes del texto automático.
- `tiendas.json`: cómo reclamar un regalo en cada tienda.
- `bloqueos.json`: lo que nunca entra desde itch.io (contenido para adultos y juegos de fans con marcas ajenas).

El generador está en `generador/`: `comun.ps1` (red, JSON, fechas), `fuentes.ps1`, `fichas.ps1` (los textos de cada ficha), `paginas.ps1` y `sitio.ps1` (el HTML), `telegram.ps1` y `comprobar-enlaces.ps1`. Funciona igual en Windows PowerShell 5.1 y en PowerShell 7, sin instalar nada.

## Probar en la PC

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File armar.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File servir.ps1
```

Después se abre http://localhost:8787/. Con `armar.ps1 -SinRed` se arma solo con lo guardado en `datos/`. Para revisar los enlaces escritos a mano: `generador\comprobar-enlaces.ps1`.

Los `.ps1` se guardan en UTF-8 con BOM: Windows PowerShell 5.1 los lee mal sin él.

Los archivos de `datos/` los guarda el flujo de GitHub. Si armas en la PC también cambian (Windows PowerShell 5.1 escribe el JSON con otro formato), pero no hace falta subirlos: `git checkout -- datos` deshace esos cambios.

## Publicar (lo hace la persona dueña de las cuentas)

1. **Cloudflare Pages:** crear la cuenta y un token de API con el permiso *Account › Cloudflare Pages › Edit*. En GitHub, guardar los secretos `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID` (está en *Workers & Pages › Account Details*). Después, correr el flujo a mano una vez (*Actions › Actualizar Guatusa › Run workflow*): esa corrida crea el proyecto `brizna-soft` y lo publica. Sin los secretos, el flujo arma el sitio y guarda los datos, pero no publica.
2. **Telegram:** crear el canal y un bot con @BotFather, y poner el bot como administrador del canal. En GitHub, el secreto `TELEGRAM_BOT_TOKEN` y la variable `TELEGRAM_CANAL` (por ejemplo `@GuatusaGratis`). En `config.json`, `telegram_canal` sin la arroba, para el botón de la página. La primera vez solo anota lo que ya existe; después cada novedad sale una vez.
3. **AdSense:** cuando lo aprueben, poner el `ca-pub-...` en `adsense_cliente`. Se agregan solos el código, la etiqueta de verificación y `ads.txt`. `brizna-soft.pages.dev` se puede agregar a AdSense porque `pages.dev` está en la lista pública de sufijos.
4. **Afiliados:** en `config.json`, `afiliados` lleva `{ "dominio de la tienda": "plantilla con {url}" }`. Esos botones se marcan como enlace de afiliado.
5. **Acortador:** `acortador` lleva la plantilla con `{url}`. Solo se usa en el contenido marcado `"acortar": true`, que debe ser algo que tenemos derecho a compartir.

## Licencia

El código es MIT (ver `LICENSE`). Las marcas, nombres y portadas de juegos, programas y películas son de sus dueños; las imágenes con licencia libre dicen su autor en cada ficha.
