function [cam,prv] = initWebcam(varargin)
% INITWEBCAM initializes a webcam object and, if applicable, opens a 
% preview.
%
%   [cam,prv] = INITWEBCAM returns both the webcam object hangle and the 
%   "preview" image object handle. Note that "prv" can be used to get 
%   images faster than snapshot.m using:
%       -> im = get(prv,'CData');
%
%   cam = INITWEBCAM returns the webcam object handle . This is required 
%   for using snapshot.m:
%       -> im = snapshot(cam);
%
%   [___] = INITWEBCAM(cam) reinitializes a specified camera object.
%
%   NOTE: This requires an installed version of the "MATLAB Support 
%       Package for USB Webcams" 
%       >> supportPackageInstaller
%           -> select "Install from Internet"
%           -> select “USB Webcams”
%           -> login to mathworks using email and password
%           -> Install
%
%   M. Kutzer, 19Jul2019, USNA

%% List existing webcams
try
    camList = webcamlist;
catch
    error('initWebcam:NoWebcamList',...
        ['The "webcamlist" function is not detected.\n',...
        ' -> Run "supportPackageInstaller"\n',...
        ' -> Select and install "USB Webcams".\n']);
end

%% Check number of outputs
if nargout < 1
    error('You must specify a variable name for your webcam object handle.');
end

%% Check inputs
if nargin > 0
    switch class(varargin{1})
        case 'webcam'
            cam = varargin{1};
            closePreview(cam);
            delete(cam);
        otherwise
            error('Specified input must be a valid webcam object.');
    end
end

%% Select webcam
if numel(camList) == 0
    error('No connected camera found');
end

if numel(camList) == 1
    camIdx = 1;
    OK = false;
else
    [camIdx,OK] = listdlg('PromptString','Select camera:',...
        'SelectionMode','single',...
        'ListString',camList);
    if ~OK
        error('No camera selected.');
    end
end

% Create webcam object
try
    cam = webcam(camIdx);
catch err
    errTXT = sprintf(['webcam ("%s") is already initialized and a handle ',...
            'for this webcam object should exist in your workspace.\n\n',...
            'If you would like to reinitialize your webcam object using this function, please consider:\n',...
            '\t(a) running [ [Webcam Handle] , [Image Handle] ] = initWebcam( [Webcam Handle] ),\n'...
            '\t(b) clearing your webcam object handle using "clear [Webcam Handle]", or\n',...
            '\t(c) clearing your workspace using "clear all" if you have lost track of the ',...
            'handle for your webcam object.'],camList{camIdx});
    if ~OK
        error('Your %s',errTXT)
    else
        error('The selected %s',errTXT);
    end
end
if nargout > 1
    % Create preview image object 
    prv = preview(cam);
    % Get preview axes object
    axs = get(prv,'Parent');
    % Set useful properties of axes object
    set(axs,'Visible','on');
    hold(axs,'on');
    xlabel(axs,'x (pixels)');
    ylabel(axs,'y (pixels)');
    
    % Get preview figure
    kid = axs;
    while true
        mom = get(kid,'Parent');
        switch lower( get(mom,'Type') )
            case 'figure'
                fig = mom;
                break;
            otherwise
                kid = mom;
        end
    end
    
    % Update tags
    set(fig,'Tag','Webcam Preview: Figure Object');
    set(axs,'Tag','Webcam Preview: Axes Object');
    set(prv,'Tag','Webcam Preview: Image Object');
    
    % Update figure name and close request function
    name = get(fig,'Name');
    name = sprintf('USNA WRC %s',name);
    set(fig,'Name',name,'CloseRequestFcn',{@previewCloseCallback,cam,prv,axs});
end

end

%% Embedded function(s)
function previewCloseCallback(src,event,cam,prv,axs)

out = questdlg(...
    'Are you sure you want to close this preview? Closing will delete the preview object.',...
    'Close Preview',...
    'Yes','No','Recover Handles','No');

switch out
    case 'Yes'
        closePreview(cam);
    case 'No'
        % Bring preview figure to front
        figure(src);
    case 'Recover Handles'
        % Bring preview figure to front
        figure(src);
        
        % Get any/all objects added to the axes
        kids = get(axs,'Children');
        bin = false(size(kids));
        for i = 1:numel(kids)
            switch get(kids(i),'Tag')
                case 'Webcam Preview: Image Object'
                    % Preview object
                    bin(i) = true;
                otherwise
                    % Miscellaneous "added" object
            end
        end
        % Remove preview object
        kids(bin) = [];
        
        % Assign values to the base workspace
        assignin('base','cam',cam);
        assignin('base','prv',prv);
        assignin('base','misc',kids);
        % Notify the user
        fprintf(...
            ['The following variables have been added/updated in your base workspace:\n',...
            '\t "cam" - webcam object handle,\n',...
            '\t "prv" - preview image object handle, and\n',...
            '\t"misc" - any objects that have been added as children of the preview axes handle.\n']);
    otherwise
        fprintf(2,'Action cancelled.\n');
        % Bring preview figure to front
        figure(src);
end

end

