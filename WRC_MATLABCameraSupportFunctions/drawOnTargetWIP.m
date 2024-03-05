function X_t = drawOnTargetWIP(varargin)
% DRAWONTARGETWIP creates a set of points associated with a target drawing.
%   X_t = DRAWONTARGETWIP
%
%   X_t = DRAWONTARGETWIP(im)
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
%   X_t = drawOnTargetWIP;
%
% Example (2):
%   % Draw "Don't Give Up the Ship"
%   [im,map] = imread('dontGiveUpTheShip.png');
%   im = ind2rgb(im,map);
%   X_t = drawOnTargetWIP(im);
%
% Example (3):
%   % Draw Navy Bill
%   [im,map] = imread('bill.png','BackgroundColor',[1,1,1]);
%   im = ind2rgb(im,map);
%   X_t = drawOnTargetWIP(im);
%
% Example (4):
%   % Draw USNA Robotic & Control Engineering logo
%   im = imread('wrcLogo.png','BackgroundColor',[1,1,1]);
%   X_t = drawOnTargetWIP(im);
%
%   -----------------------------------------------------------------------
%   USER INTERACTION:
%
%     [  Left Mouse,  Single Click] - Add new point to the drawing
%
%     [  Left Mouse,  Double Click] - Add new point to drawing and connect
%                                     that point to closest point in drawing
%
%     [ Right Mouse,  Single Click] - Transition to a new, disconnected
%                                     drawing
%
%     [Center Mouse,  Single Click] - Exit user drawing interface
%     [    (Mouse Scroll Wheel)   ]
%
%     [   Backspace, Press/Release] - Delete prior point
%
%   -----------------------------------------------------------------------
%
%   M. Kutzer, 26Feb2024, USNA

% Updates

%% Set globals
global globalDrawOnTarget

%% Check input(s)
narginchk(0,1);

im = [];
if nargin > 0
    im = varargin{1};
end

%% Create figure and axes
fig = figure('Name','drawOnTargetWIP','Pointer','Cross');
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

% Center figure
centerfig(fig);

%% Create instruction figure
% Setup figure
figG = figure('Name','drawOnTargetWIP Key Guide');
set(figG,'Toolbar','none','MenuBar','none','NumberTitle','off');
set(figG,'Units','normalized','Position',[0.76,0.56,0.23,0.40]);
set(figG,'Tag','drawOnTargetWIP Key Guide');
% Setup axes
axsG = axes('Parent',figG,'Visible','off');
set(axsG,'Units','normalized','Position',[0,0,1,1],...
    'Tag','drawOnTargetWIP Key Guide');
xlim([0,8]);
ylim([0,8]);
daspect([1 1 1]);

txt = text(axsG,0,8,...
    makeMessage,'VerticalAlignment','top','FontName','monospaced',...
    'FontWeight','bold','Tag','drawOnTargetWIP Key Guide');

% Apply close request function
figG.CloseRequestFcn = @figCloseRequestFCN;

drawnow;

%% Package global data
globalDrawOnTarget.fig = fig;
globalDrawOnTarget.figG = figG;
globalDrawOnTarget.axs = axs;
globalDrawOnTarget.xx = xx;
globalDrawOnTarget.yy = yy;
globalDrawOnTarget.zOffset = 20;
globalDrawOnTarget.hCrossHair = plot(axs,nan,nan,'k','Tag','CrossHair');
globalDrawOnTarget.DrawingStatus = 'NewDrawing';
globalDrawOnTarget.xDraw = [];
globalDrawOnTarget.hDraw = plot(axs,nan,nan,'o-','Tag','Drawing',...
    'Color',[0.00,0.45,0.74],'LineWidth',2);
globalDrawOnTarget.xMove = [];
globalDrawOnTarget.hMove = plot(axs,nan,nan,'x--','Tag','Transition',...
    'Color',[0.50,0.50,0.50],'LineWidth',1);
