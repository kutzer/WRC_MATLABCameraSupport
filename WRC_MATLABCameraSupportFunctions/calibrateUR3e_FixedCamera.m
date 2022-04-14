%function cal = calibrateUR3e_FixedCamera(pname,bname_h,bname_f,fnameRobotInfo)
function cal = calibrateUR3e_FixedCamera(varargin)
% CALIBRATEUR3E_FIXEDCAMERA calibrates a UR3e given a series of
% checkerboard images and associated end-effector poses of the robot.
%   cal = calibrateUR3e_FixedCamera(pname,bname_h,bname_f,fnameRobotInfo)
%
%   Legacy syntax:
%   cal = CALIBRATEUR3E_FIXEDCAMERA(pname,bname,fnameRobotInfo)
%
%   Input(s)
%                pname - character array containing the folder name (aka
%                        the path) containing the calibration images and 
%                        robot pose data file
%              bname_h - base filename for each handheld image
%              bname_f - base filename for each world fixed image
%       fnameRobotInfo - filename containing the robot pose data
%
%   Output(s)
%       cal - structured array containing robot/camera transformation
%             information
%           cal.cameraParams
%
%   M. Kutzer, 19Apr2021, USNA

% Updates
%   26Jan2022 - Allow user to manually find data set & dewarp image to
%               match error results with cameraCalibrator
%   31Mar2022 - Account for partial detections
%   13Apr2022 - Added handheld data sets and meanSE ZERO = 1e-8
%   14Apr2022 - Isolated common code into processRobotCameraCalibration

% TODO - Allow users to select good images from entire calibration set! 
% TODO - Prompt users to close all figures

%% Perform common calibration steps
out = processRobotCameraCalibration(varargin{:});

%% Unpack variables
varNames = fields(out);
for i = 1:numel(varNames)
    eval( sprintf('%s = out.(varNames{i});',varNames{i}) );
end

%% Define relative camera and end-effector pairs
% This defines all combinations of relative grid poses and relative
% end-effector poses, and compile "A" and "B" terms to solve the "AX = XB"
% calibration problem.

% Define total number of extrinsic and forward kinematic pairs
n = numel(cal.H_g2c);
% Initialize parameters
iter = 0;
A = {};
B = {};
for i = 1:n
    for j = 1:n
        % Define:
        %   pose of grid in image i *relative to*
        %   pose of grid in image j
        cal.H_gi2gj{i,j} = invSE( cal.H_g2c{j} )*cal.H_g2c{i};
        % Define:
        %   end-effector pose for image i *relative to*
        %   end-effector pose for image j
        cal.H_ei2ej{i,j} = invSE( cal.H_e2o{j} )*cal.H_e2o{i};
        
        if i ~= j && i < j
            % Define transformation pairs to solve for H_e2g given:
            %   H_gi2gj * H_ei2gi = H_ej2gj * H_ei2ej
            %       where H_ej2gj = H_ei2gi = H_e2g
            %
            % We can rewrite this as
            %   A * X = X * B, solve for X
            iter = iter+1;
            A{iter} = cal.H_gi2gj{i,j};
            B{iter} = cal.H_ei2ej{i,j};
        end
    end
end
fprintf('\nNumber of A/B pairs: %d\n',numel(A));

%% Solve A * X = X * B
X = solveAXeqXBinSE(A,B);
cal.H_e2g = X;

% Check H_e2g
[tf,msg] = isSE(cal.H_e2g);
if ~tf
    warning(msg);
    %fprintf('\tApplying cal.H_e2g = cal.H_e2g*Sz(-1)\n');
    %cal.H_e2g = cal.H_e2g*Sz(-1);
end

%% Make sure rotation is valid
axang = rotm2axang(cal.H_e2g(1:3,1:3));
R_e2g = axang2rotm(axang);
cal.H_e2g(1:3,1:3) = R_e2g;

%% Populate remaining useful tramsformations
cal.H_g2e = invSE( cal.H_e2g );
for i = 1:n
    H_c2o{i} = cal.H_e2o{i}*cal.H_g2e*invSE( cal.H_g2c{i} );
