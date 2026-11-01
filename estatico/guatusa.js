// Guatusa: buscador y filtros de cada lista, y cuenta regresiva de los regalos.
// Todo funciona sin este archivo; solo lo hace más cómodo. No guarda ni manda nada.
(function () {
  'use strict';

  function normalizar(texto) {
    return (texto || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  }

  // Buscador y botones de filtro: <div class="filtros" data-para="id-de-la-lista" hidden>
  document.querySelectorAll('.filtros[data-para]').forEach(function (barra) {
    var lista = document.getElementById(barra.getAttribute('data-para'));
    if (!lista) return;
    var tarjetas = Array.prototype.slice.call(lista.querySelectorAll('.tarjeta'));
    var buscador = barra.querySelector('.buscar');
    var vacio = barra.parentNode.querySelector('.sin-resultados[data-para="' + lista.id + '"]');
    var activos = {}; // grupo -> etiqueta elegida, por ejemplo tienda -> tienda:epic

    function aplicar() {
      var palabras = normalizar(buscador ? buscador.value : '').split(/\s+/).filter(Boolean);
      var visibles = 0;
      tarjetas.forEach(function (t) {
        var texto = t.getAttribute('data-texto') || '';
        var etiquetas = (t.getAttribute('data-etiquetas') || '').split(' ');
        var ok = palabras.every(function (p) { return texto.indexOf(p) !== -1; });
        Object.keys(activos).forEach(function (grupo) {
          if (ok && activos[grupo] && etiquetas.indexOf(activos[grupo]) === -1) ok = false;
        });
        t.hidden = !ok;
        if (ok) visibles++;
      });
      if (vacio) vacio.hidden = visibles !== 0;
    }

    barra.querySelectorAll('.chip').forEach(function (chip) {
      chip.addEventListener('click', function () {
        var etiqueta = chip.getAttribute('data-etiqueta');
        var grupo = chip.getAttribute('data-grupo');
        var ya = activos[grupo] === etiqueta;
        activos[grupo] = ya ? '' : etiqueta;
        barra.querySelectorAll('.chip[data-grupo="' + grupo + '"]').forEach(function (otro) {
          otro.setAttribute('aria-pressed', String(!ya && otro === chip));
        });
        aplicar();
      });
    });
    if (buscador) buscador.addEventListener('input', aplicar);
    barra.hidden = false;
  });

  // Si una portada de otro sitio no carga, se pone la de Guatusa
  function respaldo(img) {
    img.removeAttribute('data-respaldo');
    img.src = '/img/sin-portada.svg';
  }
  document.querySelectorAll('img[data-respaldo]').forEach(function (img) {
    if (img.complete && img.naturalWidth === 0) respaldo(img);
    else img.addEventListener('error', function () { if (img.hasAttribute('data-respaldo')) respaldo(img); });
  });

  // Cuenta regresiva: <span data-termina="2026-11-08T23:59:00-06:00">Termina el 8 de noviembre</span>
  var ahora = Date.now();
  document.querySelectorAll('[data-termina]').forEach(function (el) {
    var fin = Date.parse(el.getAttribute('data-termina'));
    if (isNaN(fin)) return;
    var horas = (fin - ahora) / 3600000;
    var n = Math.max(1, Math.round(horas));
    if (horas < 0) el.textContent = 'Ya terminó';
    else if (horas < 24) el.textContent = 'Termina en ' + n + (n === 1 ? ' hora' : ' horas');
    else if (horas < 48) el.textContent = 'Termina mañana';
    else el.textContent = 'Quedan ' + Math.floor(horas / 24) + ' días';
  });
})();
