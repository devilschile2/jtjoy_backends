# Integration Contract — SNES Controllers over SNAC7 in MiSTer / JTFRAME

**Status:** Technical draft v0.1 — proposal, NOT ready for hardware deployment  
**Initial goal:** Support **two SNES controllers** in JTFRAME-based arcade cores without modifying game logic.  
**Future scope:** Adapters for other MiSTer cores and, optionally, Mega Drive controllers.  
**Date:** 2026-10-16

> This document specifies interfaces and acceptance criteria; it does not certify a working FPGA implementation. Physical pin assignments, clock polarity, and pin output-enable behavior must be checked against the official SNES core and the actual hardware before use.

## 1. Design Principles

1. **Separate protocol, hardware, and framework:** (a) SNES protocol reader, (b) SNAC7 physical adapter, (c) JTFRAME selector/multiplexer.
2. **Do not modify game cores:** the input module supplies vectors compatible with the existing joystick input path.
3. **Preserve backward compatibility:** existing Off, USB, and DB15 modes must behave exactly as before when SNES mode is disabled.
4. **Avoid maintaining a fork:** target upstream JTFRAME; keep the reader reusable by other cores.
5. **No Patreon dependency:** use publicly available modules and reproducible tests.

## 2. Interfaces and Responsibilities

```text
   SNAC7 / two SNES controllers
      │   DATA1, DATA2, CLOCK1, CLOCK2, LATCH
      ▼
   snac7_snes_adapter (pin mapping + direction + output enable)
      │   protocol-level signals
      ▼
   snes_reader_dual (serial protocol + synchronization)
      │   p1_buttons[15:0], p2_buttons[15:0], valid
      ▼
   jtframe_input_adapter (mapping and SNES / DB15 / USB selection)
      │   joystick1[15:0], joystick2[15:0]
      ▼
   existing arcade game logic (unchanged)
```

### Reader Interface Contract

| Signal | Direction relative to FPGA | Description |
|---|---|---|
| `clk` | input | Synchronous system clock; configurable frequency |
| `rst` / `reset` | input | Resets FSM, sets outputs to idle, and clears button states |
| `enable` | input | Enables polling only while SNES mode is selected |
| `snes_data1` | input | Controller 1 serial data, **active-low** |
| `snes_data2` | input | Controller 2 serial data, **active-low** |
| `snes_latch` | output | Captures both controllers' button states; active-high |
| `snes_clock1` | output | Shift clock for controller 1 |
| `snes_clock2` | output | Shift clock for controller 2; initially synchronized with clock 1 |
| `joystick1[15:0]` | output | Arcade P1 state, **active-high** |
| `joystick2[15:0]` | output | Arcade P2 state, **active-high** |
| `valid` (optional) | output | Pulse indicating a complete, coherent scan |

**Note:** This table describes the **target interface**. The available v2 prototype (`joy_snes.v`) accepts `JOY_DATA` for only one controller and sets `joystick2=0`; it also has no explicit `rst`, `enable`, or `valid` signals. Do not confuse the target contract with the current HDL.

## 3. Logical Button Contract

The reader-to-integration outputs use the bit layout of the `joydb15.v` supplied for this project. **1 = pressed; 0 = released.**

| Bit | Arcade meaning | Initial SNES mapping |
|---:|---|---|
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
| 11 | Select | Select (**Coin** only if assigned by the core integration layer) |
| 12–15 | Reserved | 0 |

The same contract applies to P1 and P2. The six action-button mappings are provisional, documented, and should be configurable without changing the serial reader.

**Important:** This implementation does **not emulate the physical DB15 protocol**. It produces the same **logical button vectors** that the DB15 reader supplies to JTFRAME, allowing both paths to share the core's input interface.

## 4. SNES Protocol

- On the **LATCH** signal, the controller captures its button states.
- Each controller outputs **16 serial positions**: `B, Y, Select, Start, Up, Down, Left, Right, A, X, L, R, 1, 1, 1, 1`.
- Data bits are active-low. The reader must invert them to meet the logical output contract.
- The **first 12 bits** represent buttons. Consuming and verifying all **16 positions** per transaction is recommended.
- Typical reference timing is **12 µs for LATCH** and **~12 µs per clock position**; use conservative timing compatible with real controllers and verify it in simulation.
- Button outputs must update **atomically**, never exposing a mixture of partial scans. When `enable=0`, logical button outputs must be zero and physical lines must be held in a safe idle state.
- For **two players**, LATCH is shared. Two synchronized clocks can be driven on separate lines while sampling two DATA inputs in parallel. Do not assume the two physical CLOCK lines are hardwired together.

