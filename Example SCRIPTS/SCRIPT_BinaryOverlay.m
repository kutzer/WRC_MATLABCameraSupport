%% SCRIPT_BinaryOverlay
% Example script demonstrating how a user can overlay binary information
% onto a live camera stream using color data from the preview object and by
% updating the x/y data of a plot object.
%
%   M. Kutzer, 05Nov2016, USNA

[cam,prv] = initCamera;

%% Setup a figure and stuff
im = get(prv,'CData');

fig = figure;
axs = axes('Parent',fig);
img = imshow(im,'Parent',axs);

hold(axs,'on');
plt = plot(axs,0,0,'.m');
%% Live stream
while true
    im = get(prv,'CData');
    
    [bin,~] = createMaskRedBall(im);
    
    set(img,'CData',im);
    [i,j] = find(bin);
    set(plt,'XData',j,'YData',i);
    drawnow
end