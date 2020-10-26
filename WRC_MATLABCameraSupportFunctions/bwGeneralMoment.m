function Mij = bwGeneralMoment(imBin,i,j)
% BWGENERALMOMENT Calculate a general image moment.
%   Mij = BWGENERALMOMENT(imBin,i,j) calculate the i,j general image moment
%   associated binary image.
%
%   M. Kutzer, 14Nov2017, USNA

%% Check inputs
% Check for three inputs
narginchk(3,3);
% Check for valid binary image
if ~isBinaryImage(imBin)
    error('Specificed input must be an MxN binary image');
end

%% Calculate general moment
m = size(imBin,1);
n = size(imBin,2);

M = transpose( 1:m );
N = 1:n;

R = repmat(M,1,n);
C = repmat(N,m,1);

Mij = sum(sum( (R.^i).*(C.^j).*imBin ));
