function res = recoverPreviewRes(pHandles)
% RECOVERPREVIEWRES returns the resolution from a camera preview given
% the associated handles.
%   res = recoverPreviewRes(handles)
%
%   Inputs
%       pHandles - structured array containing handles associated with
%                  preview (an empty set is returned if the preview is not
%                  valid)
%           *.Figure - Figure handle that contains the preview
%           *.Axes   - Axes handle that contains the preview
%           *.Image  - Image handle that *is* the preview
%           *.Tag    - [OPTIONAL] Tag descriptor of preview
%           *.Text
%               *.TriggerInfo     - Text handle that contains trigger info
%               *.FramesPerSecond - Text handle that contains frames per second
%               *.Resolution      - Text handle that contains resolution info
%               *.Time            - Text handle that contains the time stamp
%
%   Outputs
%       res - 1x2 array describing the resolution of the preview (e.g.
%             1920x1080 produces res = [1920,1080].
%
%   See also initCamera initWebcam recoverPreviewHandles
%
%   M. Kutzer, 10Mar2022, USNA

%% Check inputs
narginchk(1,1);

% Check for structured array
if ~isstruct(pHandles)
    error('Input must be a valid structure containing preview handles.');
end

% Check fields
flds = {'Figure','Axes','Image','Text'};
tf = isfield(pHandles,flds);
if nnz(tf) ~= numel(tf)
    error('Input must be a valid structure containing preview handles.');
end

sflds = {'TriggerInfo','FramesPerSecond','Resolution','Time'};
tf = isfield(pHandles.Text,sflds);
if nnz(tf) ~= numel(tf)
    error('Input must be a valid structure containing preview handles.');
end

%% Recover time
if ~isempty( pHandles.Text.TriggerInfo )
    % Camera Preview
    txt = get(pHandles.Text.Resolution,'String');
    vals = regexp(txt,'\d*','match');
    if numel(vals) ~= 2
        warning('Resolution string is not in the anticipated \d*x\d* format');
        res = [nan,nan];
    end
    res = [str2double(vals{1}),str2double(vals{2})];
else
    % Webcam Preview
    txt = get(pHandles.Text.Resolution,'String');
    vals = regexp(txt,'\d*','match');
    if numel(vals) ~= 2
        warning('Resolution string is not in the anticipated \d*x\d* format');
        res = [nan,nan];
    end
    res = [str2double(vals{1}),str2double(vals{2})];
end