function hndls = plotImageReprojection(im,params,squareSize)
% PLOTIMAGEREPROJECTION 
%   hndls = plotImageReprojection(im,params)
%
%   Input(s)
%               im - image
%           params - camera parameters object 
%       squareSize - [OPTIONAL] checkerboard square size
%
%   Output(s)
%       hndls - structured array containing object handles
%
%   M. Kutzer, 04Dec2023, USNA

%% Check input(s)
narginchk(2,2);
% TODO - check inputs

%% Get board size from camera parameters
if nargin < 3
    worldPoints = params.WorldPoints;
    [boardSize,squareSize] = checkerboardPoints2boardSize(worldPoints);
else
    boardSize = [];
end

%% Get image extrinsics
% Detect checkerboard points
[imagePoints,boardSize_im,~] = detectCheckerboardPoints(im);

if isempty(boardSize)
    boardSize = boardSize_im;
end

% Check for boardSize match
if ~all( boardSize == boardSize_im )
    msg = sprintf([...
        'Checkerboard size in camera parameters does not match the checkerboard size in the images:\n',...
        '    Camera Parameters Board Size: [%3d,%3d]\n',...
        '                Image Board Size: [%3d,%3d]\n'],...
        boardSize(1),boardSize(2),boardSize_im(1),boardSize_im(2) );
    warning(msg);
end

% Generate correct checkerboard points
worldPoints = generateCheckerboardPoints(boardSize, squareSize);

% Undistort
imagePoints_u = undistortPoints(imagePoints,params);

% Estimate extrinsics
%{
    % Old Method
    [rotationMatrix, translationVector] = extrinsics(...
        imagePoints_j,worldPoints,params);
    Him_f2c{j}(1:3,1:3) = rotationMatrix.';
    Him_f2c{j}(1:3,4) = translationVector.';
    Him_f2c{j}(4,:) = [0,0,0,1];
%}
% New Method
tform3d = estimateExtrinsics(...
    imagePoints_u,worldPoints,params.Intrinsics);
H_f2c = tform3d.A;