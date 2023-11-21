%% SCRIPT_TestIntrinsicsOnDistortion
% Evaluate changes to the intrinsic matrix on the undistortPoints function
% in MATLAB.
%
%   M. Kutzer, 21Nov2023, USNA

% Required values:
%       params - camera parameters
%   imageNames - images to evaluate


%% Detect points and calculate using original intrinsics
% Detect checkerboard points
[imagePoints,boardSize,imagesUsed] = detectCheckerboardPoints(imageNames);

% Undistort and package checkerboard points detected in images
n = size(imagePoints,3);
p_m = cell(n,1);
for i = 1:n
    % TODO - allow for fisheye camera model
    p_m{i} = undistortPoints(imagePoints(:,:,i),params).';
    p_m{i}(3,:) = 1; % Append 1 to make homogeneous
end

%% Adjust intrinsics
holder = toStruct(params);
holder.IntrinsicMatrix = [...
    100,  10, 50;...
      0, 110, 30;...
      0,   0,  1].';

paramsNew = cameraParameters(holder);

errNew = [];
pNew_m = cell(n,1);
for i = 1:n
    % TODO - allow for fisheye camera model
    pNew_m{i} = undistortPoints(imagePoints(:,:,i),paramsNew).';
    pNew_m{i}(3,:) = 1; % Append 1 to make homogeneous

    % Compare
    errNew = sqrt( sum( (pNew_m{i} - p_m{i}).^2, 1) );
    errMu(i) = mean(errNew);
    errStd(i) = std(errNew);
end

figure; 
errorbar(1:n,errMu,2*errStd);