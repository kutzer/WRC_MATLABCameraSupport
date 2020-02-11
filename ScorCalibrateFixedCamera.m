function [A_c2m,H_o2c,H_t2c] = ScorCalibrateFixedCamera(prv)
% SCORCALIBRATEFIXEDCAMERA calculates the camera intrinsics and useful 
% extrinsic matrices
%   [A_c2m,H_o2c,H_t2o] = SCORCALIBRATEFIXEDCAMERA(prv) takes a camera 
%   preview (prv), collects a series of calibration images, and calculates:
%       A_c2m - camera intrinsic matrix
%       H_o2c - extrinsics relating the ScorBot base frame to the camera
%               frame.
%       H_t2c - extrinsics relating the "table" frame to the camera frame.
%
%   M. Kutzer, 06Feb2020, USNA

%% Check input(s)
if ~ishandle(prv)
    error('The input to this function must be a valid camera or webcam preview.');
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

%% Define calibration foldername
% TODO - add random 
pathName = 'ScorBot Fixed Camera Calibration';

%% Take calibration images
% Move the robot into the field of view
% -> [0,pi/2,-pi/2,0,-pi/2] % EW452 LAB 3 for correct roll
ScorSetBSEPR([0,pi/2,-pi/2,0,-pi/2]);
ScorWaitForMove;
ScorSetGripper(9);
ScorWaitForMove;

% Place checkerboard in gripper
% -> Wait for user
uiwait(...
    msgbox('Place checkerboard gripper...[Enter to Continue]','Grab Checkerboard')...
    );

% Close gripper
ScorSetGripper(6);
ScorWaitForMove;

% Place checkerboard in gripper
% -> Wait for user
uiwait(...
    msgbox('Adjust checkerboard in gripper...[Enter to Continue]','Adjust Checkerboard')...
    );

% Close gripper
ScorSetGripper(3);
ScorWaitForMove;

% Prompt user to adjust camera so checkerboard is in FOV
% -> Wait for user
uiwait(...
    msgbox('Adjust camera so the entire checkerboard is in the FOV...[Enter to Continue]','Adjust camera')...
    );
% -> Get calibration image
fprintf('\n--> Capture image of checkerboard in gripper.\n');
fileBase_ScorBot = 'img_ScorBot';
[folderName,imageNames_ScorBot] = getCalibrationImages(prv,fileBase_ScorBot,pathName,1);
% -> Get forward kinematics
H_e2o = ScorGetPose;
% -> Calculate H_g2e
% ? – The thickness of the checkerboard calibration object (in millimeters).
% ? – The width of the ScorBot gripper fingertip (in millimeters).
% ? – The gripper offset between the end-effector frame and the tip of the gripper (in millimeters).
b = ScorGetGripper;
w = 15.1;
d = ScorGetGripperOffset;
H_g2e = Ty(b/2)*Tx(w/2 + 29.2)*Tz(d + 22.4)*Ry(-pi/2)*Rx(pi/2);

% Prompt user
% -> Wait for user
uiwait(...
    msgbox('Hold checkerboard...[Enter to Continue]','Remove checkerboard')...
    );

ScorSetGripper('Open');
ScorWaitForMove;

% Move the robot out of the field of view
ScorSetDeltaBSEPR([pi/2,0,0,0,0]);
ScorWaitForMove;

% Prompt user
% -> Wait for user
uiwait(...
    msgbox('Collect handheld calibration images...[Enter to Continue]','Handheld calibration')...
    );

fprintf('\n--> Capture unique images of checkerboard in hand.\n');
fileBase_Hand = 'img_Handheld';
[folderName,imageNames_Hand] = getCalibrationImages(prv,fileBase_Hand,pathName,10);

% Prompt user
% -> Wait for user
uiwait(...
    msgbox('Place checkerboard on the table within the camera FOV...[Enter to Continue]','Table calibration')...
    );

fprintf('\n--> Capture image of checkerboard on the table.\n');
fileBase_Table = 'img_Table';
[folderName,imageNames_Table] = getCalibrationImages(prv,fileBase_Table,pathName,1);

%% Combine image names 
imageNames = [imageNames_ScorBot; imageNames_Hand; imageNames_Table];

for i = 1:numel(imageNames)
    imageFileNames{i} = fullfile(folderName,imageNames{i});
end

% Detect checkerboards in images
[imagePoints, boardSize, imagesUsed] = detectCheckerboardPoints(imageFileNames);
% Down-sample images
imageFileNames = imageFileNames(imagesUsed);

% Read the first image to obtain image size
originalImage = imread(imageFileNames{1});
[mrows, ncols, ~] = size(originalImage);

% Generate world coordinates of the corners of the squares
squareSize = 1.905000e+01;  % in units of 'millimeters'
worldPoints = generateCheckerboardPoints(boardSize, squareSize);

% Calibrate the camera
[cameraParams, imagesUsed, estimationErrors] = estimateCameraParameters(imagePoints, worldPoints, ...
    'EstimateSkew', false, 'EstimateTangentialDistortion', false, ...
    'NumRadialDistortionCoefficients', 2, 'WorldUnits', 'millimeters', ...
    'InitialIntrinsicMatrix', [], 'InitialRadialDistortion', [], ...
    'ImageSize', [mrows, ncols]);
% Down-sample images
imageFileNames = imageFileNames(imagesUsed);

%% Find ScorBot image index & Table index
idx_ScorBot = [];
idx_Table = [];
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
    error('We need to take a new ScorBot Image and start over...');
end

if isempty(idx_Table)
    error('We need to take a new Table Image and start over...');
end

%% Package output(s)
%[A_c2m,H_o2c,H_t2o]
A_c2m = transpose( cameraParams.IntrinsicMatrix );

%% Calculate H_c2o & H_o2c
cameraParams.RotationMatrices

fprintf('SCORBOT - "%s"\n',imageFileNames{idx_ScorBot});
% TODO - consider multiple transforms (meanSE)
i = idx_ScorBot(1); % index value for ScorBot holding target
H_g2c = [cameraParams.RotationMatrices(:,:,i).',...
 	     cameraParams.TranslationVectors(i,:).';...
 	     0,0,0,1];

H_c2o = H_e2o*H_g2e*(H_g2c)^(-1);

H_o2c = (H_c2o)^(-1);

%% Calculate H_t2c

fprintf('TABLE - "%s"\n',imageFileNames{idx_Table});
% TODO - consider multiple transforms (meanSE)
i = idx_Table(1); % index value for ScorBot holding target
H_g2c = [cameraParams.RotationMatrices(:,:,i).',...
 	     cameraParams.TranslationVectors(i,:).';...
 	     0,0,0,1];
H_t2g = Tz(b)*Tx(pi);

H_t2c = H_g2c*H_t2g;

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
