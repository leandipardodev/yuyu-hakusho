"""Prueba una lista curada de opcodes M68000 reales del juego para detectar
cuales NO implementa el core de Unicorn 2.1.4. Se ejecuta cada caso en un
subproceso para sobrevivir a los que crashean el proceso."""
import os
import subprocess
import sys
import tempfile

PY = sys.executable

# El lanzador de un solo caso se genera aqui en un temporal. Antes apuntaba a
# un fichero suelto en el Temp de otra maquina, asi que el script no corria en
# ningun otro lado. Contrato de salida, el que lee el bucle de abajo:
#   "OK..."      -> Unicorn ejecuto la instruccion
#   "ERR21..."   -> Unicorn lanzo excepcion (codigo UC_ERR_EXCEPTION = 21)
LANZADOR = """import sys
from unicorn import *
from unicorn.m68k_const import *

code = bytes.fromhex(sys.argv[1])
uc = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
uc.mem_map(0x000000, 0x1000)
uc.mem_map(0xFF0000, 0x10000)
uc.mem_write(0x000200, code)
uc.reg_write(UC_M68K_REG_PC, 0x000200)
try:
    uc.emu_start(0x000200, 0x000200 + len(code))
    print("OK")
except UcError as e:
    print("ERR21 %s" % e)
"""


def _crear_lanzador():
    fd, ruta = tempfile.mkstemp(prefix="m68k_probe_", suffix=".py")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(LANZADOR)
    return ruta


T = _crear_lanzador()

CASES = {
    "NOP":              "4E71",
    "RTS":              "4E75",
    "RTE":              "4E73",
    "RTR":              "4E77",
    "JMP (An)":         "4ED0",
    "JSR (An)":         "4E90",
    "BRA":              "6000",
    "BSR":              "6100",
    "MOVEQ":            "7001",
    "JSR abs.L":        "4EB900001234",
    "LEA abs.L":        "41F900001234",
    "LEA (An),An":      "E789",
    "PEA abs.L":        "487900001234",
    "MOVE.W #imm,SR":   "46C02700",
    "MOVE.B #imm,CCR":  "44C00700",
    "ORI.W #imm,SR":    "007C0700",
    "ORI.B #imm,CCR":   "003C0700",
    "DBRA":             "51C8FFFE",
    "DBEQ":             "57C8FFFE",
    "ADDI.B":           "060001",
    "ADDI.W":           "06400100",
    "ADDI.L":           "068000010000",
    "SUBI.W":           "04400100",
    "SUBI.L":           "048000010000",
    "ANDI.B":           "020001",
    "ANDI.W":           "02400100",
    "ORI.B Dn":         "000001",
    "ORI.W Dn":         "00400100",
    "EORI.W":           "0A400100",
    "CMPI.W":           "0C400100",
    "CMPI.L":           "0C8000010000",
    "CMPI.B":           "0C0001",
    "ADDQ.W":           "52400100",
    "ADDQ.L":           "528001000000",
    "SUBQ.W":           "53400100",
    "SUBQ.L":           "538001000000",
    "ADD.W D1,D0":      "D041",
    "ADD.L D1,D0":      "D081",
    "SUB.W D1,D0":      "9041",
    "SUB.L D1,D0":      "9081",
    "MOVE.W D0,D1":     "3200",
    "MOVE.L D0,D1":     "2200",
    "MOVEA.W D0,A1":    "3208",
    "MOVE.W (A0),D0":   "3010",
    "MOVE.W (xxx).L,D0":"303900001234",
    "MOVE.L (xxx).L,D0":"203900001234",
    "CLR.B D0":         "4200",
    "CLR.W D0":         "4240",
    "CLR.L D0":         "4280",
    "TST.B D0":         "4A00",
    "TST.W D0":         "4A40",
    "TST.L D0":         "4A80",
    "NEG.W D0":         "4440",
    "NEG.L D0":         "4480",
    "NOT.W D0":         "4640",
    "NOT.L D0":         "4680",
    "SWAP D0":          "4840",
    "EXT.W D0":         "4880",
    "EXT.L D0":         "48C0",
    "MOVEM.L d0-d7/a0-a6,-(sp)": "48E7FFFE",
    "MOVEM.L (sp)+,d0-d7/a0-a6": "4CDF7FFE",
    "BTST #0,D0":       "0800",
    "BTST D1,D0":       "0280",
    "BCHG #1,D0":       "0840",
    "BCLR #2,D0":       "0880",
    "BSET #3,D0":       "08C0",
    "BTSET D1,D0":      "02C0",
    "ASL.W #1,D0":      "E380",
    "ASR.W D1,D0":      "E600",
    "LSL.W #1,D0":      "E388",
    "LSR.W #1,D0":      "E308",
    "ROL.W #1,D0":      "E398",
    "ROR.W #1,D0":      "E318",
    "ROXL.W #1,D0":     "E390",
    "MULS.W D1,D0":     "C141",
    "MULU.W D1,D0":     "C041",
    "DIVS.W D1,D0":     "C141",
    "DIVU.W D1,D0":     "C041",
    "AND.W D1,D0":      "C041",
    "OR.W D1,D0":       "C041",
    "EOR.W D1,D0":      "B041",
    "BCD D1,D0":        "C141",
    "LINK/UNLK":        "4E50",
    "STOP":             "4E72",
    "TRAP #0":          "4E40",
    "JMP abs.L":        "4EF900001234",
    "MOVE.L #imm,(xxx).L": "23FC0000000100FFFF0000",
    "MOVE.W D0,(xxx).L": "31C00000FFFF00",
}

bad = []
crash = []
for name, hexs in CASES.items():
    try:
        r = subprocess.run([PY, T, hexs], capture_output=True, text=True, timeout=25)
        out = (r.stdout or "").strip()
        if r.returncode != 0:
            crash.append((name, hexs))
        elif out.startswith("ERR21"):
            bad.append((name, hexs))
        elif not out.startswith("OK"):
            bad.append((name, hexs, out))
    except Exception:
        crash.append((name, hexs))

os.remove(T)

print("total probados: %d" % len(CASES))
print()
print("NO IMPLEMENTADOS (%d):" % len(bad))
for n, h, *rest in bad:
    print("   %-28s %-16s %s" % (n, h, rest[0] if rest else ""))
print()
print("CRASHEAN (%d):" % len(crash))
for n, h in crash:
    print("   %-28s %s" % (n, h))
