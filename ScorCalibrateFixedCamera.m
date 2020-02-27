function [A_c2m,H_c2o,H_t2o,cameraParams] = ScorCalibrateFixedCamera(varargin)
% SCORCALIBRATEFIXEDCAMERA calculates the camera intrinsics and useful
% extrinsic matrices
%   [A_c2m,H_o2c,H_t2o] = SCORCALIBRATEFIXEDCAMERA(prv) takes a camera
%   preview (prv), collects a series of calibration images, and calculates:
%       A_c2m - camera intrinsic matrix
%       H_c2o - pose of camera frame relative to the ScorBot base frame.
%       H_t2o - pose of the "table" frame relative to the ScorBot base frame.
%
%   [A_c2m,H_o2c,H_t2o] = SCORCALIBRATEFIXEDCAMERA prompts the user to
%   select the folder associated with a previously run calibration, and
%   returns the values associated with the calibration.
%
%   [A_c2m,H_o2c,H_t2o] = SCORCALIBRATEFIXEDCAMERA(foldername) loads a
%   previously run calibration from a specified folder and returns the
%   values associated with that calibration.
%
%   [A_c2m,H_c2o,H_t2o,cameraParams] = ScorCalibrateFixedCamera(___) also
%   returns the camera parameters returned by the camera calibrator. This
%   can be useful if you need to undistort images or points:
%       undistorted_im = undistortImage(im,cameraParams)
%       undistortedPoints = undistortPoints(points, cameraParams)
%
%   M. Kutzer, 06Feb2020, USNA

% Updates
%   20Feb2020 - Updated to correct table/grid offset
%   20Feb2020 - Revised to allow multiple input types
%   27Feb2020 - Revised to include camera parameters as an optional output

global debugON sim icon

%% Set debug flag
debugON = true;
if debugON
    sim = ScorSimInit;
    ScorSimPatch(sim);
    
    for i = 1:5
        hideTriad( sim.Frames(i) );
    end
end

%% Define filename to save calibration variables
var_filename = 'CalibrationParameters.mat';

%% Define calibration foldername
% TODO - add time-stamped calibration foldername
pathName = 'ScorBot Fixed Camera Calibration';

%% Check input(s)
if nargin < 1
    % Prompt user to select directory
    foldername = uigetdir([],'Select Calibration Folder');
    % Check if user has cancelled action
    if foldername == 0
        A_c2m = [];
        H_c2m = [];
        H_t2o = [];
        warning('No folder was selected.');
        return;
    end
else
    % Check if input is
    if ~ishandle(varargin{1})
        % -> Not a handle
        %error('The input to this function must be a valid camera or webcam preview.');
        foldername = varargin{1};
        prv = [];
    else
        % -> A handle
        foldername = 0;
        prv = varargin{1};
    end
end

% Check if directory is provided
if ischar(foldername)
    if isfolder(foldername)
        
        load( fullfile(foldername,var_filename) );
        
        if debugON
            hg_cam = drawDFKCam;
            set(hg_cam,'Matrix',H_c2o,'Parent',sim.Frames(1));
            
            for i = 1:size(cameraParams.RotationMatrices,3)
                H_g2c{i} = ...
                    [cameraParams.RotationMatrices(:,:,i).',...
                    cameraParams.TranslationVectors(i,:).';...
                    0,0,0,1];
            end
            
            for i = 1:size(cameraParams.RotationMatrices,3)
                switch i
                    case idx_ScorBot
                        squareColors = {'g',[0.5,0.5,0.5]};
                    case idx_Table
                        squareColors = {'r',[0.5,0.5,0.5]};
                    otherwise
                        squareColors = {'k','w'};
                end

                hg_cb(i) = plotCheckerboard(boardSize,squareSize,squareColors);
                set(hg_cb(i),'Parent',hg_cam,'Matrix',H_g2c{i});
                
                hg_t2o = triad('Scale',50,'LineWidth',2,'Parent',sim.Frames(1),...
                    'AxisLabels',{'x_{t}','y_{t}','z_{t}'},'Matrix',H_t2o);
                axis(sim.Axes,'tight');
                
                ScorSimSetPose(sim,H_e2o);
                
                ScorSimSetGripper(sim,b);
                hg_g2e = triad('Scale',50,'LineWidth',2,'Parent',sim.Frames(6),...
                    'AxisLabels',{'x_{g}','y_{g}','z_{g}'},'Matrix',H_g2e);
            end
        end
        
        return;
        
    else
        error('Input must be a valid preview object or folder.');
    end
