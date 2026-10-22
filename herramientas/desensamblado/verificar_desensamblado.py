# -*- coding: utf-8 -*-
"""
VERIFICA EL DESENSAMBLADO de las zonas parcheadas.

Un parche puede poner los bytes correctos y aun asi romper el codigo: si se
cambia un opcode por otro (de move.w a move.l, por ejemplo), la instruccion
sigue occupying los mismos bytes pero hace otra cosa. Esta herramienta
comprueba que, en la ROM final, cada instruccion tocada sigue siendo la
misma instruccion.

Se usa `datos/desensamblado_68000.asm` para saber donde empieza cada
instruccion ORIGINAL (sus limites son fiables), y se vuelve a desensamblar
desde ahi con capstone.

Lo que se busca:
  - que la instruccion siga desensamblando (que no se haya roto el flujo)
  - que el MNEMONICO no haya cambiado (un cambio de opcode es el fallo
    tipico: los bytes son los "correctos" pero la instruccion es otra)
  - que el tamano siga siendo el mismo (una instruccion que crece
    desalinea todo lo que viene despues)

Uso:  python herramientas/desensamblado/verificar_desensamblado.py <rom.bin>
"""
import io, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

try:
    from capstone import Cs, CS_ARCH_M68K, CS_MODE_M68K_000, CS_MODE_BIG_ENDIAN
except ImportError:
    print("FALTA CAPSTONE:  pip install capstone")
    sys.exit(2)

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PARCHES = os.path.join(RAIZ, "datos", "parches.json")
RECETAS = os.path.join(RAIZ, "datos", "recetas.json")
ASM = os.path.join(RAIZ, "datos", "desensamblado_68000.asm")

md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000 | CS_MODE_BIG_ENDIAN)
md.detail = False


def carga_asm():
    instr = {}
    with io.open(ASM, encoding="utf-8", errors="replace") as f:
        for ln in f:
            m = re.match(r"^([0-9a-f]{6}):\s+((?:[0-9a-f]{2} )+)\s*(.*)$", ln.rstrip())
            if not m:
                continue
            addr = int(m.group(1), 16)
            raw = bytes.fromhex(m.group(2).replace(" ", ""))
            resto = m.group(3).strip()
            mm = re.match(r"^([a-z0-9.]+)\s*(.*)$", resto) if resto else None
            instr[addr] = (raw, mm.group(1) if mm else "", mm.group(2).strip() if mm else "")
    return instr


def desensambla(d, addr, n=1):
    out = []
    for i in md.disasm(bytes(d[addr:addr + 32]), addr, count=n):
        out.append((i.address, i.size, i.mnemonic, i.op_str))
    return out


def norm(s):
    return s.replace(" ", "").lower()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if not args:
        print(__doc__)
        sys.exit(1)
    ruta_rom = args[0]

    with io.open(PARCHES, encoding="utf-8") as f:
        parches = json.load(f)
    with io.open(RECETAS, encoding="utf-8") as f:
        rec = json.load(f)
    instr = carga_asm()

    aplicados = set()
    for c in rec.get("cambios", []) + rec.get("combinaciones", []):
        aplicados.update(c["grupos"])
    for cid in rec.get("aceptados", []):
        for c in rec["cambios"]:
            if c["id"] == cid:
                aplicados.update(c["grupos"])

    d = open(ruta_rom, "rb").read()
    base = open(os.path.join(RAIZ, "rom", "base", "yuyu_makyou_base.bin"), "rb").read()

    print("=" * 78)
    print("DESENSAMBLADO DE LAS ZONAS PARCHEADAS DE %s" % os.path.basename(ruta_rom))
    print("=" * 78)

    # los grupos cuyo cambio de instruccion es INTENCIONAL
    cambios_esperados = {
        "doble_salto",     # reescribe la rutina $18440 a proposito (y crece 2 bytes)
        "un_plano",        # los bloques de cruce y el filtro, a proposito
        "sin_cruce",       # lo mismo
        "sin_atajo_cruce",  # los btst de los botones C e Y (cambia el bit)
        "plano_y_dano",     # el flag del plano $A042 + el dano al cruzar
        "kage_proj",       # refactor del proyectil
        "rival_delante",   # las inicializaciones
        "kage_dur",        # duraciones a 0
        "kurama_planta", "kurama_ventana", "kurama_ciego",  # el nibble $67/$68
        "kuwabara_hoja_2hits", "kuwabara_hoja_2hits_alt",  # datos, no codigo
        "itsuki_teleport_suelo",  # sustituye una instruccion por otra del mismo tamano
    }

    problemas = 0
    avisos = 0
    vistos = set()
    for g in sorted(aplicados):
        if g not in parches["patches"]:
            continue
        for b in parches["patches"][g]["bytes"]:
            a = int(b["addr"], 16)
            inicio = None
            for ad in sorted(instr):
                if ad > a:
                    break
                raw = instr[ad][0]
                if ad <= a < ad + len(raw):
                    inicio = ad
                    break
            if inicio is None:
                continue        # es un byte de DATOS, no de codigo
            raw, mn, op = instr[inicio]
            nuevos = bytes(d[inicio:inicio + len(raw)])
            if nuevos == bytes(base[inicio:inicio + len(raw)]):
                continue        # la instruccion no cambio
            if (g, inicio) in vistos:
                continue
            vistos.add((g, inicio))
            res = desensambla(d, inicio, 1)
            if not res:
                if g in cambios_esperados:
                    print("  [ok*] %-16s $%06X  la reescribio (no desensambla desde el inicio original)" % (g, inicio))
                else:
                    print("  [MAL] %-16s $%06X  NO DESENSAMBLA (bytes %s)"
                          % (g, inicio, " ".join("%02X" % c for c in nuevos)))
                    problemas += 1
                continue
            ad, sz, nmn, nop = res[0]
            if sz != len(raw):
                if g in cambios_esperados:
                    print("  [ok*] %-16s $%06X  la reescribio: %d -> %d bytes" % (g, inicio, len(raw), sz))
                    print("        antes: %s %s" % (mn, op))
                    print("        ahora: %s %s" % (nmn, nop))
                else:
                    print("  [MAL] %-16s $%06X  CAMBIO DE TAMANO %d -> %d bytes" % (g, inicio, len(raw), sz))
                    print("        antes: %s %s" % (mn, op))
                    print("        ahora: %s %s" % (nmn, nop))
                    problemas += 1
                continue
            if nmn.lower() != mn.lower():
                if g in cambios_esperados:
                    print("  [ok*] %-16s $%06X  %s %s  ->  %s %s   (cambio previsto)"
                          % (g, inicio, mn, op, nmn, nop))
                else:
                    print("  [AVISO] %-15s $%06X  EL MNEMONICO CAMBIO" % (g, inicio))
                    print("        antes: %s %s" % (mn, op))
                    print("        ahora: %s %s" % (nmn, nop))
                    avisos += 1
                continue
            print("  [ok] %-16s $%06X  %s %s   (solo cambiaron los operandos)"
                  % (g, inicio, nmn, nop))

    print()
    if problemas:
        print("!! %d PROBLEMA(S) grave(s)" % problemas)
    if avisos:
        print("!! %d AVISO(S): el mnemonico cambio sin estar previsto" % avisos)
    if not problemas and not avisos:
        print("OK: todo correcto.")
    return 1 if (problemas or avisos) else 0


if __name__ == "__main__":
    sys.exit(main())
