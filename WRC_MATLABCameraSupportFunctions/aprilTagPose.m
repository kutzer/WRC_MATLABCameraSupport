function [H_a2c,tagLoc] = aprilTagPose(im,camParams,tagFamily,tagID,tagSize)
% APRILTAGPOSE recovers the pose and location of an AprilTag in an image
%   [H_a2c,tagLoc] = APRILTAGPOSE(im,camParams,tagFamily,tagID,tagSize)
%
%   Input(s)
%       im        - image
%       camParams - camera or fisheye parameters natively returned by 
%                   MATLAB camera calibration
%       tagFamily - character array specifying AprilTag family (see
%                   readAprilTag.m)
%       tagID     - scalar value specifying AprilTag ID (see 
%                   readAprilTag.m)
%       tagSize   - scalar value specifying AprilTag size (see
%                   readAprilTag.m)
%
%   Output(s)
%       H_a2c  - 4x4 array element of SE(3) or [] if no single AprilTag is
%                found
%       tagLoc - 4x2 array containing pixel coordinates of tag corners
%
%   M. Kutzer, 14Sep2022, USNA

%% Set default output(s)
H_a2c = [];
tagLoc = [];

%% Check inputs
narginchk(5,5);

% Check camera parameters
switch lower(class(camParams))
    case 'cameraparameters'
        % Pinhole camera
        isFisheye = false;
    case 'fisheyeparameters'
        % Fisheye camera
        isFisheye = true;
    otherwise
        error('camParams must be valid camera/fisheye parameters.');
end

%% Recover tag pose
% Dewarp image
if isFisheye
    % Undistort fisheye image and get undistorted image intrinsics
    [im,intrinsics] = undistortFisheyeImage(im,camParams);
else
    % Undistort camera image [NOT SURE IF THIS IS NECESSARY]
    [im,newOrigin] = undistortImage(im,camParams);
    % TODO - update intrinsics with new origin?

    % Get image intrinsics
    intrinsics = camParams.Intrinsics;
end

[id,loc,pose] = readAprilTag(im,tagFamily,intrinsics,tagSize);

tfID = id == tagID;
switch nnz(tfID)
    case 0
        % No tags found
    case 1
        % 1 tag found

        % Parse location & pose
        tagLoc = loc(:,:,tfID);
        pose = pose(tfID);
        
        % Format pose to SE(3)
        H_a2c = eye(4);
        H_a2c(1:3,1:3) = pose.Rotation.';
        H_a2c(1:3,4)   = pose.Translation.';

    otherwise
        % Multiple tags found
        warning('Multiple %s ID%d tags found.',tagFamily,tagID);
end