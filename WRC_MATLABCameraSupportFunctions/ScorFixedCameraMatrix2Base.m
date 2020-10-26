function [X_o,X_c] = ScorFixedCameraMatrix2Base(X_m,A_c2m,H_c2o,H_t2o)
% SCORFIXEDCAMERAMATRIX2BASE estimates an x/y/z coordinate relative to the
% base frame of ScorBot given:
%   X_o = SCORFIXEDCAMERAMATRIX2BASE(X_m,A_c2m,H_c2o,H_t2o) estimates an 
%   x/y/z coordinate relative to the base frame of ScorBot given: 
%       X_m   - x/y coordinate relative to the matrix frame
%       A_c2m - camera intrinsic matrix
%       H_c2o - pose of camera frame relative to the ScorBot base frame.
%       H_t2o - pose of the "table" frame relative to the ScorBot base frame.
%
%   [X_o,X_c] = ScorFixedCameraMatrix2Base(___) returns the coorindate
%   relative to both the ScorBot base frame and the camera frame.
%
%   M. Kutzer, 27Feb2020, USNA

% Updates
%   

%% Check inputs
narginchk(4,4);

if numel(X_m) > 3 || numel(X_m) < 2
    error('X_m must be a valid pixel coordinate');
end

% TODO - actuall check inputs
X_m(3) = 1;
X_m = reshape(X_m,3,1);

%% Define table plane relative to the camera frame
H_t2c = (H_c2o^(-1)) * H_t2o;   % Table Frame relative to Camera Frame

z_t2c = H_t2c(1:3,3); % Isolate z-direction 
X_t2c = H_t2c(1:3,4); % Isolate origin

% Define plane
d = -transpose(z_t2c) * X_t2c;
abcd = [transpose(z_t2c),d];

%% Estimate scaled coordinate relative to camera frame
X_cs = (A_c2m^(-1)) * X_m;

%% Estimate z_c
z_c = -abcd(4)/( abcd(1:3)*X_cs );

%% Calculate X_c
X_c = z_c * X_cs;

%% Calculate X_o
X_o = H_c2o * [X_c; 1];
X_o(4) = [];