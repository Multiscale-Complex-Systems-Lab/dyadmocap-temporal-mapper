function folder = DYMO_figureFolder(varargin)
%DYMO_FIGUREFOLDER  Full path of a figure subfolder, created if needed.
%
%   folder = DYMO_figureFolder('TM_GTK', '02_Skeletons_Frame1')
%   -> <current folder>/TM_GTK_Results_mednorm_180s/Figures/TM_GTK/02_Skeletons_Frame1
%      (the results folder is the one set by DYMO_files; see there)
%
% Every figure of the pipeline is saved through this function, so that
%   * nothing is written loose into the current (results) folder,
%   * each kind of figure has its own folder (e.g. the Shoulder skeleton
%     plots of all dyads in one folder, the Wrist plots in another),
% The root name is set in DYMO_files.m (F.FiguresRoot).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

F = DYMO_files();
folder = fullfile(pwd, F.FiguresRoot, varargin{:});
if ~exist(folder, 'dir')
    mkdir(folder);
end
end
