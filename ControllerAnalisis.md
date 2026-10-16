# Controller pad analysis

Family	            Controller	             Implementation
Serial	            NES / SNES	             LATCH + CLOCK + DATA
Direct Paralel 	    SMS / Atari compatible	 GPIO Read
Multiplexed Paralel Mega Drive 3/6 btn	     TH + GPIO Read
Multiplexed Paralel PcEngine                 TH + GPIO Read

Saturn original	SNAC7 + future backend
PS1 digital	SNAC7 + future backend
N64 digital SNAC7 + future backend

Out of scope, OS dependant
DualShock 3	USB
DualShock 3 Wireless	Bluetooth


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
Add button profiles 

## Phase 5
Add digital implementations

- PSOne (SCPH-1080)
- DualShock (SCPH-1200)

## Phase 6
Add implementation

- N64
- 
## Phase 7
Add button mapping

# Out of scope
DualShock 3	USB Ps3
DualShock 3 inalámbrico	Bluetooth Ps3
DualShock 4 Ps4
DualSense Ps5
Xbox Controllers
