%% SCRIPT_ScorCalibrateFixedCamera

%% Initialize
if ~ScorIsReady
    ScorInit;
    ScorHome;
end

if ~exist('prv','var')
    [~,prv] = initCamera;
elseif ~ishandle(prv)
    imaqreset;
    [~,prv] = initCamera;
end
drawnow;

%% Calibrate
[A_c2m,H_c2o,H_t2o,cameraParams] = ScorCalibrateFixedCamera(prv);

%% Test calibration
ScorSetGripper('Close');
ScorWaitForMove;
im = get(prv,'CData');
fig = figure;
img = imshow(im);
axs = get(img,'Parent');
drawnow;
while ishandle(fig)
    ScorGoHome;
    ScorWaitForMove;
    im = get(prv,'CData');
    set(img,'CData',im);
    axes(axs);
    drawnow;
    [col,row] = ginput(1);
    X_m = [col; row];
    X_m = undistortPoints(X_m.', cameraParams).';
    
    [X_o,X_c] = ScorFixedCameraMatrix2Base(X_m,A_c2m,H_c2o,H_t2o);
    
    XYZPR = [transpose(X_o),-pi/2,0];
    ScorSetXYZPR(XYZPR);
    ScorWaitForMove;
end
