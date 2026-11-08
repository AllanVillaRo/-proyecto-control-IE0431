%% IE-0431 Sistemas de Control - Proyecto final II-2026
% Equipo 2-10 | Planta: control de temperatura (TMP36 + TIP31C)
% Punto de operacion asignado: 79-27-60

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