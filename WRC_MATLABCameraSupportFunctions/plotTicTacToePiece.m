function h_p2c = plotTicTacToePiece(axs,tagID)
% PLOTTICTACTOEPIECE visualizes the EW450 tic tac toe piece(s) given
% specific AprilTag IDs.
%   h_p2c = plotTicTacToePiece(tagID)
%   h_p2c = plotTicTacToePiece(axs,___)
%
%   Input(s)
%       axs - [OPTIONAL] defines the parent of the piece visualization.
%       tagID - 1xN array defining piece AprilTag IDs to visualize. Note
%               that piece color is defined based on the tag ID used.
%           tagID \in {451, 452, ... , 455} creates a blue piece.
%           tagID \in {461, 462, ... , 465} creates a red piece. 
%
%   Output(s)
%       h_p2c - 1xN array of hgtransform objects defining the piece
%               AprilTag frames relative to a known parent frame (e.g. the 
%               camera frame)
%
%   M. Kutzer, 22Apr2024, USNA

%% Check input(s)
narginchk(1,2);

if nargin < 2
    tagID = axs; 
    
    axs = gca;
    set(axs,'DataAspectRatio',[1 1 1],'NextPlot','add');
    addSingleLight(axs);
end

%% Define tag information for visualization
tagFamily = 'tag36h11';
tagSize = 25; % mm

tagIDs_b = 451:455;
tagIDs_r = 461:465;

%% Create tic tac toe piece visualization
% Define piece dimensions
w = 39; % mm
h = 14;   % mm

% Define board corners
X_p = [...
    -w/2,-w/2, 0+0.01;...
     w/2,-w/2, 0+0.01;...
     w/2, w/2, 0+0.01;...
    -w/2, w/2, 0+0.01;...
    -w/2,-w/2, h-0.01;...
     w/2,-w/2, h-0.01;...
     w/2, w/2, h-0.01;...
    -w/2, w/2, h-0.01].';
X_p(4,:) = 1;

if debug
    plt = plot3(axsDebug,X_p(1,:),X_p(2,:),X_p(3,:),'*b');
    for i = 1:size(X_p,2)
        txt(i) = text(X_p(1,i),X_p(2,i),X_p(3,i),sprintf('%d',i));
    end
end

% Define faces
faces = [...
    4,3,2,1;...
    1,2,6,5;...
    2,3,7,6;...
    3,4,8,7;...
    4,1,5,8;...
    5,6,7,8];

%% Create board visualization
ptc = patch(axs,'Vertices',X_p(1:3,:).','Faces',faces,'FaceColor','k',...
    'EdgeColor','k');

%% Plot pieces
for i = 1:numel(tagID)
    if any(tagID(i) == tagIDs_b)
        % Define blue tag color
        color = 'b';
    elseif any(tagID(i) == tagIDs_r)
        % Define red tag color
        color = 'r';
    else
        % Tag is not recognized as a piece
        sprintf('Tag ID %d (index %d) is not a valid blue or red piece.\n',tagID(i),i);
        continue
    end
    
    % Visualize piece
    [h_p2c(i),~] = plotAprilTag(axs,tagFamily,tagID(i),tagSize);
    
    % Label piece
    lbls{1} = sprintf('x_{a_{%d}}',tagID(i));
    lbls{2} = sprintf('y_{a_{%d}}',tagID(i));
    lbls{3} = sprintf('z_{a_{%d}}',tagID(i));
    
    % Show piece frame
    showTriad(h_p2c(i));
    setTriad('AxisLabels',lbls,'LineWidth',1.4);
    
    % Show piece
    ptcPieces(i) = copyobj(ptc,h_p2c(i));
end