globalDrawOnTarget.xClosestPoint = [];
globalDrawOnTarget.xLastDraw = [];
globalDrawOnTarget.hClosestPoint = plot(axs,nan,nan,':','Tag','ClosestPoint',...
    'Color',[0.00,0.80,0.20],'LineWidth',1.5);
globalDrawOnTarget.DeletePoint = false;
globalDrawOnTarget.ArrowPush = false;
globalDrawOnTarget.EscapePush = false;
globalDrawOnTarget.RadiusFrac = 0;      % Radius = (1/radfrac)*(1/2) distance between points
globalDrawOnTarget.ArcLengthFrac = 1;   % Total points along arc length
globalDrawOnTarget.PointDistance = 0;

%% Update z-limit to account for z-offset
zlim(axs,[-1,1] + [0,globalDrawOnTarget.zOffset]);

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

% Enable KeyPressFcn
enableCallbacks(fig);

% Bring drawing figure to front
figure(fig);

%% Run function until exit condition is reached
% TODO - Consider a uiwait
while true
    if matches(globalDrawOnTarget.DrawingStatus,'ExitDrawing')
        break
    end
    drawnow
end
disableCallbacks(fig)

% Clear title
title(axs,' ');

%% Check if no drawing was made
if isempty(globalDrawOnTarget.xDraw)
    X_t = [];
    return
end

%% Combine drawing and movement points
% Drawing points
Xd_p = globalDrawOnTarget.xDraw.';  % Convert 2D points to 2xN array
Xd_p(3,:) = 0;                      % Append 0 z-coordinate

% Movement points
Xm_p = globalDrawOnTarget.xMove.';  % Convert 3D points to 3xN array

% Replace nan values
tfXd_p = isnan(Xd_p);
tfXm_p = isnan(Xm_p);

Xd_p(tfXd_p) = 0;
Xm_p(tfXm_p) = 0;

% Combine points
X_p = Xd_p + Xm_p;

% Pick up pen at end of drawing
if X_p(3,end) == 0
    X_p(:,end+1) = X_p(:,end);
    X_p(3,end) = globalDrawOnTarget.zOffset;
end

%% Reference points to target frame
X_p(4,:) = 1;
X_t = invSE(H_t2p)*X_p;
X_t(end,:) = [];

%% Save default points
save([globalDrawOnTarget.fname,'.mat'],'X_t');
saveas(fig,[globalDrawOnTarget.fname,'.fig'],'fig');
saveas(fig,[globalDrawOnTarget.fname,'.png'],'png');

%% Internal functions (shared workspace)
% -------------------------------------------------------------------------

end

%% External functions (unique workspace)
% -------------------------------------------------------------------------
function figButtonDownFCN(src, callbackdata)
% -> UNUSED
%fprintf('figButtonDownFCN\n');

end

% -------------------------------------------------------------------------
function figKeyFCN(src, callbackdata)
% -> UNUSED
%fprintf('figKeyFCN\n');

end

% -------------------------------------------------------------------------
function figWindowKeyFCN(src, callbackdata)
% Keyboard key is pressed

global globalDrawOnTarget

%fprintf('figWindowKeyFCN\n');