end
% TODO - investigate decoupled meanSE and/or use AX = XB
cal.H_c2o = meanSE(H_c2o,1,1e-8);
cal.H_o2c = invSE( cal.H_c2o );

%% Visualize base frame estimates and mean
fig3D = figure('Name','Base Frame Estimate','NumberTitle','off');
axs3D = axes('Parent',fig3D);
hold(axs3D,'on');
daspect(axs3D,[1 1 1]);
view(axs3D,3);

H_c2a = cal.H_c2o;
sc = max( abs(H_c2a(1:3,4)) )/10;
cam3D = plotCamera('Parent',axs3D,'Location',H_c2a(1:3,4).',...
    'Orientation',H_c2a(1:3,1:3).','Size',sc/2,'Color',[0,0,1]);
h_c2a = triad('Parent',axs3D,'Matrix',H_c2a,'Scale',sc,...
    'AxisLabels',{'x_c','y_c','z_c'});

for i = 1:numel(cal.H_e2o)
    H_o2c = cal.H_g2c{i}*cal.H_e2g*invSE( cal.H_e2o{i} );
    xyz = 'xyz';
    for j = 1:3
        lbls{j} = sprintf('%s_{o_%d}',xyz(j),i);
    end
    h_o2c(i) = triad('Parent',h_c2a,'Matrix',H_o2c,'Scale',sc);%,...
    %'AxisLabels',{lbls{1},lbls{2},lbls{3}});
end

h_o2c_mu = triad('Parent',h_c2a,'Matrix',cal.H_o2c,'Scale',sc*3,...
    'AxisLabels',{'x_o','y_o','z_o'},'LineWidth',2);

