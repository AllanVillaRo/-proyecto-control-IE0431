%% IE-0431 Sistemas de Control - Proyecto final II-2026
% Equipo 2-10
% Punto de operacion asignado 79-27-60

% --------------- Integrantes ---------------
% Sebastián Vila Brizuela C4k950
% Juan Diego Coto Calderón C22444
% Allan Villalobos Rojas C28447

clear; clc; close all;
set(groot, 'defaultLineLineWidth', 2.5)

% Descripción: este código se encarga de calcular las plantas y
% controladores utilizados.











% --------------------------------------------------
%% Cargar Datos de Pruebas Experimentales
% --------------------------------------------------


archivo_actual = matlab.desktop.editor.getActiveFilename;

carpeta_actual = fileparts(archivo_actual);


% datos de identificacion

dtIdentificacion = fullfile(carpeta_actual, 'tclab_ident_data_Q1_v_79-27-60.txt');

dtIdentificacion = readtable(dtIdentificacion);

t_iden = dtIdentificacion.Time_sec_ ;
heater1_iden = dtIdentificacion.Heater1___ ;
heater2_iden = dtIdentificacion.Heater2___ ;
temp1_iden = dtIdentificacion.Temperature1_degC_ ;
temp2_iden = dtIdentificacion.Temperature2_degC_ ;

Ts = mean(diff(t_iden));


% --------------------------------------------------
%% Seleccionar intervalo de identificación
% --------------------------------------------------

idx = t_iden >= 0 & t_iden <= 1117.45;

t_iden = t_iden(idx);
heater1_iden = heater1_iden(idx);
temp1_iden = temp1_iden(idx);


% ---------------------------------------------
%% 2. Punto de operacion y variables de desviacion
% ---------------------------------------------

% Instante del escalon: primera muestra donde u cambia de forma apreciable
k0 = find(abs(heater1_iden - heater1_iden(1)) > 0.5, 1);
if isempty(k0), error('No se detecto el escalon en la senal de control.'); end
t0 = t_iden(k0);

u0 = mean(heater1_iden(1:max(k0-1,1)));
y0 = mean(temp1_iden(1:max(k0-1,1)));
nfin = max(5, round(0.05*numel(temp1_iden)));
uf = mean(heater1_iden(end-nfin+1:end));
yf = mean(temp1_iden(end-nfin+1:end));

du = heater1_iden - u0;
dy = temp1_iden - y0;

Du = uf - u0;
Dy = yf - y0;
Kp_proc = Dy/Du;


% ---------------------------------------------
%% 3. Tiempos caracteristicos de la curva
% ---------------------------------------------

ys = movmean(dy, max(3, round(numel(dy)/200)));
yn = ys/Dy;

tp = t_iden - t0;
tx = @(p) cruce(tp(k0:end), yn(k0:end), p);

t25 = tx(0.25);
t75 = tx(0.75);
t28 = tx(0.283);
t63 = tx(0.632);








% --------------------------------------------------
%% Parte 1: Identificación del Sistema
% --------------------------------------------------

idx = t_iden >= 0 & t_iden <= 1117.45;
t_iden = t_iden(idx);
heater1_iden = heater1_iden(idx);
temp1_iden = temp1_iden(idx);

% curva de reacción
t0 = 120.0488;
k0 = find(t_iden >= t0, 1);

u0 = 0;
uf = 79;
y0 = mean(temp1_iden(1:k0-1));
yf = mean(temp1_iden(end-4:end));

du = heater1_iden - u0;
dy = temp1_iden - y0;

Du = uf - u0;
Dy = yf - y0;

Kp_proc = Dy/Du;


% parámetros para la identificación
ys = movmean(dy, max(3, round(numel(dy)/200)));  % Suaviza ruido de cuantización
yn = ys/Dy;                                       % Respuesta normalizada 0 -> 1
tp = t_iden - t0;                                 % Tiempo desde el escalón
tx = @(p) cruce(tp(k0:end), yn(k0:end), p);       % Tiempo al p (fracción) de Dy

t25 = tx(0.25);
t75 = tx(0.75);
t28 = tx(0.283);
t63 = tx(0.632);














% --------------------------------------------------
%% Parte 2: Identificación del Sistema
% --------------------------------------------------


s = tf('s');


% ----- M1: System Identification Toolbox, modelo P1D -----
dat = iddata(dy, du, Ts);
opt = procestOptions('InitialCondition','zero');
M1id = procest(dat, 'P1D', opt);

P1 = tf(M1id);
P1.InputDelay = M1id.Td;
P1


% ----- M2: Alfaro 123c, primer orden más tiempo muerto -----
tau2 = 0.9102*(t75 - t25);
L2   = max(0, 1.2620*t25 - 0.2620*t75);

P2 = Kp_proc/(tau2*s + 1);
P2.InputDelay = L2;
P2


% ----- M3: Smith (28.3 % y 63.2 %), primer orden más tiempo muerto -----
tau3 = 1.5*(t63 - t28);
L3   = max(0, t63 - tau3);

P3 = Kp_proc/(tau3*s + 1);
P3.InputDelay = L3;
P3


% ----- M4: Minimos cuadrados, ARX de orden 3 -----

% Se submuestrea para que haya ~20 muestras por constante de tiempo.
na = 3;
nb = 3;

Nd = max(1, round((tau2/20)/Ts));
Tls = Nd*Ts;

idx = 1:Nd:numel(t_iden);

yk = dy(idx);
uk = du(idx);

nk = max(0, round(L2/Tls));

% Índice inicial de la regresión
kini = max(na, nb+nk-1) + 1;
N = numel(yk);
% Matriz de regresión
Phi = zeros(N-kini+1, na+nb);
Yr = yk(kini:N);
for k = kini:N
    Phi(k-kini+1,:) = [-yk(k-1:-1:k-na)', ...
                        uk(k-nk:-1:k-nk-nb+1)'];
end
theta = Phi\Yr;
% Coeficientes del modelo ARX
a = [1, theta(1:na)'];
b = [zeros(1,nk), theta(na+1:end)'];

P4 = tf(b, a, Tls, 'Variable','z^-1');
P4 = minreal(P4)












% ---------------------------------------------
%% Funciones locales utilizadas
% ---------------------------------------------


function tc = cruce(t, yn, p)
% Primer instante (interpolado) en que la respuesta normalizada alcanza p
    k = find(yn >= p, 1);
    if isempty(k), error('La respuesta no alcanza el %.1f %% del cambio.', 100*p); end
    if k == 1, tc = t(1); return; end
    tc = t(k-1) + (p - yn(k-1))*(t(k) - t(k-1))/(yn(k) - yn(k-1));
end