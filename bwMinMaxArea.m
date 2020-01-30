function [bwOut,varargout] = bwMinMaxArea(bwIn,minArea,maxArea,conn)
% BWMINMAXAREA removes small and large objects from a binary image.
%   BWOUT = BWMINMAXAREA(BWIN,MINAREA,MAXAREA) removes all connected 
%   components (objects) that have less than MINAREA pixels and greater 
%   than MAXAREA pixels, producing another binary image BWOUT. The default 
%   connectivity is 8 for two dimensional binary images. 
%
%   BWOUT = BWMINMAXAREA(BWIN,MINAREA,MAXAREA,CONN) specifies the desired 
%   connectivity. CONN may have the following scalar values:  
%         4     two-dimensional four-connected neighborhood
%         8     two-dimensional eight-connected neighborhood
%
%   [BWOUT,BWMINAREA,BWMAXAREA] = BWMINMAXAREA(___)
%   additionally provides binary images with removed connected components 
%   that have less than MINAREA (BWMINAREA), and the connected components 
%   that have greater than maxAra (BWMAXAREA). This can be useful for
%   debugging.
%
%   M. Kutzer, C. Doherty, & J. Dupaix, 30Jan2020, USNA

narginchk(3,4)
if nargin < 4
    conn = 8;
end

% Label connected components
lbl = bwlabel(bwIn,conn);

% Calculate area of each connected component
s = regionprops(lbl,'area');
% Put areas into an array
areas = [s.Area];

% Find index values of areas above minArea
binMin = areas > minArea;
% Find index values of areas below maxArea
binMax = areas < maxArea;
% Find index values of areas that are above the minimum & below the maximum
bin = binMin & binMax;

% Initialize binary
bwOut = false( size(lbl) );
% Keep all regions associated with a "true" index
for i = find(bin)
    bwOut = bwOut | lbl == i;
end

% Populate optional outputs (for debugging)
if nargout > 1
    % Initialize binary
    bwMinArea = false( size(lbl) );
    % Keep all regions associated with a "true" index
    for i = find(binMin)
        bwMinArea = bwMinArea | lbl == i;
    end
    % Package output
    varargout{1} = binMinArea;
end

if nargout > 2
    % Initialize binary
    bwMaxArea = false( size(lbl) );
    % Keep all regions associated with a "true" index
    for i = find(binMax)
        bwMaxArea = bwMaxArea | lbl == i;
    end
    % Package output
    varargout{2} = bwMaxArea;
end