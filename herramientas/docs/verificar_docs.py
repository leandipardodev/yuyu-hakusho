# -*- coding: utf-8 -*-
"""verificar_docs.py -- comprueba que la DOCUMENTACION sea verdad.

Tres comprobaciones:

  1) ENLACES ROTOS: cada `algo.md` citado tiene que existir.
  2) DIRECCIONES QUE NO SON CODIGO: cada `$019e08` citado tiene que estar
     en el desensamblado (si no, es un dato, no una instruccion: se avisa
     aparte).
  3) CONTRADICCIONES: si la linea del doc afirma una instruccion concreta
     (bset, jsr, btst, cmpi, move...) y en esa direccion hay OTRA, el
     doc esta equivocado.

Uso:
    python herramientas/docs/verificar_docs.py
    python herramientas/docs/verificar_docs.py --solo-contradicciones
"""
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOCS = os.path.join(RAIZ, "docs")
ASM = os.path.join(RAIZ, "datos", "desensamblado_68000.asm")
ROM_BASE = os.path.join(RAIZ, "rom", "base", "yuyu_makyou_base.bin")

# las mnemonicas de la 68000 que aparecen en los docs
MNEMONICAS = [
    "jsr", "jmp", "rts", "rte", "bra", "bsr", "nop",
    "bset", "bclr", "btst", "bchg", "beq", "bne", "bcs", "bcc", "bhi", "bls",
    "bge", "blt", "bgt", "ble", "bmi", "bpl", "bvs", "bvc", "bne.w",
    "move", "movea", "movem", "moveq", "lea", "pea",
    "add", "addi", "addq", "addx", "sub", "subi", "subq", "subx",
    "cmp", "cmpi", "cmpm", "tst", "andi", "ori", "eori", "eor",
    "lsl", "lsr", "rol", "ror", "asl", "asr", "ext", "swap",
    "and", "or", "not", "neg", "clr", "link", "unlk", "trap",
    "dbra", "dbf", "stop", "reset", "nop",
]
# las mas frecuentes, para no hacer match de mas
MNEMONICAS.sort(key=len, reverse=True)
RE_MNEM = re.compile(r"\b(" + "|".join(MNEMONICAS) + r")\b", re.IGNORECASE)
RE_DIR = re.compile(r"\$([0-9a-fA-F]{4,6})\b|\b0x([0-9a-fA-F]{4,6})\b")
# una AFIRMACION: una direccion y, justo despues, una instruccion.
# "en $019c46 hay un sub.w" / "019c46: sub.w d0,$b8(a5)" / "$019c46 `sub.w`"
RE_AFIRMA = re.compile(
    r"(?:en\s+|0x)?\$?0?([0-9a-fA-F]{5,6})[`'\"]?\s*[:,\-]?\s*[`'\"]?("
    + "|".join(MNEMONICAS) + r")\b", re.IGNORECASE)
# lo mismo, pero aceptando tambien el prefijo 0x de 6 digitos
RE_AFIRMA = re.compile(
    r"(?:en\s+)?(?:0x)?\$?0?([0-9a-fA-F]{5,6})[`'\"]?\s*[:,\-]?\s*[`'\"]?("
    + "|".join(MNEMONICAS) + r")\b", re.IGNORECASE)
RE_MD = re.compile(r"`?([A-Za-z0-9_\-]+\.md)`?")
RE_SEC = re.compile(r"[§]\s*([0-9]+[a-z]?)")

# las direcciones que son de DATOS (no hay instruccion ahi) y estan
# confirmadas: no se pueden comprobar contra el desensamblado
def carga_desensamblado():
    """devuelve {direccion: instruccion} DESENSAMBLANDO LA ROM CRUDA.

    No se usa el .asm: es un fichero generado y puede quedarse viejo. La
    fuente de verdad es la ROM.
    """
    from capstone import Cs, CS_ARCH_M68K, CS_MODE_BIG_ENDIAN
    md = Cs(CS_ARCH_M68K, CS_MODE_BIG_ENDIAN)
    codigo = {}
    if not os.path.exists(ROM_BASE):
        return codigo
    rom = open(ROM_BASE, "rb").read()
    for d in range(0x200, len(rom) - 12):
        for i in md.disasm(rom[d:d + 12], d, count=1):
            codigo[d] = "%-9s %s" % (i.mnemonic, i.op_str)
            break
    return codigo


def direccion_es_operando(codigo, d, ventana=24):
    """True si la direccion aparece como operando de alguna instruccion
    cercana (el destino de un salto, el puntero de una tabla, ...)."""
    formas = ("$%x" % d, "$%X" % d, "0x%06x" % d, "0x%06X" % d)
    for delta in range(-ventana, ventana + 1):
        ins = codigo.get(d + delta)
        if not ins:
            continue
        baja = ins.lower()
        for f in formas:
            if f.lower() in baja:
                return True
    return False


def paginas_de_codigo():
    """las paginas de 4 KB que el mapa de la ROM dice que son CODIGO.

    Una direccion que cae en una pagina de DATOS no se puede comprobar
    contra una instruccion: es un valor, no codigo.
    """
    codigo = set()
    ruta = os.path.join(RAIZ, "datos", "mapa_rom.txt")
    if not os.path.exists(ruta):
        return None
    with io.open(ruta, encoding="utf-8", errors="replace") as f:
        for linea in f:
            m = re.match(r"\s*0x([0-9a-f]{6})\s+.*?(CODIGO|DATOS|datos|CODIGO 68k|Z80|VECTORES|vectores)",
                         linea)
            if m and m.group(2).upper().startswith("CODIGO"):
                codigo.add(int(m.group(1), 16))
    return codigo or None


