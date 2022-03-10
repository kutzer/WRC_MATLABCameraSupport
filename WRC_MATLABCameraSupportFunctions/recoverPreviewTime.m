function t = recoverPreviewTime(pHandles)
% RECOVERPREVIEWTIME returns the current time from a camera preview given
% the associated handles.
%   t = recoverPreviewTime(handles)
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
%       t - scalar describing current time of preview in seconds. If the
%           available text indicating time does not match the anticipated 
%           format, t = NaN. 
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
    txt = get(pHandles.Text.Time,'String');
    vals = regexp(txt,'\d*','match');
    if numel(vals) ~= 4
        warning('Time string is not in the anticipated HH:MM:SS.sss format');
        t = nan;
    end
    t = str2double(vals{1})*60*60 + str2double(vals{2})*60 + ...
        str2double(vals{3}) + str2double(vals{4})/1000;
else
    % Webcam Preview
    txt = get(pHandles.Text.Time,'String');
    t = str2double(txt);
end