### Proposed Timing and Latency

With 16 positions at ~12 µs each and a ~12 µs LATCH pulse, a typical transaction takes approximately **204 µs**, plus margins. A 1 kHz polling rate is an initial configuration target, not a contractual requirement. Measure end-to-end latency before claiming improvements over USB.

## 5. SNAC7: Physical Pin Mapping and Electrical Requirements

### Signals Referenced from the SNES / SGB Cores

| Function | Reference logical assignment | Status |
|---|---|---|
| Shared LATCH | `USER_OUT[0]` | Known reference |
| Controller 1 CLOCK | `USER_OUT[1]` | Known reference; verify **physical polarity inversion** |
| Controller 2 CLOCK | `USER_OUT[3]` | Known reference; verify inversion |
| Controller 1 DATA | `USER_IN[5]` | Known reference |
| Controller 2 DATA | `USER_IN[2]` | Known reference |

**Caution:** Exact connections depend on the SNAC adapter and the original core's wiring. In the reference cores, clock signals may be assigned as `~JOYx_CLK`. **Do not directly connect the clock from `joy_snes.v` to `USER_OUT` without verifying its physical polarity.** Also check `joy_swap` and any other user-port functionality before finalizing the wiring.

Unused lines must remain in the safe state defined by MiSTer integration. The design must not drive a line designated as an input or simultaneously enable outputs that conflict with another peripheral or module.

**Voltage level shifting:** HDL **cannot convert 5 V to 3.3 V**. Use only SNAC hardware with appropriate level shifting/protection, and verify the I/O board and adapter revision. An adapter working with the official SNES core is useful evidence of electrical compatibility, but does not make a new GPIO configuration automatically safe.

## 6. JTFRAME OSD Selection

**Target UI:** `User port: Off / DB15 Joystick / SNES SNAC7 [ / UART where available ]`.

- Selection must be **mutually exclusive**: never enable DB15, UART, and SNES drivers on the same lines at the same time.
- `Off`: do not drive SNES reader output lines; preserve existing USB joystick support.
- `DB15`: preserve pre-change JTFRAME behavior exactly.
- `SNES`: route normalized SNES states to P1/P2 according to multiplexer policy; preserve OSD access and pause/reset handling.
- `UART`: preserve existing behavior if the core includes it.
- For `JTFRAME_NO_DB15`, explicitly define whether SNES remains available or is excluded at build time.
- **Do not assign status bits or change `cfgstr` yet:** the OSD uses shared fields (currently documented as bits 37–38), and the complete encoding must be checked to avoid collisions.

**Expected integration point:** `jtframe_joymux` and the MiSTer integration layer (`jtframe_mister.sv`), or their current equivalents. Confirm file paths, multiplexer topology, and build source lists before editing.

## 7. Safety and Disabled-State Behavior

- Physical pins: direction, idle levels, and tri-state/output-enable controls must be defined **in the platform adapter**, not in the abstract SNES reader.
- Initialization/reset: no phantom button presses. Disabling SNES mode must clear button outputs and reset the FSM.
- Runtime mode switching: prevent an incomplete SNES scan from contaminating DB15/USB states.
- Do not change `USER_IO` electrical behavior while another mode is active.
- Never power 5 V controllers from an FPGA GPIO; verify power supply and level shifting in the adapter.

## 8. Testbenches and Acceptance Criteria

### Required Unit Tests

- [ ] Read all 16 positions for one controller; no buttons pressed → zero output.
- [ ] Verify every individual button and direction.
- [ ] Verify B + X + Start + Left, and A + R + Down combinations.
- [ ] Verify simultaneous P1/P2 reads, distinct states, and channel isolation.
- [ ] Verify active-low input and active-high output polarity.
- [ ] Verify first-bit capture and shifting on the correct clock edges; check physical CLOCK inversion.
- [ ] Confirm outputs update only after a complete scan.
- [ ] Reset and enable/disable the module mid-scan.
- [ ] Verify physical output drivers remain disabled in incompatible modes.
- [ ] Check parameter values and counter limits at the actual system clock frequency.

