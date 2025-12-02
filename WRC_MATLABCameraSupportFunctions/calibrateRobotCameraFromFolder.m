function [H_o2c,H_c2o,H_e2f,H_f2e] = calibrateRobotCameraFromFolder(pname)
% CALIBRATEROBOTCAMERAFROMFOLDER runs robot camera calibration from a
% specific folder assuming the *camera is fixed relative to the robot base
% frame*
%
%   [H_o2c,H_c2o,H_e2f,H_f2e] = calibrateRobotCameraFromFolder(pname)
%
%   Input(s)
%       pname - character array specifying the path for the robot camera
%               calibration data
%
%   Output(s)
%       H_o2c - 4x4 array element of SE(3) specifying the robot base frame
%               relative to the camera frame (useful extrinsics)
%       H_c2o - 4x4 array element of SE(3) specifying the camera frame
%               relative to the robot base frame (useful extrinsics)
%       H_e2f - 4x4 array element of SE(3) specifying the robot 
%               end-effector frame relative to the fiducial frame 
%               (validation transform)
%       H_f2e - 4x4 array element of SE(3) specifying the fiducial frame  
%               relative to the robot end-effector frame (validation
%               transform)
%
%   See also combineRobotCameraCalibration
%
%   M. Kutzer, 02Dec2025, USNA

%% Check input(s)
narginchk(1,1);

if ~isfolder(pname)
    error('The specified folder path is invalid.');
end

%% Find images
c = dir( fullfile(pname,sprintf('*.png')) );
for i = 1:numel(c)
    fnames{i} = fullfile(pname,c(i).name);
end

% TODO - check file names

%% Load data
dataFile = 'URcoCalInfo.mat';
try
    load( fullfile(pname,dataFile) );
catch
    error('Data file "%s" does not exist in specified directory.',dataFile);
end

% TODO - check variables 

if numel(squareSize) > 1
    if any( squareSize(1) ~= squareSize )
        warning('Multiple square sizes used!');
    end

    squareSize = squareSize(1);
end

%% Detect checkerboard points (define p_m)
% NOTE: MATLAB's definition of "imagePoints" relates to p_m as follows:
%   Define "imagePoints" from p_m for image i
%           imagePoints(:,:,i) = p_m(1:2,:).'; % <-- Note the transpose
%   Define p_m from "imagePoints" for image i
%           p_m(1:2,:) = imagePoints(:,:,i).'; % <-- Note the transpose
%           p_m(3,:) = 1; % <-- Convert to homogeneous, 2D coordinate
%                               pixel position
[imagePoints, boardSize, tfImagesUsed] = ...
    detectCheckerboardPoints(fnames,'PartialDetections',false);

%% Define p_f given "boardSize" and "squareSize"
% NOTE: MATLAB's definition of "worldPoints" relates to p_f as follows:
%   Define "worldPoints" from p_f
%           worldPoints = p_f(1:2,:).'; % <-- Note the transpose
%   Define p_f from "worldPoints"
%           p_f(1:2,:) = worldPoints.'; % <-- Note the transpose
%           p_f(3,:) = 0; % <-- Define z-coordinate
%           p_f(4,:) = 1; % <-- Convert to homogeneous, 3D coordinate
%                               relative to the fiducial frame
[worldPoints] = generateCheckerboardPoints(boardSize,squareSize);

%% Recover fiducial extrinsics
% (i.e., the checkerboard pose relative to the camera frame, H_f2c)
H_f2c_Used = {};
for i = 1:size(imagePoints,3)
    % Recover extrinsic information for the ith "used" image
    [R_c2f, tpose_d_f2c] = extrinsics(...
        imagePoints(:,:,i),worldPoints,cameraParams);
    R_f2c = R_c2f.';
    d_f2c = tpose_d_f2c.';
    H_f2c_Used{i} = [R_f2c, d_f2c; 0,0,0,1];
end

%% Isolate "used" image names, forward kinematics, and joint configuration
% Update list of images used
fnames_Used = fnames(tfImagesUsed);
% Update corresponding pose and joint configurations
H_e2o_Used = H_e2o(tfImagesUsed);
q_Used = q(:,tfImagesUsed);

