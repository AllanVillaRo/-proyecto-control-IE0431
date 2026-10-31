# -*- coding: utf-8 -*-
"""
IE-0431 Proyecto final - Equipo 2-10 - Prueba en la planta real (TCLab)
Controlador PI en estructura estandar  C(s) = Kp (1 + 1/(Ti s)),  Td = 0
El PI corre en la computadora; el Arduino (firmware TCLab) solo lee T1 y
aplica Q1. Todo se trabaja en 0-100 %, igual que en el diseno.

Secuencia de la prueba:
  1) Llevar la planta al punto de operacion (r = y0) en lazo cerrado
  2) Servocontrol: escalon de DR % en la referencia
  3) Regulatorio: perturbacion encendiendo el calentador 2 (Q2)
Al final guarda un .csv y grafica y, r, e, u.

Requisitos:  pip install tclab   (con el Arduino conectado por USB)
"""
import time
import numpy as np
import matplotlib.pyplot as plt
import tclab

# %% Configuracion
NOMBRE = 'C3_AMIGO'      # nombre para el archivo de resultados
Kp = 6.7804              # %/%   (C1 PID Tuner: copiar valores de MATLAB)
Ti = 123.71              # s
Ts = 1.0                 # periodo de muestreo del lazo [s]

T_MIN, T_MAX = -40.0, 150.0      # rango del TMP36 -> normalizacion
u0 = 27.0                        # punto de operacion: Q1 [%]
y0_C = 44.68                     # punto de operacion: T1 [C]
DR = 5.0                         # escalon en la referencia [%] (~9.5 C)
Q2_PERT = 50.0                   # perturbacion: potencia de Q2 [%]

T_ESTAB = 900     # s para llegar al punto de operacion
T_SERVO = 900     # s de prueba de servocontrol
T_REG = 900       # s de prueba regulatoria
SIMULAR = False   # True = usa el modelo de tclab (sin Arduino) para probar


def a_pct(T):
    return (T - T_MIN)/(T_MAX - T_MIN)*100


def a_C(p):
    return p*(T_MAX - T_MIN)/100 + T_MIN


y0 = a_pct(y0_C)
t_total = T_ESTAB + T_SERVO + T_REG

# %% Prueba
Lab = tclab.setup(connected=not SIMULAR, speedup=100 if SIMULAR else 1)
reg = []
with Lab() as lab:
    lab.Q1(0); lab.Q2(0)
    I = u0                   # integrador iniciado en u0 (arranque sin salto)
    for t in tclab.clock(t_total, Ts):
        y = a_pct(lab.T1)
        r = y0 + (DR if t >= T_ESTAB else 0.0)
        d = Q2_PERT if t >= T_ESTAB + T_SERVO else 0.0
        e = r - y                       # accion inversa
        u_sin = I + Kp*e
        u = min(max(u_sin, 0.0), 100.0)
        # anti-windup: solo integra si no esta saturado (o si ayuda a salir)
        if u == u_sin or (u_sin > 100 and e < 0) or (u_sin < 0 and e > 0):
            I += Kp*Ts/Ti*e
        lab.Q1(u); lab.Q2(d)
        reg.append([t, r, y, e, u, d, lab.T1, lab.T2])
        print(f't={t:6.0f} s  r={a_C(r):5.1f} C  T1={lab.T1:5.1f} C  '
              f'u={u:5.1f} %  Q2={d:4.0f} %')
    lab.Q1(0); lab.Q2(0)

# %% Guardar y graficar
reg = np.array(reg)
archivo = f'lab_{NOMBRE}_{time.strftime("%Y%m%d_%H%M")}.csv'
np.savetxt(archivo, reg, delimiter=',', comments='',
           header='t_s,r_pct,y_pct,e_pct,u_pct,Q2_pct,T1_C,T2_C')
print(f'Datos guardados en {archivo}')

t, r, y, e, u, d = reg[:, :6].T
fig, ax = plt.subplots(3, 1, sharex=True, figsize=(9, 8), num='Prueba real')
ax[0].plot(t, y, label='y (T1)'); ax[0].plot(t, r, 'k--', label='r')
ax[0].set_ylabel('y [%]'); ax[0].legend()
ax[0].set_title(f'{NOMBRE}: Kp = {Kp:.4f} %/%, Ti = {Ti:.2f} s')
ax[1].plot(t, e); ax[1].set_ylabel('e [%]')
ax[2].plot(t, u, label='u (Q1)'); ax[2].plot(t, d, label='d (Q2)')
ax[2].set_ylabel('[%]'); ax[2].set_xlabel('Tiempo [s]'); ax[2].legend()
for a in ax:
    a.grid(True)
    a.axvline(T_ESTAB, color='gray', ls=':')
    a.axvline(T_ESTAB + T_SERVO, color='gray', ls=':')
fig.tight_layout()
plt.show()