updatePlot = false;
switch callbackdata.EventName
    case 'WindowKeyPress'
        %fprintf('WindowKeyPress\n');
        switch lower(callbackdata.Key)
            case 'backspace'
                
                % Check for "hold down" button condition
                if globalDrawOnTarget.DeletePoint
                    % User is holding button, ignore
                    return
                end
                
                % Toggle delete point flag
                globalDrawOnTarget.DeletePoint = true;
                
                % Account for drawing status
                switch globalDrawOnTarget.DrawingStatus
                    case 'NewDrawing'
                        % A new drawing has been initialized
                        % -> Toggle drawing status
                        globalDrawOnTarget.DrawingStatus = ...
                            'ContinuedDrawing';
                        
                        % Delete point
                        globalDrawOnTarget.xDraw(end,:) = [];
                        globalDrawOnTarget.xMove(end,:) = [];
                        
                        % Show connection between points
                        showConnections;
                        updatePlot = true;
                        
                    case 'ContinuedDrawing'
                        % A drawing is currently underway
                        % -> Check to see if this is the first point of
                        %    the drawing
                        if size(globalDrawOnTarget.xDraw,1) >= 2
                            if all( isnan(globalDrawOnTarget.xDraw(end-1,:)) )
                                % This is the first point in the
                                %   drawing
                                % -> Toggle drawing status
                                globalDrawOnTarget.DrawingStatus = ...
                                    'NewDrawing';
                                
                                % Delete previous two points!
                                globalDrawOnTarget.xDraw(end,:) = [];
                                globalDrawOnTarget.xMove(end,:) = [];
                                globalDrawOnTarget.xDraw(end,:) = [];
                                globalDrawOnTarget.xMove(end,:) = [];
                                
                                % Hide connections between points
                                hideConnections;
                                updatePlot = true;
                                
                            else
                                % Delete point
                                globalDrawOnTarget.xDraw(end,:) = [];
                                globalDrawOnTarget.xMove(end,:) = [];
                                updatePlot = true;
                                
                            end
                        else
                            % Delete point
                            globalDrawOnTarget.xDraw(end,:) = [];
                            globalDrawOnTarget.xMove(end,:) = [];
                            updatePlot = true;
                        end
                end
                
            case 'uparrow'
                % Check for "hold down" button condition
                if globalDrawOnTarget.ArrowPush
                    % User is holding button, ignore
                    return
                end
                
                % Toggle arrow push flag
                globalDrawOnTarget.ArrowPush = true;
                
                % Increase arc length fraction
                globalDrawOnTarget.ArcLengthFrac =...
                    globalDrawOnTarget.ArcLengthFrac + 1;
                
                % Update UI message
                makeMessage(globalDrawOnTarget.figG);
                
            case 'downarrow'
                % Check for "hold down" button condition
                if globalDrawOnTarget.ArrowPush
                    % User is holding button, ignore
                    return
                end
                
                % Toggle arrow push flag
                globalDrawOnTarget.ArrowPush = true;
                
                % Decrease arc length fraction
                globalDrawOnTarget.ArcLengthFrac =...
                    globalDrawOnTarget.ArcLengthFrac - 1;
                
                % Update UI message
                makeMessage(globalDrawOnTarget.figG);
                
            case 'leftarrow'
                % Check for "hold down" button condition
                if globalDrawOnTarget.ArrowPush
                    % User is holding button, ignore
                    return
                end
                
                % Toggle arrow push flag
                globalDrawOnTarget.ArrowPush = true;
                
            case 'rightarrow'
                % Check for "hold down" button condition
                if globalDrawOnTarget.ArrowPush
                    % User is holding button, ignore
                    return
                end
                
                % Toggle arrow push flag
                globalDrawOnTarget.ArrowPush = true;
                
            case 'escape'
                % Check for "hold down" button condition
                if globalDrawOnTarget.EscapePush
                    % User is holding button, ignore
                    return
                end
                
                % Toggle escape push flag
                globalDrawOnTarget.EscapePush = true;
                
                globalDrawOnTarget.RadiusFrac = 0;
                globalDrawOnTarget.ArcLengthFrac = 1;
                
                % Update UI message
                makeMessage(globalDrawOnTarget.figG);
                
            otherwise
                %fprintf('  WindowKeyPress - Specified key "%s" is unused.\n',...
                %    callbackdata.Key);
        end
    case 'WindowKeyRelease'
        %fprintf('WindowKeyRelease\n');
        switch lower(callbackdata.Key)
            case 'backspace'
                
                % Toggle delete point flag
                globalDrawOnTarget.DeletePoint = false;
                
            case 'uparrow'
                
                % Toggle arrow push flag
                globalDrawOnTarget.ArrowPush = false;
                
            case 'downarrow'
                
                % Toggle arrow push flag
                globalDrawOnTarget.ArrowPush = false;
                
            case 'leftarrow'
                
                % Toggle arrow push flag
                globalDrawOnTarget.ArrowPush = false;
                
            case 'rightarrow'
                
                % Toggle arrow push flag
                globalDrawOnTarget.ArrowPush = false;
                
            case 'escape'
                
                % Toggle escape push flag
                globalDrawOnTarget.EscapePush = false;
                
            otherwise
                %fprintf('WindowKeyRelease - Specified key "%s" is unused.\n',...
                %    callbackdata.Key);
                
        end
    otherwise
        %fprintf(2,'Unexpected event type: %s\n',callbackdata.EventName);
        % Skip remaining
        return
