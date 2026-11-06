function fileName = DYMO_writeTable(T, fileName)
%DYMO_WRITETABLE  Write a results table safely, into the Tables folder.
%
%   DYMO_writeTable(T, 'SpearmanCorrCycle.xlsx')
%   -> writes <area>_Results_mednorm_180s\Tables\SpearmanCorrCycle_mednorm_180s.xlsx
%      (the area is the main-script folder that called DYMO_files; see there)
%
% Pass a name with a folder in it to write somewhere else.
%
% Two protections:
%   1. The run tag from DYMO_files (e.g. _mednorm_180s) is added to the file
%      name, so tables of different runs never overwrite each other.
%   2. An existing file with the same name is deleted before writing.
%      writetable does NOT clear an existing .xlsx: if the new table is
%      shorter than the old one, the extra old rows/columns stay in the
%      sheet and silently mix with the new results.
%
% Every table name used in the pipeline is unique, so no two scripts write
% the same file.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

F = DYMO_files();
[folder, base, ext] = fileparts(fileName);
if ~endsWith(base, ['_' F.Tag])
    base = [base '_' F.Tag];
end
% no folder given -> the Tables folder of the current results folder, so
% tables do not lie loose among the .mat files (see DYMO_files)
if isempty(folder)
    folder = F.TablesRoot;
end
if ~exist(folder, 'dir')
    mkdir(folder);
end
fileName = fullfile(folder, [base ext]);

if isfile(fileName)
    delete(fileName);
end
writetable(T, fileName);
fprintf('Table saved: %s\n', fileName);
end
