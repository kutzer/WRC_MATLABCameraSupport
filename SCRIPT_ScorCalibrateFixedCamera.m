%% SCRIPT_ScorCalibrateFixedCamera

%% Initialize
if ~ScorIsReady
    ScorInit;
    ScorHome;
end

[~,prv] = initCamera;
drawnow;

%% Calibrate
[A_c2m,H_o2c,H_t2c] = ScorCalibrateFixedCamera(prv);

%% Visualize results
sim = ScorSimInit;
ScorSimPatch(sim);

hgCamera = drawDFKCam;
set(hgCamera,'Parent',sim.hFrame0);
set(hgCamera,'Matrix',H_o2c^(-1));

hgTable  = triad('Parent',hgCamera,'LineWidth',2,'AxesLabels',{'x_t','y_t','z_t'},'Scale',50);
set(hgCamera,'Matrix',H_t2c);