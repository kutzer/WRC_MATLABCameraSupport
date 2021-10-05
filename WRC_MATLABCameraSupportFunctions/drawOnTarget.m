function X_t = drawOnTarget
% DRAWONTARGET creates a set of points associated with a target drawing.
%   X_t = DRAWONTARGET
%
%   Use instructions:
%       (1) Create new points in the drawing using the left mouse button
%       (2) Clicking the right mouse button will create a transition to a
%           new drawing by adding a +20mm z-offset
%       (3) Clicking the center mouse button (scroll wheel) will exit the
%           drawing interface and return the points
%
%   Input(s)
%
%   Output(s)
%       X_t - 3xN array containing points associated with the drawing.
%
%   M. Kutzer, 05Oct2021, USNA

%% Create figure and axes
fig = figure('Name','drawOnTarget');
axs = axes('Parent',fig);
set(fig,'Units','Inches','Position',[1,1,11,8.5]);
daspect(axs,[1 1 1]);
set(axs,'Units','Normalized','Position',[0.1,0.1,0.85,0.85]);
hold(axs,'on');
xlim(axs,[0,11*25.4]);
ylim(axs,[0,8.5*25.4]);
zlim(axs,[-1,1]);

%% Plot target points
X_t = [...
    0, 160,   0;...
    0,   0, 160;...
    0,   0,   0];
X_o = [25; 25; 0];

phi = linspace(0,2*pi,101);
phi(end) = [];

r = (0.1/2)*25.4;
X_c(1,:) = r*cos(phi);
X_c(2,:) = r*sin(phi);
X_c(3,:) = 0;

for i = 1:3
    X_i = X_c + X_t(:,i) + X_o;
    ptc(i) = patch('Faces',1:100,'Vertices',X_i.','Parent',axs,...
        'FaceColor','k','EdgeColor','none');
end

%% Draw points
title(axs,'Click points');
X_t = [];
startNew = false;
plt = plot(axs,0,0,'o-','LineWidth',2);
while true
    axes(axs);
    [x,y,b] = ginput(1);
    switch b
        case 1
            % Add point
            if startNew
                X_t(:,end+1) = [x; y; 20];
                startNew = false;
            end
            X_t(:,end+1) = [x; y; 0];
        case 3
            % Start new drawing
            X_t(:,end+1) = [X_t(1:2,end); 20];
            startNew = true;
        case 2
            % End drawing
            break
    end
    set(plt,'XData',X_t(1,:),'YData',X_t(2,:),'ZData',X_t(3,:))
    drawnow;
end
title(axs,' ');

end