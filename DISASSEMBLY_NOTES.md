# Manic Miner '88 (Cambridge Z88) – disassembly notes

Files
- `mmz88_ap0.asm` – top bank (mapped at 0xC000): code, caverns 16–19, title bitmap, text, DOR
- `mmz88_ap0_qa.asm` – the same with the Q/A scroll patch as source (= the shipped patched `.ap0`)
- `mmz88_ap0_fast.asm` – current version: speed-ups, matrix-read Q/A, screen code documented
- `mmz88_ap1.asm` – caverns 0–15 (mapped at 0x8000)

The sources are in mpm syntax (mpm 2.2).  OZ names (`oz Gn_Sop`, `RC_Time`, `BLSC_SR2`, `BL_TIM0` ...)
come from `mmz88_oz.def` beside the sources, with the standard def-file names and values, so no def
folder is needed (a full OZ def set defines names such as `app_dor`; the DOR labels are now
`mm_app_dor` / `mm_front_dor`).  Each reassembles **byte-for-byte**:

    mpm -b mmz88_ap0.asm       -> the unpatched mmz88.ap0
    mpm -b mmz88_ap0_qa.asm    -> the shipped mmz88.ap0 (Q/A patch)
    mpm -b mmz88_ap0_fast.asm  -> the speed-up mmz88.ap0
    mpm -b mmz88_ap1.asm       -> mmz88.ap1

`./build.sh` builds the RAM application (`mmz88.app` + `.ap0` + `.ap1`, legacy 40-byte `.app`:
$A5 $5A, bank count, flags, 4 reserved, then offset/length per bank) and also the fast version into mmz88.ap0/.ap1 and the 32K mmz88.epr.

## Card layout
`mmz88.app` is a 40-byte descriptor (2 × 16 KB banks). The OS binds bank 0x3F (`.ap0`) into
segment 3 (0xC000–0xFFFF) and 0x3E (`.ap1`) into segment 2 (0x8000–0xBFFF); the application DOR
(0xE829) gives entry point **0xE962**. Contiguous RAM is 38 pages = 0x2000–0x45FF.

## ap0 map (address = 0xC000 + file offset)
| Range | Content |
|---|---|
| C000–CFFF | caverns 16–19: Warehouse, Amoebatrons' Revenge, Solar Power Generator, Final Barrier |
| D000–DFFF | title screen bitmap (4 KB, frame-buffer layout) |
| E000–E1FF | 256-byte extras for caverns 16 and 17 (copied to 0x4500) |
| E200–E2FF | scrolling title text ("Written by Matthew Smith…") |
| E300–E3FF | Willy sprite frames (8 × 32 bytes) |
| E400–E4FF | scanline address table: 128 words, pixel row → address in `show_buf` (verified against the formula) |
| E500–E5FF | second scrolling title text (Bug-Byte version) |
| E600–E610 | Bug-Byte-version patch for cavern 5 (8 bytes → 0x44B4, 9-byte tile → `tile_nasty1`) |
| E611–E620 | 16 bytes, unidentified |
| E621–E632 | default keys: 6 × (row select, column mask, label char) |
| E63B–E6CA | cheat-code key sequences (?) |
| E6CB–E7E8 | title tune: 95 × (duration, period voice 1, period voice 2), 0xFF end |
| E7E9–E828 | in-game tune: 64 notes (the "Hall of the Mountain King" periods) |
| E829–E961 | application DOR, menu/help strings ("Display", "Invert", "Version", …) |
| E962–FCB1 | **code** (4.9 KB, one contiguous run, fully traced) |
| FCB2–FF2F | VDU/text strings for `GN_SOP` |
| FF30–FFBF | unused zero padding (144 bytes) |
| FFC0–FFFF | front DOR / card header ("OZ") |

ap1 = 16 × 1 KB caverns, each in the **Spectrum cavern format**: 512 B layout (16 × 32 attribute
bytes), 32 B name, 9 tile blocks (attr + 8 B bitmap), Willy start / conveyor / items / portal data,
air + clock (+0x2BC), horizontal guardians at +0x2BE (7-byte records, 0xFF end), 8 guardian sprites at +0x300.

## Game RAM
Cavern (1 KB) is copied to 0x4200 (layout) and 0x4400 (data); offsets match the Spectrum
(e.g. +0x268 `willy_y` = 0x4468). Two 4 KB frame buffers: `draw_buf` 0x2000 (game draws here) and
`show_buf` 0x3000 (copy shown). Variables near 0x1F74: `cavern_no`, `lives`, `dying_timer`, `flags` (0x1F78,
bits 0–2 used), score/hi-score strings, `lcd_map_ptr` (0x1F90), `options` (0x1F92: bit0 squash/scroll,
bit1 version, bit5 invert), `in_game`, `key_table` (0x1F95, 6 × 3 bytes), file state (0x1FF7–0x1FFD).

