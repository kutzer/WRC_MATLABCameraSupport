%% SCRIPT_ScorCalibrateFixedCamera

%% Initialize
if ~ScorIsReady
    ScorInit;
    ScorHome;
end

[~,prv] = initCamera;
drawnow;

%% Calibrate
[A_c2m,H_c2o,H_c2o] = ScorCalibrateFixedCamera(prv);

return
%% Visualize results
sim = ScorSimInit;
ScorSimPatch(sim);
zlim(sim.Axes,[-10,1500]);

H_c2o = H_o2c^(-1);
hgCamera = drawDFKCam;
set(hgCamera,'Parent',sim.Frames(1));
set(hgCamera,'Matrix',H_c2o);

hgTable  = triad('Parent',hgCamera,'LineWidth',2,'AxisLabels',{'x_t','y_t','z_t'},'Scale',50);
set(hgCamera,'Matrix',H_t2c);