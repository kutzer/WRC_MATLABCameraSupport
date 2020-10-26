function bwOut = bwIsolateProperty(bwIn,varargin)
% BWISOLATEPROPERTY removes objects outside of designated property limits.
%   BWOUT = BWISOLATEPROPERTY(BWIN,'Property1',LIMITS1,'Property2',...)
%   
%   See Also: regionprops
%
%   M. Kutzer, 30Jan2020, USNA

%% Parse property and limit values
n = numel(varargin);
if mod(n,2) ~= 0
    error('Properties and limits must be specified in pairs.');
end

idx = 0;
for i = 1:2:numel(varargin)
    idx = idx+1;
    prop{idx} = varargin{i};
    lim{idx}  = varargin{i+1};
end

s = regionprops(bwIn,prop{:});

bwOut = s;