end

switch lower( prv.Type )
    case 'image'
        % Valid image object
    otherwise
        error('The input to this function must be a valid camera or webcam preview.');
end

if ~ScorIsReady
    error('ScorBot must be initialized and homed before running this function.');
end

%% Adjust ScorBot Speed
ScorBot_Speed = ScorGetSpeed;
ScorSetSpeed(100);

%% Adjust preview position
prvFIG = getParentFigure(prv);
set(prvFIG,'Units','Normalized');

pos = get(prvFIG,'Position');
dpos = 0.005;   % Distance from side of screen
wpos = 0.030;   % Window height
pos(1) = dpos;
pos(2) = 1-(pos(4) + dpos + wpos);

set(prvFIG,'Position',pos);

figure(prvFIG);

%% Load scorbot icon
icon = imread('Icon_ScorBot.png');

%% Take calibration images
fileBase_ScorBot = 'img_ScorBot';
fileBase_Hand = 'img_Handheld';
fileBase_Table = 'img_Table';

[imageNames_ScorBot,H_e2o,H_g2e,b,w,d] = getImages_ScorBot(prv,fileBase_ScorBot,pathName,1);
imageNames_Hand = getImages_Handheld(prv,fileBase_Hand,pathName,10);
imageNames_Table = getImages_Table(prv,fileBase_Table,pathName,1);

%% Combine image names
[imageNames,imageFileNames] = combineImages(pathName, imageNames_ScorBot, imageNames_Hand, imageNames_Table);

%% Calibrate camera
squareSize = 1.905000e+01;  % in units of 'millimeters'
[imageFileNames,cameraParams,estimationErrors,boardSize] = calibrateCamera(imageFileNames,squareSize);

%% Find ScorBot image index & Table image index
idx_ScorBot = [];
idx_Table = [];
RECALIBRATE = false;
while isempty(idx_ScorBot) || isempty(idx_Table)
    
    % Find Scorbot and table image
    for i = 1:numel(imageFileNames)
        % fileBase_ScorBot
        if ~isempty( strfind(imageFileNames{i},fileBase_ScorBot) )
            idx_ScorBot(end+1) = i;
        end
        
        % fileBase_Table
        if ~isempty( strfind(imageFileNames{i},fileBase_Table) )
            idx_Table(end+1) = i;
        end
    end
    
    if isempty(idx_ScorBot)
        fprintf(2,'!!! We need to take a new ScorBot Image !!!\n');
        RECALIBRATE = true;
        [imageNames_ScorBot,H_e2o,H_g2e,b,w,d] = getImages_ScorBot(prv,fileBase_ScorBot,pathName,1);
    end
    
    if isempty(idx_Table)
        fprintf(2,'!!! We need to take a new Table Image !!!\n');
        RECALIBRATE = true;
        imageNames_Table = getImages_Table(prv,fileBase_Table,pathName,1);
    end
    
    if RECALIBRATE
        [imageNames,imageFileNames] = combineImages(pathName, imageNames_ScorBot, imageNames_Hand, imageNames_Table);
        [imageFileNames,cameraParams,estimationErrors,boardSize] = calibrateCamera(imageFileNames,squareSize);
        RECALIBRATE = false;
    end
end

%% Calculate all extrinsics
for i = 1:size(cameraParams.RotationMatrices,3)
    H_g2c{i} = ...
        [cameraParams.RotationMatrices(:,:,i).',...
        cameraParams.TranslationVectors(i,:).';...
        0,0,0,1];
end

