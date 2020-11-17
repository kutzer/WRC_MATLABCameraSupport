function phi = bwPrincipalAngle(imBin)
% BWPRINCIPALANGLE Calculate the principal angle given a binary image.
%   phi = BWPRINCIPALANGLE(imBin) returns the principal angle (phi)
%   given a binary image.
%
%   M. Kutzer, 14Nov2017, USNA

% Updates
%   29Nov2017 - Corrected calculation of phi
%   17Nov2020 - Corrected documentation
%% Check inputs
% Check for single input
narginchk(1,1);
% Check for valid binary image
if ~isBinaryImage(imBin)
    error('Specificed input must be an MxN binary image');
end

%% Calculate principal angle
U11 = bwCentralMoment(imBin,1,1); 
U20 = bwCentralMoment(imBin,2,0); 
U02 = bwCentralMoment(imBin,0,2);

phi = 1/2*atan2(2*U11,U20-U02);