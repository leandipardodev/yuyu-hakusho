---
name: Parche propuesto
about: Un cambio al manifiesto de parches (datos/parches.json)
title: "[PATCH] "
labels: parche
assignees: ''
---

## Que quiero cambiar

<!--
Un grupo nuevo del manifiesto, o una correccion de uno existente.
Recuerda: la fuente de verdad de las direcciones es la ROM BASE (la china),
no el .asm (que es de la japonesa).
-->

- **Grupo:**
- **Direccion(es) y byte(s):**
- **Old -> New:**

## Por que

<!--
Que gana el juego. Si es un parche que anula algo, recuerda:
para anular un bloque condicional hay que anular la CONDICION (el inmediato
del cmpi/btst), nunca cambiar el bne por un bra (un bra no salta nunca).
-->

## Como lo he comprobado

- **El verificador:** `python herramientas/desensamblado/verificar_desensamblado.py <rom>` da OK
- **La ROM parcheada:** (el checksum y cuantos bytes cambian)
- **En el emulador:** que se ve y que antes no se veia

## La ROM

- **Base:** la china (`rom/base/`)
- **SHA1:**
