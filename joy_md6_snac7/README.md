# Mega Drive 6-button reader for JTFRAME (SNAC7 proof of concept)

Clean-room experimental reader modeled after the output conventions of the supplied `joydb15.v`, not a drop-in replacement for its three-wire DB15 physical input.

Files: `joy_md6.v`, `tb_joy_md6.v`.

## Electrical pins

Mega Drive DE-9 pins: 1 UP, 2 DOWN, 3 LEFT, 4 RIGHT, 5 +5V, 6 TL (B/A), 7 TH (select), 8 GND, 9 TR (C/Start). Seven GPIO signals (six inputs + one output). **This DOES NOT establish compatibility with any specific SNAC7 adapter.** Validate actual SNAC7-to-DB9 pinout, voltage shifting, direction, and FPGA-safe levels before plugging hardware in. Never apply +5V logic directly to unprotected FPGA pins.

## Port conventions

`clk`, `reset`, `enable`, six MD input pins, `MD_TH` output, `joystick1`, `joystick2`, `detected_6button`, `valid`. Pressed joystick bits are active-high, matching `joy_db15` logical output. `joystick2=0` (one controller).

Bit mapping: 0 Right, 1 Left, 2 Down, 3 Up, 4 A, 5 B, 6 C, 7 X, 8 Y, 9 Z, 10 Start, 11 Mode (optional Select). 12-15 zero.

## Six button phase sequence

TH high normal, low A/Start, high normal, low A/Start, high normal, low ID code (all D0..D3 low), high extended X/Y/Z/Mode on D2/D1/D0/D3. If ID missing, X/Y/Z/Mode remain zero: compatible with 3-button pads. State machine samples each level 20 µs after transition. TH stays high for >=3 ms between reads so the six-button controller's internal timeout resets. At 50 MHz, the default overall polling rate is approximately 200 Hz; avoid increasing this without ensuring a sufficient reset interval. Timing needs physical validation on original and third-party pads.

## Simulate

```sh
iverilog -g2012 -s tb_joy_md6 -o /tmp/md6sim joy_md6.v tb_joy_md6.v
vvp /tmp/md6sim
```

## Integration

Add a new USER_IO selection in JTFRAME and route relevant physical pins to the six inputs and TH output. Merge/select `joystick1` via the existing joystick multiplexer. The user supplied `joydb15.v` has a different physical interface (clock/load/data), so wiring cannot be swapped directly. Compile and test first with a safe electrical interface. The mode/Select mapping and arcade button mapping may need customization.

This is a prototype, not yet validated on a physical MiSTer. The testbench models the 6-button and 3-button protocols; it cannot prove electrical compatibility.
