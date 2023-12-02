function [paramsOut,imagesUsed] = refineCameraIntrinsics(params,imageNames,H_f2c,squareSize)
% REFINECAMERAINTRINSIS refines camera intrinsics using fiducial
% extrinsics.
%   paramsOut = refineCameraIntrinsics(params,imageNames,H_f2c)
%   paramsOut = refineCameraIntrinsics(params,imageNames,H_f2c,squareSize)
%
%   Input(s)
%           params - camera parameters object
%       imageNames - array of image names 
%            H_f2c - fiducial extrinsics corresponding to the image names
%                    provided
%       squareSize - [OPTIONAL] scalar defining the square size for the
%                    checkerboard fiducial. If undefined, the "WorldPoints"
%                    property of the camera parameters is used to define
%                    square size.
%
%   Output(s)
%        paramsOut - camera parameters with intrinsics refined using the
%                    images and fiducial extrinsics
%       imagesUsed - binary array defining images used in updated
%                    parameters
%
%   USE NOTES:
%       (1) The current implementation of this function does not update
%           distortion coefficients to account for the refined camera 
%           intrinsics.
%       (2) Per (1), if/when undistortX functions are required, the
%           original camera parameters should be used. 
%
%   See also updateCameraParamsImagesUsed
%   
%   C. Civetta & M. Kutzer, 21Nov2023, USNA

%% Check input(s)
% TODO - check inputs

if nargin < 4
    squareSize = params.WorldPoints(2,2); 
end

%% Detect image points (p_m)

% Detect checkerboard points
[imagePoints,boardSize,imagesUsed] = detectCheckerboardPoints(imageNames);

% Downsample image names
imageNames = imageNames(imagesUsed);

% Downsample extrinsics using images used in checkerboard detection
H_f2c = H_f2c(imagesUsed);

% Undistort and package checkerboard points detected in images
n = size(imagePoints,3);
p_m = cell(n,1);
px_m = [];  % Combination of x-only coordinates 
py_m = [];  % Combination of y-only coordinates 
imagesUsed_i = true( size(imageNames) );
for i = 1:n
    % Check for finite imagePoints
    if ~all( isfinite(imagePoints(:,:,i)) )
        imagesUsed_i(i) = false;
        continue
    end

    % TODO - allow for fisheye camera model
    p_m{i} = undistortPoints(imagePoints(:,:,i),params).';
    p_m{i}(3,:) = 1; % Append 1 to make homogeneous

    % Compile subsamples for solving for new intrinsics
    px_m = [px_m, p_m{i}(1,:)];
    py_m = [py_m, p_m{i}(2,:)];
end

% Downsample based on images used
p_m = p_m(imagesUsed_i);
imageNames = imageNames(imagesUsed_i);
H_f2c = H_f2c(imagesUsed_i);
% Update number of values
n = numel(p_m);

%% Update imagesUsed
i = 0;
for j = reshape( find(imagesUsed),1,[] )
    i = i+1;
    imagesUsed(j) = imagesUsed_i(i);
end

%% Define fiducial-based points
[worldPoints] = generateCheckerboardPoints(boardSize,squareSize);
p_f = worldPoints.';
p_f(3,:) = 0; % Append z-coordinate
p_f(4,:) = 1; % Append 1 to make homogeneous

%% Reference fiducial points to the camera frame, scale, & isolate
p_c = cell(n,1);        % Points referenced to camera frame
tilde_p_c = cell(n,1);  % Scaled points referenced to camera frame
tilde_p1_c= []; % Combination of scaled x/y/z coordinates 
tilde_p2_c= []; % Combination of scaled y/z coordinates
for i = 1:n
    % Define fiducial points relative to camera frame
    p_c{i} = H_f2c{i}*p_f;
    % Define scaled fiducial points relative to camera frame
    tilde_p_c{i} = p_c{i}./p_c{i}(3,:);

    % Combine points
    tilde_p1_c = [tilde_p1_c, tilde_p_c{i}(1:3,:)];
    tilde_p2_c = [tilde_p2_c, tilde_p_c{i}(2:3,:)];
end

%% Calculate new intrinsics
A_c2m = eye(3);
A_c2m(1,1:3) = px_m*pinv(tilde_p1_c);
A_c2m(2,2:3) = py_m*pinv(tilde_p2_c);

%% Package camera parameters
paramsStruct = toStruct(params);

if isfield(paramsStruct,'IntrinsicMatrix')
    % MATLAB 2022b and older
    paramsStruct.IntrinsicMatrix = A_c2m.';
elseif isfield(paramsStruct,'K')
    % MATLAB 2023a and newer
    paramsStruct.K = A_c2m;
end
paramsOut = cameraParameters(paramsStruct);

%% Calculate new fiducial extrinsics
Intrinsics = paramsOut.Intrinsics;
% Package undistorted image points
for i = 1:n
    imagePoints(:,:,i) = p_m{i}(1:2,:).';
end
% Calculate new extrinscs
worldPoints3 = worldPoints;
worldPoints3(:,3) = 0;
for i = 1:n
    camExtrinsics = estimateExtrinsics(...
        imagePoints(:,:,i),worldPoints,Intrinsics);
    
    % 2023a+ parameters
    RotationVectors(i,:) = rotmat2vec3d(camExtrinsics.R);
    TranslationVectors(i,:) = camExtrinsics.Translation;

    % 2022b- parameters
    RotationMatrices(:,:,i) = (camExtrinsics.R).';

    % Calculate reprojection errors
    p_m_est = worldToImage(Intrinsics,camExtrinsics,worldPoints3);
    ReprojectionErrors(:,:,i) = p_m_est - p_m{i}(1:2,:).';
end

%% Update parameters
if isfield(paramsStruct,'RotationMatrices')
    % MATLAB 2022b and older
    paramsStruct.RotationMatrices = RotationMatrices;
    paramsStruct.TranslationVectors = TranslationVectors;
    paramsStruct.ReprojectionErrors = ReprojectionErrors;

    % TODO - calculate keypoints
    paramsStruct.DetectedKeyPoints = true(size(worldPoints,1),n);
elseif isfield(paramsStruct,'K')
    % MATLAB 2023a and newer
    paramsStruct.RotationVectors = RotationVectors;
    paramsStruct.TranslationVectors = TranslationVectors;
    paramsStruct.ReprojectionErrors = ReprojectionErrors;

    % TODO - calculate keypoints
    paramsStruct.DetectedKeyPoints = true(size(worldPoints,1),n);
end
paramsOut = cameraParameters(paramsStruct);

%% Adjust distortion parameters
% TODO - match distortion parameters to new intrinsics
paramsStruct.RadialDistortion = zeros(1,2);
paramsStruct.TangentialDistortion = zeros(1,2);
paramsStruct.EstimateSkew = false;
paramsStruct.NumRadialDistortionCoefficients = 2;
paramsStruct.EstimateTangentialDistortion = false;

paramsOut = cameraParameters(paramsStruct);
