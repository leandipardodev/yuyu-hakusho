#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera STURDIMIENTO.md a partir de los datos REALES que ya estan en
FICHAS_DE_PERSONAJES.md (traducidos de newton / nesbbs / kakusi).

No inventa nada: copia las celdas de stun tal como estan en la fuente y
marca con [?] lo que este incompleto.

Los datos VERIFICADOS contra el ROM no se escriben aqui: se leen de la
seccion "## 2b. Stun" de DATOS_VERIFICADOS.md, que es la unica fuente de
verdad (ver MEMORIA.md regla 1). Antes esta copia estaba escrita a mano en
este script y se desincronizo: llegó a afirmar que el stun estaba en
"$14(a5), 32 bits", que es exactamente la trampa que MEMORIA.md marca como
falsa. Ahora si DATOS_VERIFICADOS.md no tiene esa seccion, el script falla
en vez de escribir una suposicion.

    python gen_stun.py
"""
import io
import os
import re
import sys

# Raiz del repo: este fichero vive en tools/
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Los documentos viven en docs/ desde la reorganizacion del proyecto.
DOCS = os.path.join(BASE, "docs")
ORIGEN = os.path.join(DOCS, "2-personajes", "FICHAS_DE_PERSONAJES.md")
VERIFICADOS = os.path.join(DOCS, "1-datos", "DATOS_VERIFICADOS.md")
SALIDA = os.path.join(DOCS, "2-personajes", "STURDIMIENTO.md")

# Titulo exacto de la seccion de referencia en DATOS_VERIFICADOS.md
TITULO_VERIFICADO = re.compile(r"^#{2,3}\s*2b\.?\s*Stun\s*$", re.IGNORECASE)


def leer():
    return io.open(ORIGEN, encoding="utf-8", errors="replace").read().split("\n")


def seccion_verificada():
    """Devuelve las lineas de la seccion '## 2b. Stun' de
    DATOS_VERIFICADOS.md, tal cual, sin el titulo.

    Es la unica copia de estos datos. Si no existe, se aborta: es preferible
    no generar el documento a generarlo con suposiciones.
    """
    if not os.path.isfile(VERIFICADOS):
        raise SystemExit(
            "No encuentro %s.\n"
            "Sin el no puedo escribir la parte verificada del stun: "
            "preferible no generar a inventar." % VERIFICADOS
        )

    lineas = io.open(VERIFICADOS, encoding="utf-8", errors="replace").read().split("\n")

    ini = None
    for i, l in enumerate(lineas):
        if TITULO_VERIFICADO.match(l.strip()):
            ini = i + 1
            break

    if ini is None:
        raise SystemExit(
            "DATOS_VERIFICADOS.md no tiene la seccion '## 2b. Stun'.\n"
            "Es la fuente de verdad del stun segun MEMORIA.md regla 1, y el "
            "generador no puede escribirla por su cuenta.\n"
            "Restaurala o ajusta TITULO_VERIFICADO en tools/gen_stun.py."
        )

    fin = len(lineas)
    for j in range(ini, len(lineas)):
        if re.match(r"^#{2}\s", lineas[j].strip()):
            fin = j
            break

    cuerpo = [l for l in lineas[ini:fin]]

    # recorta lineas en blanco al final
    while cuerpo and not cuerpo[-1].strip():
        cuerpo.pop()

    if not any(l.strip() for l in cuerpo):
        raise SystemExit("La seccion '## 2b. Stun' de DATOS_VERIFICADOS.md esta vacia.")

    return cuerpo


def partir_tabla(lineas, inicio):
    """devuelve (cabecera, filas) de la tabla markdown que empieza en `inicio`"""
    cab = None
    filas = []
    i = inicio
    while i < len(lineas):
        l = lineas[i].strip()
        if not l.startswith("|"):
            break
        celdas = [c.strip() for c in l.strip("|").split("|")]
        if set("".join(celdas)) <= set("-: "):
            i += 1
            continue
        if cab is None:
            cab = celdas
        else:
            filas.append(celdas)
        i += 1
    return cab, filas, i


def quitar_md(txt):
    txt = re.sub(r"\*\*(.+?)\*\*", r"\1", txt)
    txt = txt.replace("`", "")
    return txt.strip()


def main():
    lineas = leer()
    verif = seccion_verificada()
    L = []
    a = L.append

    a("# Sturdimiento por golpe y habilidad, por personaje")
    a("## Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994)\n")
    a("> **Procedencia de los datos de las tablas:** traducidos y reorganizados")
    a("> de `newton.com.tw`, `wiki.nesbbs.com` y `kakusi.jp` (ver el aviso de")
    a("> `FICHAS_DE_PERSONAJES.md`). Son la mejor informacion publica que")
    a("> existe del juego, pero **no estan verificados contra el ROM**.")
    a("> Lo unico verificado leyendo el codigo va al final del documento y se")
    a("> copia literalmente de `DATOS_VERIFICADOS.md` 2b, que es la fuente de")
    a("> verdad.\n")
    a("> **Leyenda:** el dano esta en puntos de HP (HP maximo = 255; el 223 es")
    a("> el tope del mana). El stun es el aturdimiento que inflige el golpe al")
    a("> oponente. `[?]` marca celdas que la fuente no completa.\n")

    a("---\n")

    # recorrer personajes
    i = 0
    n_personajes = 0
    while i < len(lineas):
        m = re.match(r"^#\s*ID\s*(\d+)\s*[-—]\s*(.+)$", lineas[i].strip())
        if not m:
            i += 1
            continue
        pid, nombre = m.group(1), quitar_md(m.group(2))
        n_personajes += 1
        a("\n# ID %s — %s\n" % (pid, nombre))

        # perfil: va DESPUES del subtitulo ### "..." y antes de las tablas
        # de golpes, asi que se corta en esas, no en cualquier ###
        j = i + 1
        perfil = {}
        while j < len(lineas):
            l = lineas[j].strip()
            if l.startswith("### Golpes") or l.startswith("### Especial"):
                break
            if l.startswith("|"):
                celdas = [quitar_md(c) for c in l.strip("|").split("|")]
                # el formato real es  | **Stun** | 54 | **Dash** 83 | ...
                # o sea: la palabra clave en una celda y el valor en la SIGUIENTE
                claves = ("Stun", "Dash", "Backdash", "Walk", "Super")
                for ci, c in enumerate(celdas):
                    for clave in claves:
                        if c.strip() == clave and ci + 1 < len(celdas):
                            v = celdas[ci + 1].strip(" :")
                            if v:
                                perfil.setdefault(clave, v)
            j += 1

        if perfil:
            a("### Perfil\n")
            a("| Dato | Valor |\n|---|---|")
            etiquetas = {
                "Stun": "Stun maximo del personaje",
                "Dash": "Dash (frames)",
                "Backdash": "Backdash (frames)",
                "Walk": "Velocidad de caminata",
            }
            for k, v in perfil.items():
                if k in etiquetas:
                    a("| %s | %s |" % (etiquetas[k], v))
            if "Super" in perfil:
                a("| Super (comando) | %s |" % perfil["Super"])
            a("")

        # tablas de golpes
        while j < len(lineas):
            tit = lineas[j].strip()
            if tit.startswith("# ID"):
                break
            if tit.startswith("### "):
                nombre_t = quitar_md(tit[4:])
                cab, filas, k = partir_tabla(lineas, j + 1)
                if filas:
                    a("### %s\n" % nombre_t)
                    idx_stun = None
                    idx_dmg = None
                    for ci, c in enumerate(cab or []):
                        cl = quitar_md(c).lower()
                        if "stun" in cl:
                            idx_stun = ci
                        if "da" in cl and "o" in cl and idx_dmg is None:
                            idx_dmg = ci
                    columnas = [quitar_md(c) for c in cab]
                    # la tabla original YA trae la columna Stun: no se duplica.
                    # solo se marcan como [?] las celdas vacias.
                    a("| " + " | ".join(columnas) + " |")
                    a("|" + "|".join(["---"] * len(columnas)) + "|")
                    for f in filas:
                        vals = [quitar_md(x) for x in f]
                        while len(vals) < len(columnas):
                            vals.append("[?]")
                        for ci, v in enumerate(vals):
                            if not v or v in ("-", "—"):
                                vals[ci] = "[?]"
                        a("| " + " | ".join(vals[:len(columnas)]) + " |")
                    a("")
                    j = k
                    continue
            j += 1
        i = j

    a("\n---\n")
    a("## Lo que falta\n")
    a("| Dato | Estado |\n|---|---|")
    a("| Stun por golpe | **Completo** para los 11 personajes, de fuente web |")
    a("| Stun maximo por personaje | Presente; verificado contra el ROM abajo |")
    a("| Danio por golpe | Completo, de fuente web |")
    a("| Mana por golpe | Completo, de fuente web |")
    a("| **Startup / active / recovery** | **FALTA COMPLETO** |")
    a("| **Hitstun y blockstun por separado** | **FALTA**: solo hay stun total |")
    a("| **Cancelaciones reales** | Parcial (solo si/no) |")
    a("| Dash y backdash en frames | Presente por personaje |")
    a("")
    a("### Lo unico verificado del ROM sobre el stun\n")
    a("_(copiado literalmente de `DATOS_VERIFICADOS.md` 2b; no editar aqui)_\n")
    for l in verif:
        a(l)
    a("")
    a("### Por que falta el frame data\n")
    a("`COMANDOS_Y_FRAME_DATA.md` **no contiene** startup, active ni recovery:")
    a("son los numeros que hay que medir. Ninguna fuente publica los tiene (el")
    a("juego salio solo en Japon en 1994) y no se han extraido del ROM.\n")
    a("Para obtenerlos habria que ejecutar el juego hasta un combate y leer")
    a("los estados del struct frame a frame, o bien localizar el campo de")
    a("duracion dentro de las tablas de moves (`$8C`) y de la tabla `$90`")
    a("de 30 bytes.")

    io.open(SALIDA, "w", encoding="utf-8").write("\n".join(L) + "\n")
    print("escrito: %s" % SALIDA)
    print("personajes: %d" % n_personajes)
    print("lineas: %d" % len(L))
    print("seccion verificada copiada de DATOS_VERIFICADOS.md: %d lineas" % len(verif))


if __name__ == "__main__":
    main()
