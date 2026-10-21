# -*- coding: utf-8 -*-
"""
Construye TODAS las ROMs del proyecto a partir de las recetas.

  datos/recetas.json      -> que ROMs se construyen y con que grupos
  datos/parches.json      -> los bytes de cada grupo (direccion -> valor)

Uso:
  python herramientas/desensamblado/construir_roms.py            # todas
  python herramientas/desensamblado/construir_roms.py --cambios   # solo las de un cambio
  python herramientas/desensamblado/construir_roms.py --limpiar   # borra rom/cambios y rom/combinaciones antes

Salida:
  rom/cambios/        una ROM por cambio, con SOLO ese cambio
  rom/combinaciones/  ROMs con varios cambios

Cada ROM se verifica: se relee y se comprueba byte a byte, y el checksum de
la cabecera se recalcula y se comprueba.
"""
import io, json, os, shutil, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.join(RAIZ, "herramientas", "desensamblado")
ROM = os.path.join(RAIZ, "rom")
BASE = os.path.join(ROM, "base", "yuyu_makyou_base.bin")
RECETAS = os.path.join(RAIZ, "datos", "recetas.json")
PARCHES = os.path.join(RAIZ, "datos", "parches.json")


def carga(ruta):
    with io.open(ruta, encoding="utf-8") as f:
        return json.load(f)


def checksum(d, ini=0x200):
    s = 0
    n = len(d)
    if (n - ini) & 1:
        n -= 1
    for o in range(ini, n, 2):
        s += (d[o] << 8) | d[o + 1]
    return s & 0xFFFF


def parchea(grupos, salida):
    """Aplica los grupos a la base y escribe la salida. Devuelve (ok, mensaje)."""
    cmd = [sys.executable, os.path.join(TOOLS, "patch_rom.py"), BASE, salida] + list(grupos)
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        return False, (r.stdout + r.stderr)
    return True, r.stdout


def verifica(salida, grupos, parches):
    """Relee la ROM y comprueba cada byte del manifiesto y el checksum."""
    d = open(salida, "rb").read()
    base = open(BASE, "rb").read()
    for g in grupos:
        for b in parches["patches"][g]["bytes"]:
            a = int(b["addr"], 16)
            viejo = int(b["old"], 16)
            nuevo = int(b["new"], 16)
            if d[a] != nuevo:
                return False, "  $%06X quedo en %02X, se pedia %02X" % (a, d[a], nuevo)
            if base[a] != viejo:
                return False, "  la base tiene %02X en $%06X, el manifiesto esperaba %02X" % (base[a], a, viejo)
    alm = (d[0x18E] << 8) | d[0x18F]
    cal = checksum(d)
    if alm != cal:
        return False, "  el checksum no cuadra: %04X != %04X" % (alm, cal)
    return True, "  ok, %d bytes, checksum $%04X" % (
        sum(1 for i in range(len(d)) if d[i] != base[i]), cal)