end

% Impose limits on values
if globalDrawOnTarget.ArcLengthFrac < 1
    globalDrawOnTarget.ArcLengthFrac = 1;
end

% Update plots
if updatePlot
    % -> Update drawing
    set(globalDrawOnTarget.hDraw,...
        'XData',globalDrawOnTarget.xDraw(:,1),...
        'YData',globalDrawOnTarget.xDraw(:,2));
    
    % -> Update transition
    set(globalDrawOnTarget.hMove,...
        'XData',globalDrawOnTarget.xMove(:,1),...
        'YData',globalDrawOnTarget.xMove(:,2),...
        'ZData',globalDrawOnTarget.xMove(:,3));
    
    % -> Update closest point
    % Hide closest point
    set(globalDrawOnTarget.hClosestPoint,'Visible','off');
    
    drawnow
end

end

% -------------------------------------------------------------------------
function figWindowButtonDownFCN(src, callbackdata)
% Detect mouse button-down

global globalDrawOnTarget

% Detect mouse button-down
%fprintf('figWindowButtonDownFCN\n');

% Track cursor movement in window
% -> Get axes handle
axs = globalDrawOnTarget.axs;
% -> Get just x/y of current point in axes
xy = boundAxsXY( axs.CurrentPoint(1,1:2) );

switch lower(src.SelectionType)
    case 'normal'
        % Left mouse button
        % -> Start or continue drawing
        
        switch globalDrawOnTarget.DrawingStatus
            case 'NewDrawing'
                % Switch Drawing Status
                globalDrawOnTarget.DrawingStatus = 'ContinuedDrawing';
                
                % Add transition point
                globalDrawOnTarget.xDraw(end+1,:) = nan(1,2);
                globalDrawOnTarget.xMove(end+1,:) = ...
                    [xy,globalDrawOnTarget.zOffset];
                
                % Add new drawing point
                globalDrawOnTarget.xDraw(end+1,:) = xy;
                globalDrawOnTarget.xMove(end+1,:) = nan(1,3);
                
            case 'ContinuedDrawing'
                % Add new drawing point
                globalDrawOnTarget.xDraw(end+1,:) = xy;
                globalDrawOnTarget.xMove(end+1,:) = nan(1,3);
                
            case 'ExitDrawing'
                % Exit triggered
                disableCallbacks(globalDrawOnTarget.fig);
                
            otherwise
                %fprintf(2,'[figWindowButtonDownFCN] Unexpected Case: *.DrawingStatus = "%s"\n',...
                %    globalDrawOnTarget.DrawingStatus);
        end
        
    case 'extend'
        % Center mouse button
        % -> Exit drawing
        
        % Switch Drawing Status
        globalDrawOnTarget.DrawingStatus = 'ExitDrawing';
        
        % Exit triggered
        disableCallbacks(globalDrawOnTarget.fig);
        
    case 'alt'
        % Right mouse button
        % -> Add transition between drawings
        
        switch globalDrawOnTarget.DrawingStatus
            case 'NewDrawing'
                % Do nothing (drawing is already in transition)
                
            case 'ContinuedDrawing'
                % Switch Drawing Status
                globalDrawOnTarget.DrawingStatus = 'NewDrawing';
                
                % Add transition point
                % -> Get last drawing point
                tfXY = isfinite(globalDrawOnTarget.xDraw);
                tfXY = tfXY(:,1) & tfXY(:,2);
                xy = globalDrawOnTarget.xDraw(tfXY,:);
                xy = xy(end,:);
                
                % -> Define transition point
                globalDrawOnTarget.xDraw(end+1,:) = nan(1,2);
                globalDrawOnTarget.xMove(end+1,:) = ...
                    [xy,globalDrawOnTarget.zOffset];
                
            case 'ExitDrawing'
                % Exit triggered
                disableCallbacks(globalDrawOnTarget.fig);
                
            otherwise
                %fprintf(2,'[figWindowButtonDownFCN] Unexpected Case: *.DrawingStatus = "%s"\n',...
                %    globalDrawOnTarget.DrawingStatus);
        end
        
    case 'open'
        % Double-click left mouse button
        % -> Connect the drawing to closest point
        switch globalDrawOnTarget.DrawingStatus
            case 'NewDrawing'
                % Do nothing
                
            case 'ContinuedDrawing'
                
                if ~any( isnan(globalDrawOnTarget.xLastDraw ) )
                    % Connect the drawing to closest point
                    globalDrawOnTarget.xDraw(end+1,:) = ...
                        globalDrawOnTarget.xClosestPoint;
                    globalDrawOnTarget.xMove(end+1,:) = nan(1,3);
                end
                
            case 'ExitDrawing'
                % Exit triggered
                disableCallbacks(globalDrawOnTarget.fig);
                
            otherwise
                %fprintf(2,'[figWindowButtonDownFCN] Unexpected Case: *.DrawingStatus = "%s"\n',...
                %    globalDrawOnTarget.DrawingStatus);
        end
        
    otherwise
        %fprintf(2,'[figWindowButtonDownFCN] Unexpected case: src.SelectionType = "%s"\n',...
        %    src.SelectionType);