%% Solve AX = XB for X = H_e2f (Validation Transform)
% Initialize parameters
iter = 0;
A_f = {};
B_e = {};
n = numel(H_f2c_Used);
for i = 1:n
    for j = 1:n
        % Define:
        % pose of fiducial in image i *relative to*
        % pose of fiducial in image j
        H_fi2fj{i,j} = invSE(H_f2c_Used{j} )*H_f2c_Used{i};
        % Define:
        % end-effector pose for image i *relative to*
        % end-effector pose for image j
        H_ei2ej{i,j} = invSE( H_e2o_Used{j} )*H_e2o_Used{i};
        if i ~= j && i < j
            % Define transformation pairs to solve for H e2f given:
            % H fi2fj * H ei2fi = H ej2fj * H ei2ej
            % where H ej2fj = H ei2fi = H e2f
            %
            % We can rewrite this as
            % A * X = X * B, solve for X
            iter = iter+1;
            A_f{iter} = H_fi2fj{i,j};
            B_e{iter} = H_ei2ej{i,j};
        end
    end
end
fprintf('Number of A/B pairs (Validation Transform): %d\n',numel(A_f));

% Solve AX = XB
X = solveAXeqXBinSE(A_f,B_e);
H_e2f = X;
% Correct possible round-off error in the rotation matrix
H_e2f = nearestSE(H_e2f);
H_f2e = invSE(H_e2f);

%% Solve AX = XB for X = H_c2o (Useful Extrinsics)
iter = 0;
A_o = {};
B_c = {};
n = numel(H_f2c_Used);
for i = 1:n
    for j = 1:n
        % Define:
        % pose of base frame in image i *relative to*
        % pose of base in image j
        H_oi2oj{i,j} = H_e2o_Used{j}*invSE(H_e2o_Used{i});
        % Define:
        % cam pose for image i *relative to*
        % cam pose for image j
        H_ci2cj{i,j} = H_f2c_Used{j}*invSE(H_f2c_Used{i});
        if i ~= j && i < j
            iter = iter+1;
            A_o{iter} = H_oi2oj{i,j};
            B_c{iter} = H_ci2cj{i,j};
        end
    end
end
fprintf('Number of A/B pairs (Useful Extrinsics): %d\n',numel(A_f));

% Solve AX = XB
X = solveAXeqXBinSE(A_o,B_c);
H_c2o = X;
% Correct possible round-off error in the rotation matrix
H_c2o = nearestSE(H_c2o);
H_o2c = invSE(H_c2o);

%% Define p_f from "worldPoints"
p_f(1:2,:) = worldPoints.'; % <-- Note the transpose
p_f(3,:) = 0; % <-- Define z-coordinate
p_f(4,:) = 1; % <-- Convert to homogeneous, 3D

%% Parse Intrinsic Matrix
A_c2m = cameraParams.IntrinsicMatrix.'; % <-- Note the transpose

%% Plot result
for i = 1:n
    % Define filename
    fname = fnames_Used{i};
    % Load distorted image
    imDist = imread( fname );
    % Undistort image
    im = undistortImage(imDist,cameraParams);
    % Plot image
    fig = figure('Name',fname);
    axs = axes('Parent',fig);
    img = imshow(im,'Parent',axs);
    hold(axs,'on');
    axis(axs,'tight');
    % Calculate extrinsics for image
    H_f2c_i = H_o2c * H_e2o_Used{i} * H_f2e;
    % Calculate projection matrix
    P_f2m = A_c2m * H_f2c_i(1:3,:);
    % Project points using intrinsics and extrinsics
    tilde_p_m = P_f2m*p_f; % <-- Scaled pixel coordinates
    p_m = tilde_p_m./tilde_p_m(3,:); % <-- Pixel coordinates
    % Plot points
    % - Fiducial origin point
    plt0 = plot(axs,p_m(1,1),p_m(2,1),'ys','LineWidth',3,'MarkerSize',8);
    % - All other fiducial points
    plti = plot(axs,p_m(1,2:end),p_m(2,2:end),'go','LineWidth',2,'MarkerSize',8);
    % Label points
    for j = 1:size(p_m,2)
        txt(j) = text(axs,p_m(1,j),p_m(2,j),sprintf('$p_{%d}^{m}$',j),...
            'Interpreter','Latex','Color','m','FontSize',14);
    end
end