### Integration Tests

- [ ] Run Icarus and/or Verilator simulation/lint with no critical warnings.
- [ ] Build **JTHIGE** unmodified and save a baseline.
- [ ] Build JTHIGE with SNAC7 selectable from the OSD.
- [ ] Detect controller 1 and controller 2 (on a 1P core, use diagnostics or a 2P core to verify the second controller).
- [ ] Switch between `Off / DB15 / SNES` with no regressions.
- [ ] Open the OSD using USB while SNES is active.
- [ ] Repeat in a second JTFRAME core without changing its game logic.
- [ ] Verify FPGA synthesis, timing/STA, and resource usage.
- [ ] Measure—not estimate—latency using the final hardware.

## 9. Delivery Stages / PR Readiness

1. **Standalone protocol:** dual-controller reader with a self-contained testbench.
2. **MiSTer physical adapter:** pinout and polarity derived from an identified revision of the official core; safe GPIO validation.
3. **JTFRAME integration:** OSD selection, mutually exclusive modes, P1/P2 routing, and USB/DB15 regression testing.
4. **Demonstration:** JTHIGE and a second public JTFRAME arcade core, built and tested.
5. **Upstream PR:** documentation, simulation instructions, test results, base revision/commit, FPGA resource impact, and backward-compatibility notes.

PR acceptance and distribution of new `.rbf` binaries are up to the maintainers. Do not assume that existing distributed binaries gain the feature automatically; they must be rebuilt.

## 10. Porting Guidelines for Other MiSTer Cores

- Reuse the **serial reader** and timing logic without coupling them to JTFRAME's OSD.
- Provide a platform adapter translating the SNAC pinout and `joystick[15:0]` format to the target core's input convention.
- Do not assume DB15 support: only an insertion point upstream of game logic is required.
- Preserve service controls, Coin/Start, keyboard, USB joystick, and other existing input sources.
- Document the physical pins actually used by each core.

## 11. References and Starting Files

- `joydb15.v` (file supplied for this project): `JOY_CLK`, `JOY_LOAD`, `JOY_DATA`, `joystick1[15:0]`, and `joystick2[15:0]` interface; active-high outputs generated by inverting the internal shift register.
- `joy_snes.v` and `joy_snes_snac7.v` (v2 prototype): **single controller only**, not fully validated on hardware, no dual-controller support yet.
- [JTCORES / JTFRAME](https://github.com/jotego/jtcores).
- [JTFRAME — OSD and user-port documentation](https://github.com/jotego/jtcores/blob/master/modules/jtframe/doc/osd.md).
- [JTFRAME — MiSTer `cfgstr` configuration](https://github.com/jotego/jtcores/blob/master/modules/jtframe/target/mister/cfgstr).
- [SNES_MiSTer — SNAC integration](https://github.com/MiSTer-devel/SNES_MiSTer/blob/master/SNES.sv).
- [SGB_MiSTer — alternative SNES SNAC pin reference](https://github.com/MiSTer-devel/SGB_MiSTer/blob/main/SGB.sv).

## 12. Open Decisions

1. Confirm pinout and CLOCK polarity **against a specific SNES_MiSTer commit** for both ports.
2. Decide whether the dual reader uses a single sequencer with two DATA inputs (preferred) or two synchronized readers.
3. Define OSD placement without conflicting with DB15/UART, including the `JTFRAME_NO_DB15` configuration.
4. Confirm physical integration into `jtframe_joymux` and Coin/Select handling.
5. Define USB composition policy: replacement versus logical combination, including protection against duplicate button presses.
6. Run testbenches and synthesize the design before declaring support validated.

---

**Definition of done:** Two SNES controllers connected through SNAC7 work in two public JTFRAME-based arcade cores, using the same logical joystick vectors as DB15, with no changes to game logic and no regressions in other input modes. All tests and outstanding decisions are documented.


**Documentation**

- [GameFaqs] (https://gamefaqs.gamespot.com/snes/916396-super-nintendo/faqs/5395)
- [Snes Dev] (https://snes.nesdev.org/wiki/Standard_controller)
	