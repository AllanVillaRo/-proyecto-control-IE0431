# Resumen del proyecto – IE-0431 Equipo 2-10

Planta: TCLab, lazo Q1 (calentador 1) → T1 (temperatura 1).
Datos de identificación: `tclab_ident_data_Q1_v_79-27-60.txt` (Q1: 0 → 79 → 27 → 60 %).
Normalización: temperatura a % con el rango del TMP36 (−40 a 150 °C): `y% = (T + 40)/190*100`.

## Archivos

| Archivo | Qué es |
|---|---|
| `untitled.m` | Script de MATLAB: identificación (4 modelos), sintonía (4 PI), simulación y tablas |
| `proyecto_control.py` | El mismo script traducido a Python (Spyder) |
| `m1.m` / `m1.sid` | Preparación de datos y sesión guardada del System Identification Toolbox |
| `test_PID_servo_reg.py` | Script oficial del profe (guía 2), **ya editado** con C3 AMIGO |
| `test_PID_servo_reg_ORIGINAL.py` | Respaldo del script del profe sin cambios |
| `lab_tclab_pi.py` | Script propio de prueba (solo respaldo; la prueba oficial usa el del profe) |
| `lab_C3_AMIGO_20261026_1525.csv` | Prueba real del 26/10 con C3 (funcionó: ep ≈ 0, Mp ≈ 3 %) |

## Identificación

Se usa el último escalón (27 → 60 %). Punto de operación: **u0 = 27 %, y0 = 44.57 % (44.68 °C)**.

| Modelo | Método | K (%/%) | τ (s) | L (s) | IAE | Ajuste |
|---|---|---|---|---|---|---|
| **M1** | Toolbox P1D | 0.346 | 190.7 | 22.3 | **190** | **94.8 %** |
| M2 | Alfaro 123c | 0.3475 | 172.4 | 32.0 | 252 | 93.0 % |
| M3 | Smith | 0.3475 | 171.1 | 36.3 | 258 | 92.7 % |
| M4 | Mínimos cuadrados ARX(3,3,4), Ts = 9 s | – | – | – | 252 | 92.8 % |

**Mejor modelo: M1** → `G(s) = 0.346 e^(−22.3 s) / (190.7 s + 1)`.

## Controladores PI (estructura estándar, Td = 0)

| Controlador | Kp (%/%) | **Kp (%/°C)** ← usar en el script del profe | Ti (s) | Mp | ta2% (s) | Ms |
|---|---|---|---|---|---|---|
| C1 PID Tuner | 10.6488 | **5.6046** | 142.16 | 7.0 % | 297 | 1.51 |
| C2 SIMC | 12.3779 | 6.5147 | 178.09 | 5.4 % | 151 | 1.60 |
| **C3 AMIGO** | 6.7804 | **3.5686** | 123.71 | 7.7 % | 435 | **1.31** |
| C4 Discreto (Ts = 9 s) | 8.0 | 4.2105 | 191.63 | 0 % | 144 | 1.51 |

Conversión: `Kp[%/°C] = Kp[%/%] * 100/190`. Ti no cambia.

Elección para el laboratorio: **C3 AMIGO** (el más robusto y suave, ya probado). Si hay tiempo: C1.

## Prueba de laboratorio (guía 2, `test_PID_servo_reg.py`)

Cambios hechos al script del profe:
- `Kc = 3.5686`, `tauI = 123.71`, `tauD = 0.0` (C3 AMIGO)
- Referencias: 44.7 °C (s 20), 54.2 °C (s 550), 49.5 °C (s 1000)
- Se dejó igual: `run_time = 35`, perturbación 1 con Q2 = 100 % entre 1500 y 1800 s

Checklist:
1. La fuente va al barril del **shield TCLab**, no al del Arduino.
2. Perturbación 2 (soplar o tapar el TCLab) **después de 1801 s**. Anotar el tiempo exacto.
3. Al terminar, renombrar `data.txt` y `test_PID.png` (se sobrescriben en cada corrida).
4. Antes de otra corrida, reiniciar el kernel de Spyder (si no: `AlreadyConnectedError`).
5. Para correr C1: `Kc = 5.6046`, `tauI = 142.16`.

## Pendientes

- **Confirmar con el profe las referencias.** Si "79-27-60" son tres temperaturas: 76.4, 44.7 y 66.2 °C.
- Enunciado, punto 7: como máximo **un** método visto en clase (Síntesis Analítica, uSORT, LGR). SIMC y AMIGO son de literatura → OK. Citar Skogestad (2003) y Åström & Hägglund (2006) en el informe.
- C4: hacer el diseño en el Control System Designer (`sisotool(P4)`) y sacar capturas; `Kc4 = 8` está puesto a mano.
- Justificar las especificaciones (Mp ≤ 10 %, ta2 ≤ 500 s, ep = 0, Ms ≤ 1.8) con la aplicación industrial.
- Simular en MATLAB/Python el mismo perfil de la prueba real para la comparación del punto 11.
- Nota para el informe: el 26/10 la planta necesitó Q1 ≈ 40 % (no 27 %) para 44.7 °C; el ambiente estaba más frío (21 °C vs 27 °C).
