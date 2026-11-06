function DYMO_clearResults(confirm)
%DYMO_CLEARRESULTS  Delete the results of the ACTIVE run tag, and nothing else.
%
%   DYMO_clearResults              % lists what WOULD be deleted, deletes nothing
%   DYMO_clearResults('confirm')   % deletes it
%
% Every folder this pipeline writes carries the run tag (see DYMO_files.m), so
% this can only ever remove the folders of the analysis that is currently
% selected in DYMO_runTag.m. The other analyses cannot be touched, whatever the
% current folder contains.
%
% Deleting results before a rerun matters for more than tidiness: a stage that is
% not rerun leaves its old tables and figures in place, and they then sit beside
% new ones as though they belonged to the same run. That is how a results folder
% comes to hold two analyses at once.
%
% HOW TO USE
%   DYMO_setup
%   cd <the results folder for this analysis>
%   DYMO_clearResults               % read the list, check it is what you expect
%   DYMO_clearResults('confirm')    % then delete
%
% WHAT IT DELETES
%   <area>_Results_<tag>\  for every main-script area, and Shared_<tag>\,
%   directly under the current folder. It does not search subfolders, and it
%   never deletes anything whose name does not end in the active tag.
%
% NOTE ON DATA
%   These folders hold participant-level .mat files. Deletion is permanent -
%   there is no recycle bin for rmdir. The raw exports are untouched: everything
%   here can be rebuilt by rerunning the pipeline.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 1, confirm = ''; end

tag = DYMO_runTag();

% Only names ending in the active tag are ever considered.
d = dir('*');
d = d([d.isdir]);
keep = ~ismember({d.name}, {'.', '..'}) & ...
       (endsWith({d.name}, ['_Results_' tag]) | strcmp({d.name}, ['Shared_' tag]));
targets = {d(keep).name};

fprintf('\nRun tag        : %s\n', tag);
fprintf('Current folder : %s\n', pwd);

if isempty(targets)
    fprintf('\nNothing to delete: no folder here ends in ''_Results_%s''.\n', tag);
    fprintf('If you expected some, check you are in the right folder for this analysis.\n');
    return
end

fprintf('\n%d folder(s) belong to this run tag:\n\n', numel(targets));
totalBytes = 0;
totalFiles = 0;
for i = 1:numel(targets)
    f = dir(fullfile(targets{i}, '**', '*'));
    f = f(~[f.isdir]);
    bytes = sum([f.bytes]);
    totalBytes = totalBytes + bytes;
    totalFiles = totalFiles + numel(f);
    fprintf('   %-45s %6d files  %8.1f MB\n', targets{i}, numel(f), bytes/1e6);
end
fprintf('\n   %-45s %6d files  %8.1f MB\n', 'TOTAL', totalFiles, totalBytes/1e6);

if ~strcmpi(confirm, 'confirm')
    fprintf(['\nNothing was deleted. If that list is right, run:\n' ...
             '    DYMO_clearResults(''confirm'')\n' ...
             'Deletion is permanent - rmdir does not use the recycle bin.\n']);
    return
end

fprintf('\nDeleting...\n');
for i = 1:numel(targets)
    [ok, msg] = rmdir(targets{i}, 's');
    if ok
        fprintf('   deleted %s\n', targets{i});
    else
        % the usual cause is a file open in MATLAB, Explorer or OneDrive
        warning('Could not delete %s: %s', targets{i}, msg);
    end
end

left = dir(['*_Results_' tag]);
if isempty(left) && ~isfolder(['Shared_' tag])
    fprintf('\nAll folders for tag %s are gone. The folder is clean for a fresh run.\n', tag);
else
    fprintf(['\nSome folders remain. Close any open figures, tables or File Explorer\n' ...
             'windows pointing into them, then run DYMO_clearResults(''confirm'') again.\n']);
end
end
