# -*- coding: utf-8 -*-
"""
IE-0431 Sistemas de Control - Proyecto final II-2026
Equipo 2-10 | Planta: control de temperatura (TMP36 + TIP31C)
Punto de operacion asignado: 79-27-60

Traduccion a Python (Spyder) del script de MATLAB untitled.m.
Solo usa numpy, scipy, matplotlib y pandas (vienen con Anaconda).

  1) Carga y normaliza los datos experimentales (0-100 %)
  2) Identifica 4 modelos: 3 continuos + 1 discreto
       M1: Ajuste no lineal POMTM (equivalente a procest 'P1D')
       M2: Metodo de Alfaro 123c (POMTM)
       M3: Metodo de Smith (dos puntos, POMTM)
       M4: Minimos cuadrados, ARX discreto de orden 3
  3) Compara los modelos (IAE, ISE y % de ajuste)
  4) Sintoniza 4 controladores PI (3 continuos + 1 discreto):
       C1: Equivalente a pidtune (margen de fase 60 grados)
       C2: SIMC de Skogestad (2003)
       C3: AMIGO de Astrom y Hagglund
       C4: PI discreto con el modelo de minimos cuadrados
  5) Simula servocontrol y regulatorio y mide Mp, ta2%, ep, IAE, TVu, Ms

En Spyder cada bloque "# %%" es una celda: Ctrl+Enter ejecuta la celda,
F5 ejecuta todo el archivo.
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.optimize import least_squares
from scipy.signal import lfilter

pd.set_option('display.width', 200)
pd.set_option('display.max_columns', 20)

# %% 0. Configuracion (lo unico que hay que revisar)
ARCHIVO_CSV = 'tclab_ident_data_Q1_v_79-27-60.txt'  # datos del equipo 2-10

# Archivo TCLab: 0 = tiempo [s], 1 = Heater 1 [%], 2 = Heater 2 [%],
#                3 = Temperature 1 [C], 4 = Temperature 2 [C]  (indices de Python)
# Se usa el lazo 1: u = Heater 1 (Q1), y = Temperature 1 (T1).
COL_T, COL_U, COL_Y = 0, 1, 3
# Prueba: Q1 = 0 -> 79 -> 27 -> 60 %. Se identifica con el ultimo escalon.
N_PREVIO = 120          # muestras antes del escalon que se conservan
Y_EN_CELSIUS = True     # True si la salida viene en grados C
U_EN_PORCENTAJE = True  # True si la senal de control ya viene en 0-100 %
U_MAX_FISICO = 255      # solo si U_EN_PORCENTAJE = False (ej. PWM 0-255)
T_MIN, T_MAX = -40.0, 150.0  # rango del sensor TMP36 [C]

DR = 5.0   # cambio en el valor deseado (servocontrol) [%]
DD = 5.0   # cambio en la perturbacion (regulatorio) [%]

ESP = dict(Mp_max=10,    # sobrepaso maximo [%]
           ta2_max=500,  # tiempo de asentamiento al 2 % [s]
           ep_max=0,     # error permanente [%]
           Ms_max=1.8)   # sensibilidad maxima

# Si ya tiene los valores de pidtune de MATLAB y quiere usarlos exactos,
# escribalos aqui, ej. C1_MATLAB = (Kp, Ti). Con None se calcula en Python.
C1_MATLAB = None

# %% Funciones auxiliares


def cruce(t, yn, p):
    """Primer instante (interpolado) en que la respuesta normalizada alcanza p."""
    k = np.argmax(yn >= p)
    if yn[k] < p:
        raise ValueError(f'La respuesta no alcanza el {100*p:.1f} % del cambio.')
    if k == 0:
        return t[0]
    return t[k-1] + (p - yn[k-1])*(t[k] - t[k-1])/(yn[k] - yn[k-1])


def sim_pomtm(K, tau, L, u, dt):
    """Respuesta exacta de K e^{-Ls}/(tau s + 1) a una entrada u retenida
    (ZOH) muestreada cada dt, con condicion inicial cero (como lsim)."""
    tau = max(tau, 1e-9)
    L = max(L, 0.0)
    m = int(np.floor(L/dt))
    f = L/dt - m                     # parte fraccionaria del retardo
    a = np.exp(-dt/tau)
    b1 = K*(np.exp(-(1 - f)*dt/tau) - a)   # peso de u[k-m-1]
    b2 = K*(1 - np.exp(-(1 - f)*dt/tau))   # peso de u[k-m]
    n = len(u)
    up = np.concatenate([np.zeros(m + 1), u])   # u retrasado
    y = np.zeros(n)
    for k in range(n - 1):
        y[k+1] = a*y[k] + b1*up[k] + b2*up[k+1]
    return y


def pi_cont(Kp, Ti, w):
    return Kp*(1 + 1/(1j*w*Ti))


def P_cont(K, tau, L, w):
    return K*np.exp(-1j*w*L)/(1j*w*tau + 1)


def sintonia_pm(K, tau, L, PM=60.0):
    """Equivalente aproximado de pidtune(P,'PI') con margen de fase PM.
    Para cada frecuencia de cruce wc calcula el PI que da exactamente PM y
    escoge el de mayor ganancia integral Ki = Kp/Ti (mejor rechazo de
    perturbaciones), con margen de ganancia >= 6 dB y Ms <= 2."""
    mejor = None
    for wc in np.logspace(-4, 1, 4000)/max(tau, 1e-6):
        phiP = -wc*L - np.arctan(wc*tau)
        phiC = np.deg2rad(-180 + PM) - phiP        # fase que debe dar el PI
        if not (-np.pi/2 < phiC < -1e-3):
            continue
        Ti = 1/(wc*np.tan(-phiC))
        Kp = 1/(abs(P_cont(K, tau, L, wc))*np.sqrt(1 + 1/(wc*Ti)**2))
        w = np.logspace(np.log10(wc) - 3, np.log10(wc) + 2, 2000)
        Lw = pi_cont(Kp, Ti, w)*P_cont(K, tau, L, w)
        Ms = np.max(1/abs(1 + Lw))
        # margen de ganancia: |L| donde la fase cruza -180
        fase = np.unwrap(np.angle(Lw))
        i180 = np.where(fase <= -np.pi)[0]
        GM = 1/abs(Lw[i180[0]]) if len(i180) else np.inf
        if GM < 2 or Ms > 2:
            continue
        if mejor is None or Kp/Ti > mejor[0]:
            mejor = (Kp/Ti, Kp, Ti, wc)
    if mejor is None:
        raise RuntimeError('No se encontro un PI con el margen de fase pedido.')
    return mejor[1], mejor[2]


def ajuste(y, ym):
    """% de ajuste NRMSE (misma formula que compare de MATLAB)."""
    return 100*(1 - np.linalg.norm(y - ym)/np.linalg.norm(y - np.mean(y)))


def tiempo_asent(t, y, yfin, tol=0.02):
    """Tiempo de asentamiento: ultimo instante fuera de la banda +-tol*yfin."""
    fuera = np.where(np.abs(y - yfin) > tol*abs(yfin))[0]
    if len(fuera) == 0:
        return 0.0
    if fuera[-1] == len(t) - 1:
        return np.nan                   # no se asienta en el horizonte
    return t[fuera[-1] + 1]


def lazo_continuo(K, tau, L, Kp, Ti, r, d, dt, n):
    """Simula lazo cerrado PI continuo + POMTM con paso fino dt.
    r y d son escalones constantes. Devuelve y, u (desviacion)."""
    m = int(np.floor(L/dt))
    f = L/dt - m
    a = np.exp(-dt/tau)
    b1 = K*(np.exp(-(1 - f)*dt/tau) - a)
    b2 = K*(1 - np.exp(-(1 - f)*dt/tau))
    buf = np.zeros(m + 2)          # historial de la entrada a la planta
    x = 0.0
    I = 0.0
    y = np.zeros(n)
    u = np.zeros(n)
    for k in range(n):
        y[k] = x
        e = r - x
        u[k] = Kp*(e + I)
        I += dt/Ti*e
        buf = np.roll(buf, 1)
        buf[0] = u[k] + d
        # buf[m] = v[k-m], buf[m+1] = v[k-m-1]
        x = a*x + b1*buf[m+1] + b2*buf[m]
    return y, u


def lazo_discreto(b, a, Kp, Ti, Ts, r, d, n):
    """Lazo cerrado del PI discreto (Euler hacia atras) con el ARX
    A(z^-1) y = B(z^-1) u. Devuelve y, u (desviacion)."""
    na, nb = len(a) - 1, len(b)
    y = np.zeros(n)
    u = np.zeros(n)
    v = np.zeros(n)
    e_ant = 0.0
    u_ant = 0.0
    for k in range(n):
        y[k] = -sum(a[i]*y[k-i] for i in range(1, na + 1) if k - i >= 0) \
               + sum(b[j]*v[k-j] for j in range(nb) if k - j >= 0)
        e = r - y[k]
        u[k] = u_ant + Kp*(e - e_ant) + Kp*Ts/Ti*e
        v[k] = u[k] + d
        e_ant, u_ant = e, u[k]
    return y, u


def tf_texto_pomtm(K, tau, L):
    return f'{K:.4f} e^(-{L:.2f} s) / ({tau:.2f} s + 1)'


# %% 1. Carga de datos
try:
    carpeta = os.path.dirname(os.path.abspath(__file__))
except NameError:
    carpeta = os.getcwd()
ruta = os.path.join(carpeta, ARCHIVO_CSV)
if not os.path.isfile(ruta):
    raise FileNotFoundError(f'No se encontro {ruta}')
print(f'Datos cargados de: {ruta}')

datos = np.genfromtxt(ruta, delimiter=',', skip_header=1)
datos = datos[~np.isnan(datos).any(axis=1)]
t = datos[:, COL_T] - datos[0, COL_T]
u = datos[:, COL_U].copy()
y = datos[:, COL_Y].copy()

if Y_EN_CELSIUS:
    y = (y - T_MIN)/(T_MAX - T_MIN)*100        # C -> %
if not U_EN_PORCENTAJE:
    u = u/U_MAX_FISICO*100

Ts = np.median(np.diff(t))
# Se remuestrea siempre a una malla uniforme (el TCLab tiene ~1 ms de jitter)
tn = np.arange(0, t[-1] + 1e-9, Ts)
idx_prev = np.clip(np.searchsorted(t, tn, side='right') - 1, 0, len(t) - 1)
u = u[idx_prev]
y = np.interp(tn, t, y)
t = tn
print(f'Tiempo de muestreo de los datos: Ts = {Ts:.4f} s')

fig, ax = plt.subplots(2, 1, sharex=True, num='Prueba completa')
ax[0].plot(t, y*(T_MAX - T_MIN)/100 + T_MIN, lw=1.2); ax[0].grid(True)
ax[0].set_ylabel('T1 [C]')
ax[0].set_title('Prueba experimental completa (Q1: 0 → 79 → 27 → 60 %)')
ax[1].step(t, u, where='post', lw=1.2); ax[1].grid(True)
ax[1].set_ylabel('Q1 [%]'); ax[1].set_xlabel('Tiempo [s]')

# Tramo para identificar: desde N_PREVIO muestras antes del ultimo escalon
cambios = np.where(np.abs(np.diff(u)) > 0.5)[0] + 1
kult = cambios[-1]
kini = max(0, kult - N_PREVIO)
t = t[kini:] - t[kini]; u = u[kini:]; y = y[kini:]

# %% 2. Punto de operacion y variables de desviacion
k0 = np.argmax(np.abs(u - u[0]) > 0.5)
if k0 == 0:
    raise ValueError('No se detecto el escalon en la senal de control.')
t0 = t[k0]

u0 = np.mean(u[:k0]); y0 = np.mean(y[:k0])
nfin = max(5, round(0.05*len(y)))
uf = np.mean(u[-nfin:]); yf = np.mean(y[-nfin:])

du = u - u0; dy = y - y0
Du = uf - u0; Dy = yf - y0
Kp_proc = Dy/Du

print(f'\nPunto de operacion (de los datos): u0 = {u0:.2f} %, y0 = {y0:.2f} % '
      f'({y0*(T_MAX-T_MIN)/100 + T_MIN:.2f} C)')
print(f'Escalon: Du = {Du:.2f} %, Dy = {Dy:.2f} %, ganancia K = {Kp_proc:.4f} %/%')

fig, ax = plt.subplots(2, 1, sharex=True, num='Curva de reaccion')
ax[0].plot(t, y, lw=1.2); ax[0].grid(True); ax[0].set_ylabel('y [%]')
ax[0].set_title('Curva de reaccion del proceso (lazo abierto)')
ax[1].step(t, u, where='post', lw=1.2); ax[1].grid(True)
ax[1].set_ylabel('u [%]'); ax[1].set_xlabel('Tiempo [s]')

# %% 3. Tiempos caracteristicos de la curva (sobre la salida suavizada)
ventana = max(3, round(len(dy)/200))
ys = pd.Series(dy).rolling(ventana, center=True, min_periods=1).mean().to_numpy()
yn = ys/Dy
tp = t - t0
t25 = cruce(tp[k0:], yn[k0:], 0.25)
t75 = cruce(tp[k0:], yn[k0:], 0.75)
t28 = cruce(tp[k0:], yn[k0:], 0.283)
t63 = cruce(tp[k0:], yn[k0:], 0.632)

# %% 4. Identificacion de modelos
# --- M2: Alfaro 123c ---
tau2 = 0.9102*(t75 - t25)
L2 = max(0.0, 1.2620*t25 - 0.2620*t75)

# --- M3: Smith (28.3 % y 63.2 %) ---
tau3 = 1.5*(t63 - t28)
L3 = max(0.0, t63 - tau3)

# --- M1: ajuste no lineal POMTM (lo mismo que hace procest con 'P1D') ---
# Minimiza el error de simulacion, partiendo del modelo de Alfaro.
def residuo(p):
    return dy - sim_pomtm(p[0], p[1], p[2], du, Ts)


sol = least_squares(residuo, x0=[Kp_proc, tau2, L2],
                    bounds=([0, 1e-3, 0], [np.inf, np.inf, 10*tau2]))
K1, tau1, L1 = sol.x

# --- M4: Minimos cuadrados, ARX de orden 3 ---
na, nb = 3, 3
Nd = max(1, round((tau2/20)/Ts))
Tls = Nd*Ts
idx = np.arange(0, len(t), Nd)
yk = dy[idx]; uk = du[idx]; tk = t[idx]
nk = max(1, round(L2/Tls))
kin = max(na, nb + nk - 1)             # primer indice valido (base 0)
N = len(yk)
Phi = np.zeros((N - kin, na + nb)); Yr = yk[kin:]
for k in range(kin, N):
    Phi[k - kin, :] = np.concatenate([-yk[k-na:k][::-1],
                                      uk[k-nk-nb+1:k-nk+1][::-1]])
theta = np.linalg.lstsq(Phi, Yr, rcond=None)[0]
a4 = np.concatenate([[1.0], theta[:na]])
b4 = np.concatenate([np.zeros(nk), theta[na:]])

modelos = {'M1 Ajuste P1D': (K1, tau1, L1),
           'M2 Alfaro 123c': (Kp_proc, tau2, L2),
           'M3 Smith': (Kp_proc, tau3, L3)}

print('\n--- Modelos identificados (desviacion, %/%) ---')
for nom, (K, tau, L) in modelos.items():
    print(f'{nom:15s}: K={K:.4f}  tau={tau:.2f} s  L={L:.2f} s   '
          f'P(s) = {tf_texto_pomtm(K, tau, L)}')
print(f'M4 MC ARX(3,3,{nk}), Ts={Tls:.3f} s')
num_txt = ' + '.join(f'{c:.5g} z^-{i}' for i, c in enumerate(b4) if c != 0)
den_txt = '1 ' + ' '.join(f'{c:+.5g} z^-{i}' for i, c in enumerate(a4) if i > 0)
print(f'   P4(z) = ({num_txt}) / ({den_txt})')

# %% 5. Comparacion de modelos
ym = [sim_pomtm(*p, du, Ts) for p in modelos.values()]
ym4k = lfilter(b4, a4, uk)
ym4 = ym4k[np.clip(np.searchsorted(tk, t, side='right') - 1, 0, len(tk) - 1)]
ym.append(ym4)
Ym = np.column_stack(ym)
nombres = list(modelos.keys()) + ['M4 MC ARX3']
E = dy[:, None] - Ym
IAE = np.trapezoid(np.abs(E), t, axis=0)
ISE = np.trapezoid(E**2, t, axis=0)
FIT = [ajuste(dy, Ym[:, i]) for i in range(4)]
Tmod = pd.DataFrame({'IAE': IAE, 'ISE': ISE, 'Ajuste_pct': FIT}, index=nombres)
print('\n--- Comparacion de modelos ---'); print(Tmod)

plt.figure('Comparacion de modelos')
plt.plot(t, dy, 'k', lw=1.5, label='Datos reales')
for i, nom in enumerate(nombres):
    plt.plot(t, Ym[:, i], lw=1.2, label=f'{nom} ({FIT[i]:.1f} %)')
plt.grid(True); plt.legend(loc='lower right')
plt.xlabel('Tiempo [s]'); plt.ylabel('Δy [%]')
plt.title('Respuesta de los modelos vs. proceso real')

# Mejor modelo continuo (los controladores continuos se sintonizan con el)
ib = int(np.argmin(IAE[:3]))
Kb, taub, Lb = list(modelos.values())[ib]
print(f'Mejor modelo continuo (menor IAE): {nombres[ib]}')

# %% 6. Sintonizacion de controladores PI
# K > 0 (subir Q1 sube T1) -> controlador de ACCION INVERSA: e = r - y.
accion = 'inversa' if Kb > 0 else 'directa'
print(f'\nGanancia del proceso K = {Kb:.4f} > 0  ->  controlador de accion {accion}')

# C1: equivalente a pidtune, margen de fase 60 grados
if C1_MATLAB is None:
    Kc1, Ti1 = sintonia_pm(Kb, taub, Lb, PM=60)
else:
    Kc1, Ti1 = C1_MATLAB

# C2: SIMC de Skogestad, tau_c = L
tauc = max(Lb, 0.1*taub)
Kc2 = taub/(Kb*(tauc + Lb))
Ti2 = min(taub, 4*(tauc + Lb))

# C3: AMIGO de Astrom y Hagglund (2004)
Kc3 = 0.15/Kb + (0.35 - Lb*taub/(Lb + taub)**2)*taub/(Kb*Lb)
Ti3 = 0.35*Lb + 13*Lb*taub**2/(taub**2 + 12*Lb*taub + 7*Lb**2)

# C4: PI discreto con el modelo de minimos cuadrados (cero sobre polo dominante)
pz = np.roots(a4)
pz = np.real(pz[np.abs(np.imag(pz)) < 1e-9])
pd_ = np.max(pz)
Ti4 = -Tls/np.log(pd_)
Kc4 = 8.0                     # ganancia escogida en sisotool

Cs = [(Kc1, Ti1), (Kc2, Ti2), (Kc3, Ti3), (Kc4, Ti4)]
cn = ['C1 PID Tuner', 'C2 SIMC', 'C3 AMIGO', 'C4 Discreto MC']

print('\n--- Controladores PI en forma estandar  C(s) = Kp(1 + 1/(Ti s)) ---')
for nom, (Kc, Ti) in zip(cn, Cs):
    print(f'{nom:15s} Kp = {Kc:.4f} %/%   Ti = {Ti:.2f} s   Td = 0.00 s')

print('\nFunciones de transferencia:')
for nom, (Kc, Ti) in zip(cn[:3], Cs[:3]):
    print(f'{nom:15s} C(s) = ({Kc:.4f} s + {Kc/Ti:.6f}) / s')
print(f'{cn[3]:15s} C(z) = {Kc4:.4f}*(1 + {Tls:.2f}/{Ti4:.2f} * z/(z-1))'
      f' = ({Kc4*(1+Tls/Ti4):.4f} z - {Kc4:.4f}) / (z - 1),  Ts = {Tls:.2f} s')

# %% 7. Simulacion: servocontrol y regulatorio en el punto de operacion
Tf = 10*(taub + Lb)
res = np.zeros((4, 9))
SUB = 20                                   # pasos finos por cada Ts (continuo)
figS, axS = plt.subplots(3, 1, sharex=True, num='Servocontrol', figsize=(8, 8))
figR, axR = plt.subplots(3, 1, sharex=True, num='Regulatorio', figsize=(8, 8))

for i, (Kc, Ti) in enumerate(Cs):
    if i == 3:       # discreto con el modelo de minimos cuadrados
        ts = np.arange(0, Tf + 1e-9, Tls); n = len(ts)
        ysv, usv = lazo_discreto(b4, a4, Kc, Ti, Tls, DR, 0, n)
        yrg, urg = lazo_discreto(b4, a4, Kc, Ti, Tls, 0, DD, n)
        wmax = np.pi/Tls
        w = np.logspace(np.log10(wmax) - 6, np.log10(wmax), 3000)
        z = np.exp(1j*w*Tls)
        P4w = np.polyval(b4[::-1], 1/z)/np.polyval(a4[::-1], 1/z)
        Cw = Kc*(1 + Tls/Ti*z/(z - 1))
        Ms = np.max(np.abs(1/(1 + Cw*P4w)))
    else:            # continuo con el mejor modelo
        ts = np.arange(0, Tf + 1e-9, Ts); n = len(ts)
        dt = Ts/SUB; nf = (n - 1)*SUB + 1
        ysv, usv = lazo_continuo(Kb, taub, Lb, Kc, Ti, DR, 0, dt, nf)
        yrg, urg = lazo_continuo(Kb, taub, Lb, Kc, Ti, 0, DD, dt, nf)
        ysv, usv, yrg, urg = ysv[::SUB], usv[::SUB], yrg[::SUB], urg[::SUB]
        wmax = 100/max(taub, 1e-3)
        w = np.logspace(np.log10(wmax) - 6, np.log10(wmax), 3000)
        Ms = np.max(np.abs(1/(1 + pi_cont(Kc, Ti, w)*P_cont(Kb, taub, Lb, w))))

    Mp = max(0.0, (np.max(ysv) - DR)/DR*100)
    ta = tiempo_asent(ts, ysv, DR)
    ep = (DR - ysv[-1])/DR*100
    IAEs = np.trapezoid(np.abs(DR - ysv), ts)
    TVs = np.sum(np.abs(np.diff(usv)))
    IAEr = np.trapezoid(np.abs(yrg), ts)
    epr = yrg[-1]/DD*100
    TVr = np.sum(np.abs(np.diff(urg)))
    res[i] = [Mp, ta, ep, IAEs, TVs, IAEr, epr, TVr, Ms]

    axS[0].plot(ts, y0 + ysv, lw=1.2, label=cn[i])
    axS[1].plot(ts, DR - ysv, lw=1.2)
    axS[2].plot(ts, u0 + usv, lw=1.2)
    axR[0].plot(ts, y0 + yrg, lw=1.2, label=cn[i])
    axR[1].plot(ts, -yrg, lw=1.2)
    axR[2].plot(ts, u0 + urg, lw=1.2)

    if np.any((u0 + usv > 100) | (u0 + usv < 0)) or \
       np.any((u0 + urg > 100) | (u0 + urg < 0)):
        print(f'AVISO: {cn[i]}: la senal de control sale del rango 0-100 %.')

axS[0].axhline(y0 + DR, color='k', ls='--', label='r')
axS[0].set_title(f'Servocontrol: escalon de {DR:g} % en r'); axS[0].legend()
axS[0].set_ylabel('y [%]'); axS[1].set_ylabel('e [%]'); axS[2].set_ylabel('u [%]')
axS[2].set_xlabel('Tiempo [s]')
axR[0].axhline(y0, color='k', ls='--', label='y0')
axR[0].set_title(f'Regulatorio: escalon de {DD:g} % en d'); axR[0].legend()
axR[0].set_ylabel('y [%]'); axR[1].set_ylabel('e [%]'); axR[2].set_ylabel('u [%]')
axR[2].set_xlabel('Tiempo [s]')
for a_ in list(axS) + list(axR):
    a_.grid(True)
figS.tight_layout(); figR.tight_layout()

Tctl = pd.DataFrame(res, index=cn, columns=[
    'Mp_pct', 'ta2_s', 'ep_servo_pct', 'IAE_servo', 'TVu_servo',
    'IAE_reg', 'ep_reg_pct', 'TVu_reg', 'Ms'])
print('\n--- Desempeno simulado de los controladores ---'); print(Tctl.round(4))

Tesp = pd.DataFrame({
    'Mp_ok': res[:, 0] <= ESP['Mp_max'],
    'ta2_ok': res[:, 1] <= ESP['ta2_max'],
    'ep_servo_ok': np.abs(res[:, 2]) <= ESP['ep_max'] + 0.5,
    'ep_reg_ok': np.abs(res[:, 6]) <= ESP['ep_max'] + 0.5,
    'Ms_ok': res[:, 8] <= ESP['Ms_max']}, index=cn).astype(int)
print('--- Cumplimiento de especificaciones (1 = cumple) ---'); print(Tesp)

# %% 8. Parametros para llevar al laboratorio
# Si el Arduino recibe la temperatura en C: Kp[%/C] = Kp[%/%]*100/(T_MAX-T_MIN)
print('\n=== Para el laboratorio (estructura PID estandar) ===')
for nom, (Kc, Ti) in zip(cn, Cs):
    print(f'{nom:15s} Kp = {Kc:.4f} %/%  ({Kc*100/(T_MAX-T_MIN):.4f} %/C)'
          f'   Ti = {Ti:.2f} s   Td = 0')
print(f'(C4 es discreto: periodo de muestreo Ts = {Tls:.0f} s, '
      'integral por Euler hacia atras)')
print(f'Punto de operacion: u0 = {u0:.2f} %,  y0 = {y0:.2f} % '
      f'({y0*(T_MAX-T_MIN)/100 + T_MIN:.2f} C)')

plt.show()