## Sound
There is no sound chip: both tunes are bit-banged square waves on the speaker (toggle bit 0x40 of the
BLINK COM register, port 0xB0, soft copy at 0x04B0) with interrupts disabled via OZ routines 0x0051/0x0054,
and only if the panel sound setting is on (`flags` bit 2).
- **In-game music** (`play_music_note`, in the frame loop): one note per two frames from `ingame_tune`;
  the music key toggles it (`flags` bit 1).
- **Title tune** (`play_title_tune`): two voices from `title_tune`; `draw_piano_key` shows the notes.
- **Sound effects** (`move_willy_vertical`): jump and fall tones.

## Program structure
`app_init` → title screen/tune → `load_cavern` → `frame_loop`. Each frame: restore layout, copy
draw_buf→show_buf, guardians/conveyor/items/specials (Eugene = cavern 4, Skylab = 13, Kong = 7 and 11,
solar beam = 18), portal, blit to LCD, status panel, direct keyboard matrix reads (port 0xB2), then
`OS_TIN` → `menu_command` for OZ menu commands.
The LCD blitter `blit_to_lcd` shows 8 of 16 cavern rows; `frame_scroll` (0xEB8F) picks the row from Willy's Y.

OZ calls used: os_bye os_out os_in os_tin os_pur os_mv os_frm os_fwm os_nq os_sr os_esc os_sci os_map,
gn_sip gn_sop gn_err gn_esa gn_opf gn_cl.

## Q/A scroll
Now part of the source (`qa_render`, `qa_pause`).  flags bits 3–7 = window row + 8 (0 = automatic
on the next frame, reset by `load_cavern`).  In `_fast`, Q and A are read from the keyboard matrix
(row 0xDF: Q = bit 4, A = bit 3) every frame; during pause they still come through `OS_IN`.

## Screen drawing
The Spectrum engine is kept; only the screen is replaced by RAM buffers in Spectrum format.

| Buffer | Address | Spectrum equivalent | Contents |
|---|---|---|---|
| `draw_buf` | 0x2000–0x2FFF | 0x7000 back buffer | static cavern picture |
| `show_buf` | 0x3000–0x3FFF | 0x6000 screen buffer | background + sprites, source of the blit |
| attribute buffer | 0x4000–0x41FF | 0x5C00 | working attributes (collision map) |
| `cav_layout` | 0x4200–0x43FF | 0x5E00 | cavern attribute layout |

Pixel buffers are 2 Spectrum "thirds" (16 rows × 32 columns): `base + (row>>3)*0x800 + scanline*0x100
+ (row&7)*32 + col`; an attribute at 0x40RC/0x41RC shares its low byte with the cell's pixels.
`relocate_addrs` turns the Spectrum addresses in cavern data into these (attr −0x1C, back buffer −0x50,
screen −0x30 on the high byte).

Attributes are still the collision map though the Z88 has no colour: Willy marks his cells ink 7
(`check_cell`); items collect when their cell is ink 7; the solar beam detects 0x27; Eugene, Skylab and
vertical guardians paint 2×3 blocks (`paint_attr_block`).  Colour effects are redone in pixels:
portal FLASH = inverting `portal_gfx` every 4th frame, solar beam = 0xAA/0x55 stipple, item flashing =
drawing the item only when `air_clock` bit 2 is clear.

