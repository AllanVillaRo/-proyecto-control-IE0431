%% IE-0431 Sistemas de Control - Proyecto final II-2026
% Equipo 2-10
% Punto de operacion asignado 79-27-60

% --------------- Integrantes ---------------
% Sebastián Vila Brizuela C4k950
% Juan Diego Coto Calderón C22444
% Allan Villalobos Rojas C28447

clear; clc; close all;
set(groot, 'defaultLineLineWidth', 2.5)

% Descripción: este código se encarga del calculo de distintos parámetros
% que necesitamos. Indices de error, tiempos de asentamiento, entre otros.











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


% datos prueba 1 con controlador SIMC

dtSIMC = fullfile(carpeta_actual, 'dataPrueba1.txt');

dtSIMC = readtable(dtSIMC);

t_simc = dtSIMC.Time_sec_ ;
heater1_simc = dtSIMC.Heater1___ ;
heater2_simc = dtSIMC.Heater2___ ;
temp1_simc = dtSIMC.Temperature1_degC_ ;
temp2_simc = dtSIMC.Temperature2_degC_ ;
setpoint1_simc = dtSIMC.SetPoint1_degC_ ;
setpoint2_simc = dtSIMC.SetPoint1_degC_ ;


% datos prueba 2 con controlador Sisotool

dtSisotool = fullfile(carpeta_actual, 'dataprueba2.txt');

dtSisotool = readtable(dtSisotool);

t_siso = dtSisotool.Time_sec_ ;
heater1_siso = dtSisotool.Heater1___ ;
heater2_siso = dtSisotool.Heater2___ ;
temp1_siso = dtSisotool.Temperature1_degC_ ;
temp2_siso = dtSisotool.Temperature2_degC_ ;
setpoint1_siso = dtSisotool.SetPoint1_degC_ ;
setpoint2_siso = dtSisotool.SetPoint1_degC_ ;











% --------------------------------------------------
%% Cargar Plantas y Controladores para Simulaciones
% --------------------------------------------------


s = tf('s') ;
z = tf('z', 9) ;
Ts = 9 ;


% plantas

P1 = 1.9 * 0.346 *exp(-22.3 *s)/(190.7 *s + 1);

P2 = 1.9 * 0.3475 *exp(-32.0 *s)/(172.4 *s + 1);

P3 = 1.9 * 0.3475 *exp(-36.3 *s)/(171.1 *s + 1);

P4d = 1.9 * (0.01666 *z^(-4) + 0.008841 *z^(-5) - 0.004581 *z^(-6)) / ...
     (1 - 0.7908 *z^(-1) - 0.007349 *z^(-2) - 0.1417 *z^(-3));


% controladores en servocontrol

Kp = 2.1 ;
Ti = 98.4 ;
C1s = Kp *( 1 + 1/( Ti *s) ) ;

Kp = 12.4 ;
Ti = 178 ;
C2s = Kp *( 1 + 1/( Ti *s) ) ;

Kp = 12.4 ;
Ti = 3.93e3 ;
C3s = Kp *( 1 + 1/( Ti *s) ) ; % no tiene par para regulatorio

Kp = 8 ;
Ti = 192 ;
C4s = Kp *( 1 + Ts *z/( Ti *(z-1)) ) ;


% controladores en regulatorio

% Kp = ;
% Ti = ;
% C2r = Kp *( 1 + 1/( Ti *s) ) ;

Kp = 10 ;
Ti = 80.3 ;
C1r = Kp *( 1 + 1/( Ti *s) ) ;

% Kp = ;
% Ti = ;
% C4r = Kp *( 1 + 1/( Ti *s) ) ;











% Evaluación del último escalón: Q1 = 27 % -> 60 %
tPaso = 2220;      
Nprevio = 120;     % muestras previas al escalón

k0 = find(t_iden >= tPaso, 1, 'first');
kini = max(1, k0 - Nprevio);

t = t_iden(kini:end);
t = t - t(1);

u = heater1_iden(kini:end);
y = temp1_iden(kini:end);     % temperatura real, en °C

% Punto de operación antes de aplicar 60 %
u0 = mean(u(1:k0-kini));
y0 = mean(y(1:k0-kini));

% Variables de desviación
du = u - u0;
dy = y - y0;

% Salida estimada de cada planta: desviación de temperatura en °C
ym1 = lsim(P1, du, t);
ym2 = lsim(P2, du, t);
ym3 = lsim(P3, du, t);

% Para reportar temperaturas absolutas
T1_modelo = y0 + ym1;
T2_modelo = y0 + ym2;
T3_modelo = y0 + ym3;

% Errores e índices IAE
E1 = dy - ym1;
E2 = dy - ym2;
E3 = dy - ym3;

IAE1 = trapz(t, abs(E1));
IAE2 = trapz(t, abs(E2));
IAE3 = trapz(t, abs(E3));

tablaIAE = table(IAE1, IAE2, IAE3, ...
    'VariableNames', {'P1','P2','P3'});
disp(tablaIAE)


%%
dat = iddata(temp1_iden - 27, heater1_iden, 1.0007);

compare(dat, P1, P2, P3)

%%
compare(dat, P2D, P1D)
