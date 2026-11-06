function C = DYMO_config()
%DYMO_CONFIG  Where the data are and where the results go.
%
%   C = DYMO_config();
%   C.repoRoot    the repository folder
%   C.dataIndex   the dataset index (JSON) listing the dyads and their files
%   C.resultsDir  where the MATLAB pipeline writes its results
%   C.tmapperDir  the Temporal Mapper (tmapper2) folder, '' if not set
%
% Read from dymo_config.ini in the repository folder, the same file the Python
% version reads (copy dymo_config.example.ini to dymo_config.ini; it is
% git-ignored, so no local path is ever committed). Without that file:
%   dataIndex  = data/simulated/generated/simulated_dyads.json
%   resultsDir = outputs/matlab_results
% For real participant data, keep resultsDir OUTSIDE the repository.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

here = fileparts(mfilename('fullpath'));          % .../matlab/Functions
C.repoRoot   = fileparts(fileparts(here));
C.dataIndex  = fullfile(C.repoRoot, 'data', 'simulated', 'generated', 'simulated_dyads.json');
C.resultsDir = fullfile(C.repoRoot, 'outputs', 'matlab_results');
C.tmapperDir = '';

ini = fullfile(C.repoRoot, 'dymo_config.ini');
if ~isfile(ini), return; end
section = '';
lines = splitlines(fileread(ini));
for i = 1:numel(lines)
    L = strtrim(lines{i});
    if isempty(L) || startsWith(L, {';', '#'}), continue; end
    if startsWith(L, '[') && endsWith(L, ']')
        section = lower(L(2:end-1));
        continue
    end
    if ~strcmp(section, 'paths'), continue; end
    eq = strfind(L, '=');
    if isempty(eq), continue; end
    key = lower(strtrim(L(1:eq(1)-1)));
    val = strtrim(L(eq(1)+1:end));
    if isempty(val), continue; end                % empty = keep the default
    switch key
        case 'data_index',          C.dataIndex  = val;
        case 'matlab_results_dir',  C.resultsDir = val;
        case 'tmapper2_dir',        C.tmapperDir = val;
    end
end
end
