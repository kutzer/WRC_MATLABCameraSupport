function addHandheldImages(pname,bname_h,i0)
% ADDHANDHELDIMAGES adds handheld images to a calibration folder
%   ADDHANDHELDIMAGES()
%   ADDHANDHELDIMAGES(pname)
%   ADDHANDHELDIMAGES(pname,bname_h)
%   ADDHANDHELDIMAGES(pname,bname_h,i0)
%
%   Input(s)
%            pname - character array containing the folder name (aka the path)
%                    containing the calibration images and robot pose data 
%                    file. Default value is 'CalImgs_yyyymmdd_HHMMSS'.
%          bname_h - base filename for each handheld image. Default value
%                    is 'img'.
%               i0 - starting image index value. Default value is 1.
%
%   Output(s)
%
%
%   See also calibrateUR3e_FixedCamera calibrateUR3e_EyeInHandCamera
%
%   M. Kutzer, 13Apr2022, USNA

% Update(s)
%   11Oct2023 - Get camera and preview from 'caller' workspace
%   11Oct2023 - Create path if it does not exist
%   11Oct2023 - Set default values

%% Set default(s)
if nargin < 1
    pname = sprintf('CalImgs_%s',datestr(now,'yyyymmdd_HHMMSS'));
end
if nargin < 2
    bname_h = 'img';
end
if nargin < 3
    i0 = 1;
end

%% Check input(s)
% Check for valid pathname
if ~ischar(pname)
    error('Path must be specified as a character array.');
end

% Check for valid image base name
if ~ischar(bname_h)
    error('Base filename for images must be specified as a character array.');
end

% Check for valid last image
if i0 > 1
    % Check if other images exist
    fname = fullfile(pname,sprintf('%s_%03d.png',bname_h,i0-1));
    if exist(fname,'file') ~= 2
        error('The following file does not exist:\n\t"%s".',fname);
    end
else
    % Create all new images
end

% TODO - add extrinsics for image overlay?

%% Initialize camera
while true
    rsp = questdlg('Is your fixed camera currently initialized?',...
        'Existing Camera','Yes','No','Cancel','No');

    switch rsp
        case 'Yes'
            % Get current list of variables in workspace
            % TODO - get workspace outside of calling function!
            %list = who;
            list = evalin('caller','who');

            % Find existing camera object with typical variable name
            bin = matches(list,'cam','IgnoreCase',false);
            if nnz(bin) == 0
                bin = matches(list,'cam','IgnoreCase',true);
            end
            if nnz(bin) ~= 0
                idx = find(bin,1,'first');
            else
                idx = 1;
            end

            % Ask user to specify their camera object
            [idx,tf] = listdlg('ListString',list,'SelectionMode','single',...
                'InitialValue',idx,'PromptString',...
                {'Select your existing','"camera" object handle',...
                '(typically "cam" is used as','the variable name)'});

            if tf
                %cam = eval(sprintf('%s',list{idx}));
                cam = evalin('caller',list{idx});
                prv = preview(cam);
                handles = recoverPreviewHandles(prv);
                break
            end

        case 'No'
            % Initialize camera
            [cam,prv,handles] = initCamera;
            break

        case 'Cancel'
            % Action cancelled by user
            fprintf('Action cancelled by user\n');
            return

        otherwise
            warning('Please select a valid response.');
    end
end

%% Take handheld calibration images
% Prompt user for number of calibration images
nImages = inputdlg({'Enter number of handheld calibration images'},...
    'Handheld Calibration Images',[1,35],{'20'});
if numel(nImages) == 0
    warning('Action cancelled by user.');
    cal = [];
    return
end
n = ceil( str2double( nImages{1} ) );

% Create calibration directory if it does not exist
if ~isfolder(pname)
    [status,msg] = mkdir(pname);
    if ~status
        error('Unable to create the specified pathname: %s\n\t%s',pname,msg);
    end
end

% Get standard calibration images
% TODO - share format string across functions
fmt = 'png';
for i = 1:n
    % Define filename of image
    fname = sprintf('%s_%03d.%s',bname_h,(i+i0-1),fmt);
    % Bring preview to foreground
    figure(handles.Figure);
    % Prompt user to move arm
    msg = sprintf(['Move the checkerboard to a new pose that is ',...
        'fully in the camera FOV avoiding poses with glare.',...
        'Taking Image %d of %d.'],i,n);
    f = msgbox(msg,'Get Handheld Image');
    uiwait(f);
   
    % Get the image from the preview
    im = get(prv,'CData');
    % Save the image
    imwrite(im,fullfile(pname,fname),fmt);
end