# Mega Drive 3 botones: lector para JTFRAME (prototipo)

Basado en la interfaz lógica de `joy_db15` (salida `joystick1[15:0]`, `joystick2[15:0]`), **no en sus tres conexiones físicas**. Un mando MD entrega **6 líneas de entrada simultáneas y TH de salida**, así que NO se puede conectar directamente usando solamente `JOY_CLK`, `JOY_LOAD` y `JOY_DATA` de `joy_db15`.

## Puertos

- `clk`, `reset`, `enable`: sistema y control.
- `MD_TH`: salida al SELECT del mando (pin DE-9 7).
- `MD_UP/DOWN/LEFT/RIGHT`: pines 1,2,3,4.
- `MD_TL`: pin 6, B con TH=1, A con TH=0.
- `MD_TR`: pin 9, C con TH=1, Start con TH=0.
- `joystick1`: botones activos en alto según `joy_db15`.
- `joystick2`: cero (solo un mando).
- `valid`: pulso de un ciclo al actualizar los botones.

## Mapeo joystick1

| Bit | Significado |
| --- | --- |
| 0 | Derecha |
| 1 | Izquierda |
| 2 | Abajo |
| 3 | Arriba |
| 4 | A |
| 5 | B |
| 6 | C |
| 10 | Start |

Resto de bits a cero. Se lee con TH alto (direcciones, B, C), después TH bajo (A, Start), y el módulo vuelve a TH alto durante reposo. Ajustes por defecto: 50 MHz, sondeo de 1 kHz, estabilización de 20 microsegundos por fase. Las salidas se registran juntas al finalizar el ciclo. `reset` debe activarse al arrancar.

## Simulación

```sh
iverilog -g2012 -s tb_joy_md3 -o sim joy_md3.v tb_joy_md3.v
vvp sim
```

## Integración y seguridad

Es un **prototipo**, no está integrado ni validado con el multiplexor o el pinout SNAC7 de JTFRAME. La implementación del SNAC7 físico necesita una asignación específica de las siete líneas GPIO, soporte de dirección del puerto, y adaptación eléctrica (el mando funciona típicamente a 5 V; no conectar señales de 5 V directamente al FPGA). Verificar también los pull-ups y la circuitería de cada adaptador. En particular `JOY_CLK/JOY_LOAD/JOY_DATA` del adaptador DB15 no son equivalentes a TH y las seis líneas del mando MD.

El testbench emula un mando de 3 botones, no comprueba un mando físico ni variantes de seis botones.
