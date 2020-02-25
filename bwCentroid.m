function [r,c] = bwCentroid(imBin)
% BWCENTROID Calculate the centroid given a binary image.
%   [r,c] = BWCENTROID(imBin) returns the row (r) and column (c) 
%   coordinates for the centroid given a binary image.
%
%   M. Kutzer, 14Nov2017, USNA

%% Check inputs
% Check for single input
narginchk(1,1);
% Check for valid binary image
if ~isBinaryImage(imBin)
    error('Specificed input must be an MxN binary image');
end

%% Calculate centroid
M00 = bwGeneralMoment(imBin,0,0);
M10 = bwGeneralMoment(imBin,1,0);
M01 = bwGeneralMoment(imBin,0,1);

r = M10/M00;
c = M01/M00;