def main():
    args = sys.argv[1:]
    rec = carga(RECETAS)
    parches = carga(PARCHES)

    if "--limpiar" in args:
        for sub in ("cambios", "combinaciones"):
            d = os.path.join(ROM, sub)
            if os.path.isdir(d):
                shutil.rmtree(d)
                print("  borrado rom/%s" % sub)

    solo_cambios = "--cambios" in args
    solo_combi = "--combinaciones" in args

    print("=" * 78)
    print("CONSTRUYENDO LAS ROMs")
    print("=" * 78)
    print("base: %s" % os.path.relpath(BASE, RAIZ))
    print()

    for sub, clave in (("cambios", "cambios"), ("combinaciones", "combinaciones")):
        if solo_cambios and clave == "combinaciones":
            continue
        if solo_combi and clave == "cambios":
            continue
        destino = os.path.join(ROM, sub)
        os.makedirs(destino, exist_ok=True)
        print("--- rom/%s/" % sub)
        for r in rec[clave]:
            salida = os.path.join(destino, r["id"] + ".bin")
            ok, msg = parchea(r["grupos"], salida)
            if not ok:
                print("  [FALLO] %s" % r["id"])
                print(msg)
                continue
            ok2, msg2 = verifica(salida, r["grupos"], parches)
            marca = "OK  " if ok2 else "MAL"
            print("  [%s] %-32s %s" % (marca, r["id"], msg2.strip()))
            if not ok2:
                print(msg2)
        print()

    # ---------------------------------------------------- LA VERSION UNIFICADA
    # Se construye con la union de los cambios de la lista 'aceptados'. Cada
    # cambio nuevo que acepte entra en esa lista, y con esto se suma a la
    # unificada (que ademas se guarda suelto en rom/cambios/).
    print("--- rom/combinaciones/  (la version UNIFICADA)")
    print("    se construye con la union de los cambios de 'aceptados'")
    por_id = {c["id"]: c for c in rec["cambios"]}
    grupos_uni = []
    falta = []
    for cid in rec.get("aceptados", []):
        c = por_id.get(cid)
        if c is None:
            falta.append(cid)
            continue
        for g in c["grupos"]:
            if g not in grupos_uni:
                grupos_uni.append(g)
    if falta:
        print("  [FALLO] ids de 'aceptados' que no existen en 'cambios': %s" % ", ".join(falta))
    salida = os.path.join(ROM, "combinaciones", "yuyu_makyou_UNIFICADA.bin")
    ok, msg = parchea(grupos_uni, salida)
    if not ok:
        print("  [FALLO] yuyu_makyou_UNIFICADA.bin")
        print(msg)
    else:
        ok2, msg2 = verifica(salida, grupos_uni, parches)
        print("  [%s] %-32s %s" % ("OK  " if ok2 else "MAL",
                                   "yuyu_makyou_UNIFICADA.bin", msg2.strip()))
        print("      grupos: %s" % ", ".join(grupos_uni))
        print("      cambios: %s" % ", ".join(rec.get("aceptados", [])))
    print()

    # un indice legible de lo que se ha construido
    with io.open(os.path.join(RAIZ, "rom", "LEEME.md"), "w", encoding="utf-8", newline="") as f:
        f.write("# Las ROMs\n\n")
        f.write("`base/` la ROM original reparada (con el checksum al dia).\n\n")
        f.write("`cambios/` **una ROM por cambio**, cada una con SOLO ese cambio\n")
        f.write("sobre la base. Son las piezas.\n\n")
        f.write("`combinaciones/` ROMs con varios cambios a la vez. La principal es\n")
        f.write("**`yuyu_makyou_UNIFICADA.bin`**: lleva todos los cambios de la lista\n")
        f.write("`aceptados` de `datos/recetas.json`.\n\n")
        f.write("`fuentes/` los dumps de referencia.\n\n")
        f.write("Todo se reconstruye con:\n\n```powershell\n")
        f.write("python herramientas\\desensamblado\\construir_roms.py\n```\n\n")
        f.write("## El flujo\n\n")
        f.write("1. Se hace un cambio: su grupo se anade a `datos/parches.json`.\n")
        f.write("2. Su id se anade a la lista `aceptados` de `datos/recetas.json`.\n")
        f.write("3. `python herramientas\\desensamblado\\construir_roms.py`\n\n")
        f.write("Con eso el cambio aparece **(a)** en su propia ROM de `cambios/` y\n")
        f.write("**(b)** sumado a la version unificada de `combinaciones/`.\n\n")
        f.write("## La version unificada ahora\n\n")
        f.write("Lleva estos cambios:\n\n")
        for cid in rec.get("aceptados", []):
            c = por_id.get(cid)
            if c:
                f.write("- **%s**: %s\n" % (c["titulo"], c["que_hace"]))
        f.write("\n## Los cambios, uno a uno\n\n")
        f.write("| Fichero | Qué hace | Grupos |\n|---|---|---|\n")
        for r in rec["cambios"]:
            f.write("| `cambios/%s.bin` | %s | `%s` |\n"
                    % (r["id"], r["que_hace"], "`, `".join(r["grupos"])))
        f.write("\n## Las combinaciones\n\n")
        f.write("| Fichero | Qué hace | Grupos |\n|---|---|---|\n")
        f.write("| `combinaciones/yuyu_makyou_UNIFICADA.bin` | **la version unificada**: la union de `aceptados` | (automatico) |\n")
        for r in rec["combinaciones"]:
            f.write("| `combinaciones/%s.bin` | %s | `%s` |\n"
                    % (r["id"], r["que_hace"], "`, `".join(r["grupos"])))
        f.write("\n## Para aplicar una combinacion que no este aqui\n\n")
        f.write("```powershell\npython herramientas\\desensamblado\\patch_rom.py `\n")
        f.write("    rom\\base\\yuyu_makyou_base.bin <salida.bin> <grupos...>\n```\n")
        f.write("\nEl checksum de la cabecera se reescribe SIEMPRE al final: el juego lo\n")
        f.write("verifica al arrancar (`0x4318`) y sin recalcularlo se queda clavado en\n")
        f.write("el logo SEGA.\n")
    print("  escrito rom/LEEME.md")


if __name__ == "__main__":
    main()
