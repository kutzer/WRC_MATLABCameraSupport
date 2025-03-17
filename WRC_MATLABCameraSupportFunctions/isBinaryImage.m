function tf = isBinaryImage(bw)
% ISBINARYIMAGE checks if an image is binary
%   tf = ISBINARYIMAGE(bw)
%
%   Input(s)
%       bw - MxN logical array
%
%   Output(s)
%       tf - scalar logical array indicating whether input is a binary
%            image
%
%   M. Kutzer, 17Mar2025, USNA

%% Check input(s)
narginchk(1,1);

%% Check for binary image
if ~ismatrix(bw)
    tf = false;
    return
end

if ~islogical(bw)
    tf = false;
    return
end

tf = true;
