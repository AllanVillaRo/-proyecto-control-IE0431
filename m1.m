% 1) Importar
datos = readmatrix('tclab_ident_data_Q1_v_79-27-60.txt');
t = datos(:,1); u = datos(:,2); yC = datos(:,4);

% Remuestrear a 1 s exacto (hay un hueco en los datos)
Ts = 1;
tn = (0:Ts:t(end))';
u  = interp1(t, u,  tn, 'previous');
yC = interp1(t, yC, tn, 'linear');
t  = tn;

% Pasar temperatura a % (rango TMP36: -40 a 150 C), igual que el script
y = (yC + 40)/190*100;

% 2) Inspección visual de la prueba completa
figure; plot(t, u, t, y); grid on; legend('u [%]','y [%]');

% Recortar: desde 120 s antes del último escalón hasta el final
k = find(t >= 2222, 1);          % instante del escalón 27 -> 60 %
idx = (k-120):numel(t);
t = t(idx) - t(idx(1)); u = u(idx); y = y(idx);

% 3) Restar el punto de operación (promedio antes del escalón)
u0 = mean(u(1:119));
y0 = mean(y(1:119));
u_1 = u - u0;
y_1 = y - y0;
figure; plot(t, u_1, t, y_1); grid on; legend('\Delta u','\Delta y');
fprintf('u0 = %.2f %%   y0 = %.2f %%\n', u0, y0);