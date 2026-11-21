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

P1 = 0.346 *exp(-22.3 *s)/(190.7 *s + 1);

P2 = 0.3475 *exp(-32.0 *s)/(172.4 *s + 1);

P3 = 0.3475 *exp(-36.3 *s)/(171.1 *s + 1);

P4d = (0.01666 *z^(-4) + 0.008841 *z^(-5) - 0.004581 *z^(-6)) / ...
     (1 - 0.7908 *z^(-1) - 0.007349 *z^(-2) - 0.1417 *z^(-3));

% controladores en servocontrol

Kp = 4 ;
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

Kp = 10 ;
Ti = 80.3 ;
C1r = Kp *( 1 + 1/( Ti *s) ) ;

% Kp = ;
% Ti = ;
% C2r = Kp *( 1 + 1/( Ti *s) ) ;
% 
% Kp = ;
% Ti = ;
% C4r = Kp *( 1 + 1/( Ti *s) ) ;


















% --------------------------------------------------
%% Pruebas Simuladas
% --------------------------------------------------

figure
ly = tiledlayout(1,1);
ly.Padding = "tight";

t = (0:9:1210)';

u = 79*(t >= 10);

y1 = 27 + lsim(P1, u, t);
y2 = 27 + lsim(P2, u, t);
y3 = 27 + lsim(P3, u, t);
y4 = 27 + lsim(P4d, u, t);

plot(t, y1, 'LineWidth', 1.5)
hold on
plot(t, y2, 'LineWidth', 1.5)
plot(t, y3, 'LineWidth', 1.5)
plot(t, y4, 'LineWidth', 1.5)

plot(t_iden, temp1_iden, 'Color', 'b', 'LineStyle', '-')

plot(t, u)

xlim([0, 1210])
ylim([0, 90])

ylabel('Temperatura (^oC)')
xlabel('Tiempo (s)')
title('Comparación de modelos')
subtitle('Respuesta ante un escalón de amplitud 79')

legend('P_1', 'P_2', 'P_3', 'P_{4d}', ...
       'Experimental', 'Location', 'southeast')

set(gca, 'FontSize', 19)
grid on




















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
% exportgraphics(gcf, 'figuras_experimentales/pruebaExp_identificacion.pdf', 'ContentType', 'vector');


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
% exportgraphics(gcf, 'figuras_experimentales/pruebaExp_simc.pdf', 'ContentType', 'vector');


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
% exportgraphics(gcf, 'figuras_experimentales/pruebaExp_sisotool.pdf', 'ContentType', 'vector');