if debugON
    fig = figure;
    axs = axes('Parent',fig);
    hold(axs,'on');
    daspect(axs,[1 1 1]);
    hg_cam = drawDFKCam;
    for i = 1:size(cameraParams.RotationMatrices,3)
        switch i
            case idx_ScorBot
                squareColors = {'g',[0.5,0.5,0.5]};
            case idx_Table
                squareColors = {'r',[0.5,0.5,0.5]};
            otherwise
                squareColors = {'k','w'};
        end
        hg_cb(i) = plotCheckerboard(boardSize,squareSize,squareColors);
        set(hg_cb(i),'Parent',hg_cam,'Matrix',H_g2c{i});
    end
end

%% Package output(s)
%[A_c2m,H_o2c,H_t2o]
A_c2m = transpose( cameraParams.IntrinsicMatrix );

%% Calculate H_c2o & H_o2c
fprintf('SCORBOT Image - "%s"\n',imageFileNames{idx_ScorBot});
% TODO - consider multiple transforms (meanSE)
H_c2o = H_e2o*H_g2e*( H_g2c{idx_ScorBot(1)} )^(-1);

if debugON
    set(hg_cam,'Matrix',H_c2o,'Parent',sim.Frames(1));
    delete(fig);
end

%% Calculate H_t2c
fprintf('TABLE Image - "%s"\n',imageFileNames{idx_Table});
% TODO - consider multiple transforms (meanSE)
H_t2g = Tz(b)*Rx(pi);

H_t2c = H_g2c{idx_Table(1)}*H_t2g;
H_t2o = H_c2o*H_t2c;

if debugON
    hg_t2o = triad('Scale',50,'LineWidth',2,'Parent',sim.Frames(1),...
        'AxisLabels',{'x_{t}','y_{t}','z_{t}'},'Matrix',H_t2o);
    axis(sim.Axes,'tight');
end

%% Display errors
%{
% View reprojection errors
h1=figure; showReprojectionErrors(cameraParams);

% Visualize pattern locations
h2=figure; showExtrinsics(cameraParams, 'CameraCentric');

% Display parameter estimation errors
displayErrors(estimationErrors, cameraParams);

% For example, you can use the calibration data to remove effects of lens distortion.
undistortedImage = undistortImage(originalImage, cameraParams);
%}

%% Update speed
ScorSetSpeed(ScorBot_Speed);

%% Save outputs
var_filename = fullfile(pathName,var_filename);
save(var_filename,'A_c2m','H_c2o','H_t2o','H_e2o','H_g2e','b','w','d',...
    'imageFileNames','idx_Table','idx_ScorBot',...
    'cameraParams','estimationErrors','boardSize','squareSize');

end

%% EXTERNAL FUNCTIONS
function [imageNames_ScorBot,H_e2o,H_g2e,b,w,d] = getImages_ScorBot(prv,fileBase_ScorBot,pathName,n)

global debugON sim icon

% Move the robot into the field of view
% -> [0,pi/2,-pi/2,0,-pi/2] % EW452 LAB 3 for correct roll
ScorSetBSEPR([0,pi/2,-pi/2,0,-pi/2]);
ScorWaitForMove;
ScorSetGripper(9);
ScorWaitForMove;

% Place checkerboard in gripper
UserPrompt(...
    {'Place checkerboard',...
    'in gripper...'},...
    'Grab Checkerboard', icon);

% Close gripper
ScorSetGripper(6);
ScorWaitForMove;

% Place checkerboard in gripper
UserPrompt(...
    {'Adjust checkerboard',...
    'in gripper...'},...
    'Adjust Checkerboard', icon);

% Close gripper
ScorSetGripper(3);
ScorWaitForMove;

% Prompt user to adjust camera so checkerboard is in FOV
UserPrompt(...
    {'Adjust camera so the',...
    'entire checkerboard',...
    'is in the FOV...'},...
    'Adjust camera', icon);

% -> Get calibration image
fprintf('\n--> Capture image of checkerboard in gripper.\n');

[~,imageNames_ScorBot] = getCalibrationImages(prv,fileBase_ScorBot,pathName,n);