Routines (labels inside them renamed from `l_xxxx`):
- `draw_cavern`/`draw_cavern_half` – CPIR each attribute in the tile table, copy the 8-byte bitmap.
  CPIR also scans bitmap bytes, so an attribute that is no tile's can match a bitmap byte; harmless
  in practice (cavern 19's top half is replaced by the title picture).
- `draw_sprite` – 16×16; mode 0 overwrites, mode 1 tests (AND) then ORs and returns NZ on the first
  overlapping byte, against *anything* in `show_buf`.
- `draw_willy` – ORed via `scanline_table`; `willy_y` is 2 × pixel Y, so it is the table's byte offset.
- `crumble_floor`, `conveyor`, `kong_switch` and Kong's wall work in `draw_buf`, so changes persist.
- `blit_to_lcd` – OZ map = HIRES0 bitmaps, 32 chars × 8 rows, 8 consecutive bytes per char.
  Copies rows B..B+7 (the original's squash mode, all 16 rows at half height, is removed in `_fast`).
  options bit 5 XORs 0xFF.  `draw_piano_key` XORs straight into the map's bottom row.
- `setup_lcd_map` – OS_MAP (256 px map in window '2'), OS_SCI SC_HR0 for the bitmap base, bank
  bound into S2 permanently; S2 is borrowed back only to read ap1.
- Text (cavern name row 0, AIR bar row 2, scores row 3, lives row 4, title scroller) is OZ VDU:
  `SOH 3 @ x y` cursor, `SOH 2 +/- R` reverse etc.  The air bar is reverse-video spaces.

Sprites kept in ap1's cavern data (offset 0x2E0): swordfish 0x82E0 (ending), plinth 0x86E0 and boot
0x8AE0 (game over).

## Speed-ups (`mmz88_ap0_fast.asm`)
`frame_wait` paces frames on BLINK TIM0 (port 0xD0, 5 ms) – `frame_ticks` = 18 (90 ms); score
reprinted only when changed (options bit 7); no OS_NQ on OS_TIN timeouts; unrolled scroll blitter
(~113k → ~66k T); unrolled LDI frame copy (~86k → ~71k T).
Squash mode removed (blitter path, half-height piano keys, 'Display:' status text, menu handler):
options bit 0 is now unused, and the Display command is moved to the end of the OPTIONS list with
attribute $04 (CMDF_HIDDEN, the byte before the entry's trailing length) so the menu shows only
Invert and Version (checked on OZ 5).  116 bytes free at $FF4C.

## Enquiry entry point (E965)
The 8 bytes after the entry `jp app_init` are not dead code: OZ calls entry+3 (the enquiry entry
point).  `ld bc,$3000 / ld de,$4200 / or a / ret` returns Fc = 0, giving $3000-$41FF (`show_buf` and the
working attribute buffer, both rebuilt every frame) back to OZ while the game is suspended.
(An earlier `_fast` build removed them: INDEX then restarted the game and the Display setting was lost.)

## OZ behaviour (`_fast`)
- Sound: the nine sound loops no longer run between OZ_Di/OZ_Ei ($0051/$0054), so OZ's tick, keyboard
  and serial interrupts keep running (expect a slightly rougher tone).
- Q/A: the first press arrives from OZ as a character (so it is the key labelled Q/A on any keyboard
  layout); `menu_command` then records that key's matrix position in `qa_up`/`qa_dn` ($1F70/$1F72: row
  select, column mask; $FF,$FF = not yet known) and sets a one-row step pending (options bit 0 = up,
  bit 6 = down).  `qa_render` scrolls one row per frame while the learned key is held, or once for a tap.
  The DOR's safe workspace grew from $8A to $8E bytes for this ($1F70-$1FFD).
- `os_poll` (OS_TIN 1 cs + menu/error handling) is shared by `frame_wait` and the air-to-score
  countdown; game over now sleeps in OS_TIN (`os_wait`, ~1.8 s, after OS_PUR) instead of a busy loop.
  The game-over boot animation itself still does not poll: its picture is only in `show_buf`, which
  the enquiry entry gives back to OZ while suspended.
- Not changed: the map is still found via OS_SCI (HIRES0) and S2 is bound by writing BLSC_SR2 + port
  $D2 directly (Gunther's `opengraphics` and OS_MPB would be the documented route).

## Bugs found in the original
- End of cavern 19: the "skip the ending when cheating" test compared `options` instead of
  `cheat_index` (fixed in `_fast`).
- Cheat teleport (Bug-Byte version): after 6031769 the code read port $DF (`ld bc,$FEDF`) instead of
  the keyboard row A8 bit 5 (the 6 key, `$FEB2`).  In the emulator it reloaded Central Cavern every
  frame (game frozen); on hardware the result depends on what port $DF returns.  Fixed in `_fast`:
  hold 6 with 1-5 (binary, 1 = bit 0) to pick a cavern; release 6 first or it goes to cavern 0.
- The ending draws Willy and the swordfish in rows 2–5 then blits rows 8–15 (`ld b,8` at F469), so in
  scroll mode it appears to be off-screen (not changed; `ld b,0` would show it).

## Corrections made while analysing
`EE98` was first guessed to be music; it is Willy's vertical movement (jump/fall + their sound effects).
`0x1F77` is the music position counter. `E7 0C 0C` is the 2-byte OZ call `DC_NAM` (sets the application name).

## Still to do
- Decode the DOR strings structurally (the per-cavern specials are now documented, see Screen drawing;
  E611–E620 is Willy's direction table, new state = table[keys*4 + state])
- The cheat-sequence tables; the remaining ~146 `l_xxxx` labels (game logic, menus, files) are still address-named
- Names marked `(?)` in the listing are guesses
