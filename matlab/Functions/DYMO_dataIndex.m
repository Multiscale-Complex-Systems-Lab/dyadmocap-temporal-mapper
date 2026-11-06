function [dyads, index] = DYMO_dataIndex(indexFile)
%DYMO_DATAINDEX  The dyads listed in the dataset index.
%
%   dyads = DYMO_dataIndex();            % index from DYMO_config
%   [dyads, index] = DYMO_dataIndex(indexFile);
%
% The index is a JSON file (the format written by
% data/simulated/simulate_dyad.py):
%   {"dyads": {"<dyad>": {"files": {"casual":   {"Person 1": "<file>", "Person 2": "<file>"},
%                                   "conflict": {"Person 1": "<file>", "Person 2": "<file>"}}}}}
% File names are relative to the folder of the index file. Dyad names must be
% valid MATLAB names (a letter first, then letters, digits or underscores,
% e.g. dyad001 or simdyad01), because jsondecode turns them into field
% names. dyads is a cell array of the dyad names, sorted.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 1 || isempty(indexFile)
    cfg = DYMO_config();
    indexFile = cfg.dataIndex;
end
indexFile = char(indexFile);
if ~isfile(indexFile)
    error('DYMO_dataIndex:missing', ['Dataset index not found: %s\nFor the simulated ' ...
        'data run first (from the repository folder):  python data/simulated/simulate_dyad.py'], indexFile);
end
raw = jsondecode(fileread(indexFile));
f = fieldnames(raw.dyads);
dyads = cell(numel(f), 1);
for i = 1:numel(f)
    dyads{i} = f{i};          % simulated names (simdyadNN) are valid field names already
end
dyads = sort(dyads);
index.file   = indexFile;
index.folder = fileparts(indexFile);
index.dyads  = raw.dyads;
end