% -> Get forward kinematics
H_e2o = ScorGetPose;

if debugON
    ScorSimSetPose(sim,H_e2o);
end

% -> Calculate H_g2e
% b – The thickness of the checkerboard calibration object (in millimeters).
% w – The width of the ScorBot gripper fingertip (in millimeters).
% d – The gripper offset between the end-effector frame and the tip of the gripper (in millimeters).
b = ScorGetGripper;
w = 15.1;
d = ScorGetGripperOffset;
H_g2e = Ty(b/2)*Tx(w/2 + 29.2)*Tz(d + 22.4)*Ry(-pi/2)*Rx(pi/2);

if debugON
    ScorSimSetGripper(sim,b);
    hg_g2e = triad('Scale',50,'LineWidth',2,'Parent',sim.Frames(6),...
        'AxisLabels',{'x_{g}','y_{g}','z_{g}'},'Matrix',H_g2e);
end

% Prompt user
UserPrompt(...
    {'Hold checkerboard!'},...
    'Remove checkerboard', icon);

ScorSetGripper('Open');
ScorWaitForMove;

% Move the robot out of the field of view
ScorSetDeltaBSEPR([pi/2,0,0,0,0]);
ScorWaitForMove;
end

% -------------------------------------------------------------------------

function imageNames_Hand = getImages_Handheld(prv,fileBase_Hand,pathName,n)

global icon

% Prompt user
UserPrompt(...
    {'Collect handheld',...
    'calibration images...'},...
    'Handheld calibration', icon);

fprintf('\n--> Capture unique images of checkerboard in hand.\n');

[~,imageNames_Hand] = getCalibrationImages(prv,fileBase_Hand,pathName,n);

end

% -------------------------------------------------------------------------

function imageNames_Table = getImages_Table(prv,fileBase_Table,pathName,n)

global icon

% Prompt user
UserPrompt(...
    {'Place checkerboard on',...
    'the table within the',...
    'camera FOV...'},...
    'Table calibration', icon);

fprintf('\n--> Capture image of checkerboard on the table.\n');

[~,imageNames_Table] = getCalibrationImages(prv,fileBase_Table,pathName,n);

end

% -------------------------------------------------------------------------

function [imageNames,imageFileNames] = combineImages(pathName, imageNames_ScorBot, imageNames_Hand, imageNames_Table)

imageNames = [imageNames_ScorBot; imageNames_Hand; imageNames_Table];

imageFileNames = {};
for ii = 1:numel(imageNames)
    imageFileNames{ii} = fullfile(pathName,imageNames{ii});
end

end

% -------------------------------------------------------------------------

function [imageFileNames,cameraParams,estimationErrors,boardSize] = calibrateCamera(imageFileNames,squareSize)

% Detect checkerboards in images
[imagePoints, boardSize, imagesUsed] = detectCheckerboardPoints(imageFileNames);
% Down-sample images
imageFileNames = imageFileNames(imagesUsed);

% Read the first image to obtain image size
originalImage = imread(imageFileNames{1});
[mrows, ncols, ~] = size(originalImage);

% Generate world coordinates of the corners of the squares
worldPoints = generateCheckerboardPoints(boardSize, squareSize);

% Calibrate the camera
[cameraParams, imagesUsed, estimationErrors] = estimateCameraParameters(imagePoints, worldPoints, ...
    'EstimateSkew', false, 'EstimateTangentialDistortion', false, ...
    'NumRadialDistortionCoefficients', 2, 'WorldUnits', 'millimeters', ...
    'InitialIntrinsicMatrix', [], 'InitialRadialDistortion', [], ...
    'ImageSize', [mrows, ncols]);
% Down-sample images
imageFileNames = imageFileNames(imagesUsed);

end

% -------------------------------------------------------------------------

function UserPrompt(msg,ttl,icon)

h = msgbox(msg,ttl, 'custom', icon);
th = findall(h, 'Type', 'Text');        % Get handle to text within msgbox
th.FontSize = 12;                       % Change the font size
drawnow;

uiwait(h);

end