end

% Update plots
% -> Update drawing
if numel(globalDrawOnTarget.xDraw) >= 2
    set(globalDrawOnTarget.hDraw,...
        'XData',globalDrawOnTarget.xDraw(:,1),...
        'YData',globalDrawOnTarget.xDraw(:,2));
end
% -> Update transition
if numel(globalDrawOnTarget.xMove) >= 3
    set(globalDrawOnTarget.hMove,...
        'XData',globalDrawOnTarget.xMove(:,1),...
        'YData',globalDrawOnTarget.xMove(:,2),...
        'ZData',globalDrawOnTarget.xMove(:,3));
end
drawnow

end

% -------------------------------------------------------------------------
function figWindowButtonUpFCN(src, callbackdata)
% Detect mouse button-up
% -> UNUSED
%fprintf('figWindowButtonUpFCN\n');

end

% -------------------------------------------------------------------------
function figWindowButtonMotionFCN(src, callbackdata)

global globalDrawOnTarget

% Track cursor movement in window
axs = globalDrawOnTarget.axs;
xx = globalDrawOnTarget.xx;
yy = globalDrawOnTarget.yy;
plt = globalDrawOnTarget.hCrossHair;

offset = 5;
switch callbackdata.EventName
    case 'WindowMouseMotion'
        % Get just x/y of current point in axes
        xy = boundAxsXY( axs.CurrentPoint(1,1:2) );
        
        % Define crosshair x/y coordinates
        crossHair_Pnts = [...
            xx(1) , xy(1)-offset , nan , xy(1)+offset, xx(2) , nan , xy(1) , xy(1)        , nan , xy(1)        , xy(1)  ;...
            xy(2) , xy(2)        , nan , xy(2)       , xy(2) , nan , yy(1) , xy(2)-offset , nan , xy(2)+offset , yy(2)  ...
            ];
        
        % Update crosshair
        set(plt,'XData',crossHair_Pnts(1,:),'YData',crossHair_Pnts(2,:));
        
        % Check drawing status
        switch globalDrawOnTarget.DrawingStatus
            case 'NewDrawing'
                % Hide connection between current position and
                %   previous drawing point
                hideConnections;
                
            case 'ContinuedDrawing'
                % Show connection between current position and
                %   previous drawing point
                showConnections(xy);
                
            case 'ExitDrawing'
                % Exit triggered
                disableCallbacks(globalDrawOnTarget.fig);
                
            otherwise
                %fprintf(2,'[figWindowButtonMotionFCN] Unexpected Case: *.DrawingStatus = "%s"\n',...
                %    globalDrawOnTarget.DrawingStatus);
                
        end
        
        % Update drawing
        drawnow;
        
    otherwise
        callbackdata.EventName
