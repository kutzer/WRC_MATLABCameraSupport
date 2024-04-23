function h_a2c = plotTicTacToeBoard(axs)
% PLOTTICTACTOEBOARD visualizes the EW450 tic tac toe board and associated
% AprilTags.
%   h_a2c = plotTicTacToeBoard
%   h_a2c = plotTicTacToeBoard(axs)
%
%   Input(s)
%       axs - [OPTIONAL] defines the parent of the board visualization
%
%   Output(s)
%       h_a2c - hgtransform object defining the AprilTag "a450" frame
%               relative to a known parent frame (e.g. the camera frame).
%
%   M. Kutzer, 22Apr2024, USNA

debug = false;
showAxisLabels = true;

%% Check input(s)
narginchk(0,1);

if nargin < 1
    axs = gca;
    set(axs,'DataAspectRatio',[1 1 1],'NextPlot','add');
    addSingleLight(axs);
end

%% Define tag information for visualization
tagFamily = 'tag36h11';
tagSize = 29; % mm

tagID_a = 450;
tagID_b = 460;

%% Initialize debug figure
if debug
    figDebug = figure('Name','plotTicTacToeBoard.m, debug = true');
    axsDebug = axes('Parent',figDebug,'DataAspectRatio',[1 1 1],'NextPlot','add');
end

%% Create tic tac toe board visualization
% Define tag offset to improve visualization
tagOffset = 0.05;

% Define board dimensions
l = 233; % mm
w = 195; % mm
h = 5;   % mm

% Define board corners
X_t = [...
    0, 0, 0;...
    w, 0, 0;...
    w, l, 0;...
    0, l, 0;...
    0, 0, h;...
    w, 0, h;...
    w, l, h;...
    0, l, h].';
X_t(4,:) = 1;

if debug
    plt = plot3(axsDebug,X_t(1,:),X_t(2,:),X_t(3,:),'*b');
    for i = 1:size(X_t,2)
        txt(i) = text(X_t(1,i),X_t(2,i),X_t(3,i),sprintf('%d',i));
    end
end

% Reference board corners for tag a450
H_t2a = Tz(h+tagOffset)*Ty(20)*Tx(-(w-150)/2)*Rx(pi);
X_a = H_t2a*X_t;

% Define faces
faces = [...
    4,3,2,1;...
    1,2,6,5;...
    2,3,7,6;...
    3,4,8,7;...
    4,1,5,8;...
    5,6,7,8];

%% Create board visualization
ptc = patch(axs,'Vertices',X_a(1:3,:).','Faces',faces,'FaceColor','w',...
    'EdgeColor','k');

%% Define tag frames
[h_a2c,~] = plotAprilTag(axs  ,tagFamily,tagID_a,tagSize);
[h_b2a,~] = plotAprilTag(h_a2c,tagFamily,tagID_b,tagSize);

set(h_a2c,'Matrix',Rx(pi));
set(h_b2a,'Matrix',Tx(150));
set(ptc,'Parent',h_a2c);

showTriad(h_a2c);
setTriad(h_a2c,'AxisLabels',{'x_{a_{450}}','y_{a_{450}}','z_{a_{450}}'},...
    'LineWidth',1.4);

showTriad(h_b2a);
setTriad(h_b2a,'AxisLabels',{'x_{a_{460}}','y_{a_{460}}','z_{a_{460}}'},...
    'LineWidth',1.4);

%% Define board "space" frames relative to Frame a450
% First column
H_s2a{1,1} = Tx(75-63)*Ty(-52-126);
H_s2a{2,1} = Tx(75-63)*Ty(-52-126+63);
H_s2a{3,1} = Tx(75-63)*Ty(-52);

% Second column
H_s2a{1,2} = Tx(75)*Ty(-52-126);
H_s2a{2,2} = Tx(75)*Ty(-52-126+63);
H_s2a{3,2} = Tx(75)*Ty(-52);

% Third column
H_s2a{1,3} = Tx(75-63+126)*Ty(-52-126);
H_s2a{2,3} = Tx(75-63+126)*Ty(-52-126+63);
H_s2a{3,3} = Tx(75-63+126)*Ty(-52);

%% Visualize Spaces
sw = 59;
verts = [...
    -sw/2, sw/2, sw/2,-sw/2;...
    -sw/2,-sw/2, sw/2, sw/2].';
ptcSpace = patch(axs,'Vertices',verts,'Faces',1:4,'EdgeColor','k','FaceColor','none');

for i = 1:numel(H_s2a)
    % Define space frame
    if showAxisLabels
        lbls{1} = sprintf('x_{s_{%d}}',i);
        lbls{2} = sprintf('y_{s_{%d}}',i);
        lbls{3} = sprintf('z_{s_{%d}}',i);
        h_s2a(i) = triad('Parent',h_a2c,'Matrix',H_s2a{i},'Scale',1.2*tagSize/2,...
            'LineWidth',1.4,'AxisLabels',lbls);
    else
        h_s2a(i) = triad('Parent',h_a2c,'Matrix',H_s2a{i},'Scale',1.2*tagSize/2,...
            'LineWidth',1.4);
    end

    % Show space
    ptcSpaces(i) = copyobj(ptcSpace,h_s2a(i));
end

delete(ptcSpace);
drawnow;