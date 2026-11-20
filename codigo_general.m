%% IE-0431 Sistemas de Control - Proyecto final II-2026
% Equipo 2-10
% Punto de operacion asignado 79-27-60

% --------------- Integrantes ---------------
% Sebastián Vila Brizuela C4k950
% Juan Diego Coto Calderón C22444
% Allan Villalobos Rojas C28447

clear; clc; close all;
set(groot, 'defaultLineLineWidth', 2)



% --------------------------------------------------
%% Cargar Datos
% --------------------------------------------------


archivo_actual = matlab.desktop.editor.getActiveFilename;

carpeta_actual = fileparts(archivo_actual);

% datos de identificacion

dtIdentificacion = fullfile(carpeta_actual, 'datos', 'tclab_ident_data_Q1_v_79-27-60.txt');

dtIdentificacion = readtable(dtIdentificacion);

t = dtIdentificacion.Time_sec_ ;
Heater1 = dtIdentificacion.Heater1___ ;
Heater2 = dtIdentificacion.Heater2___ ;
Temp1 = dtIdentificacion.Temperature1_degC_ ;
Temp2 = dtIdentificacion.Temperature2_degC_ ;





% --------------------------------------------------
%% Identificación de Modelos
% --------------------------------------------------


figure
plot(t, Heater1)
hold on
plot(t, Temp1)

xlim([0, max(t)])
ylim([0, 100])

title("Respuesta del Sistema a Escalón")
xlabel('Tiempo [s]')
ylabel('Magnitud [%]')
legend('u{(t)}', 'y{(t)}', 'Location', 'best')
grid on

set(gca, 'FontSize', 22)





% --------------------------------------------------
%% Modelos
% --------------------------------------------------

s = tf('s') ;

P1 = 0.346 / (190.7*s + 1) ;
P1.InputDelay = 22.3 ;

P2 = 0.3475 / (172.4*s + 1) ;
P2.InputDelay = 32 ;

P3 = 0.3475 / (171.1*s + 1) ;
P3.InputDelay = 22.3 ;

Ts = 9 ;
z = tf('z', Ts) ;

P4 = (0.01666*z^(-4) + 0.008841*z^(-5) - 0.004581*z^(-6)) / (1 - 0.7908*z^(-1) - 0.007349*z^(-2) - 0.1417*z^(-3));











t = (0:9:3000)';

r = zeros(size(t));

r(t >= 10)   = 79;
r(t >= 1220) = 27;
r(t >= 2220) = 60;

figure
plot(r, Temp1)
plot(t, Heater1)
hold on
lsim(P1, r, t)
lsim(P2, r, t)
lsim(P3, r, t)
lsim(P4, r, t)

xlim([0, max(t)])
ylim([0, 100])

title("Respuesta del Sistema a Escalón")
xlabel('Tiempo [s]')
ylabel('Magnitud [%]')
grid on

set(gca, 'FontSize', 22)