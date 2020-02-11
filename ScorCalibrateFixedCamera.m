function [A_c2m,H_o2c,H_t2c] = ScorCalibrateFixedCamera(prv)
% SCORCALIBRATEFIXEDCAMERA calculates the camera intrinsics and useful 
% extrinsic matrices
%   [A_c2m,H_o2c,H_t2c] = SCORCALIBRATEFIXEDCAMERA(prv) takes a camera 
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
% [0,pi/2,-pi/2,0,-pi/2] % CHECK EW452 LAB 3 for correct roll
% Place in gripper
%   Open Gripper (enough)
%   Close gripper
%   Prompt user to adjust calibraiton target
%   Close gripper completely
% Prompt user to adjust camera so checkerboard is in FOV
fprintf('\n--> Capture image of checkerboard in gripper.\n');
fileBase_ScorBot = 'img_ScorBot';
[folderName,imageNames_ScorBot] = getCalibrationImages(prv,fileBase_ScorBot,pathName,1);

% Move the robot out of the field of view
fprintf('\n--> Capture unique images of checkerboard in hand.\n');
fileBase_Hand = 'img_Handheld';
[folderName,imageNames_Hand] = getCalibrationImages(prv,fileBase_Hand,pathName,10);

fprintf('\n--> Capture image of checkerboard on the table.\n');
fileBase_Table = 'img_Table';
[folderName,imageNames_Table] = getCalibrationImages(prv,fileBase_Table,pathName,1);

%% Combine image names 
imageNames = [imageNames_ScorBot; imageNames_Hand; imageNames_Table];
