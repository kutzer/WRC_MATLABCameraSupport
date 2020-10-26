function rho = bwPerimeter(imBin)
% BWPERIMETER calculates the perimeter of an object in a binary 
% image following the method described in ES450, Introduction to Robotic 
% Systems.
%   rho = BWPERIMETER(imBin) calculates the perimeter of an object 
%   in a binary image.
%
%   M. Kutzer, 22Nov2016, USNA

%% Check inputs
% Check for single input
narginchk(1,1);
% Check for valid binary image
if ~isBinaryImage(imBin)
    error('Specificed input must be an MxN binary image');
end

%% Calculate perimeter
% Buffer image with zeros
[M,N] = size(imBin);
imBin_buffered = zeros(M+2, N+2);
imBin_buffered(2:(M+1),2:(N+1)) = imBin;

% Calculate perimeter
rho = sum( reshape(abs(diff(imBin_buffered )),1,[]) ) + ... % Absolute sum of row differences 
      sum( reshape(abs(diff(imBin_buffered')),1,[]) );      % Absolute sum of column differences