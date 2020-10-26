function Vij = bwNormalizedCentralMoment(imBin,i,j)
% BWNORMALIZEDCENTRALMOMENT Calculate a normalized central image moment.
%   Vij = BWNORMALIZEDCENTRALMOMENT(imBin,i,j) calculate the i,j normalized 
%   central image moment associated binary image.
%
%   M. Kutzer, 14Nov2017, USNA

%% Check inputs
% Check for three inputs
narginchk(3,3);
% Check for valid binary image
if ~isBinaryImage(imBin)
    error('Specificed input must be an MxN binary image');
end

%% Calculate normalized central moment
U00 = bwCentralMoment(imBin,0,0);
Uij = bwCentralMoment(imBin,i,j);

Vij = Uij / (U00^((i+j+2)/2));