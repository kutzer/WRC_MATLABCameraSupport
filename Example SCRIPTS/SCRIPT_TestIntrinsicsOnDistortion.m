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
u_m = cell(n,1);
for i = 1:n
    % TODO - allow for fisheye camera model
    
    % Define distorted image points
    p_m{i} = imagePoints(:,:,i).';
    p_m{i}(3,:) = 1; % Append 1 to make homogeneous

    % Define undistorted image points
    u_m{i} = undistortPoints(imagePoints(:,:,i),params).';
    u_m{i}(3,:) = 1; % Append 1 to make homogeneous
end

%% Test camera distortion
for i = 1:numel(u_m)
    [d_m{i},axs] = distortImagePoints(u_m{i}(1:2,:),params);
    plt_Xm = plot(axs(1),p_m{i}(1,:),p_m{i}(2,:),'ob','Tag','Original Points');
end

%% Compare results
n = numel(p_m);
for i = 1:n
    delta = p_m{i}(1:2,:) - d_m{i}(1:2,:);
    delta_i = sqrt(sum(delta.^2,1));
    deltaMu(i) = mean(delta_i);
    deltaStd(i) = std(delta_i);
end
figure; 
errorbar(1:n,deltaMu,2*deltaStd);

return
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
    errNew = sqrt( sum( (pNew_m{i} - u_m{i}).^2, 1) );
    errMu(i) = mean(errNew);
    errStd(i) = std(errNew);
end

figure; 
errorbar(1:n,errMu,2*errStd);