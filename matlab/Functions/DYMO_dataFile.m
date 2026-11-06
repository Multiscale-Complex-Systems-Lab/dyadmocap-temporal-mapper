function fileName = DYMO_dataFile(dyad, group, sub)
%DYMO_DATAFILE  The marker file of one dyad, condition and person.
%
%   fileName = DYMO_dataFile('simdyad01', "GTK", 1)
%
% group is "GTK" (casual chat) or "MAN" (conflict), sub is 1 or 2, as in the
% lab scripts. The file is looked up in the dataset index (DYMO_dataIndex).
% Returns '' if the index has no such file, so callers can treat it as
% missing.
%
% Compressed files (.gz, as the simulator writes) are unpacked once into a
% folder under tempdir and that copy is returned, because readmatrix reads
% plain text only. The copy is reused while it is newer than the .gz file.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

persistent IDX
cfg = DYMO_config();
if isempty(IDX) || ~strcmp(IDX.file, char(cfg.dataIndex))
    [~, IDX] = DYMO_dataIndex(cfg.dataIndex);
end
groupKey = struct('GTK', 'casual', 'MAN', 'conflict');
fileName = '';
dyad = char(dyad);
if ~isfield(IDX.dyads, dyad), return; end
files = IDX.dyads.(dyad).files;
g = groupKey.(char(group));
if ~isfield(files, g), return; end
% jsondecode makes "Person 1" the field Person1
person = sprintf('Person%d', sub);
if ~isfield(files.(g), person), return; end
fileName = fullfile(IDX.folder, files.(g).(person));
if ~isfile(fileName)
    fileName = '';
    return
end
if endsWith(fileName, '.gz')
    outDir = fullfile(tempdir, 'dyadmocap_unzipped');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    [~, base] = fileparts(fileName);              % name without .gz
    plain = fullfile(outDir, base);
    gzInfo = dir(fileName);
    plainInfo = dir(plain);
    if isempty(plainInfo) || plainInfo.datenum < gzInfo.datenum
        gunzip(fileName, outDir);
    end
    fileName = plain;
end
end
