function X_t = drawOnTarget(varargin)
% DRAWONTARGET creates a set of points associated with a target drawing.
%   X_t = DRAWONTARGET
%
%   X_t = DRAWONTARGET(im)
%
%   Use instructions:
%       (1) Create new points in the drawing using the left mouse button
%       (2) Clicking the right mouse button will create a transition to a
%           new drawing by adding a +20mm z-offset
%       (3) Clicking the center mouse button (scroll wheel) will exit the
%           drawing interface and return the points
%
%   Input(s)
%       im  - [OPTIONAL] image to overlay on the target drawing
%
%   Output(s)
%       X_t - 3xN array containing x/y/z points associated with the 
%             drawing referenced to the "target" frame. Points are defined
%             in millimeters. 
%
%   NOTE: The target drawing is available in WRC_MATLABCameraSupport
%         repository:
%
%           WRC_MATLABCameraSupport\SupportFiles\DrawingTargetPage.pdf
%
% Example (1):
%   % Draw on blank paper
%   X_t = drawOnTarget;
%
% Example (2):
%   % Draw "Don't Give Up the Ship"
%   [im,map] = imread('dontGiveUpTheShip.png');
%   im = ind2rgb(im,map);
%   X_t = drawOnTarget(im);
%
% Example (3):
%   % Draw Navy Bill
%   [im,map] = imread('bill.png','BackgroundColor',[1,1,1]);
%   im = ind2rgb(im,map);
%   X_t = drawOnTarget(im);
%
% Example (4):
%   % Draw USNA Robotic & Control Engineering logo
%   im = imread('wrcLogo.png','BackgroundColor',[1,1,1]);
%   X_t = drawOnTarget(im);
%
%   M. Kutzer, 05Oct2021, USNA

% Updates
%   09Mar2022 - Documentation update, corrected offset definitions, and
%               included image overlay option

%% Check input(s)
narginchk(0,1);

im = [];
if nargin > 0
    im = varargin{1};
end

%% Create figure and axes
fig = figure('Name','drawOnTarget');
axs = axes('Parent',fig);
set(fig,'Units','Inches','Position',[1,1,11,8.5]);
set(axs,'Units','Normalized','Position',[0.1,0.1,0.85,0.85]);
hold(axs,'on');
daspect(axs,[1 1 1]);

% Set axes limits to 11" x 8.5"
xx = [0,11*25.4];  % 11.0" wide (converted to mm)
yy = [0,8.5*25.4]; %  8.5" high (converted to mm)
xlim(axs,xx);     
ylim(axs,yy);     
zlim(axs,[-1,1]);

%% Overlay image
if ~isempty(im)
    % Define image size
    x_im = size(im,2);
    y_im = size(im,1);

    % Define scale
    scale = min([xx(2)/x_im,yy(2)/y_im]);

    % Define "image" relative to "corner" frame
    H_c2a = Tz(-0.1)*Rx(pi)*Tx(xx(2)/2)*Ty(-yy(2)/2);
    h_c2a = triad('Parent',axs,'Scale',20,'Matrix',H_c2a,'LineWidth',2);
    H_s2c = Tx( -(x_im*scale)/2 )*Ty( -(y_im*scale)/2 );
    h_s2c = triad('Parent',h_c2a,'Scale',30,'Matrix',H_s2c);
    H_i2s = Sx(scale)*Sy(scale);
    h_i2s = triad('Parent',h_s2c,'Scale',max([x_im,y_im])/2,'Matrix',H_i2s);

    % Show image
    img = imshow(im,'Parent',axs);
    set(img,'Parent',h_i2s,'AlphaData',0.5);
    set(axs,'Visible','on','YDir','Normal');

    % Hide triads
    hideTriad(h_c2a);
    hideTriad(h_s2c);
    hideTriad(h_i2s);
end

%% Plot target points
% Calibration points defined relative to the "target" frame
X_t = [...
    0, 160,   0;...
    0,   0, 160;...
    0,   0,   0];

% Transformation relating the "target" frame to the "paper" frame
% -> The paper frame is located in the lower left of the page assuming a
%    landscape orientation
H_t2p = Tx(25)*Ty(25);

%% Render target dots
n = 100;
phi = linspace(0,2*pi,n+1);
phi(end) = [];
r = (0.1/2)*25.4;
dot(1,:) = r*cos(phi);
dot(2,:) = r*sin(phi);
dot(3,:) = 0;

for i = 1:3
    % Define dot centered at ith target point location
    dot_t = dot + X_t(:,i);
    dot_t(4,:) = 1; 
    % Reference dot to paper frame
    dot_o = H_t2p*dot_t;
    dot_o(4,:) = [];

    % Render dot on paper
    ptc(i) = patch('Faces',1:n,'Vertices',dot_o.','Parent',axs,...
        'FaceColor','k','EdgeColor','none');
end

%% Label points
X_t(4,:) = 1;
X_p = H_t2p*X_t;

txt(1) = text(X_p(1,1)+r,X_p(2,1)-r,X_p(1,1),'$\underline{p}_{0}$',...
    'Interpreter','latex','HorizontalAlignment','left',...
    'VerticalAlignment','top','Parent',axs);
txt(2) = text(X_p(1,2)+r,X_p(2,2)-r,X_p(1,2),'$\underline{p}_{1}$',...
    'Interpreter','latex','HorizontalAlignment','left',...
    'VerticalAlignment','top','Parent',axs);
txt(3) = text(X_p(1,3)-2*r,X_p(2,3),X_p(1,3),'$\underline{p}_{2}$',...
    'Interpreter','latex','HorizontalAlignment','right',...
    'VerticalAlignment','middle','Parent',axs);

set(txt,'FontUnits','Normalized','FontSize',0.025,'FontWeight','bold');

%% Draw points
title(axs,sprintf('Click points\n[Center Mouse Button to Exit]'));
X_p = [];
startNew = false;
plt = plot(axs,0,0,'o-','LineWidth',2);
while true
    axes(axs);
    [x,y,b] = ginput(1);
    switch b
        case 1
            % Add point
            if startNew
                X_p(:,end+1) = [x; y; 20];
                startNew = false;
            end
            X_p(:,end+1) = [x; y; 0];
        case 3
            % Start new drawing
            X_p(:,end+1) = [X_p(1:2,end); 20];
            startNew = true;
        case 2
            % End drawing
            break
    end
    set(plt,'XData',X_p(1,:),'YData',X_p(2,:),'ZData',X_p(3,:))
    drawnow;
end
title(axs,' ');

%% Reference points to target frame
X_p(4,:) = 1;
X_t = invSE(H_t2p)*X_p;
X_t(end,:) = [];
