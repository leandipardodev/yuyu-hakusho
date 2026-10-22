---
name: Dato dudoso o error en la documentacion
about: Una direccion que no cuadra, o un dato sin verificar
title: "[DATO] "
labels: dato-dudoso
assignees: ''
---

## Que he comprobado

<!--
Que has hecho: has desensamblado la ROM, has ejecutado un Lua, has
mirado el juego... Ponlo aqui. Con el "como" se puede reproducir.
-->

## El dato

<!-- La afirmacion, tal cual esta en el documento (con su fichero y su linea). -->

- **Fichero y linea:**
- **Lo que dice el documento:**
- **Lo que hay en la ROM** (la instruccion real y su direccion):

```
019e08:  0c 2d 00 0f 00 5f  cmpi.b    #$f, $5f(a5)
```

## De donde sale

<!--
[ROM]  = leido en el desensamblado
[MEDIDO] = medido en el emulador (FBNeo) o jugando
[NOTAS] = viene del repo de notas
-->

- **Marca:** [ROM] / [MEDIDO] / [NOTAS]
- **Como se comprueba:** el script que lo comprueba, o el Lua

## La ROM

<!--
IMPORTANTE: la J y la CHINA no tienen el codigo en los mismos sitios.
Di de que ROM es la direccion que citas.
-->

- **ROM:** la base (la china) / la japonesa (J) / la inglesa
- **SHA1 de la base:** (la de `rom/base/`)
