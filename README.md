# jtjoy_backends

**Reusable original-controller input backends for MiSTer FPGA arcade cores.**

`jtjoy_backends` is an experimental HDL project that aims to let players use their existing console controllers—starting with **SNES controllers over standard SNAC7**—in arcade cores that currently expect USB or DB15-style joystick inputs.

The initial upstream target is **[JTFRAME](https://github.com/jotego/jtcores)**, the shared framework used by Jotego's arcade cores. The longer-term goal is to keep the controller readers independent of JTFRAME so other MiSTer core maintainers can adopt them with small integration wrappers.

> **Status: proof of concept / not hardware-validated.** No JTFRAME integration or upstream acceptance is claimed. Do not connect experimental GPIO wiring to your MiSTer until pin mapping, output enables, and voltage levels have been checked against your specific SNAC hardware.

## Why?

SNAC allows original controllers to communicate directly with the FPGA without routing input through the USB input stack. However, console-specific SNAC support does not automatically make those controllers usable in arcade cores. Many arcade cores already consume a normalized set of joystick bits, so the missing piece is a **protocol reader and input adapter**, not a rewrite of the game's input logic.

The project aims to:

- Enable **two original SNES controllers** over compatible SNAC7 hardware in JTFRAME arcade cores.
- Preserve existing **USB and DB15** behavior when the new mode is disabled.
- Keep console protocol readers reusable for other MiSTer cores, including those without existing DB15 support.
- Make integration, simulation, and testing easy for external contributors.
- Submit a focused pull request to JTFRAME once implementation and real-hardware testing are complete; release timing and acceptance remain with its maintainers.

## Design

```text
SNES controller(s)                  Mega Drive controller (future)
        |                                       |
        +--------- SNAC7 physical adapter ------+
                              |
               protocol-specific HDL readers
                 (SNES / MD 3B / MD 6B)
                              |
              normalized P1/P2 button vectors
                              |
                  framework-specific adapter
                              |
              JTFRAME input selection / mux
                    (USB / DB15 / SNAC)
                              |
                   existing arcade core
```

**Important:** The goal is to match the **logical joystick output vectors** already used by the DB15 path, **not** to imitate the DB15 electrical or serial protocol. The individual arcade game's logic should not need changes. Each target core must nevertheless be rebuilt to include the new HDL.

## Roadmap and current state

| Area | Current state | Next milestone |
| --- | --- | --- |
| SNES, 1 player | Prototype reader and SNAC7 port-1 wrapper | Validate protocol with simulation and hardware |
| SNES, 2 players | Designed in the integration contract | Add dual-reader support and test both ports |
| Mega Drive, 3 buttons | Experimental reader | Validate SNAC7 adapter wiring and timing |
| Mega Drive, 6 buttons | Experimental reader | Validate TH phase sequence and hardware compatibility |
| JTFRAME integration | Not implemented | Connect to common input mux and OSD selection |
| Upstream adoption | Not submitted | Propose to JTFRAME maintainers after validation |
| Other MiSTer arcade cores | Long-term goal | Provide reusable wrappers and integration examples |

The current stand-alone readers are **prototypes**, not production-ready drivers. Their testbenches have not been established as passing in a verified CI environment, and the physical SNAC7 configuration has not yet been tested on MiSTer hardware.

## Logical input contract

Reader outputs should provide independent `joystick1[15:0]` and `joystick2[15:0]` signals, with **1 meaning pressed** and **0 meaning released**, following the project's DB15-style logical layout:

| Bit | Arcade input | Proposed SNES button |
| ---: | --- | --- |
| 0 | Right | Right |
| 1 | Left | Left |
| 2 | Down | Down |
| 3 | Up | Up |
| 4 | A | B |
| 5 | B | A |
| 6 | C | Y |
| 7 | D | X |
| 8 | E | L |
| 9 | F | R |
| 10 | Start | Start |
| 11 | Select / Coin mapping | Select |
| 12–15 | Reserved / unused | — |

This mapping is **provisional**. Coin/Select and arcade-specific button ordering belong in the integration adapter as needed, rather than being assumed universal across all MiSTer cores.

## SNES protocol

An SNES controller captures its buttons on **LATCH** and serializes **16 bit positions** on **DATA**, shifted by **CLOCK**. The first 12 positions contain the buttons; the last four are normally high (not pressed). The button order is:

```text
B, Y, Select, Start, Up, Down, Left, Right, A, X, L, R, 1, 1, 1, 1
```

Data is **active low**: `0` means pressed.

The MiSTer SNES core is our reference for SNAC pin assignment and signal polarity. For controller port 1, the previous prototype uses:

| Signal | MiSTer signal | Direction relative to FPGA |
| --- | --- | --- |
| LATCH | `USER_OUT[0]` | Output |
| CLOCK | `USER_OUT[1]` | Output |
| DATA | `USER_IN[5]` | Input |

**Do not generalize these assignments to a second port or a different adapter without checking the upstream SNES core and real pinout.** Both ports are a target requirement, not implemented by the current one-player prototype.

## Mega Drive controllers

Mega Drive controllers use **six parallel data signals and a `TH` select signal**, rather than SNES-style serial data. A 3-button controller requires reading two TH phases; 6-button controllers expose X/Y/Z/Mode through additional TH transitions and need adequate idle time for their internal phase counter to reset.

A seven-signal interface may be sufficient **in principle** for one controller, but electrical compatibility with a particular SNAC7 adapter must be confirmed before use.

## Development and simulation

You can work on HDL and run simulations **without a MiSTer, a Patreon subscription, or Quartus**. On Ubuntu:

```bash
sudo apt update
sudo apt install -y git iverilog
```

For the existing proof-of-concept files, run the corresponding testbench from the folder containing the sources:

```bash
# SNES SNAC7 port 1 prototype
iverilog -g2012 -s tb_joy_snes_snac7 -o /tmp/snes_sim \
  joy_snes.v joy_snes_snac7.v tb_joy_snes_snac7.v
vvp /tmp/snes_sim

# Mega Drive 3-button prototype
iverilog -g2012 -s tb_joy_md3 -o /tmp/md3_sim \
  joy_md3.v tb_joy_md3.v
vvp /tmp/md3_sim

# Mega Drive 6-button prototype
iverilog -g2012 -s tb_joy_md6 -o /tmp/md6_sim \
  joy_md6.v tb_joy_md6.v
vvp /tmp/md6_sim
```

These commands assume that the files from the respective prototypes have been copied to your working directory. They are **not** evidence that the modules have already passed simulation. Check results and waveforms before moving to hardware.

For full JTFRAME builds, clone the public [JTCORES repository](https://github.com/jotego/jtcores), follow its official setup documentation, and install the supported Quartus toolchain. Public JTFRAME development does not require Patreon; some early-access cores and unrelated private submodules may have separate access requirements.

A small public core such as **JTHIGE** is a reasonable first integration target, followed by a second JTFRAME arcade core to demonstrate reuse.

## Hardware safety

- A successful SNAC connection in the SNES or Genesis core **does not automatically prove** that a new arcade core drives the pins safely.
- Verify the adapter's **5 V / 3.3 V level shifting** in hardware; HDL cannot perform electrical level conversion.
- Match the official core's GPIO **directions, idle states, and output-enable behavior**.
- Ensure only the selected backend drives `USER_OUT`; avoid bus contention with DB15, UART, or other USER_IO modes.
- Keep SNAC input data isolated from the USB path when the new mode is off; test all existing modes for regressions.

## Proposed acceptance criteria for the first JTFRAME PR

- [ ] Two SNES controllers independently report directions, face buttons, shoulders, Start, and Select.
- [ ] LATCH/CLOCK timing, bit order, active-low input, reset, and output updates pass automated simulations.
- [ ] SNAC7 pin assignments and output enables match supported hardware.
- [ ] No unexpected behavior in existing Off / USB / DB15 modes.
- [ ] Works on real MiSTer hardware in at least two JTFRAME arcade cores without editing game-specific logic.
- [ ] Documented build steps and a reproducible testbench are included.

## Documentation and references

- [Integration contract](INTEGRATION_CONTRACT_EN.md) — proposed interfaces, pin mapping, requirements, and acceptance tests.
- [JTCORES / JTFRAME](https://github.com/jotego/jtcores)
- [MiSTer SNES core (`SNES.sv`)](https://github.com/MiSTer-devel/SNES_MiSTer/blob/master/SNES.sv) — reference for SNAC signal mapping.
- [SNES controller protocol FAQ](https://gamefaqs.gamespot.com/snes/916396-super-nintendo/faqs/5395)
- [SNESdev Wiki: Standard controller](https://snes.nesdev.org/wiki/Standard_controller)

## Contributions

Issues, protocol reviews, testbenches, hardware reports, and adapters for other MiSTer cores are welcome. For changes targeting JTFRAME, the intention is to discuss upstream design expectations before proposing a pull request. This project is **unofficial** and is not affiliated with or endorsed by Jotego or MiSTer-devel.

## License

**To be decided before publication.** Verify the provenance and license of all included HDL files and dependencies. Do not assume that code copied or adapted from an existing MiSTer core can be relicensed without checking its original license. JTFRAME itself uses GPLv3; upstream integration must satisfy the relevant licensing requirements.
