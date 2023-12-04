function [param2image,image2param] = findImagesUsed(params,imageNames,ZERO)
% FINDIMAGESUSED
%   [paramsUsed,imagesUsed] = findImagesUsed(params,imageNames)
%   [paramsUsed,imagesUsed] = findImagesUsed(params,imageNames,ZERO)
%
%   Input(s)
%           params - camera parameters object 
%       imageNames - cell array containing image names
%             ZERO - [OPTIONAL] scalar defining close enough to zero
%
%   Output(s)
%       param2image - Nx1 array of image indices corresponding to each 
%                     pattern extrinsics matrix contained in the camera 
%                     parameters. 
%       image2param - Mx1 array of pattern extrinsic matrix indices
%                     corresponding to each image index.
%
%   M. Kutzer, 04Dec2023, USNA

%% Check input(s)
narginchk(2,3);

if nargin < 3
    ZERO = 1e-8;
end

% TODO - check input(s)

%% Get board size from camera parameters
worldPoints = params.WorldPoints;
[boardSize,~] = checkerboardPoints2boardSize(worldPoints);

%% Define number of extrinsic patters and number of images
n = params.NumPatterns;
m = numel(imageNames);

param2image = nan(n,1);
image2param = nan(m,1);

%% Get pattern extrinsics from camera parameters
for i = 1:n
    Hcp_f2c{i} = getExtrinsics(params,i);
end

%% Get image extrinsics
% Detect checkerboard points
[imagePoints,boardSize_im,imagesUsed] = detectCheckerboardPoints(imageNames);

% Check for boardSize match
if ~all( boardSize == boardSize_im )
    msg = sprintf([...
        'Checkerboard size in camera parameters does not match the checkerboard size in the images:\n',...
        '    Camera Parameters Board Size: [%3d,%3d]\n',...
        '                Image Board Size: [%3d,%3d]\n'],...
        boardSize(1),boardSize(2),boardSize_im(1),boardSize_im(2) );
    error(msg);
end

% Define imageNames indices
j_all = reshape( find(imagesUsed),1,[] );

imagesFinite = true(size(j_all));
for j = j_all

    % Check for finite elements
    if ~all( isfinite(imagePoints(:,:,j)) )
        imagesFinite(j) = false;
        continue
    end

    % Undistort 
    imagePoints_j = undistortPoints(imagePoints(:,:,j),params);

    % Estimate extrinsics
    Him_f2c{j} = estimateExtrinsics(...
        imagePoints,worldPoints,params.Intrinsics);

    % Find matches
    tf_match = false(1,n);
    H_c2f = invSE(Him_f2c{j});
    for i = 1:n
        H_f2f = H_c2f*Hcp_f2c{i};
        Z = H_f2f - eye(4);
        if isZero(Z,ZERO)
            tf_match(i) = true;
        end
    end

    % Check for match
    switch nnz(tf_match)
        case 0
            % No camera parameter extrinsics matched image extrinsics

        case 1 
            % 1 camera parameter extrinsics matched 1 image extrinsics
            i = find(tf_match);
            param2image(i) = j;
            image2param(j) = i;
        otherwise
            % >1 camera parameter extrinsics matched 1 image extrinsics
            i = find(tf_match);
            vals = sprintf('%d ',i);
            msg = sprintf(...
                'Pattern extrinsics [%s] match Image %d, using first.\n',...
                vals,j);
            warning(msg);

            i = i(1);
            param2image(i) = j;
            image2param(j) = i;
    end

end

end
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Extract pattern extrinsics
function H_f2c = getExtrinsics(params,i)

H_f2c = [];

if isprop(params,'RotationMatrices')
    % MATLAB 2022b and older
    H_f2c(1:3,1:3) = params.RotationMatrices(:,:,i).';
    H_f2c(1:3,4) = params.TranslationVectors(:,:,i).';
    H_f2c(4,:) = [0,0,0,1];
end

if isprop(params,'PatternExtrinsics')
    % MATLAB 2023a and newer
    tform3d = params.PatternExtrinsics(i);
    H_f2c = tform3d.A;
end

if isempty(H_f2c)
    error('Unexpected parameters!')
end

end