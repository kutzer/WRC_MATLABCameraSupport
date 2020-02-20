%% SCRIPT_ScorCalibrateFixedCamera

%% Initialize
if ~ScorIsReady
    ScorInit;
    ScorHome;
end

[~,prv] = initCamera;
drawnow;

%% Calibrate
[A_c2m,H_c2o,H_t2o] = ScorCalibrateFixedCamera(prv);
