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