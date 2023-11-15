function clearPreview(prv)
% CLEARPREVIEW deletes all added objects from a camera preview.
%   clearPreview(prv)
%
%   Input(s)
%       prv - camera preview image object
%
%   M. Kutzer, 15Nov2023, USNA

%% Check input(s)
% TODO - check inputs

%% Recover preview handles
hndls = recoverPreviewHandles(prv);

%% Find all children of the axes
kids = get(hndls.Axes,'Children');

%% Delete all objects that are not a camera preview image
types = get(kids,'Type');
tf = ~contains(lower(types),'image');

delete(kids(tf));


