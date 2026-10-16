# SNES controller reader for JTFRAME — revision 2 (SNAC7 mapping)

This updates the prior `joy_snes.v` example using the **official MiSTer SNES core's SNAC7 port 1 pin mapping**. 
It is an independent serial reader; the console's internal joypad-scanning HDL is **not** copied. The reader's 
interface remains compatible with the previously shared `joydb15.v` **logical output layout**, not its physical 
DB15 wiring.

Source reference: https://github.com/MiSTer-devel/SNES_MiSTer/blob/master/SNES.sv (look for `USER_OUT[0]`, `USER_OUT[1]`, `USER_IN[5]`). The SNES core has additional arrangements for multitap, light gun and port swap that this **one-player** reader does not implement.

## SNAC7 signals, player one

| FPGA bus | Function | Direction (from FPGA) |
|--|--|--|
| `USER_OUT[0]` | SNES LATCH/STROBE | Output |
| `USER_OUT[1]` | SNES CLOCK | Output |
| `USER_IN[5]` | SNES DATA (D0, active low) | Input |

Other `USER_OUT` bits are set to logical 1. In JTFRAME, the OSD and USER_IO integration must ensure these 
outputs are enabled only when SNES mode is selected. **Never directly drive live USER_OUT nets from two cores simultaneously.** 
The wrapper is an example of the SNES mode side of a mux; do not drop it into a top module 
that already drives USER_OUT without modifying that mux.

The reader uses 12 us LATCH and approximately 12 us per clock bit (at CLK_HZ divisible by 1MHz); 16-bit scanning.
 `POLL_HZ` controls polling start period. `joystick1` updates on frame completion, so the output never shows a 
 partly sampled frame. `joystick2=0`.

Joystick layout: `[0] Right [1] Left [2] Down [3] Up [4] Arcade A (=SNES B) [5] Arcade B (=SNES A) [6] 
C (=SNES Y) [7] D (=SNES X) [8] E (=SNES L) [9] F (=SNES R) [10] Start [11] Select`. High=pressed.

## Test

```sh
iverilog -g2012 -s tb_joy_snes_snac7 -o sim \
  joy_snes.v joy_snes_snac7.v tb_joy_snes_snac7.v
vvp sim
```

This testbench verifies the SNAC7 wrapper and three input patterns through serial emulation. 
**Not validated on a real MiSTer**. Run electrical checks of SNAC adapter and GPIO direction before hardware 
tests. 5V ↔ 3.3V conversion is handled by suitable SNAC hardware, *not* Verilog.

## Next integration step

JTFRAME must select DB15/SNES/Off and drive USER_OUT from **one** source. Wire `joystick1`/`joystick2` into 
existing joymux logic, respecting normal USB fallback and OSD state. Existing `.rbf` files cannot pick up this 
support without rebuilding.
