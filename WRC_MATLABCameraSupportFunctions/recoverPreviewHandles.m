function pHandles = recoverPreviewHandles(prv)
% RECOVERPREVIEWHANDLES recovers the handles of a "videoinput" or "webcam"
% preview.
%   handles = recoverPreviewHandles(prv)
%
%   Inputs
%       prv - preview of "videoinput" or "webcam" object
%
%   Outputs
%       pHandles - structured array containing handles associated with
%                  preview (an empty set is returned if the preview is not
%                  valid)
%           *.Figure - Figure handle that contains the preview
%           *.Axes   - Axes handle that contains the preview
%           *.Image  - Image handle that *is* the preview
%           *.Tag    - Tag descriptor of preview
%           *.Text
%               *.TriggerInfo     - Text handle that contains trigger info
%               *.FramesPerSecond - Text handle that contains frames per second
%               *.Resolution      - Text handle that contains resolution info
%               *.Time            - Text handle that contains the time stamp
%
%   M. Kutzer, 10Mar2022, USNA

%% Check input(s)
narginchk(1,1);

if ~ishandle(prv)
    pHandles = [];
    warning('Specified preview handle is not valid.');
    return
end

switch lower( class(prv) )
    case 'matlab.graphics.primitive.image'
        % Valid preview
    otherwise
        pHandles = [];
        warning('Specified preview handle is not valid.');
        return
end

%% Recover handles
tag = get(prv,'tag');
switch lower( tag )
    case 'camera preview: image object'
        % Parse preview handles
        % Image object
        img = prv;
        % Axes object
        axs = get(img,'Parent');
        % Scroll panel object
        scrlPanel = get(axs,'Parent');
        % Panel object (containing preview image)
        imagPanel = get(scrlPanel,'Parent');
        % Figure object
        fig = get(imagPanel,'Parent');
        % Get children of the preview object
        kids = get(fig,'Children');
        % Panel object (containing preview info)
        infoPanel = kids(2);
        kids = get(infoPanel,'Children');
        % Preview info text objects
        txtTrg = get(kids(1),'Children');
        txtFPS = get(kids(2),'Children');
        txtRes = get(kids(3),'Children');
        txtTime = get(kids(4),'Children');
    case 'webcam preview: image object'
        % Parse preview handles
        % Image object
        img = prv;
        % Axes object
        axs = get(img,'Parent');
        % Scroll panel object
        imagPanel = get(axs,'Parent');
        % Figure object
        fig = get(imagPanel,'Parent');
        % Get children of the preview object
        kids = get(fig,'Children');
        % Panel object (containing preview info)
        infoPanel = kids(2);
        kids = get(infoPanel,'Children');
        % Preview info text objects
        txtTrg = [];
        txtFPS = get(kids(1),'Children');
        txtRes = get(kids(2),'Children');
        txtTime = get(kids(3),'Children');
    otherwise
        % Image object
        img = prv;
        % Axes object
        axs = get(img,'Parent');
        % Get/check parent
        mom = get(axs,'Parent');
        gmom = get(mom,'Parent');
        switch lower( class(gmom) )
            case 'matlab.ui.figure'
                tag = 'Webcam Preview: Image Object';
                imagPanel = mom;
                fig = gmom;
                % Get children of the preview object
                kids = get(fig,'Children');
                % Panel object (containing preview info)
                infoPanel = kids(2);
                kids = get(infoPanel,'Children');
                % Preview info text objects
                txtTrg = [];
                txtFPS = get(kids(1),'Children');
                txtRes = get(kids(2),'Children');
                txtTime = get(kids(3),'Children');
            otherwise
                tag = 'Camera Preview: Image Object';
                scrlPanel = mom;
                imagPanel = gmom;
                % Figure object
                fig = get(imagPanel,'Parent');
                % Get children of the preview object
                kids = get(fig,'Children');
                % Panel object (containing preview info)
                infoPanel = kids(2);
                kids = get(infoPanel,'Children');
                % Preview info text objects
                txtTrg = get(kids(1),'Children');
                txtFPS = get(kids(2),'Children');
                txtRes = get(kids(3),'Children');
                txtTime = get(kids(4),'Children');
        end
end

% Package output
pHandles.Figure = fig;
pHandles.Axes   = axs;
pHandles.Image  = img;
pHandles.Tag    = tag;
pHandles.Text.TriggerInfo = txtTrg;
pHandles.Text.FramesPerSecond = txtFPS;
pHandles.Text.Resolution = txtRes;
pHandles.Text.Time = txtTime;