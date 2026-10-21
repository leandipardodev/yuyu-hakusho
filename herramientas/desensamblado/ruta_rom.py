# -*- coding: utf-8 -*-
"""
Resolucion de la ruta de la ROM.

Antes cada script llevaba la ruta absoluta quemada
(r"C:\\Users\\leand\\Downloads\\..."), lo que hacia que el repo solo
funcionara en la maquina de quien lo escribio. Ahora la ruta se resuelve
en este modulo y hay tres formas de decir donde esta la ROM, en orden
de prioridad:

1. Variable de entorno YUYU_ROM.
   PowerShell:  $env:YUYU_ROM = "D:\\roms\\yuyu.bin"
   cmd:         set YUYU_ROM=D:\\roms\\yuyu.bin
   Linux/mac:   export YUYU_ROM=/ruta/yuyu.bin

2. Fichero .rom_path en la raiz del repo, con una linea con la ruta.
   Se ignora por git, asi que cada uno tiene el suyo.

3. La ROM en la raiz del repo, con el nombre de origen.

Si ninguna funciona, el error dice exactamente que hacer.

La ROM NO se distribuye con el repo: es una obra con derechos de autor.
Descargala por tu cuenta y aplica el punto 1 o el 2 de arriba.
"""
import os
import sys

NOMBRE_ROM = "Yuu Yuu Hakusho - Makyou Toitsusen (J).bin"

# Raiz del repo: este fichero vive en herramientas/desensamblado/, asi que
# hay que subir DOS niveles (desensamblado -> herramientas -> raiz).
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

FICHERO_CONFIG = os.path.join(RAIZ, ".rom_path")


def _desde_config():
    """Lee .rom_path si existe. Devuelve None si no."""
    if not os.path.isfile(FICHERO_CONFIG):
        return None
    try:
        # utf-8-sig: tolera que el fichero tenga BOM, que es lo que escribe
        # Set-Content -Encoding utf8 en Windows PowerShell. Sin esto el BOM
        # se cuela en la ruta y el fichero no se encuentra nunca.
        with open(FICHERO_CONFIG, "r", encoding="utf-8-sig") as f:
            ruta = f.read().strip()
    except OSError:
        return None
    if not ruta:
        return None
    # Normalizar separadores: el fichero se puede haber escrito en Windows
    # y leido en otro sistema.
    return os.path.normpath(ruta)


def candidatos():
    """Rutas candidatas en orden de prioridad. Para diagnostico."""
    lista = []

    env = os.environ.get("YUYU_ROM")
    if env:
        lista.append(os.path.normpath(env))

    conf = _desde_config()
    if conf:
        lista.append(conf)

    lista.append(os.path.join(RAIZ, "rom", "base", NOMBRE_ROM))
    return lista


def ruta_rom():
    """Devuelve la ruta de la ROM. Falla con un mensaje util si no la hay."""
    for ruta in candidatos():
        if os.path.isfile(ruta):
            return os.path.abspath(ruta)

    msg = [
        "No encuentro la ROM del juego.",
        "",
        "  Buscado en:",
    ]
    for ruta in candidatos():
        msg.append("    %s%s" % (ruta, "   <- no existe" if not os.path.isfile(ruta) else ""))
    msg += [
        "",
        "  Como arreglarlo (elegir una):",
        "",
        '  1) Definir la variable de entorno',
        '     PowerShell:  $env:YUYU_ROM = "D:\\roms\\%s"' % NOMBRE_ROM,
        '     cmd:         set YUYU_ROM=D:\\roms\\%s' % NOMBRE_ROM,
        "",
        "  2) Crear el fichero %s en la raiz del repo" % os.path.basename(FICHERO_CONFIG),
        '     con una sola linea:  D:\\roms\\%s' % NOMBRE_ROM,
        "",
        "  3) Dejar la ROM en la raiz del repo con el nombre original.",
        "",
        "  La ROM no va en el repo: es material con derechos de autor.",
    ]
    raise SystemExit("\n".join(msg))


def leer_rom():
    """Devuelve el contenido de la ROM como bytes."""
    with open(ruta_rom(), "rb") as f:
        return f.read()


def camino_asm():
    """Ruta del desensamblado del 68000 (datos/desensamblado_68000.asm).
    No es configurable, pero se centraliza aqui para no repetir el '..'."""
    return os.path.join(RAIZ, "datos", "desensamblado_68000.asm")


def dir_sprites():
    """Carpeta assets/imagenes/ del repo. Se crea si no existe."""
    d = os.path.join(RAIZ, "assets", "imagenes")
    if not os.path.isdir(d):
        os.makedirs(d)
    return d


if __name__ == "__main__":
    # Comprobacion manual:  python herramientas\desensamblado\ruta_rom.py
    try:
        print("ROM encontrada en:\n  %s" % ruta_rom())
    except SystemExit as e:
        print(str(e), file=sys.stderr)
        raise SystemExit(1)