end

end

% -------------------------------------------------------------------------
function figWindowScrollWheelFCN(src, callbackdata)

global globalDrawOnTarget

deltaRadius = 0.05;

%fprintf('figWindowScrollWheelFCN\n');
switch callbackdata.EventName
    case 'WindowScrollWheel'
        if callbackdata.VerticalScrollCount < 0
            % Scroll Up - Increase radius
            %fprintf('Scroll Up\n');
            
            globalDrawOnTarget.RadiusFrac = ...
                globalDrawOnTarget.RadiusFrac + deltaRadius;
            
            % Update UI message
            makeMessage(globalDrawOnTarget.figG);
            
        end
        
        if callbackdata.VerticalScrollCount > 0
            % Scoll Down - Decrease radius
            %fprintf('Scroll Down\n');
            
            globalDrawOnTarget.RadiusFrac = ...
                globalDrawOnTarget.RadiusFrac - deltaRadius;
            
            % Update UI message
            makeMessage(globalDrawOnTarget.figG);
        end
        
    otherwise
        fprintf(2,'[figWindowScrollWheelFCN] Unexpected Event Type: %s\n',callbackdata.EventName);
end


end

% -------------------------------------------------------------------------
function figCloseRequestFCN(src, callbackdata)
% Figure close request
global globalDrawOnTarget

globalDrawOnTarget.DrawingStatus = 'ExitDrawing';

% Exit triggered
disableCallbacks(globalDrawOnTarget.fig);

% Close UI key guide
delete(globalDrawOnTarget.figG);

end

% -------------------------------------------------------------------------
function showConnections(xy)

global globalDrawOnTarget

if nargin < 1
    % Track cursor movement in window
    % -> Get axes handle
    axs = globalDrawOnTarget.axs;
    % -> Get just x/y of current point in axes
    xy = boundAxsXY( axs.CurrentPoint(1,1:2) );
end

if numel(globalDrawOnTarget.xDraw) >= 2
    globalDrawOnTarget.PointDistance = ...
        norm(globalDrawOnTarget.xDraw(end,:) - xy);
end

% Show connection between current position and
%   previous drawing point
set(globalDrawOnTarget.hDraw,'Visible','on',...
    'XData',[globalDrawOnTarget.xDraw(:,1); xy(1)],...
    'YData',[globalDrawOnTarget.xDraw(:,2); xy(2)]);

% Find closest point
[globalDrawOnTarget.xClosestPoint,globalDrawOnTarget.xLastDraw] = ...
    findClosestPoint(globalDrawOnTarget.xDraw,xy);

% Show closest point
set(globalDrawOnTarget.hClosestPoint,'Visible','on',...
    'XData',[xy(:,1); globalDrawOnTarget.xClosestPoint(:,1)],...
    'YData',[xy(:,2); globalDrawOnTarget.xClosestPoint(:,2)]);

% Update info
makeMessage(globalDrawOnTarget.figG);

end

% -------------------------------------------------------------------------
function hideConnections

global globalDrawOnTarget

% Hide connection between current position and
%   previous drawing point
if size(globalDrawOnTarget.xDraw,2) == 2
    % Account for initial condition of xDraw = []
    set(globalDrawOnTarget.hDraw,'Visible','on',...
        'XData',globalDrawOnTarget.xDraw(:,1),...
        'YData',globalDrawOnTarget.xDraw(:,2));
end

