# Analisis de Implementaciones de mandos

Familia	Mandos	Implementación
Serie	NES / SNES	LATCH + CLOCK + DATA
Paralela directa	SMS / Atari compatible	Lectura de GPIO
Paralela multiplexada	Mega Drive 3/6 botones	TH + lectura de GPIO
Paralela multiplexada	PcEngine TH + lectura de GPIO

Saturn original	SNAC7 + futuro backend
PS1 digital	SNAC7 + futuro backend
N64 digital SNAC7 + futuro backend

Fuera del alcance, interviene el OS
DualShock 3	USB
DualShock 3 inalámbrico	Bluetooth


# Roadmap

## Phase 1
POC and initial implementatin

- SNES
  
## Phase 2
Add Megadrive implementation

- MD 3 btn

## Phase 3
Add compatible implementations

- NES
- SMS
- Atari

## Phase 4
Add digital implementations

- PSOne (SCPH-1080)
- DualShock (SCPH-1200)

## Phase 5
Add N64 implementation


# Out of scope
DualShock 3	USB Ps3
DualShock 3 inalámbrico	Bluetooth Ps3
DualShock 4 Ps4
DualSense Ps5
Xbox Controllers