%% Calculate reprojection errors using calculated extrinsics
% Delete extrinsics figure
delete(extrin.Figure);
% Plot reprojection error & extrinsics
for i = 1:n
    % Define segmented image points
    X_m = P_m(:,:,i).';
    X_m(3,:) = 1;
    % Define reproject image points (using camera extrinsics)
    X_m_cam = P_m_cam(:,:,i).';
    X_m_cam(3,:) = 1;
    % Define calibrated robot extrinsics
    H_g2c_ext = cal.H_o2c*cal.H_e2o{i}*cal.H_g2e;
    
    % Visualize 3D checkerboard
    [h_g2c(i),ptc_g{i}] = plotCheckerboard(h_c2a,...
        boardSize,squareSize,{'r','w'});
    [h_g2c_ext(i),ptc_g_ext{i}] = plotCheckerboard(h_c2a,...
        boardSize,squareSize,{'c','w'});
    set(h_g2c(i),'Matrix',cal.H_g2c{i});
    set(h_g2c_ext(i),'Matrix',H_g2c_ext);
    set(ptc_g{i},'FaceAlpha',0.5);
    set(ptc_g_ext{i},'FaceAlpha',0.5,'EdgeColor','none');
    hideTriad(h_g2c(i));
    hideTriad(h_g2c_ext(i));
   
    % Display 
    % Project points
    switch list{listIdx}
        case 'Standard'
            % Define projection
            P_g2m_ext = cal.A_c2m * H_g2c_ext(1:3,:);
            % Project grid-referenced points
            sX_m_ext = P_g2m_ext * X_g;
            X_m_ext = sX_m_ext./sX_m_ext(3,:);
        case 'Fisheye'
            % Project points
            X_m_ext = worldToImage(cal.cameraParams.Intrinsics,...
                H_g2c_ext(1:3,1:3).',H_g2c_ext(1:3,4).',X_g(1:3,:).').';
            X_m_ext(3,:) = 1;
    end
    
    % Calculate RMS error
    err = X_m_cam(1:2,:) - X_m_ext(1:2,:);
    err = sum( sqrt(sum(err.^2,1)),2 )/size(err,2);
    delete(ttl(i));
    ttl(i) = title(axs(i),...
        sprintf('Reprojection RMS Error: %.2f pixels',err));
    % Append error
    errALL(i) = err;

    % Plot reprojected points
    plt_m_ext(i) = plot(axs(i),X_m_ext(1,2:end),X_m_ext(2,2:end),...
        'xc','MarkerSize',8,'LineWidth',1.5);
    plt_m0_ext(i) = plot(axs(i),X_m_ext(1,1),X_m_ext(2,1),...
        '+c','MarkerSize',10,'LineWidth',2.0);
    % Plot connections
    con_m_ext(i) = plot(axs(i),...
        reshape([X_m_cam(1,2:end); X_m_ext(1,2:end); nan(1,size(X_m_cam,2)-1)],1,[]),...
        reshape([X_m_cam(2,2:end); X_m_ext(2,2:end); nan(1,size(X_m_cam,2)-1)],1,[]),...
        'c');
    con_m0_ext(i) = plot(axs(i),...
        [X_m_cam(1,1),X_m_ext(1,1)],...
        [X_m_cam(2,1),X_m_ext(2,1)],'c');
    
    % Create legend
    delete(lgnd(i))
    lgnd(i) = legend(...
        [plt_m(i),plt_m0(i),plt_m_cam(i),plt_m0_cam(i),...
        plt_m_ext(i),plt_m0_ext(i)],...
        'Detected points',...
        'Checkerboard origin',...
        'Reprojected points (Cam. Ext.)',...
        'Reprojected origin (Cam. Ext.)',...
        'Reprojected points (Rob. Ext.)',...
        'Reprojected origin (Rob. Ext.)');
    
    % Adjust axes limits
    xx = [...
        max([min( [X_m(1,:),X_m_cam(1,:),X_m_ext(1,:)] ),0.5]),...
        min([max( [X_m(1,:),X_m_cam(1,:),X_m_ext(1,:)] ),size(im,2)+0.5])...
        ] + [-50,50];
    yy = [...
        max([min( [X_m(2,:),X_m_cam(2,:),X_m_ext(2,:)] ),0.5]),...
        min([max( [X_m(2,:),X_m_cam(2,:),X_m_ext(2,:)] ),size(im,1)+0.5])...
        ] + [-50,50];
    xx = [max([xx(1),0.5]),min([xx(2),size(im,2)+0.5])];
    yy = [max([yy(1),0.5]),min([yy(2),size(im,1)+0.5])];
    xlim(axs(i),xx);
    ylim(axs(i),yy);
    
    figure(fig(i));
    centerfig(fig(i));
    drawnow
end

%% Update bar graph
hold(reproj.Axes,'on');
% Overlay robot/camera reprojection errors
reproj.RobotBar = bar(robotIdx,errALL,'Parent',reproj.Axes,'BarWidth',0.4,...
    'FaceColor','r','FaceAlpha',0.5);
% Overlay robot/camera mean error
reproj.RobotLine = copyobj(reproj.Line,reproj.Axes);
set(reproj.RobotLine,'YData',repmat(mean(errALL),1,2),'Color','r');
% Update legend
lgndStr{1} = sprintf('Robot/Camera Mean Error: %5.2f',mean(errALL));
lgndStr{2} = sprintf('      Camera Mean Error: %5.2f',mean( get(reproj.Line,'YData') ));
reproj.NewLegend = legend([reproj.RobotLine,reproj.Line],lgndStr,...
    'Parent',reproj.Figure,'FontName','Monospaced','FontWeight','Bold');

% Bring calibration error to front
figure(reproj.Figure);

%% Prompt user to close reprojection issues
rsp = questdlg('Would you like to close the reprojection error figures?',...
    'Close Figures','Keep All','Keep Best/Worst','Close All','Keep Best/Worst');
switch rsp
    case 'Keep All'
        % Keep all reprojection error figures
    case 'Keep Best/Worst'
        % Keep best/worst reprojection error figures
        bin = errALL == max(errALL) | errALL == min(errALL);
        delete(fig(~bin));
    case 'Close All'
        % Close all reprojection error figures
        delete(fig);
    otherwise
        fprintf([...
            'Action cancelled by user\n\n',...
            'Keeping "Best/Worst" reprojection error figures.\n']);
        % Keep best/worst reprojection error figures
        bin = errALL == max(errALL) | errALL == min(errALL);
        delete(fig(~bin));
        return
end