% Hide closest point
set(globalDrawOnTarget.hClosestPoint,'Visible','off');

% Reset radius
globalDrawOnTarget.PointDistance = 0;

% Update info
makeMessage(globalDrawOnTarget.figG);

end

% -------------------------------------------------------------------------
function [xyClose,xyLastDraw] = findClosestPoint(xyAll,xy)
% Find the closest point to the last continuous section within an array of
% points. This ignores the last point in the array.

% Set default output(s)
xyClose = nan(1,2);
xyLastDraw = nan(1,2);

% Check for special case(s)
if isempty(xyAll)
    % No drawing data
    return
end
if ~any(isfinite(xyAll(end,:)))
    % Drawing is in transition
    return
end

% Isolate "last continuous drawing"
% Find rows where both columns are NaN
nanRows = isnan(xyAll(:,1)) & isnan(xyAll(:,2));

% Find the index of the last chunk of values
idxLastDraw = find(nanRows, 1, 'last');
idxLastDraw = idxLastDraw+1;

% Slice the array to get the last chunk
xyLastDraw = xyAll(idxLastDraw:end,:);

% Check for special case(s)
if size(xyLastDraw,1) <= 1
    % Only one point exists, do not provide connection option
    return
end

% Remove most recent point
xyLastDraw(end,:) = [];

% Find closest point
dxyLastDraw = xyLastDraw - repmat(xy,size(xyLastDraw,1),1);
dxyLastDraw = dxyLastDraw.^2;
dxyLastDraw = sum(dxyLastDraw,2);

tfFinite = isfinite(dxyLastDraw);
tfMin = dxyLastDraw == min(dxyLastDraw(tfFinite));

tfMin = tfFinite & tfMin;

xyClose = xyLastDraw(tfMin,:);

end

% -------------------------------------------------------------------------
function xy = boundAxsXY(xy)
% Bound position to axes limits
% TODO - Bound to buffered axes limits

global globalDrawOnTarget

x = xy(1);
y = xy(2);

if x < globalDrawOnTarget.xx(1)
    x = globalDrawOnTarget.xx(1);
end

if x > globalDrawOnTarget.xx(2)
    x = globalDrawOnTarget.xx(2);
end

if y < globalDrawOnTarget.yy(1)
    y = globalDrawOnTarget.yy(1);
end

if y > globalDrawOnTarget.yy(2)
    y = globalDrawOnTarget.yy(2);
end

xy = [x,y];

end


% -------------------------------------------------------------------------
function enableCallbacks(fig)

fig.ButtonDownFcn = @figButtonDownFCN;
fig.KeyPressFcn = @figKeyFCN;
fig.KeyReleaseFcn = @figKeyFCN;
fig.WindowKeyPressFcn = @figWindowKeyFCN;
fig.WindowKeyReleaseFcn = @figWindowKeyFCN;
fig.WindowButtonDownFcn = @figWindowButtonDownFCN;
fig.WindowButtonUpFcn = @figWindowButtonUpFCN;
fig.WindowButtonMotionFcn = @figWindowButtonMotionFCN;
fig.WindowScrollWheelFcn = @figWindowScrollWheelFCN;
fig.CloseRequestFcn = @figCloseRequestFCN;

end

% -------------------------------------------------------------------------
function disableCallbacks(fig)

global globalDrawOnTarget

fig.ButtonDownFcn = '';
fig.KeyPressFcn = '';
fig.KeyReleaseFcn = '';
fig.WindowKeyPressFcn = '';
fig.WindowKeyReleaseFcn = '';
fig.WindowButtonDownFcn = '';
fig.WindowButtonUpFcn = '';
fig.WindowButtonMotionFcn = '';
fig.WindowScrollWheelFcn = '';
fig.CloseRequestFcn = 'closereq';

% Hide closest point
set(globalDrawOnTarget.hClosestPoint,'Visible','off');

