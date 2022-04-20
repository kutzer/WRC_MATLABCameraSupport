function [p_m,z_c,ps_m] = propsRedBall(im,A_c2m,r)
% PROPSREDBALL calculate the homogeneous pixel coordinate associated with
% the centroid of a red ball in an image. If intrinsic and radius
% information is provided, an approximate depth for a red ball is
% calculated.
%   p_m = propsRedBall(im)
%
%   [p_m,~,ps_m] = propsRedBall(im)
%
%   [p_m,z_c] = propsRedBall(im,A_c2m,r)
%
%   [p_m,z_c,ps_m] = propsRedBall(___)
%
%   Input(s)
%       im    - rgb image (MxNx3 uint8 array)
%       A_c2m - [OPTIONAL] intrinsic matrix
%                   [fx,  s, x0]
%           A_c2m = [ 0, fy, y0]
%                   [ 0,  0,  1]
%       r     - [OPTIONAL] positive scalar value defining the radius of the sphere
%
%   Output(s)
%       p_m  - 3x1 array defining the pixel coordinate associated with the
%              centroid of the sphere in the image
%       z_c  - scalar value defining the approximate distance of the sphere
%              from the camera along the z-axis of the camera frame. If no
%              intrinsics and/or radius is provided, z_c = [].
%       ps_m - polyshape associated with segmentation region boundary
%
%   M. Kutzer, 10Mar2022, USNA

% Updates
%   20Apr2022 - Corrected p_m dimension consistency

%% Check inputs
narginchk(1,3);

if nargin < 3
    if nargin == 2
        warning('No radius was provided, ignoring intrinsics.');
    end
    A_c2m = [];
    r = [];
end

% TODO - check if image is valid

if ~isempty(A_c2m)
    [am,an] = size(A_c2m);
    if am ~= an || am ~= 3
        error('Intrinsic matrix must be a 3x3.');
    end
end

if ~isempty(r)
    if numel(r) ~= 1
        error('Radius must be defined as a scalar argument.');
    end

    if r <= 0
        error('Radius must be a positive scalar value.');
    end
end

%% Segment ball
bw = segmentRedBall(im);

%% Calculate center & area
stats = regionprops(bw,'area','centroid');

if ~isempty(stats)
    % Ball is segmented
    a = stats.Area;
    p_m = stats.Centroid.';
    p_m(3,:) = 1;
else
    % No ball segmented
    p_m = [nan; nan; 1];
    z_c = [];
    ps_m = polyshape(nan,nan);
    return
end

%% Calculate depth
if ~isempty(A_c2m)
    z_c = depthFromSphereArea(A_c2m,r,a);
else
    z_c = [];
end

%% Calculate polyshape
if nargout > 2
    warning off
    bnd = bwboundaries(bw);
    if numel(bnd) >= 1
        ps_m = polyshape(bnd{1}(:,2),bnd{1}(:,1));
    else
        ps_m = [];
    end
    warning on
end