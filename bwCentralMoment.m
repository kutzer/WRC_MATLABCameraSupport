function Uij = bwCentralMoment(imBin,i,j)
% BWCENTRALMOMENT Calculate a central image moment.
%   Uij = BWCENTRALMOMENT(imBin,i,j) calculate the i,j central image moment
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

%% Calculate central moment
m = size(imBin,1);
n = size(imBin,2);

M = transpose( 1:m );
N = 1:n;

R = repmat(M,1,n);
C = repmat(N,m,1);

[xc,yc] = bwCentroid(imBin);

Xc = repmat(xc,m,n);
Yc = repmat(yc,m,n);

Uij = sum(sum( ((R-Xc).^i).*((C-Yc).^j).*imBin ));