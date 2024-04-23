function [h_a2c,h_ab2c,h_ar2c] = plotTicTacToe(H_a2c,H_ab2c,H_ar2c,H_c2o)
% PLOTTICTACTOE visualizes the EW450 tic tac toe board, pieces, and
% associated AprilTag frames given rigid body transformations defining
% AprilTag poses.
%   [h_a2c,h_ab2c,h_ar2c] = plotTicTacToe(H_a2c,H_ar2c,H_ab2c)
%   [h_a2c,h_ab2c,h_ar2c] = plotTicTacToe(H_a2c,H_ar2c,H_ab2c,H_c2o)
%
%   Input(s)
%       H_a2c - 4x4 array defining the pose of Frame a450 relative to the
%               camera frame
%       H_ab2c - 5-element cell array defining the pose of each BLUE piece
%                AprilTag relative to the camera frame. 
%                NOTE: Use H_ab2c{i} = [] if the tag is not visible
%       H_ar2c - 5-element cell array defining the pose of each RED piece
%                AprilTag relative to the camera frame. 
%                NOTE: Use H_ar2c{i} = [] if the tag is not visible
%       H_c2o - [OPTIONAL] 4x4 array defining the pose of the camera 
%               relative to the robot frame.
%
%   Output(s)
%       h_a2c - hgtransform object visualizing the AprilTag "a450" frame
%               relative to the camera frame.
%       h_ab2c - 1x5 array of hgtransform objects visualizing the BLUE 
%                piece frame relative to the camera frame.
%       h_ar2c - 1x5 array of hgtransform objects visualizing the RED 
%                piece frame relative to the camera frame.
%
%   M. Kutzer, 22Apr2024, USNA

%% Check input(s)
narginchk(3,4);

if nargin < 4
    showRobot = false;
else
    showRobot = true;
end

if ~iscell(H_ab2c)
    error('BLUE piece poses must be defined as a 1x5 cell array.');
end

if ~iscell(H_ar2c)
    error('RED piece poses must be defined as a 1x5 cell array.');
end

% TODO - check remaining inputs

%% Create visualization
camScale = 80;
if showRobot

    % ------ CRASHING WINDOW DEBUG ----------------------------------------
    % - Adjust OpenGL to software to avoid crashing
    %opengl software
    % ---------------------------------------------------------------------

    % Show robot
    sim = URsim;
    sim.Initialize('UR3');
    for i = 1:6
        hideTriad(sim.(sprintf('hFrame%d',i)));
    end
    hideTriad(sim.hFrameT);
    sim.Home;
    
    % ------ CRASHING WINDOW DEBUG ----------------------------------------
    % - Update renderer to avoid crashing
    %set(sim.Figure,...
    %    'RendererMode','manual',...
    %    'Renderer','opengl',...
    %    'GraphicsSmoothing','off');
    % ---------------------------------------------------------------------
    drawnow
    
    % Show camera
    lbls = {'x_c','y_c','z_c'};
    h_c2o = triad('Parent',sim.hFrame0,'Matrix',H_c2o,...
        'AxisLabels',lbls,'Scale',camScale);
    c_Vis = plotCameraTransform(h_c2o,'Size',camScale/2,...
            'Color',[0,0,1]);
        
    % Define common variable name
    fig = sim.Figure;
else
    fig = figure('Name','plotTicTacToe.m');
    axs = axes('Parent',fig,'NextPlot','Add','DataAspectRatio',[1 1 1]);
    view(axs,3);
    
    H_a2o = Rx(pi);
    H_c2o = H_a2o*invSE(H_a2c);
    
    % Show camera
    lbls = {'x_c','y_c','z_c'};
    h_c2o = triad('Parent',axs,'Matrix',H_c2o,...
        'AxisLabels',lbls,'Scale',camScale);
    
    c_Vis = plotCameraTransform(h_c2o,'Size',camScale/2,...
            'Color',[0,0,1]);
end
drawnow

%% Plot board
h_a2c = plotTicTacToeBoard(h_c2o);
set(h_a2c,'Matrix',H_a2c);
drawnow

%% Plot pieces
h_ab2c = plotTicTacToePiece(h_c2o,451:455);
h_ar2c = plotTicTacToePiece(h_c2o,461:465);
set(h_ab2c,'Visible','off');
set(h_ar2c,'Visible','off');
drawnow

%% Update pieces
for i = 1:numel(H_ab2c)
    if ~isempty(H_ab2c{i})
        set(h_ab2c(i),'Matrix',H_ab2c{i},'Visible','on');
        drawnow
    end
end

for i = 1:numel(H_ar2c)
    if ~isempty(H_ar2c{i})
        set(h_ar2c(i),'Matrix',H_ar2c{i},'Visible','on');
        drawnow
    end
end
        
    
    
 
    
    
    