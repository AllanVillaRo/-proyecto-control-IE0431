%% IE-0431 Sistemas de Control - Proyecto final II-2026
% Equipo 2-10
% Punto de operacion asignado 79-27-60

% --------------- Integrantes ---------------
% Sebastián Vila Brizuela C4k950
% Juan Diego Coto Calderón C22444
% Allan Villalobos Rojas C28447

clear; clc; close all;
set(groot, 'defaultLineLineWidth', 2.5)

% Descripción: este código solo se encarga de producir las figuras
% utilizadas durante el proyecto












% --------------------------------------------------
%% Cargar Datos de Pruebas Experimentales
% --------------------------------------------------


archivo_actual = matlab.desktop.editor.getActiveFilename;

carpeta_actual = fileparts(archivo_actual);


% datos de identificacion

dtIdentificacion = fullfile(carpeta_actual, 'datos', 'tclab_ident_data_Q1_v_79-27-60.txt');

dtIdentificacion = readtable(dtIdentificacion);

t_iden = dtIdentificacion.Time_sec_ ;
heater1_iden = dtIdentificacion.Heater1___ ;
heater2_iden = dtIdentificacion.Heater2___ ;
temp1_iden = dtIdentificacion.Temperature1_degC_ ;
temp2_iden = dtIdentificacion.Temperature2_degC_ ;


% datos prueba 1 con controlador SIMC

dtSIMC = fullfile(carpeta_actual, 'datos', 'dataPrueba1.txt');

dtSIMC = readtable(dtSIMC);

t_simc = dtSIMC.Time_sec_ ;
heater1_simc = dtSIMC.Heater1___ ;
heater2_simc = dtSIMC.Heater2___ ;
temp1_simc = dtSIMC.Temperature1_degC_ ;
temp2_simc = dtSIMC.Temperature2_degC_ ;
setpoint1_simc = dtSIMC.SetPoint1_degC_ ;
setpoint2_simc = dtSIMC.SetPoint1_degC_ ;


% datos prueba 2 con controlador Sisotool

dtSisotool = fullfile(carpeta_actual, 'datos', 'dataprueba2.txt');

dtSisotool = readtable(dtSisotool);

t_siso = dtSisotool.Time_sec_ ;
heater1_siso = dtSisotool.Heater1___ ;
heater2_siso = dtSisotool.Heater2___ ;
temp1_siso = dtSisotool.Temperature1_degC_ ;
temp2_siso = dtSisotool.Temperature2_degC_ ;
setpoint1_siso = dtSisotool.SetPoint1_degC_ ;
setpoint2_siso = dtSisotool.SetPoint1_degC_ ;











% --------------------------------------------------
%% Pruebas Simuladas
% --------------------------------------------------























% --------------------------------------------------
%% Pruebas Experimentales
% --------------------------------------------------


% figura para la identificación
figure
ly = tiledlayout(1,1);

ly.Padding = "tight";

plot(t_iden, heater1_iden, 'Color', [0 0.75 0], 'LineStyle', '--')
hold on

plot(t_iden, temp1_iden, 'Color', 'b')

xlim([0, 3210])
ylim([0, 90])

ylabel('Temperatura (^oC)')
xlabel('Tiempo (s)')

ylabel('Temperatura (^oC)')
xlabel('Tiempo (s)')
title('Prueba Experimental')
subtitle('Identificación del Sistema')

legend('x(t)', 'y(t)', 'Location', 'southeast')

set(gca, 'FontSize', 19)
grid on
exportgraphics(gcf, 'figuras_experimentales/pruebaExp_identificacion.pdf', 'ContentType', 'vector');


% ----- figuras para simc -----

figure
ly = tiledlayout(2,1);

ly.Padding = 'tight';

sgtitle(ly, 'Prueba Experimental de Controlador', ...
    'FontSize', 21, 'FontWeight', 'bold')
subtitle(ly, 'Sintonizado por SIMC para Servocontrol', ...
    'FontSize', 20)

% figura 1
nexttile
plot(t_simc, setpoint1_simc, 'Color', [0 0.75 0], 'LineStyle', '--')
hold on

plot(t_simc, temp1_simc, 'Color', 'b')

xlim([0, 2099])
ylim([0, 90])

ylabel('Temperatura (^oC)')
xlabel('Tiempo (s)')

legend('r(t)', 'y(t)', 'Location', 'best')

set(gca, 'FontSize', 19)
grid on

% figura 2
nexttile
plot(t_simc, setpoint1_simc, 'Color', [0 0.75 0], 'LineStyle', '--')
hold on

plot(t_simc, heater1_simc, 'Color', [0.75 0 1])
plot(t_siso, heater2_simc, 'Color', [1 0.75 0])

xlim([0, 2099])
ylim([-5, 105])

ylabel('Amplitud (%)')
xlabel('Tiempo (s)')

legend('r(t)', 'u(t)', 'd(t)', 'Location', 'best')

set(gca, 'FontSize', 19)
grid on
exportgraphics(gcf, 'figuras_experimentales/pruebaExp_simc.pdf', 'ContentType', 'vector');


% ----- figuras para sisotool -----

figure
ly = tiledlayout(2,1);

ly.Padding = 'tight';

sgtitle(ly, 'Prueba Experimental de Controlador', ...
    'FontSize', 21, 'FontWeight', 'bold')
subtitle(ly, 'Sintonizado por Sisotool para Servocontrol', ...
    'FontSize', 20)

% figura 1
nexttile
plot(t_siso, setpoint1_siso, 'Color', [0 0.75 0], 'LineStyle', '--')
hold on

plot(t_siso, temp1_siso, 'Color', 'b')

xlim([0, 2099])
ylim([0, 90])

ylabel('Temperatura (^oC)')
xlabel('Tiempo (s)')

legend('r(t)', 'u(t)', 'Location', 'best')

set(gca, 'FontSize', 19)
grid on

% figura 2
nexttile
plot(t_siso, setpoint1_siso, 'Color', [0 0.75 0], 'LineStyle', '--')
hold on

plot(t_siso, heater1_siso, 'Color', [0.75 0 1])
plot(t_siso, heater2_siso, 'Color', [1 0.75 0])

xlim([0, 2099])
ylim([0, 105])

ylabel('Amplitud (%)')
xlabel('Tiempo (s)')

legend('r(t)', 'u(t)', 'd(t)', 'Location', 'best')

set(gca, 'FontSize', 19)
grid on
exportgraphics(gcf, 'figuras_experimentales/pruebaExp_sisotool.pdf', 'ContentType', 'vector');