# los .md que son MATERIAL EXTERNO (del usuario, no de este repo): no son
# enlaces internos y no se pueden arreglar aqui
EXTERNOS = {
    "MODIFICAR.md", "LEEME.md", "README_PROYECTO.md", "GUIA.md",
    "MAPA_DIRECCIONES.md", "DATOS_VERIFICADOS.md", "MEMORIA.md",
    "14f-7f.md",
}


def mds_existentes():
    nombres = set()
    for raiz, dirs, files in os.walk(RAIZ):
        dirs[:] = [d for d in dirs if d not in (".git", "__pycache__")]
        for f in files:
            if f.endswith(".md"):
                nombres.add(f)
    return nombres


def main():
    solo_contra = "--solo-contradicciones" in sys.argv
    codigo = carga_desensamblado()
    paginas = paginas_de_codigo()
    print("el desensamblado tiene %d instrucciones" % len(codigo))
    mds = mds_existentes()

    enlaces_rotos = []
    dirs_sin_codigo = {}
    contradicciones = []
    ndirs = 0

    for raiz, dirs, files in os.walk(DOCS):
        for f in sorted(files):
            if not f.endswith(".md"):
                continue
            ruta = os.path.join(raiz, f)
            with io.open(ruta, encoding="utf-8", errors="replace") as fh:
                lineas = fh.read().splitlines()
            for n, linea in enumerate(lineas, 1):
                # 1) los enlaces a .md (solo los que son un token suelto)
                if not solo_contra and ":\\" not in linea and "C:/" not in linea:
                    for nombre in RE_MD.findall(linea):
                        if nombre in mds or nombre in EXTERNOS:
                            continue
                        if not re.search(r"\s", nombre):
                            enlaces_rotos.append((ruta, n, nombre, linea.strip()[:90]))
                # 2) y 3) las direcciones
                # se ignoran las filas de tabla (empiezan por |) y las
                # lineas con rutas de windows
                if linea.lstrip().startswith("|"):
                    continue
                if ":\\" in linea or "C:/" in linea:
                    continue
                for a, b in RE_DIR.findall(linea):
                    d = int(a or b, 16)
                    if d < 0x200 or d > 0x2FFFFF:
                        continue
                    ndirs += 1
                    if codigo.get(d) is None:
                        dirs_sin_codigo.setdefault(ruta, []).append((n, d))
                # 3) las AFIRMACIONES: "en $019c4e hay un sub.w" o
                #    "019c4e: sub.w d0,$b8(a5)"
                for m in RE_AFIRMA.finditer(linea):
                    d = int(m.group(1), 16)
                    mn = m.group(2).lower()
                    if d < 0x200 or d > 0x2FFFFF:
                        continue
                    ins = codigo.get(d)
                    if ins is None:
                        continue          # es un dato: no se comprueba
                    # si la pagina de la direccion no es de codigo, es un
                    # dato: no se comprueba
                    if paginas is not None and (d & ~0xFFF) not in paginas:
                        continue
                    if mn in ins.lower():
                        continue          # coincide
                    # si la direccion citada es un operando de la
                    # instruccion afirmada, el doc cita el destino
                    if ("$%x" % d) in ins.lower() or ("0x%06x" % d) in ins.lower():
                        continue
                    contradicciones.append((ruta, n, d, mn, ins, linea.strip()[:90]))

    print()
    print("=== 1) ENLACES ROTOS a ficheros .md ===")
    if enlaces_rotos:
        for r, n, nombre, txt in enlaces_rotos:
            print("  %s:%d  ->  %s" % (os.path.relpath(r, RAIZ), n, nombre))
            print("      %s" % txt)
        print("  %d enlaces rotos" % len(enlaces_rotos))
    else:
        print("  ninguno")

    print()
    print("=== 2) DIRECCIONES CITADAS QUE NO SON CODIGO (son datos) ===")
    total = sum(len(v) for v in dirs_sin_codigo.values())
    for r, v in sorted(dirs_sin_codigo.items()):
        print("  %s: %d" % (os.path.relpath(r, RAIZ), len(v)))
    print("  %d en total (no es un error: son tablas y datos)" % total)

    print()
    print("=== 3) CONTRADICCIONES (el doc dice una instruccion y hay otra) ===")
    if contradicciones:
        for r, n, d, mn, ins, txt in contradicciones:
            print("  %s:%d  $%06X" % (os.path.relpath(r, RAIZ), n, d))
            print("      el doc dice '%s'   y en la ROM hay: %s" % (mn, ins))
            print("      %s" % txt)
        print("  %d contradicciones" % len(contradicciones))
    else:
        print("  ninguna")

    print()
    print("resumen: %d direcciones citadas, %d enlaces rotos, %d contradicciones"
          % (ndirs, len(enlaces_rotos), len(contradicciones)))
    return 1 if (enlaces_rotos or contradicciones) else 0


if __name__ == "__main__":
    sys.exit(main())
