function z_c = depthFromSphereArea(A_c2m,r,a)
% DEPTHFROMSPHEREAREA calculates the depth (z_c) from a sphere of known 
% radius given camera intrinsics and the area in an image.
%   z_c = DEPTHFROMSPHEREAREA(A_c2m,r,a)
%
%   Input(s) 
%       A_c2m - 3x3 camera intrinsics
%       r     - scalar radius of sphere (units should match camera 
%               calibration units)
%       a     - scalar area of the sphere in the image (pixels)
%
%   Output(s)
%       z_c   - Depth (or distance) from camera relative to the camera
%               frame
%
%   Note: This function currently assumes an intrinsic matrix with zero 
%         shear (i.e. having the following form):
%                 [sx,  0, u]
%         A_c2m = [ 0, sy, v]
%                 [ 0,  0, 1]
%       
%   M. Kutzer, 07Apr2021, USNA

% Updates
%   10Mar2022 - Fixed documentation errors and removed commented content

%% Check input(s)
narginchk(3,3);
% TODO - check inputs

%% Calculate z_c
sx = A_c2m(1,1);
sy = A_c2m(2,2);
z_c = sqrt( (pi*abs(r*sx)*abs(r*sy))./a );