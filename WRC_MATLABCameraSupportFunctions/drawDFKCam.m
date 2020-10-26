function hg = drawDFKCam
% DRAWDFKCAM creates a patch object representing a DFK 21BU04.H USB 2.0 
% Color Industrial Camera and lens assembly that is the child of an assumed
% camera frame visualized using a triad frame representation (see triad.m).
%   hg = DRAWDFKCAM returns the hgtransform object associated with the
%   camera frame.
%
%   M. Kutzer, 30Jan2016, USNA

% Updates
%   18Jan2017 - Updated documentation

%% Define camera frame
hg = triad('Scale',60,'LineWidth',2,'Tag','CameraFrame');

%% Create camera body
verts = [0,0,0;... % vertex 1
         1,0,0;... % vertex 2
         1,1,0;... % vertex 3
         0,1,0;... % vertex 4
         0,0,1;... % vertex 5
         1,0,1;... % vertex 6
         1,1,1;... % vertex 7
         0,1,1];   % vertex 8

%% Scale and shift camera body
X = verts';
X(4,:) = 1;

X = Tx(-0.5)*Ty(-0.5)*Tz(-0.9)*X;
X = Sx(50)*Sy(50)*Sz(56)*X;

%% Update vertices, define faces, and plot camera body
verts = X(1:3,:)';

faces = [1,2,3,4;... % bottom face
         2,3,7,6;... % right face 
         3,7,8,4;... % back face
         4,8,5,1;... % left face
         1,2,6,5;... % front face
         5,6,7,8];   % top face

pCam = patch('Vertices',verts,'Faces',faces,'FaceColor','b',...
    'Parent',hg);

%% Plot lens
[X,Y,Z] = cylinder;
p = surf2patch(X,Y,Z);

verts = p.vertices;
faces = p.faces;

%% Scale and shift lens
X = verts';
X(4,:) = 1;

X = Sx(33/2)*Sy(33/2)*Sz(35)*X;
X = Tz(0.1 * 56)*X;

%% Update vertices and plot lens
verts = X(1:3,:)';
pLens = patch('Vertices',verts,'Faces',faces,'FaceColor','k',...
    'Parent',hg);