% Hide connection between current position and previous drawing point
if size(globalDrawOnTarget.xDraw,2) == 2
    % Account for initial condition of xDraw = []
    set(globalDrawOnTarget.hDraw,'Visible','on',...
        'XData',globalDrawOnTarget.xDraw(:,1),...
        'YData',globalDrawOnTarget.xDraw(:,2));
end

% Hide crosshair
set(globalDrawOnTarget.hCrossHair,'Visible','off');

% Return point to standard arrow
set(fig,'Pointer','Arrow');

% Create filename for saving
globalDrawOnTarget.fname = sprintf('drawOnTargetWIP_%s',...
    string(datetime('now'),'yyMMdd_hhmmss' ));

% Delete guide figure
if ishandle(globalDrawOnTarget.figG)
    delete(globalDrawOnTarget.figG);
end

drawnow

end

% -------------------------------------------------------------------------
function varargout = makeMessage(varargin)

global globalDrawOnTarget

%----0123456789012345678901234567890123456789012345678901234567890123456789
msg = sprintf([...
    'UI Controls:\n',...
    ' ----- Left Mouse (single click) --- Add new point to drawing\n',...
    '\n',...
    ' ----- Left Mouse (double click) --- Add new point to drawing and \n',...
    '                                    connect the new point to the \n',...
    '                                    closest point in the drawing\n',...
    '\n',...
    ' ---- Right Mouse (single click) --- Transition to a new, disconnected \n',...
    '                                    drawing\n',...
    '\n',...
    ' --- Center Mouse (single click) --- Exit user drawing interface\n',...
    '\n',...
    ' --- Center Mouse (scroll up/down) - [UNUSED, coming soon]\n',...
    '\n',...
    ' ------ Backspace (press/release) -- Delete prior drawing or transition \n',...
    '                                     point\n',...
    '\n',...
    ' ---- Right Arrow (press/release) -- [UNUSED, coming soon]\n',...
    '\n',...
    ' ----- Left Arrow (press/release) -- [UNUSED, coming soon]\n',...
    '\n',...
    ' ------- Up Arrow (press/release) -- [UNUSED, coming soon]\n',...
    '\n',...
    ' ----- Down Arrow (press/release) -- [UNUSED, coming soon]\n']);

if nargin == 0
    varargout{1} = msg;
    return
end

if nargin == 1
    figG = varargin{1};
    txt = findobj(figG,'Type','Text',...
        'Tag','drawOnTargetWIP Key Guide');
end

msg = sprintf([...
    'UI Controls:\n',...
    ' ----- Left Mouse (single click) --- Add new point to drawing\n',...
    '\n',...
    ' ----- Left Mouse (double click) --- Add new point to drawing and \n',...
    '                                    connect the new point to the \n',...
    '                                    closest point in the drawing\n',...
    '\n',...
    ' ---- Right Mouse (single click) --- Transition to a new, disconnected \n',...
    '                                    drawing\n',...
    '\n',...
    ' --- Center Mouse (single click) --- Exit user drawing interface\n',...
    '\n',...
    ' --- Center Mouse (scroll up/down) - [UNUSED, coming soon]\n',...
    '\n',...
    ' ------ Backspace (press/release) -- Delete prior drawing or transition \n',...
    '                                     point\n',...
    '\n',...
    ' ---- Right Arrow (press/release) -- [UNUSED, coming soon]\n',...
    '\n',...
    ' ----- Left Arrow (press/release) -- [UNUSED, coming soon]\n',...
    '\n',...
    ' ------- Up Arrow (press/release) -- [UNUSED, coming soon]\n',...
    '\n',...
    ' ----- Down Arrow (press/release) -- [UNUSED, coming soon]\n',...
    '\n',...
    'Drawing Parameters:\n',...
    ' --> Connection Radius = (%.2f)/(2*%.2f)\n',...
    ' -->     Point Spacing = (Arc Length)/(%d)\n'],...
    globalDrawOnTarget.PointDistance,globalDrawOnTarget.RadiusFrac,...
    globalDrawOnTarget.ArcLengthFrac);

set(txt,'String',msg);
drawnow

end