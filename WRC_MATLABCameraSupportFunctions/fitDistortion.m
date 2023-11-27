function [k,p] = fitDistortion(d_m,u_m,params)
% FITDISTORTION fits radial and tangential distortion coefficients to a
% given data set.
%   [k,p] = fitDistortion(d_m,u_m,params)
%
%   Input(s)
%         d_m - M-element cell array
%           d_m{i} - 2xN array containing distorted x/y pixel locations
%         u_m - M-element cell array
%           u_m{i} - 2xN array containing undistorted x/y pixel locations
%       params - camera parameters
%
%   Output(s)
%       k - radial distortion coefficients
%       p - tangential distortion coefficients