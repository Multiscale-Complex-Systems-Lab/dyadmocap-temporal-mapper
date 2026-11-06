function Tymz = FindGTKMANTimes(folderPath, cacheFile)
% Reads only the time column of each file, to get its first and last time
% stamp. With a cacheFile, the table is re-used on the next call (both the GTK
% and the MAN TM scripts call this function).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
%   Tymz = FindGTKMANTimes(folderPath)
%   Tymz = FindGTKMANTimes(folderPath, cacheFile)
%
% Purpose:
%   Extract original and trimmed time windows for every
%   dyad x group (GTK/MAN) x subject (1/2) trial.
%
%   Trimming rule (stability):
%     - Remove first 25 seconds (calibration)
%     - Remove last 5 seconds  (end transients)
%
% Output: table Tymz with
%   Dyad, Group, Sub, MinTime, MaxTime, OriginalDuration,
%   TrimMinTime, TrimMaxTime, TrimmedDuration, FileID

% -------------------------
% User-defined parameters
% -------------------------
trimStart = 25;   % seconds removed from beginning
trimEnd   = 5;    % seconds removed from end

groups   = ["GTK", "MAN"];
subs     = [1, 2];
% The dyads and their files come from the dataset index (folderPath is the
% index file).
dyadNames = DYMO_dataIndex(folderPath);
numDyads  = numel(dyadNames);

% -------------------------
% Cache
% -------------------------
if nargin >= 2 && ~isempty(cacheFile) && isfile(cacheFile)
    S = load(cacheFile, 'Tymz', 'cacheInfo');
    if isfield(S,'cacheInfo') && strcmp(S.cacheInfo.folderPath, char(folderPath)) ...
            && S.cacheInfo.trimStart == trimStart && S.cacheInfo.trimEnd == trimEnd
        Tymz = S.Tymz;
        fprintf('FindGTKMANTimes: using cached time table %s\n', cacheFile);
        return
    end
end

% Only the first (time) column is read
opts = delimitedTextImportOptions('NumVariables', 1);
opts.DataLines        = [2 Inf];
opts.Delimiter        = "\t";
opts.VariableTypes    = "double";
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule    = "skip";

rows    = numDyads * numel(groups) * numel(subs);
results = cell(rows, 10);
row = 1;

for i = 1:numDyads
    dyadID = dyadNames{i};

    for g = 1:numel(groups)
        for s = subs

            fileName = DYMO_dataFile(dyadID, groups(g), s);   % '' if not in the index
            fileID = sprintf('%s_%s_SUB%03d', dyadID, groups(g), s);

            if isfile(fileName)

                t = readmatrix(fileName, opts);

                % Original time window
                minTime = min(t);
                maxTime = max(t);
                dur     = maxTime - minTime;

                % Trimmed time window
                trimMinTime = minTime + trimStart;
                trimMaxTime = maxTime - trimEnd;

                if trimMaxTime > trimMinTime
                    trimDur = trimMaxTime - trimMinTime;
                else
                    trimMinTime = NaN;
                    trimMaxTime = NaN;
                    trimDur     = NaN;
                end

                results(row,:) = {dyadID, groups(g), s, ...
                                  minTime, maxTime, dur, ...
                                  trimMinTime, trimMaxTime, trimDur, ...
                                  fileID};
            else
                results(row,:) = {dyadID, groups(g), s, ...
                                  NaN, NaN, NaN, ...
                                  NaN, NaN, NaN, ...
                                  fileID};
                fprintf('Missing file: %s\n', fileName);
            end

            row = row + 1;
        end
    end
end

Tymz = cell2table(results, ...
    'VariableNames', {'Dyad','Group','Sub', ...
                      'MinTime','MaxTime','OriginalDuration', ...
                      'TrimMinTime','TrimMaxTime','TrimmedDuration', ...
                      'FileID'});

if nargin >= 2 && ~isempty(cacheFile)
    cacheInfo.folderPath = char(folderPath);
    cacheInfo.trimStart  = trimStart;
    cacheInfo.trimEnd    = trimEnd;
    save(cacheFile, 'Tymz', 'cacheInfo');
end
end
