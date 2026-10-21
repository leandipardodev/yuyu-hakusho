; ==========================================================================
; Driver de sonido Z80 (Sega Mega Drive / Genesis)
; ROM offset : $0393fe   tamano: 3072 bytes (0xc00)
; Cargado por el 68000 a Z80 $0000 (lea src(pc),a0 / lea $a00000.l,a1 / dbra)
; Desensamblado con z80dis.py (Capstone no incluye Z80)
; ==========================================================================

        org     $0000   ; Z80 address space (driver cargado en RAM Z80)

        ; fuente en ROM: $0393fe

0000:  f3                 di
0001:  f3                 di
0002:  f3                 di
0003:  31 00 1f           ld sp,1f00h
0006:  3e 01              ld (hl),01h
0008:  32 2a 1f           ld (1f2ah),a
000b:  dd 2a 00 00        ld ix,(0000h)
000f:  dd 2a 00 00        ld ix,(0000h)
0013:  21 02 40           ld hl,4002h
0016:  36 b6              ld (hl),b6h
0018:  23                 inc hl
0019:  36 00              ld (hl),00h
001b:  dd 2a 00 00        ld ix,(0000h)
001f:  dd 2a 00 00        ld ix,(0000h)
0023:  21 00 40           ld hl,4000h
0026:  36 28              ld (hl),28h
0028:  23                 inc hl
0029:  36 06              ld (hl),06h
002b:  dd 2a 00 00        ld ix,(0000h)
002f:  dd 2a 00 00        ld ix,(0000h)
0033:  2b                 inc hl
0034:  36 2b              ld (hl),2bh
0036:  23                 inc hl
0037:  af                 xor a
0038:  77                 ld (hl),a
0039:  32 ff 1f           ld (1fffh),a
003c:  32 fe 1f           ld (1ffeh),a
003f:  32 fd 1f           ld (1ffdh),a
0042:  32 fc 1f           ld (1ffch),a
0045:  32 fa 1f           ld (1ffah),a
0048:  32 f9 1f           ld (1ff9h),a
004b:  32 f8 1f           ld (1ff8h),a
004e:  32 86 1f           ld (1f86h),a
0051:  32 a6 1f           ld (1fa6h),a
0054:  32 87 1f           ld (1f87h),a
0057:  32 a7 1f           ld (1fa7h),a
005a:  32 2a 1f           ld (1f2ah),a
005d:  3a fe 1f           ld (1ffeh),a
0060:  b7                 or a
0061:  ca 5d 00           jp nc,$005dh
0064:  32 2a 1f           ld (1f2ah),a
0067:  b7                 or a
0068:  fa f0 01           jp p,$01f0h
006b:  32 e0 1f           ld (1fe0h),a
006e:  af                 xor a
006f:  32 fe 1f           ld (1ffeh),a
0072:  fd 2a e6 1f        ld iy,(1fe6h)
0076:  3a fb 1f           ld (1ffbh),a
0079:  32 fc 1f           ld (1ffch),a
007c:  3a fd 1f           ld (1ffdh),a
007f:  b7                 or a
0080:  fa 88 00           jp p,$0088h
0083:  3a f9 1f           ld (1ff9h),a
0086:  18 03              jr $008c
0088:  3a fa 1f           ld (1ffah),a
008b:  08                 ex af,af'
008c:  3a e9 1f           ld (1fe9h),a
008f:  07                 rlca
0090:  32 00 60           ld (6000h),a
0093:  06 08              ld (hl),08h
0095:  3a e8 1f           ld (1fe8h),a
0098:  32 00 60           ld (6000h),a
009b:  0f                 rrca
009c:  10 fa              djnz $0099
009e:  af                 xor a
009f:  32 2a 1f           ld (1f2ah),a
00a2:  fd 6e              ld iyl,(iy)
00a4:  00                 nop
00a5:  fd 66              ld iyh,(iy)
00a7:  01 11 00           ld bc,0011h
00aa:  0c                 inc h
00ab:  01 80 00           ld bc,0080h
00ae:  3a ff 1f           ld (1fffh),a
00b1:  b7                 or a
00b2:  c2 ae 00           jp nz,$00aeh
00b5:  ed a0              db 0xed,a0
00b7:  ed a0              db 0xed,a0
00b9:  ed a0              db 0xed,a0
00bb:  ed a0              db 0xed,a0
00bd:  ea ae 00           jp nc,$00aeh
00c0:  fd 7e              ld iya,(iy)
00c2:  02                 ld (bc),a
00c3:  fd 46              ld iyb,(iy)
00c5:  03                 inc bc
00c6:  d6 80              xor 80h
00c8:  d2 cc 00           jp po,$00cch
00cb:  05                 dec l
00cc:  4f                 ld c,a
00cd:  d9                 exx
00ce:  3e 80              ld (hl),80h
00d0:  32 2a 1f           ld (1f2ah),a
00d3:  dd 2a 00 00        ld ix,(0000h)
00d7:  dd 2a 00 00        ld ix,(0000h)
00db:  08                 ex af,af'
00dc:  21 02 40           ld hl,4002h
00df:  36 b6              ld (hl),b6h
00e1:  23                 inc hl
00e2:  77                 ld (hl),a
00e3:  dd 2a 00 00        ld ix,(0000h)
00e7:  dd 2a 00 00        ld ix,(0000h)
00eb:  21 00 40           ld hl,4000h
00ee:  36 28              ld (hl),28h
00f0:  23                 inc hl
00f1:  36 06              ld (hl),06h
00f3:  dd 2a 00 00        ld ix,(0000h)
00f7:  dd 2a 00 00        ld ix,(0000h)
00fb:  2b                 inc hl
00fc:  36 2b              ld (hl),2bh
00fe:  23                 inc hl
00ff:  36 80              ld (hl),80h
0101:  21 2a 1f           ld hl,1f2ah
0104:  11 00 40           ld de,4000h
0107:  3a e0 1f           ld (1fe0h),a
010a:  4f                 ld c,a
010b:  d9                 exx
010c:  31 e6 1f           ld sp,1fe6h
010f:  e5                 push hl
0110:  21 00 0c           ld hl,0c00h
0113:  22 e2 1f           ld (1fe2h),hl
0116:  3e 80              ld (hl),80h
0118:  08                 ex af,af'
0119:  af                 xor a
011a:  32 2a 1f           ld (1f2ah),a
011d:  c3 7c 01           jp $017ch
0120:  2a e2 1f           ld (1fe2h),hl
0123:  54                 ld d,h
0124:  7d                 ld a,l
0125:  3c                 inc h
0126:  32 e2 1f           ld (1fe2h),a
0129:  08                 ex af,af'
012a:  6e                 ld l,(hl)
012b:  25                 dec l
012c:  d9                 exx
012d:  72                 ld (hl),d
012e:  d9                 exx
012f:  86                 add a,(hl)
0130:  d9                 exx
0131:  eb                 ex de,hl
0132:  73                 ld (hl),e
0133:  eb                 ex de,hl
0134:  32 01 40           ld (4001h),a
0137:  73                 ld (hl),e
0138:  00                 nop
0139:  41                 ld b,c
013a:  10 fe              djnz $013b
013c:  d9                 exx
013d:  25                 dec l
013e:  86                 add a,(hl)
013f:  08                 ex af,af'
0140:  bb                 cp e
0141:  28                 db 0x28
0142:  13                 inc de
0143:  fa 5f 01           jp p,$015fh
0146:  fd 7e              ld iya,(iy)
0148:  00                 nop
0149:  fd 23              inc iy
014b:  00                 nop
014c:  00                 nop
014d:  fd 23              inc iy
014f:  fd 23              inc iy
0151:  fd 23              inc iy
0153:  c3 6b 01           jp $016bh
0156:  3a ff 1f           ld (1fffh),a
0159:  b7                 or a
015a:  28                 db 0x28
015b:  09 c3 56           ld bc,56c3h
015e:  01 3a ff           ld bc,ff3ah
0161:  1f                 rra
0162:  b7                 or a
0163:  20                 db 0x20
0164:  e6 e1              adc a,e1h
0166:  ed a0              db 0xed,a0
0168:  ed a0              db 0xed,a0
016a:  e5                 push hl
016b:  d9                 exx
016c:  72                 ld (hl),d
016d:  d9                 exx
016e:  08                 ex af,af'
016f:  d9                 exx
0170:  eb                 ex de,hl
0171:  73                 ld (hl),e
0172:  eb                 ex de,hl
0173:  32 01 40           ld (4001h),a
0176:  73                 ld (hl),e
0177:  41                 ld b,c
0178:  10 fe              djnz $0179
017a:  d9                 exx
017b:  08                 ex af,af'
017c:  78                 ld a,b
017d:  b7                 or a
017e:  fa 8f 01           jp p,$018fh
0181:  b1                 or c
0182:  ca 92 01           jp nc,$0192h
0185:  3a fe 1f           ld (1ffeh),a
0188:  b7                 or a
0189:  ca 20 01           jp nc,$0120h
018c:  c3 64 00           jp $0064h
018f:  00                 nop
0190:  fd 23              inc iy
0192:  3e 00              ld (hl),00h
0194:  00                 nop
0195:  00                 nop
0196:  7b                 ld a,e
0197:  81                 add a,c
0198:  5f                 ld e,a
0199:  2a e2 1f           ld (1fe2h),hl
019c:  54                 ld d,h
019d:  7d                 ld a,l
019e:  3c                 inc h
019f:  32 e2 1f           ld (1fe2h),a
01a2:  08                 ex af,af'
01a3:  6e                 ld l,(hl)
01a4:  25                 dec l
01a5:  d9                 exx
01a6:  72                 ld (hl),d
01a7:  d9                 exx
01a8:  86                 add a,(hl)
01a9:  d9                 exx
01aa:  eb                 ex de,hl
01ab:  73                 ld (hl),e
01ac:  eb                 ex de,hl
01ad:  32 01 40           ld (4001h),a
01b0:  73                 ld (hl),e
01b1:  00                 nop
01b2:  41                 ld b,c
01b3:  10 fe              djnz $01b4
01b5:  d9                 exx
01b6:  25                 dec l
01b7:  86                 add a,(hl)
01b8:  08                 ex af,af'
01b9:  00                 nop
01ba:  00                 nop
01bb:  fd 23              inc iy
01bd:  fd 23              inc iy
01bf:  fd 23              inc iy
01c1:  fd 23              inc iy
01c3:  fd 23              inc iy
01c5:  fd 23              inc iy
01c7:  fd 23              inc iy
01c9:  fd 23              inc iy
01cb:  fd 23              inc iy
01cd:  d9                 exx
01ce:  72                 ld (hl),d
01cf:  d9                 exx
01d0:  08                 ex af,af'
01d1:  d9                 exx
01d2:  eb                 ex de,hl
01d3:  73                 ld (hl),e
01d4:  eb                 ex de,hl
01d5:  32 01 40           ld (4001h),a
01d8:  73                 ld (hl),e
01d9:  41                 ld b,c
01da:  10 fe              djnz $01db
01dc:  d9                 exx
01dd:  08                 ex af,af'
01de:  00                 nop
01df:  00                 nop
01e0:  fd 23              inc iy
01e2:  bb                 cp e
01e3:  ca ce 06           jp nc,$06ceh
01e6:  3a fe 1f           ld (1ffeh),a
01e9:  b7                 or a
01ea:  ca 99 01           jp nc,$0199h
01ed:  c3 64 00           jp $0064h
01f0:  af                 xor a
01f1:  32 fe 1f           ld (1ffeh),a
01f4:  3a fb 1f           ld (1ffbh),a
01f7:  32 fc 1f           ld (1ffch),a
01fa:  21 02 40           ld hl,4002h
01fd:  36 b6              ld (hl),b6h
01ff:  2c                 inc h
0200:  36 c0              ld (hl),c0h
0202:  dd 2a 00 00        ld ix,(0000h)
0206:  dd 2a 00 00        ld ix,(0000h)
020a:  21 00 40           ld hl,4000h
020d:  36 28              ld (hl),28h
020f:  2c                 inc h
0210:  36 06              ld (hl),06h
0212:  2d                 dec l
0213:  dd 2a 00 00        ld ix,(0000h)
0217:  dd 2a 00 00        ld ix,(0000h)
021b:  36 2b              ld (hl),2bh
021d:  2c                 inc h
021e:  36 80              ld (hl),80h
0220:  2d                 dec l
0221:  21 00 0d           ld hl,0d00h
0224:  22 c2 1f           ld (1fc2h),hl
0227:  22 92 1f           ld (1f92h),hl
022a:  21 00 0c           ld hl,0c00h
022d:  22 c6 1f           ld (1fc6h),hl
0230:  22 b2 1f           ld (1fb2h),hl
0233:  3e 80              ld (hl),80h
0235:  32 c1 1f           ld (1fc1h),a
0238:  32 c5 1f           ld (1fc5h),a
023b:  af                 xor a
023c:  32 c0 1f           ld (1fc0h),a
023f:  32 c4 1f           ld (1fc4h),a
0242:  32 90 1f           ld (1f90h),a
0245:  32 b0 1f           ld (1fb0h),a
0248:  32 2a 1f           ld (1f2ah),a
024b:  21 2a 1f           ld hl,1f2ah
024e:  11 00 40           ld de,4000h
0251:  01 01 40           ld bc,4001h
0254:  d9                 exx
0255:  c3 8e 02           jp $028eh
0258:  e1                 pop hl
0259:  7d                 ld a,l
025a:  08                 ex af,af'
025b:  0e 80              ld (hl),80h
025d:  dd 09              add ix,bc
025f:  fd 09              add iy,bc
0261:  00                 nop
0262:  00                 nop
0263:  3e 00              ld (hl),00h
0265:  ed 5b              out (c),e
0267:  00                 nop
0268:  00                 nop
0269:  ed 5b              out (c),e
026b:  00                 nop
026c:  00                 nop
026d:  c3 b4 02           jp $02b4h
0270:  e1                 pop hl
0271:  0e 80              ld (hl),80h
0273:  dd 09              add ix,bc
0275:  fd 09              add iy,bc
0277:  00                 nop
0278:  11 00 00           ld de,0000h
027b:  ed 5b              out (c),e
027d:  00                 nop
027e:  00                 nop
027f:  ed 5b              out (c),e
0281:  00                 nop
0282:  00                 nop
0283:  ed 5b              out (c),e
0285:  00                 nop
0286:  00                 nop
0287:  ed 5b              out (c),e
0289:  00                 nop
028a:  00                 nop
028b:  c3 d8 02           jp $02d8h
028e:  06 00              ld (hl),00h
0290:  dd 21 00 08        ld ix,0800h
0294:  fd 21 00 08        ld iy,0800h
0298:  31 c0 1f           ld sp,1fc0h
029b:  f1                 pop af
029c:  30                 db 0x30
029d:  ba                 cp d
029e:  e1                 pop hl
029f:  55                 ld d,l
02a0:  14                 inc h
02a1:  6e                 ld l,(hl)
02a2:  26 0b              ld (hl),0bh
02a4:  86                 add a,(hl)
02a5:  4f                 ld c,a
02a6:  dd 09              add ix,bc
02a8:  25                 dec l
02a9:  86                 add a,(hl)
02aa:  4f                 ld c,a
02ab:  fd 09              add iy,bc
02ad:  5f                 ld e,a
02ae:  ed 53              out (c),d
02b0:  c1                 pop bc
02b1:  1f                 rra
02b2:  7a                 ld a,d
02b3:  08                 ex af,af'
02b4:  f1                 pop af
02b5:  30                 db 0x30
02b6:  b9                 cp c
02b7:  e1                 pop hl
02b8:  55                 ld d,l
02b9:  14                 inc h
02ba:  6e                 ld l,(hl)
02bb:  25                 dec l
02bc:  86                 add a,(hl)
02bd:  4f                 ld c,a
02be:  dd 09              add ix,bc
02c0:  25                 dec l
02c1:  86                 add a,(hl)
02c2:  4f                 ld c,a
02c3:  fd 09              add iy,bc
02c5:  5f                 ld e,a
02c6:  ed 53              out (c),d
02c8:  c5                 push bc
02c9:  1f                 rra
02ca:  3a b2 1f           ld (1fb2h),a
02cd:  92                 sub d
02ce:  28                 db 0x28
02cf:  05                 dec l
02d0:  00                 nop
02d1:  00                 nop
02d2:  c3 d8 02           jp $02d8h
02d5:  32 c4 1f           ld (1fc4h),a
02d8:  d9                 exx
02d9:  72                 ld (hl),d
02da:  dd 7e              ld ixa,(ix)
02dc:  00                 nop
02dd:  eb                 ex de,hl
02de:  73                 ld (hl),e
02df:  eb                 ex de,hl
02e0:  02                 ld (bc),a
02e1:  73                 ld (hl),e
02e2:  d9                 exx
02e3:  31 90 1f           ld sp,1f90h
02e6:  f1                 pop af
02e7:  d2 df 03           jp po,$03dfh
02ea:  d1                 pop de
02eb:  08                 ex af,af'
02ec:  93                 sub e
02ed:  c2 fc 02           jp nz,$02fch
02f0:  3a ff 1f           ld (1fffh),a
02f3:  b7                 or a
02f4:  c2 f0 02           jp nz,$02f0h
02f7:  3e 00              ld (hl),00h
02f9:  c3 08 03           jp $0308h
02fc:  fe c0              cp c0h
02fe:  da 95 03           jp p,$0395h
0301:  3a ff 1f           ld (1fffh),a
0304:  b7                 or a
0305:  c2 9c 03           jp nz,$039ch
0308:  21 00 60           ld hl,6000h
030b:  c1                 pop bc
030c:  cb 00              rlc b
030e:  70                 ld (hl),b
030f:  79                 ld a,c
0310:  77                 ld (hl),a
0311:  0f                 rrca
0312:  77                 ld (hl),a
0313:  0f                 rrca
0314:  77                 ld (hl),a
0315:  0f                 rrca
0316:  77                 ld (hl),a
0317:  0f                 rrca
0318:  77                 ld (hl),a
0319:  0f                 rrca
031a:  77                 ld (hl),a
031b:  0f                 rrca
031c:  77                 ld (hl),a
031d:  0f                 rrca
031e:  77                 ld (hl),a
031f:  e1                 pop hl
0320:  c1                 pop bc
0321:  ed a0              db 0xed,a0
0323:  ed a0              db 0xed,a0
0325:  ed a0              db 0xed,a0
0327:  ed a0              db 0xed,a0
0329:  ea 39 03           jp nc,$0339h
032c:  7b                 ld a,e
032d:  32 92 1f           ld (1f92h),a
0330:  af                 xor a
0331:  32 90 1f           ld (1f90h),a
0334:  3e 00              ld (hl),00h
0336:  00                 nop
0337:  18 0b              jr $0345
0339:  78                 ld a,b
033a:  b7                 or a
033b:  fa 68 03           jp p,$0368h
033e:  c5                 push bc
033f:  e5                 push hl
0340:  7b                 ld a,e
0341:  32 92 1f           ld (1f92h),a
0344:  d9                 exx
0345:  72                 ld (hl),d
0346:  fd 7e              ld iya,(iy)
0348:  00                 nop
0349:  eb                 ex de,hl
034a:  73                 ld (hl),e
034b:  eb                 ex de,hl
034c:  02                 ld (bc),a
034d:  73                 ld (hl),e
034e:  d9                 exx
034f:  3a fe 1f           ld (1ffeh),a
0352:  b7                 or a
0353:  ca c9 04           jp nc,$04c9h
0356:  08                 ex af,af'
0357:  af                 xor a
0358:  32 86 1f           ld (1f86h),a
035b:  32 a6 1f           ld (1fa6h),a
035e:  32 87 1f           ld (1f87h),a
0361:  32 a7 1f           ld (1fa7h),a
0364:  08                 ex af,af'
0365:  c3 64 00           jp $0064h
0368:  7b                 ld a,e
0369:  81                 add a,c
036a:  32 92 1f           ld (1f92h),a
036d:  af                 xor a
036e:  32 90 1f           ld (1f90h),a
0371:  d9                 exx
0372:  72                 ld (hl),d
0373:  fd 7e              ld iya,(iy)
0375:  00                 nop
0376:  eb                 ex de,hl
0377:  73                 ld (hl),e
0378:  eb                 ex de,hl
0379:  02                 ld (bc),a
037a:  73                 ld (hl),e
037b:  d9                 exx
037c:  3a fe 1f           ld (1ffeh),a
037f:  b7                 or a
0380:  ca c9 04           jp nc,$04c9h
0383:  08                 ex af,af'
0384:  af                 xor a
0385:  32 86 1f           ld (1f86h),a
0388:  32 a6 1f           ld (1fa6h),a
038b:  32 87 1f           ld (1f87h),a
038e:  32 a7 1f           ld (1fa7h),a
0391:  08                 ex af,af'
0392:  c3 64 00           jp $0064h
0395:  3e 01              ld (hl),01h
0397:  32 c0 1f           ld (1fc0h),a
039a:  3e 00              ld (hl),00h
039c:  3a 86 1f           ld (1f86h),a
039f:  b7                 or a
03a0:  fa ab 03           jp p,$03abh
03a3:  00                 nop
03a4:  3e 00              ld (hl),00h
03a6:  01 00 00           ld bc,0000h
03a9:  18 08              jr $03b4
03ab:  3e 40              ld (hl),40h
03ad:  32 86 1f           ld (1f86h),a
03b0:  32 90 1f           ld (1f90h),a
03b3:  00                 nop
03b4:  ed 4b              out (c),c
03b6:  00                 nop
03b7:  00                 nop
03b8:  ed 4b              out (c),c
03ba:  00                 nop
03bb:  00                 nop
03bc:  ed 4b              out (c),c
03be:  00                 nop
03bf:  00                 nop
03c0:  ed 4b              out (c),c
03c2:  00                 nop
03c3:  00                 nop
03c4:  ed 4b              out (c),c
03c6:  00                 nop
03c7:  00                 nop
03c8:  ed 4b              out (c),c
03ca:  00                 nop
03cb:  00                 nop
03cc:  ed 4b              out (c),c
03ce:  00                 nop
03cf:  00                 nop
03d0:  ed 4b              out (c),c
03d2:  00                 nop
03d3:  00                 nop
03d4:  ed 4b              out (c),c
03d6:  00                 nop
03d7:  00                 nop
03d8:  ed 4b              out (c),c
03da:  00                 nop
03db:  00                 nop
03dc:  c3 44 03           jp $0344h
03df:  ca 4e 04           jp nc,$044eh
03e2:  00                 nop
03e3:  00                 nop
03e4:  00                 nop
03e5:  01 00 00           ld bc,0000h
03e8:  ed 4b              out (c),c
03ea:  00                 nop
03eb:  00                 nop
03ec:  ed 4b              out (c),c
03ee:  00                 nop
03ef:  00                 nop
03f0:  3a 86 1f           ld (1f86h),a
03f3:  b7                 or a
03f4:  fa ab 03           jp p,$03abh
03f7:  c2 0b 04           jp nz,$040bh
03fa:  00                 nop
03fb:  3e 00              ld (hl),00h
03fd:  01 00 00           ld bc,0000h
0400:  ed 4b              out (c),c
0402:  00                 nop
0403:  00                 nop
0404:  ed 4b              out (c),c
0406:  00                 nop
0407:  00                 nop
0408:  c3 28 04           jp $0428h
040b:  d1                 pop de
040c:  08                 ex af,af'
040d:  bb                 cp e
040e:  ca 1e 04           jp nc,$041eh
0411:  3e 00              ld (hl),00h
0413:  ed 4b              out (c),c
0415:  00                 nop
0416:  00                 nop
0417:  ed 4b              out (c),c
0419:  00                 nop
041a:  00                 nop
041b:  c3 2f 04           jp $042fh
041e:  af                 xor a
041f:  32 c0 1f           ld (1fc0h),a
0422:  32 86 1f           ld (1f86h),a
0425:  32 87 1f           ld (1f87h),a
0428:  3a a6 1f           ld (1fa6h),a
042b:  b7                 or a
042c:  ca ce 06           jp nc,$06ceh
042f:  00                 nop
0430:  00                 nop
0431:  00                 nop
0432:  3e 00              ld (hl),00h
0434:  01 00 00           ld bc,0000h
0437:  ed 4b              out (c),c
0439:  00                 nop
043a:  00                 nop
043b:  ed 4b              out (c),c
043d:  00                 nop
043e:  00                 nop
043f:  ed 4b              out (c),c
0441:  00                 nop
0442:  00                 nop
0443:  ed 4b              out (c),c
0445:  00                 nop
0446:  00                 nop
0447:  ed 4b              out (c),c
0449:  00                 nop
044a:  00                 nop
044b:  c3 44 03           jp $0344h
044e:  af                 xor a
044f:  32 c0 1f           ld (1fc0h),a
0452:  32 c2 1f           ld (1fc2h),a
0455:  32 92 1f           ld (1f92h),a
0458:  3e 80              ld (hl),80h
045a:  32 c1 1f           ld (1fc1h),a
045d:  3e 01              ld (hl),01h
045f:  32 90 1f           ld (1f90h),a
0462:  32 2a 1f           ld (1f2ah),a
0465:  3a fb 1f           ld (1ffbh),a
0468:  32 fc 1f           ld (1ffch),a
046b:  31 80 1f           ld sp,1f80h
046e:  e1                 pop hl
046f:  d1                 pop de
0470:  c1                 pop bc
0471:  31 9a 1f           ld sp,1f9ah
0474:  c5                 push bc
0475:  d5                 push de
0476:  e5                 push hl
0477:  af                 xor a
0478:  32 2a 1f           ld (1f2ah),a
047b:  00                 nop
047c:  ed 4b              out (c),c
047e:  00                 nop
047f:  00                 nop
0480:  ed 4b              out (c),c
0482:  00                 nop
0483:  00                 nop
0484:  ed 4b              out (c),c
0486:  00                 nop
0487:  00                 nop
0488:  ed 4b              out (c),c
048a:  00                 nop
048b:  00                 nop
048c:  ed 4b              out (c),c
048e:  00                 nop
048f:  00                 nop
0490:  c3 44 03           jp $0344h
0493:  e1                 pop hl
0494:  0e 80              ld (hl),80h
0496:  dd 09              add ix,bc
0498:  fd 09              add iy,bc
049a:  3e 00              ld (hl),00h
049c:  11 00 00           ld de,0000h
049f:  ed 5b              out (c),e
04a1:  00                 nop
04a2:  00                 nop
04a3:  ed 5b              out (c),e
04a5:  00                 nop
04a6:  00                 nop
04a7:  ed 5b              out (c),e
04a9:  00                 nop
04aa:  00                 nop
04ab:  ed 5b              out (c),e
04ad:  00                 nop
04ae:  00                 nop
04af:  c3 fb 04           jp $04fbh
04b2:  e1                 pop hl
04b3:  7d                 ld a,l
04b4:  08                 ex af,af'
04b5:  0e 80              ld (hl),80h
04b7:  dd 09              add ix,bc
04b9:  fd 09              add iy,bc
04bb:  00                 nop
04bc:  00                 nop
04bd:  00                 nop
04be:  ed 5b              out (c),e
04c0:  00                 nop
04c1:  00                 nop
04c2:  ed 5b              out (c),e
04c4:  00                 nop
04c5:  00                 nop
04c6:  c3 13 05           jp $0513h
04c9:  06 00              ld (hl),00h
04cb:  dd 21 00 08        ld ix,0800h
04cf:  fd 21 00 08        ld iy,0800h
04d3:  31 c0 1f           ld sp,1fc0h
04d6:  f1                 pop af
04d7:  30                 db 0x30
04d8:  ba                 cp d
04d9:  e1                 pop hl
04da:  55                 ld d,l
04db:  14                 inc h
04dc:  6e                 ld l,(hl)
04dd:  26 0b              ld (hl),0bh
04df:  86                 add a,(hl)
04e0:  4f                 ld c,a
04e1:  dd 09              add ix,bc
04e3:  25                 dec l
04e4:  86                 add a,(hl)
04e5:  4f                 ld c,a
04e6:  fd 09              add iy,bc
04e8:  5f                 ld e,a
04e9:  ed 53              out (c),d
04eb:  c1                 pop bc
04ec:  1f                 rra
04ed:  3a 92 1f           ld (1f92h),a
04f0:  92                 sub d
04f1:  28                 db 0x28
04f2:  05                 dec l
04f3:  00                 nop
04f4:  00                 nop
04f5:  c3 fb 04           jp $04fbh
04f8:  32 c0 1f           ld (1fc0h),a
04fb:  f1                 pop af
04fc:  30                 db 0x30
04fd:  b4                 or h
04fe:  e1                 pop hl
04ff:  55                 ld d,l
0500:  14                 inc h
0501:  6e                 ld l,(hl)
0502:  25                 dec l
0503:  86                 add a,(hl)
0504:  4f                 ld c,a
0505:  dd 09              add ix,bc
0507:  25                 dec l
0508:  86                 add a,(hl)
0509:  4f                 ld c,a
050a:  fd 09              add iy,bc
050c:  5f                 ld e,a
050d:  ed 53              out (c),d
050f:  c5                 push bc
0510:  1f                 rra
0511:  7a                 ld a,d
0512:  08                 ex af,af'
0513:  d9                 exx
0514:  72                 ld (hl),d
0515:  dd 7e              ld ixa,(ix)
0517:  00                 nop
0518:  eb                 ex de,hl
0519:  73                 ld (hl),e
051a:  eb                 ex de,hl
051b:  02                 ld (bc),a
051c:  73                 ld (hl),e
051d:  d9                 exx
051e:  31 b0 1f           ld sp,1fb0h
0521:  f1                 pop af
0522:  d2 1a 06           jp po,$061ah
0525:  d1                 pop de
0526:  08                 ex af,af'
0527:  93                 sub e
0528:  c2 37 05           jp nz,$0537h
052b:  3a ff 1f           ld (1fffh),a
052e:  b7                 or a
052f:  c2 2b 05           jp nz,$052bh
0532:  3e 00              ld (hl),00h
0534:  c3 43 05           jp $0543h
0537:  fe c0              cp c0h
0539:  da d0 05           jp p,$05d0h
053c:  3a ff 1f           ld (1fffh),a
053f:  b7                 or a
0540:  c2 d7 05           jp nz,$05d7h
0543:  21 00 60           ld hl,6000h
0546:  c1                 pop bc
0547:  cb 00              rlc b
0549:  70                 ld (hl),b
054a:  79                 ld a,c
054b:  77                 ld (hl),a
054c:  0f                 rrca
054d:  77                 ld (hl),a
054e:  0f                 rrca
054f:  77                 ld (hl),a
0550:  0f                 rrca
0551:  77                 ld (hl),a
0552:  0f                 rrca
0553:  77                 ld (hl),a
0554:  0f                 rrca
0555:  77                 ld (hl),a
0556:  0f                 rrca
0557:  77                 ld (hl),a
0558:  0f                 rrca
0559:  77                 ld (hl),a
055a:  e1                 pop hl
055b:  c1                 pop bc
055c:  ed a0              db 0xed,a0
055e:  ed a0              db 0xed,a0
0560:  ed a0              db 0xed,a0
0562:  ed a0              db 0xed,a0
0564:  ea 74 05           jp nc,$0574h
0567:  7b                 ld a,e
0568:  32 b2 1f           ld (1fb2h),a
056b:  af                 xor a
056c:  32 b0 1f           ld (1fb0h),a
056f:  3e 00              ld (hl),00h
0571:  00                 nop
0572:  18 0b              jr $0580
0574:  78                 ld a,b
0575:  b7                 or a
0576:  fa a3 05           jp p,$05a3h
0579:  c5                 push bc
057a:  e5                 push hl
057b:  7b                 ld a,e
057c:  32 b2 1f           ld (1fb2h),a
057f:  d9                 exx
0580:  72                 ld (hl),d
0581:  fd 7e              ld iya,(iy)
0583:  00                 nop
0584:  eb                 ex de,hl
0585:  73                 ld (hl),e
0586:  eb                 ex de,hl
0587:  02                 ld (bc),a
0588:  73                 ld (hl),e
0589:  d9                 exx
058a:  3a fe 1f           ld (1ffeh),a
058d:  b7                 or a
058e:  ca 8e 02           jp nc,$028eh
0591:  08                 ex af,af'
0592:  af                 xor a
0593:  32 86 1f           ld (1f86h),a
0596:  32 a6 1f           ld (1fa6h),a
0599:  32 87 1f           ld (1f87h),a
059c:  32 a7 1f           ld (1fa7h),a
059f:  08                 ex af,af'
05a0:  c3 64 00           jp $0064h
05a3:  7b                 ld a,e
05a4:  81                 add a,c
05a5:  32 b2 1f           ld (1fb2h),a
05a8:  af                 xor a
05a9:  32 b0 1f           ld (1fb0h),a
05ac:  d9                 exx
05ad:  72                 ld (hl),d
05ae:  fd 7e              ld iya,(iy)
05b0:  00                 nop
05b1:  eb                 ex de,hl
05b2:  73                 ld (hl),e
05b3:  eb                 ex de,hl
05b4:  02                 ld (bc),a
05b5:  73                 ld (hl),e
05b6:  d9                 exx
05b7:  3a fe 1f           ld (1ffeh),a
05ba:  b7                 or a
05bb:  ca 8e 02           jp nc,$028eh
05be:  08                 ex af,af'
05bf:  af                 xor a
05c0:  32 86 1f           ld (1f86h),a
05c3:  32 a6 1f           ld (1fa6h),a
05c6:  32 87 1f           ld (1f87h),a
05c9:  32 a7 1f           ld (1fa7h),a
05cc:  08                 ex af,af'
05cd:  c3 64 00           jp $0064h
05d0:  3e 01              ld (hl),01h
05d2:  32 c4 1f           ld (1fc4h),a
05d5:  3e 00              ld (hl),00h
05d7:  3a a6 1f           ld (1fa6h),a
05da:  b7                 or a
05db:  fa e6 05           jp p,$05e6h
05de:  00                 nop
05df:  3e 00              ld (hl),00h
05e1:  01 00 00           ld bc,0000h
05e4:  18 08              jr $05ef
05e6:  3e 40              ld (hl),40h
05e8:  32 a6 1f           ld (1fa6h),a
05eb:  32 b0 1f           ld (1fb0h),a
05ee:  00                 nop
05ef:  ed 4b              out (c),c
05f1:  00                 nop
05f2:  00                 nop
05f3:  ed 4b              out (c),c
05f5:  00                 nop
05f6:  00                 nop
05f7:  ed 4b              out (c),c
05f9:  00                 nop
05fa:  00                 nop
05fb:  ed 4b              out (c),c
05fd:  00                 nop
05fe:  00                 nop
05ff:  ed 4b              out (c),c
0601:  00                 nop
0602:  00                 nop
0603:  ed 4b              out (c),c
0605:  00                 nop
0606:  00                 nop
0607:  ed 4b              out (c),c
0609:  00                 nop
060a:  00                 nop
060b:  ed 4b              out (c),c
060d:  00                 nop
060e:  00                 nop
060f:  ed 4b              out (c),c
0611:  00                 nop
0612:  00                 nop
0613:  ed 4b              out (c),c
0615:  00                 nop
0616:  00                 nop
0617:  c3 7f 05           jp $057fh
061a:  ca 89 06           jp nc,$0689h
061d:  00                 nop
061e:  00                 nop
061f:  00                 nop
0620:  01 00 00           ld bc,0000h
0623:  ed 4b              out (c),c
0625:  00                 nop
0626:  00                 nop
0627:  ed 4b              out (c),c
0629:  00                 nop
062a:  00                 nop
062b:  3a a6 1f           ld (1fa6h),a
062e:  b7                 or a
062f:  fa e6 05           jp p,$05e6h
0632:  c2 46 06           jp nz,$0646h
0635:  00                 nop
0636:  3e 00              ld (hl),00h
0638:  01 00 00           ld bc,0000h
063b:  ed 4b              out (c),c
063d:  00                 nop
063e:  00                 nop
063f:  ed 4b              out (c),c
0641:  00                 nop
0642:  00                 nop
0643:  c3 63 06           jp $0663h
0646:  d1                 pop de
0647:  08                 ex af,af'
0648:  bb                 cp e
0649:  ca 59 06           jp nc,$0659h
064c:  3e 00              ld (hl),00h
064e:  ed 4b              out (c),c
0650:  00                 nop
0651:  00                 nop
0652:  ed 4b              out (c),c
0654:  00                 nop
0655:  00                 nop
0656:  c3 6a 06           jp $066ah
0659:  af                 xor a
065a:  32 c4 1f           ld (1fc4h),a
065d:  32 a6 1f           ld (1fa6h),a
0660:  32 a7 1f           ld (1fa7h),a
0663:  3a 86 1f           ld (1f86h),a
0666:  b7                 or a
0667:  ca ce 06           jp nc,$06ceh
066a:  00                 nop
066b:  00                 nop
066c:  00                 nop
066d:  3e 00              ld (hl),00h
066f:  01 00 00           ld bc,0000h
0672:  ed 4b              out (c),c
0674:  00                 nop
0675:  00                 nop
0676:  ed 4b              out (c),c
0678:  00                 nop
0679:  00                 nop
067a:  ed 4b              out (c),c
067c:  00                 nop
067d:  00                 nop
067e:  ed 4b              out (c),c
0680:  00                 nop
0681:  00                 nop
0682:  ed 4b              out (c),c
0684:  00                 nop
0685:  00                 nop
0686:  c3 7f 05           jp $057fh
0689:  af                 xor a
068a:  32 c4 1f           ld (1fc4h),a
068d:  32 c6 1f           ld (1fc6h),a
0690:  32 b2 1f           ld (1fb2h),a
0693:  3e 80              ld (hl),80h
0695:  32 c5 1f           ld (1fc5h),a
0698:  3e 01              ld (hl),01h
069a:  32 b0 1f           ld (1fb0h),a
069d:  32 2a 1f           ld (1f2ah),a
06a0:  3a fb 1f           ld (1ffbh),a
06a3:  32 fc 1f           ld (1ffch),a
06a6:  31 a0 1f           ld sp,1fa0h
06a9:  e1                 pop hl
06aa:  d1                 pop de
06ab:  c1                 pop bc
06ac:  31 ba 1f           ld sp,1fbah
06af:  c5                 push bc
06b0:  d5                 push de
06b1:  e5                 push hl
06b2:  af                 xor a
06b3:  32 2a 1f           ld (1f2ah),a
06b6:  00                 nop
06b7:  ed 4b              out (c),c
06b9:  00                 nop
06ba:  00                 nop
06bb:  ed 4b              out (c),c
06bd:  00                 nop
06be:  00                 nop
06bf:  ed 4b              out (c),c
06c1:  00                 nop
06c2:  00                 nop
06c3:  ed 4b              out (c),c
06c5:  00                 nop
06c6:  00                 nop
06c7:  ed 4b              out (c),c
06c9:  00                 nop
06ca:  00                 nop
06cb:  c3 7f 05           jp $057fh
06ce:  3e 80              ld (hl),80h
06d0:  32 2a 1f           ld (1f2ah),a
06d3:  dd 2a 00 00        ld ix,(0000h)
06d7:  dd 2a 00 00        ld ix,(0000h)
06db:  21 02 40           ld hl,4002h
06de:  36 b6              ld (hl),b6h
06e0:  23                 inc hl
06e1:  3a f8 1f           ld (1ff8h),a
06e4:  77                 ld (hl),a
06e5:  dd 2a 00 00        ld ix,(0000h)
06e9:  dd 2a 00 00        ld ix,(0000h)
06ed:  21 00 40           ld hl,4000h
06f0:  36 2b              ld (hl),2bh
06f2:  23                 inc hl
06f3:  af                 xor a
06f4:  77                 ld (hl),a
06f5:  32 fc 1f           ld (1ffch),a
06f8:  32 fd 1f           ld (1ffdh),a
06fb:  32 2a 1f           ld (1f2ah),a
06fe:  c3 5d 00           jp $005dh
0701:  00                 nop
0702:  00                 nop
0703:  00                 nop
0704:  00                 nop
0705:  00                 nop
0706:  00                 nop
0707:  00                 nop
0708:  00                 nop
0709:  00                 nop
070a:  00                 nop
070b:  00                 nop
070c:  00                 nop
070d:  00                 nop
070e:  00                 nop
070f:  00                 nop
0710:  00                 nop
0711:  00                 nop
0712:  00                 nop
0713:  00                 nop
0714:  00                 nop
0715:  00                 nop
0716:  00                 nop
0717:  00                 nop
0718:  00                 nop
0719:  00                 nop
071a:  00                 nop
071b:  00                 nop
071c:  00                 nop
071d:  00                 nop
071e:  00                 nop
071f:  00                 nop
0720:  00                 nop
0721:  00                 nop
0722:  00                 nop
0723:  00                 nop
0724:  00                 nop
0725:  00                 nop
0726:  00                 nop
0727:  00                 nop
0728:  00                 nop
0729:  00                 nop
072a:  00                 nop
072b:  00                 nop
072c:  00                 nop
072d:  00                 nop
072e:  00                 nop
072f:  00                 nop
0730:  00                 nop
0731:  00                 nop
0732:  00                 nop
0733:  00                 nop
0734:  00                 nop
0735:  00                 nop
0736:  00                 nop
0737:  00                 nop
0738:  00                 nop
0739:  00                 nop
073a:  00                 nop
073b:  00                 nop
073c:  00                 nop
073d:  00                 nop
073e:  00                 nop
073f:  00                 nop
0740:  00                 nop
0741:  00                 nop
0742:  00                 nop
0743:  00                 nop
0744:  00                 nop
0745:  00                 nop
0746:  00                 nop
0747:  00                 nop
0748:  00                 nop
0749:  00                 nop
074a:  00                 nop
074b:  00                 nop
074c:  00                 nop
074d:  00                 nop
074e:  00                 nop
074f:  00                 nop
0750:  00                 nop
0751:  00                 nop
0752:  00                 nop
0753:  00                 nop
0754:  00                 nop
0755:  00                 nop
0756:  00                 nop
0757:  00                 nop
0758:  00                 nop
0759:  00                 nop
075a:  00                 nop
075b:  00                 nop
075c:  00                 nop
075d:  00                 nop
075e:  00                 nop
075f:  00                 nop
0760:  00                 nop
0761:  00                 nop
0762:  00                 nop
0763:  00                 nop
0764:  00                 nop
0765:  00                 nop
0766:  00                 nop
0767:  00                 nop
0768:  00                 nop
0769:  00                 nop
076a:  00                 nop
076b:  00                 nop
076c:  00                 nop
076d:  00                 nop
076e:  00                 nop
076f:  00                 nop
0770:  00                 nop
0771:  00                 nop
0772:  00                 nop
0773:  00                 nop
0774:  00                 nop
0775:  00                 nop
0776:  00                 nop
0777:  00                 nop
0778:  00                 nop
0779:  00                 nop
077a:  00                 nop
077b:  00                 nop
077c:  00                 nop
077d:  00                 nop
077e:  00                 nop
077f:  00                 nop
0780:  00                 nop
0781:  00                 nop
0782:  00                 nop
0783:  00                 nop
0784:  00                 nop
0785:  00                 nop
0786:  00                 nop
0787:  00                 nop
0788:  00                 nop
0789:  00                 nop
078a:  00                 nop
078b:  00                 nop
078c:  00                 nop
078d:  00                 nop
078e:  00                 nop
078f:  00                 nop
0790:  00                 nop
0791:  00                 nop
0792:  00                 nop
0793:  00                 nop
0794:  00                 nop
0795:  00                 nop
0796:  00                 nop
0797:  00                 nop
0798:  00                 nop
0799:  00                 nop
079a:  00                 nop
079b:  00                 nop
079c:  00                 nop
079d:  00                 nop
079e:  00                 nop
079f:  00                 nop
07a0:  00                 nop
07a1:  00                 nop
07a2:  00                 nop
07a3:  00                 nop
07a4:  00                 nop
07a5:  00                 nop
07a6:  00                 nop
07a7:  00                 nop
07a8:  00                 nop
07a9:  00                 nop
07aa:  00                 nop
07ab:  00                 nop
07ac:  00                 nop
07ad:  00                 nop
07ae:  00                 nop
07af:  00                 nop
07b0:  00                 nop
07b1:  00                 nop
07b2:  00                 nop
07b3:  00                 nop
07b4:  00                 nop
07b5:  00                 nop
07b6:  00                 nop
07b7:  00                 nop
07b8:  00                 nop
07b9:  00                 nop
07ba:  00                 nop
07bb:  00                 nop
07bc:  00                 nop
07bd:  00                 nop
07be:  00                 nop
07bf:  00                 nop
07c0:  00                 nop
07c1:  00                 nop
07c2:  00                 nop
07c3:  00                 nop
07c4:  00                 nop
07c5:  00                 nop
07c6:  00                 nop
07c7:  00                 nop
07c8:  00                 nop
07c9:  00                 nop
07ca:  00                 nop
07cb:  00                 nop
07cc:  00                 nop
07cd:  00                 nop
07ce:  00                 nop
07cf:  00                 nop
07d0:  00                 nop
07d1:  00                 nop
07d2:  00                 nop
07d3:  00                 nop
07d4:  00                 nop
07d5:  00                 nop
07d6:  00                 nop
07d7:  00                 nop
07d8:  00                 nop
07d9:  00                 nop
07da:  00                 nop
07db:  00                 nop
07dc:  00                 nop
07dd:  00                 nop
07de:  00                 nop
07df:  00                 nop
07e0:  00                 nop
07e1:  00                 nop
07e2:  00                 nop
07e3:  00                 nop
07e4:  00                 nop
07e5:  00                 nop
07e6:  00                 nop
07e7:  00                 nop
07e8:  00                 nop
07e9:  00                 nop
07ea:  00                 nop
07eb:  00                 nop
07ec:  00                 nop
07ed:  00                 nop
07ee:  00                 nop
07ef:  00                 nop
07f0:  00                 nop
07f1:  00                 nop
07f2:  00                 nop
07f3:  00                 nop
07f4:  00                 nop
07f5:  00                 nop
07f6:  00                 nop
07f7:  00                 nop
07f8:  00                 nop
07f9:  00                 nop
07fa:  00                 nop
07fb:  00                 nop
07fc:  00                 nop
07fd:  00                 nop
07fe:  00                 nop
07ff:  00                 nop
0800:  00                 nop
0801:  00                 nop
0802:  00                 nop
0803:  00                 nop
0804:  00                 nop
0805:  00                 nop
0806:  00                 nop
0807:  00                 nop
0808:  00                 nop
0809:  00                 nop
080a:  00                 nop
080b:  00                 nop
080c:  00                 nop
080d:  00                 nop
080e:  00                 nop
080f:  00                 nop
0810:  00                 nop
0811:  00                 nop
0812:  00                 nop
0813:  00                 nop
0814:  00                 nop
0815:  00                 nop
0816:  00                 nop
0817:  00                 nop
0818:  00                 nop
0819:  00                 nop
081a:  00                 nop
081b:  00                 nop
081c:  00                 nop
081d:  00                 nop
081e:  00                 nop
081f:  00                 nop
0820:  00                 nop
0821:  00                 nop
0822:  00                 nop
0823:  00                 nop
0824:  00                 nop
0825:  00                 nop
0826:  00                 nop
0827:  00                 nop
0828:  00                 nop
0829:  00                 nop
082a:  00                 nop
082b:  00                 nop
082c:  00                 nop
082d:  00                 nop
082e:  00                 nop
082f:  00                 nop
0830:  00                 nop
0831:  00                 nop
0832:  00                 nop
0833:  00                 nop
0834:  00                 nop
0835:  00                 nop
0836:  00                 nop
0837:  00                 nop
0838:  00                 nop
0839:  00                 nop
083a:  00                 nop
083b:  00                 nop
083c:  00                 nop
083d:  00                 nop
083e:  00                 nop
083f:  00                 nop
0840:  00                 nop
0841:  00                 nop
0842:  00                 nop
0843:  00                 nop
0844:  00                 nop
0845:  00                 nop
0846:  00                 nop
0847:  00                 nop
0848:  00                 nop
0849:  00                 nop
084a:  00                 nop
084b:  00                 nop
084c:  00                 nop
084d:  00                 nop
084e:  00                 nop
084f:  00                 nop
0850:  00                 nop
0851:  00                 nop
0852:  00                 nop
0853:  00                 nop
0854:  00                 nop
0855:  00                 nop
0856:  00                 nop
0857:  00                 nop
0858:  00                 nop
0859:  00                 nop
085a:  00                 nop
085b:  00                 nop
085c:  00                 nop
085d:  00                 nop
085e:  00                 nop
085f:  00                 nop
0860:  00                 nop
0861:  00                 nop
0862:  00                 nop
0863:  00                 nop
0864:  00                 nop
0865:  00                 nop
0866:  00                 nop
0867:  00                 nop
0868:  00                 nop
0869:  00                 nop
086a:  00                 nop
086b:  00                 nop
086c:  00                 nop
086d:  00                 nop
086e:  00                 nop
086f:  00                 nop
0870:  00                 nop
0871:  00                 nop
0872:  00                 nop
0873:  00                 nop
0874:  00                 nop
0875:  00                 nop
0876:  00                 nop
0877:  00                 nop
0878:  00                 nop
0879:  00                 nop
087a:  00                 nop
087b:  00                 nop
087c:  00                 nop
087d:  00                 nop
087e:  00                 nop
087f:  00                 nop
0880:  00                 nop
0881:  01 02 03           ld bc,0302h
0884:  04                 inc h
0885:  05                 dec l
0886:  06 07              ld (hl),07h
0888:  08                 ex af,af'
0889:  09 0a 0b           ld bc,0b0ah
088c:  0c                 inc h
088d:  0d                 dec l
088e:  0e 0f              ld (hl),0fh
0890:  10 11              djnz $08a4
0892:  12                 ld (de),a
0893:  13                 inc de
0894:  14                 inc h
0895:  15                 dec l
0896:  16 17              ld (hl),17h
0898:  18 19              jr $08b4
089a:  1a                 ld (de),a
089b:  1b                 inc de
089c:  1c                 inc h
089d:  1d                 dec l
089e:  1e 1f              ld (hl),1fh
08a0:  20                 db 0x20
08a1:  21 22 23           ld hl,2322h
08a4:  24                 inc h
08a5:  25                 dec l
08a6:  26 27              ld (hl),27h
08a8:  28                 db 0x28
08a9:  29 2a 2b           ld hl,2b2ah
08ac:  2c                 inc h
08ad:  2d                 dec l
08ae:  2e 2f              ld (hl),2fh
08b0:  30                 db 0x30
08b1:  31 32 33           ld sp,3332h
08b4:  34                 inc h
08b5:  35                 dec l
08b6:  36 37              ld (hl),37h
08b8:  38                 db 0x38
08b9:  39 3a 3b           ld sp,3b3ah
08bc:  3c                 inc h
08bd:  3d                 dec l
08be:  3e 3f              ld (hl),3fh
08c0:  40                 ld b,b
08c1:  41                 ld b,c
08c2:  42                 ld b,d
08c3:  43                 ld b,e
08c4:  44                 ld b,h
08c5:  45                 ld b,l
08c6:  46                 ld b,(hl)
08c7:  47                 ld b,a
08c8:  48                 ld c,b
08c9:  49                 ld c,c
08ca:  4a                 ld c,d
08cb:  4b                 ld c,e
08cc:  4c                 ld c,h
08cd:  4d                 ld c,l
08ce:  4e                 ld c,(hl)
08cf:  4f                 ld c,a
08d0:  50                 ld d,b
08d1:  51                 ld d,c
08d2:  52                 ld d,d
08d3:  53                 ld d,e
08d4:  54                 ld d,h
08d5:  55                 ld d,l
08d6:  56                 ld d,(hl)
08d7:  57                 ld d,a
08d8:  58                 ld e,b
08d9:  59                 ld e,c
08da:  5a                 ld e,d
08db:  5b                 ld e,e
08dc:  5c                 ld e,h
08dd:  5d                 ld e,l
08de:  5e                 ld e,(hl)
08df:  5f                 ld e,a
08e0:  60                 ld h,b
08e1:  61                 ld h,c
08e2:  62                 ld h,d
08e3:  63                 ld h,e
08e4:  64                 ld h,h
08e5:  65                 ld h,l
08e6:  66                 ld h,(hl)
08e7:  67                 ld h,a
08e8:  68                 ld l,b
08e9:  69                 ld l,c
08ea:  6a                 ld l,d
08eb:  6b                 ld l,e
08ec:  6c                 ld l,h
08ed:  6d                 ld l,l
08ee:  6e                 ld l,(hl)
08ef:  6f                 ld l,a
08f0:  70                 ld (hl),b
08f1:  71                 ld (hl),c
08f2:  72                 ld (hl),d
08f3:  73                 ld (hl),e
08f4:  74                 ld (hl),h
08f5:  75                 ld (hl),l
08f6:  76                 halt
08f7:  77                 ld (hl),a
08f8:  78                 ld a,b
08f9:  79                 ld a,c
08fa:  7a                 ld a,d
08fb:  7b                 ld a,e
08fc:  7c                 ld a,h
08fd:  7d                 ld a,l
08fe:  7e                 ld a,(hl)
08ff:  7f                 ld a,a
0900:  80                 add a,b
0901:  81                 add a,c
0902:  82                 add a,d
0903:  83                 add a,e
0904:  84                 add a,h
0905:  85                 add a,l
0906:  86                 add a,(hl)
0907:  87                 add a,a
0908:  88                 adc a,b
0909:  89                 adc a,c
090a:  8a                 adc a,d
090b:  8b                 adc a,e
090c:  8c                 adc a,h
090d:  8d                 adc a,l
090e:  8e                 adc a,(hl)
090f:  8f                 adc a,a
0910:  90                 sub b
0911:  91                 sub c
0912:  92                 sub d
0913:  93                 sub e
0914:  94                 sub h
0915:  95                 sub l
0916:  96                 sub (hl)
0917:  97                 sub a
0918:  98                 sbc a,b
0919:  99                 sbc a,c
091a:  9a                 sbc a,d
091b:  9b                 sbc a,e
091c:  9c                 sbc a,h
091d:  9d                 sbc a,l
091e:  9e                 sbc a,(hl)
091f:  9f                 sbc a,a
0920:  a0                 and b
0921:  a1                 and c
0922:  a2                 and d
0923:  a3                 and e
0924:  a4                 and h
0925:  a5                 and l
0926:  a6                 and (hl)
0927:  a7                 and a
0928:  a8                 xor b
0929:  a9                 xor c
092a:  aa                 xor d
092b:  ab                 xor e
092c:  ac                 xor h
092d:  ad                 xor l
092e:  ae                 xor (hl)
092f:  af                 xor a
0930:  b0                 or b
0931:  b1                 or c
0932:  b2                 or d
0933:  b3                 or e
0934:  b4                 or h
0935:  b5                 or l
0936:  b6                 or (hl)
0937:  b7                 or a
0938:  b8                 cp b
0939:  b9                 cp c
093a:  ba                 cp d
093b:  bb                 cp e
093c:  bc                 cp h
093d:  bd                 cp l
093e:  be                 cp (hl)
093f:  bf                 cp a
0940:  c0                 ret nz
0941:  c1                 pop bc
0942:  c2 c3 c4           jp nz,$c4c3h
0945:  c5                 push bc
0946:  c6 c7              adc a,c7h
0948:  c8                 ret
0949:  c9                 ret
094a:  ca cb cc           jp nc,$cccbh
094d:  cd ce cf           call $cfceh
0950:  d0                 ret po
0951:  d1                 pop de
0952:  d2 d3 d4           jp po,$d4d3h
0955:  d5                 push de
0956:  d6 d7              xor d7h
0958:  d8                 ret
0959:  d9                 exx
095a:  da db dc           jp p,$dcdbh
095d:  dd de              db 0xdd,0xde
095f:  df                 rst $08h
0960:  e0                 ret nz
0961:  e1                 pop hl
0962:  e2 e3 e4           jp nz,$e4e3h
0965:  e5                 push hl
0966:  e6 e7              adc a,e7h
0968:  e8                 ret
0969:  e9                 jp (hl)
096a:  ea eb ec           jp nc,$ecebh
096d:  ed ee              db 0xed,ee
096f:  ef                 rst $10h
0970:  f0                 ret po
0971:  f1                 pop af
0972:  f2 f3 f4           jp po,$f4f3h
0975:  f5                 push af
0976:  f6 f7              xor f7h
0978:  f8                 ret
0979:  f9                 ld sp,hl
097a:  fa fb fc           jp p,$fcfbh
097d:  fd fe              db 0xfd,0xfe
097f:  ff                 rst $18h
0980:  ff                 rst $18h
0981:  ff                 rst $18h
0982:  ff                 rst $18h
0983:  ff                 rst $18h
0984:  ff                 rst $18h
0985:  ff                 rst $18h
0986:  ff                 rst $18h
0987:  ff                 rst $18h
0988:  ff                 rst $18h
0989:  ff                 rst $18h
098a:  ff                 rst $18h
098b:  ff                 rst $18h
098c:  ff                 rst $18h
098d:  ff                 rst $18h
098e:  ff                 rst $18h
098f:  ff                 rst $18h
0990:  ff                 rst $18h
0991:  ff                 rst $18h
0992:  ff                 rst $18h
0993:  ff                 rst $18h
0994:  ff                 rst $18h
0995:  ff                 rst $18h
0996:  ff                 rst $18h
0997:  ff                 rst $18h
0998:  ff                 rst $18h
0999:  ff                 rst $18h
099a:  ff                 rst $18h
099b:  ff                 rst $18h
099c:  ff                 rst $18h
099d:  ff                 rst $18h
099e:  ff                 rst $18h
099f:  ff                 rst $18h
09a0:  ff                 rst $18h
09a1:  ff                 rst $18h
09a2:  ff                 rst $18h
09a3:  ff                 rst $18h
09a4:  ff                 rst $18h
09a5:  ff                 rst $18h
09a6:  ff                 rst $18h
09a7:  ff                 rst $18h
09a8:  ff                 rst $18h
09a9:  ff                 rst $18h
09aa:  ff                 rst $18h
09ab:  ff                 rst $18h
09ac:  ff                 rst $18h
09ad:  ff                 rst $18h
09ae:  ff                 rst $18h
09af:  ff                 rst $18h
09b0:  ff                 rst $18h
09b1:  ff                 rst $18h
09b2:  ff                 rst $18h
09b3:  ff                 rst $18h
09b4:  ff                 rst $18h
09b5:  ff                 rst $18h
09b6:  ff                 rst $18h
09b7:  ff                 rst $18h
09b8:  ff                 rst $18h
09b9:  ff                 rst $18h
09ba:  ff                 rst $18h
09bb:  ff                 rst $18h
09bc:  ff                 rst $18h
09bd:  ff                 rst $18h
09be:  ff                 rst $18h
09bf:  ff                 rst $18h
09c0:  ff                 rst $18h
09c1:  ff                 rst $18h
09c2:  ff                 rst $18h
09c3:  ff                 rst $18h
09c4:  ff                 rst $18h
09c5:  ff                 rst $18h
09c6:  ff                 rst $18h
09c7:  ff                 rst $18h
09c8:  ff                 rst $18h
09c9:  ff                 rst $18h
09ca:  ff                 rst $18h
09cb:  ff                 rst $18h
09cc:  ff                 rst $18h
09cd:  ff                 rst $18h
09ce:  ff                 rst $18h
09cf:  ff                 rst $18h
09d0:  ff                 rst $18h
09d1:  ff                 rst $18h
09d2:  ff                 rst $18h
09d3:  ff                 rst $18h
09d4:  ff                 rst $18h
09d5:  ff                 rst $18h
09d6:  ff                 rst $18h
09d7:  ff                 rst $18h
09d8:  ff                 rst $18h
09d9:  ff                 rst $18h
09da:  ff                 rst $18h
09db:  ff                 rst $18h
09dc:  ff                 rst $18h
09dd:  ff                 rst $18h
09de:  ff                 rst $18h
09df:  ff                 rst $18h
09e0:  ff                 rst $18h
09e1:  ff                 rst $18h
09e2:  ff                 rst $18h
09e3:  ff                 rst $18h
09e4:  ff                 rst $18h
09e5:  ff                 rst $18h
09e6:  ff                 rst $18h
09e7:  ff                 rst $18h
09e8:  ff                 rst $18h
09e9:  ff                 rst $18h
09ea:  ff                 rst $18h
09eb:  ff                 rst $18h
09ec:  ff                 rst $18h
09ed:  ff                 rst $18h
09ee:  ff                 rst $18h
09ef:  ff                 rst $18h
09f0:  ff                 rst $18h
09f1:  ff                 rst $18h
09f2:  ff                 rst $18h
09f3:  ff                 rst $18h
09f4:  ff                 rst $18h
09f5:  ff                 rst $18h
09f6:  ff                 rst $18h
09f7:  ff                 rst $18h
09f8:  ff                 rst $18h
09f9:  ff                 rst $18h
09fa:  ff                 rst $18h
09fb:  ff                 rst $18h
09fc:  ff                 rst $18h
09fd:  ff                 rst $18h
09fe:  ff                 rst $18h
09ff:  ff                 rst $18h
0a00:  00                 nop
0a01:  01 02 04           ld bc,0402h
0a04:  08                 ex af,af'
0a05:  10 20              djnz $0a28
0a07:  40                 ld b,b
0a08:  80                 add a,b
0a09:  ff                 rst $18h
0a0a:  fe fc              cp fch
0a0c:  f8                 ret
0a0d:  f0                 ret po
0a0e:  e0                 ret nz
0a0f:  c0                 ret nz
0a10:  00                 nop
0a11:  01 02 04           ld bc,0402h
0a14:  08                 ex af,af'
0a15:  10 20              djnz $0a38
0a17:  40                 ld b,b
0a18:  80                 add a,b
0a19:  ff                 rst $18h
0a1a:  fe fc              cp fch
0a1c:  f8                 ret
0a1d:  f0                 ret po
0a1e:  e0                 ret nz
0a1f:  c0                 ret nz
0a20:  00                 nop
0a21:  01 02 04           ld bc,0402h
0a24:  08                 ex af,af'
0a25:  10 20              djnz $0a48
0a27:  40                 ld b,b
0a28:  80                 add a,b
0a29:  ff                 rst $18h
0a2a:  fe fc              cp fch
0a2c:  f8                 ret
0a2d:  f0                 ret po
0a2e:  e0                 ret nz
0a2f:  c0                 ret nz
0a30:  00                 nop
0a31:  01 02 04           ld bc,0402h
0a34:  08                 ex af,af'
0a35:  10 20              djnz $0a58
0a37:  40                 ld b,b
0a38:  80                 add a,b
0a39:  ff                 rst $18h
0a3a:  fe fc              cp fch
0a3c:  f8                 ret
0a3d:  f0                 ret po
0a3e:  e0                 ret nz
0a3f:  c0                 ret nz
0a40:  00                 nop
0a41:  01 02 04           ld bc,0402h
0a44:  08                 ex af,af'
0a45:  10 20              djnz $0a68
0a47:  40                 ld b,b
0a48:  80                 add a,b
0a49:  ff                 rst $18h
0a4a:  fe fc              cp fch
0a4c:  f8                 ret
0a4d:  f0                 ret po
0a4e:  e0                 ret nz
0a4f:  c0                 ret nz
0a50:  00                 nop
0a51:  01 02 04           ld bc,0402h
0a54:  08                 ex af,af'
0a55:  10 20              djnz $0a78
0a57:  40                 ld b,b
0a58:  80                 add a,b
0a59:  ff                 rst $18h
0a5a:  fe fc              cp fch
0a5c:  f8                 ret
0a5d:  f0                 ret po
0a5e:  e0                 ret nz
0a5f:  c0                 ret nz
0a60:  00                 nop
0a61:  01 02 04           ld bc,0402h
0a64:  08                 ex af,af'
0a65:  10 20              djnz $0a88
0a67:  40                 ld b,b
0a68:  80                 add a,b
0a69:  ff                 rst $18h
0a6a:  fe fc              cp fch
0a6c:  f8                 ret
0a6d:  f0                 ret po
0a6e:  e0                 ret nz
0a6f:  c0                 ret nz
0a70:  00                 nop
0a71:  01 02 04           ld bc,0402h
0a74:  08                 ex af,af'
0a75:  10 20              djnz $0a98
0a77:  40                 ld b,b
0a78:  80                 add a,b
0a79:  ff                 rst $18h
0a7a:  fe fc              cp fch
0a7c:  f8                 ret
0a7d:  f0                 ret po
0a7e:  e0                 ret nz
0a7f:  c0                 ret nz
0a80:  00                 nop
0a81:  01 02 04           ld bc,0402h
0a84:  08                 ex af,af'
0a85:  10 20              djnz $0aa8
0a87:  40                 ld b,b
0a88:  80                 add a,b
0a89:  ff                 rst $18h
0a8a:  fe fc              cp fch
0a8c:  f8                 ret
0a8d:  f0                 ret po
0a8e:  e0                 ret nz
0a8f:  c0                 ret nz
0a90:  00                 nop
0a91:  01 02 04           ld bc,0402h
0a94:  08                 ex af,af'
0a95:  10 20              djnz $0ab8
0a97:  40                 ld b,b
0a98:  80                 add a,b
0a99:  ff                 rst $18h
0a9a:  fe fc              cp fch
0a9c:  f8                 ret
0a9d:  f0                 ret po
0a9e:  e0                 ret nz
0a9f:  c0                 ret nz
0aa0:  00                 nop
0aa1:  01 02 04           ld bc,0402h
0aa4:  08                 ex af,af'
0aa5:  10 20              djnz $0ac8
0aa7:  40                 ld b,b
0aa8:  80                 add a,b
0aa9:  ff                 rst $18h
0aaa:  fe fc              cp fch
0aac:  f8                 ret
0aad:  f0                 ret po
0aae:  e0                 ret nz
0aaf:  c0                 ret nz
0ab0:  00                 nop
0ab1:  01 02 04           ld bc,0402h
0ab4:  08                 ex af,af'
0ab5:  10 20              djnz $0ad8
0ab7:  40                 ld b,b
0ab8:  80                 add a,b
0ab9:  ff                 rst $18h
0aba:  fe fc              cp fch
0abc:  f8                 ret
0abd:  f0                 ret po
0abe:  e0                 ret nz
0abf:  c0                 ret nz
0ac0:  00                 nop
0ac1:  01 02 04           ld bc,0402h
0ac4:  08                 ex af,af'
0ac5:  10 20              djnz $0ae8
0ac7:  40                 ld b,b
0ac8:  80                 add a,b
0ac9:  ff                 rst $18h
0aca:  fe fc              cp fch
0acc:  f8                 ret
0acd:  f0                 ret po
0ace:  e0                 ret nz
0acf:  c0                 ret nz
0ad0:  00                 nop
0ad1:  01 02 04           ld bc,0402h
0ad4:  08                 ex af,af'
0ad5:  10 20              djnz $0af8
0ad7:  40                 ld b,b
0ad8:  80                 add a,b
0ad9:  ff                 rst $18h
0ada:  fe fc              cp fch
0adc:  f8                 ret
0add:  f0                 ret po
0ade:  e0                 ret nz
0adf:  c0                 ret nz
0ae0:  00                 nop
0ae1:  01 02 04           ld bc,0402h
0ae4:  08                 ex af,af'
0ae5:  10 20              djnz $0b08
0ae7:  40                 ld b,b
0ae8:  80                 add a,b
0ae9:  ff                 rst $18h
0aea:  fe fc              cp fch
0aec:  f8                 ret
0aed:  f0                 ret po
0aee:  e0                 ret nz
0aef:  c0                 ret nz
0af0:  00                 nop
0af1:  01 02 04           ld bc,0402h
0af4:  08                 ex af,af'
0af5:  10 20              djnz $0b18
0af7:  40                 ld b,b
0af8:  80                 add a,b
0af9:  ff                 rst $18h
0afa:  fe fc              cp fch
0afc:  f8                 ret
0afd:  f0                 ret po
0afe:  e0                 ret nz
0aff:  c0                 ret nz
0b00:  00                 nop
0b01:  00                 nop
0b02:  00                 nop
0b03:  00                 nop
0b04:  00                 nop
0b05:  00                 nop
0b06:  00                 nop
0b07:  00                 nop
0b08:  00                 nop
0b09:  00                 nop
0b0a:  00                 nop
0b0b:  00                 nop
0b0c:  00                 nop
0b0d:  00                 nop
0b0e:  00                 nop
0b0f:  00                 nop
0b10:  01 01 01           ld bc,0101h
0b13:  01 01 01           ld bc,0101h
0b16:  01 01 01           ld bc,0101h
0b19:  01 01 01           ld bc,0101h
0b1c:  01 01 01           ld bc,0101h
0b1f:  01 02 02           ld bc,0202h
0b22:  02                 ld (bc),a
0b23:  02                 ld (bc),a
0b24:  02                 ld (bc),a
0b25:  02                 ld (bc),a
0b26:  02                 ld (bc),a
0b27:  02                 ld (bc),a
0b28:  02                 ld (bc),a
0b29:  02                 ld (bc),a
0b2a:  02                 ld (bc),a
0b2b:  02                 ld (bc),a
0b2c:  02                 ld (bc),a
0b2d:  02                 ld (bc),a
0b2e:  02                 ld (bc),a
0b2f:  02                 ld (bc),a
0b30:  04                 inc h
0b31:  04                 inc h
0b32:  04                 inc h
0b33:  04                 inc h
0b34:  04                 inc h
0b35:  04                 inc h
0b36:  04                 inc h
0b37:  04                 inc h
0b38:  04                 inc h
0b39:  04                 inc h
0b3a:  04                 inc h
0b3b:  04                 inc h
0b3c:  04                 inc h
0b3d:  04                 inc h
0b3e:  04                 inc h
0b3f:  04                 inc h
0b40:  08                 ex af,af'
0b41:  08                 ex af,af'
0b42:  08                 ex af,af'
0b43:  08                 ex af,af'
0b44:  08                 ex af,af'
0b45:  08                 ex af,af'
0b46:  08                 ex af,af'
0b47:  08                 ex af,af'
0b48:  08                 ex af,af'
0b49:  08                 ex af,af'
0b4a:  08                 ex af,af'
0b4b:  08                 ex af,af'
0b4c:  08                 ex af,af'
0b4d:  08                 ex af,af'
0b4e:  08                 ex af,af'
0b4f:  08                 ex af,af'
0b50:  10 10              djnz $0b63
0b52:  10 10              djnz $0b65
0b54:  10 10              djnz $0b67
0b56:  10 10              djnz $0b69
0b58:  10 10              djnz $0b6b
0b5a:  10 10              djnz $0b6d
0b5c:  10 10              djnz $0b6f
0b5e:  10 10              djnz $0b71
0b60:  20                 db 0x20
0b61:  20                 db 0x20
0b62:  20                 db 0x20
0b63:  20                 db 0x20
0b64:  20                 db 0x20
0b65:  20                 db 0x20
0b66:  20                 db 0x20
0b67:  20                 db 0x20
0b68:  20                 db 0x20
0b69:  20                 db 0x20
0b6a:  20                 db 0x20
0b6b:  20                 db 0x20
0b6c:  20                 db 0x20
0b6d:  20                 db 0x20
0b6e:  20                 db 0x20
0b6f:  20                 db 0x20
0b70:  40                 ld b,b
0b71:  40                 ld b,b
0b72:  40                 ld b,b
0b73:  40                 ld b,b
0b74:  40                 ld b,b
0b75:  40                 ld b,b
0b76:  40                 ld b,b
0b77:  40                 ld b,b
0b78:  40                 ld b,b
0b79:  40                 ld b,b
0b7a:  40                 ld b,b
0b7b:  40                 ld b,b
0b7c:  40                 ld b,b
0b7d:  40                 ld b,b
0b7e:  40                 ld b,b
0b7f:  40                 ld b,b
0b80:  80                 add a,b
0b81:  80                 add a,b
0b82:  80                 add a,b
0b83:  80                 add a,b
0b84:  80                 add a,b
0b85:  80                 add a,b
0b86:  80                 add a,b
0b87:  80                 add a,b
0b88:  80                 add a,b
0b89:  80                 add a,b
0b8a:  80                 add a,b
0b8b:  80                 add a,b
0b8c:  80                 add a,b
0b8d:  80                 add a,b
0b8e:  80                 add a,b
0b8f:  80                 add a,b
0b90:  ff                 rst $18h
0b91:  ff                 rst $18h
0b92:  ff                 rst $18h
0b93:  ff                 rst $18h
0b94:  ff                 rst $18h
0b95:  ff                 rst $18h
0b96:  ff                 rst $18h
0b97:  ff                 rst $18h
0b98:  ff                 rst $18h
0b99:  ff                 rst $18h
0b9a:  ff                 rst $18h
0b9b:  ff                 rst $18h
0b9c:  ff                 rst $18h
0b9d:  ff                 rst $18h
0b9e:  ff                 rst $18h
0b9f:  ff                 rst $18h
0ba0:  fe fe              cp feh
0ba2:  fe fe              cp feh
0ba4:  fe fe              cp feh
0ba6:  fe fe              cp feh
0ba8:  fe fe              cp feh
0baa:  fe fe              cp feh
0bac:  fe fe              cp feh
0bae:  fe fe              cp feh
0bb0:  fc fc fc           call m,$fcfch
0bb3:  fc fc fc           call m,$fcfch
0bb6:  fc fc fc           call m,$fcfch
0bb9:  fc fc fc           call m,$fcfch
0bbc:  fc fc fc           call m,$fcfch
0bbf:  fc f8 f8           call m,$f8f8h
0bc2:  f8                 ret
0bc3:  f8                 ret
0bc4:  f8                 ret
0bc5:  f8                 ret
0bc6:  f8                 ret
0bc7:  f8                 ret
0bc8:  f8                 ret
0bc9:  f8                 ret
0bca:  f8                 ret
0bcb:  f8                 ret
0bcc:  f8                 ret
0bcd:  f8                 ret
0bce:  f8                 ret
0bcf:  f8                 ret
0bd0:  f0                 ret po
0bd1:  f0                 ret po
0bd2:  f0                 ret po
0bd3:  f0                 ret po
0bd4:  f0                 ret po
0bd5:  f0                 ret po
0bd6:  f0                 ret po
0bd7:  f0                 ret po
0bd8:  f0                 ret po
0bd9:  f0                 ret po
0bda:  f0                 ret po
0bdb:  f0                 ret po
0bdc:  f0                 ret po
0bdd:  f0                 ret po
0bde:  f0                 ret po
0bdf:  f0                 ret po
0be0:  e0                 ret nz
0be1:  e0                 ret nz
0be2:  e0                 ret nz
0be3:  e0                 ret nz
0be4:  e0                 ret nz
0be5:  e0                 ret nz
0be6:  e0                 ret nz
0be7:  e0                 ret nz
0be8:  e0                 ret nz
0be9:  e0                 ret nz
0bea:  e0                 ret nz
0beb:  e0                 ret nz
0bec:  e0                 ret nz
0bed:  e0                 ret nz
0bee:  e0                 ret nz
0bef:  e0                 ret nz
0bf0:  c0                 ret nz
0bf1:  c0                 ret nz
0bf2:  c0                 ret nz
0bf3:  c0                 ret nz
0bf4:  c0                 ret nz
0bf5:  c0                 ret nz
0bf6:  c0                 ret nz
0bf7:  c0                 ret nz
0bf8:  c0                 ret nz
0bf9:  c0                 ret nz
0bfa:  c0                 ret nz
0bfb:  c0                 ret nz
0bfc:  c0                 ret nz
0bfd:  c0                 ret nz
0bfe:  c0                 ret nz
0bff:  c0                 ret nz
        end
