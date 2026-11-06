function F = DYMO_files(scriptArea)
%DYMO_FILES  One place for the names of every file the scripts share.
%
%   F = DYMO_files('TM_GTK');   % at the top of MainScripts\TM\GTK\...
%   F = DYMO_files();           % anywhere below: keeps the area already set
%   load(F.GTK_TM, 'GTK_AllDyads_GraphData')
%
% WHY THIS EXISTS
% Previously the TM scripts saved 'GTK_AllDyads_FourColorGraphData_26June26.mat'
% while every analysis script loaded 'GTK_Above3Min_Dyads_TM_Data_26June26.mat',
% and the cycle script saved 'GTK_Above30Min_cycles_29July26.mat' while the
% cycle analyses loaded '..._WinShanon_cycles_29July26.mat' (or _03July26), so
% the pipeline could not run end-to-end without renaming files by hand. Now a
% rename is a one-line change here instead of a hunt through 15 scripts.
%
% WHERE THE OUTPUTS GO
% Each main-script folder writes into its OWN results folder, named after that
% folder plus "_Results", so it is obvious which script produced what.
% Inside the results folder:
%
%   TM_GTK_Results_mednorm_180s\        <- MainScripts\TM\GTK
%       ProcessedData\   every .mat file       (F.DataRoot)
%       Tables\          every .csv and .xlsx  (F.TablesRoot, via DYMO_writeTable)
%       Figures\         every figure          (F.FiguresRoot, via DYMO_figureFolder)
%   TM_MAN_Results_mednorm_180s\        <- MainScripts\TM\MAN
%   Cycles_CycleData_Results_mednorm_180s\   <- MainScripts\Cycles\CycleData
%   ... one folder per main-script folder ...
%   Shared_mednorm_180s\                <- the few files every script uses (times cache)
%
% The three inner folders do NOT repeat the run tag: the results folder name
% already carries it, and shorter paths matter on Windows (a path over 260
% characters cannot be saved).
%
% HOW THE AREA IS CHOSEN
% Each main script says which area it is ONCE, at the top:
%       F = DYMO_files('TM_GTK');
% The name is remembered (a persistent variable) so that the guards further
% down the script, and DYMO_writeTable / DYMO_figureFolder, can call
% DYMO_files() with no argument and still write into the same place. If no
% script has set an area yet, 'Other' is used, so nothing is ever lost.
%
% The files that other scripts load (TM graphs, cycles, subgraphs) always keep
% the SAME address, whichever script asks for them: F.GTK_TM points into
% TM_GTK_Results_mednorm_180s\ProcessedData no matter who is running. So a cycles
% or statistics script finds the TM data without knowing where it was made.
%
% The names carry the run tag from DYMO_runTag.m (mednorm_180s), so runs with
% different tags never overwrite each other.
%
% NOTE ON DATA
% The .mat files under ProcessedData include marker coordinates and joint
% angles, i.e. participant-level data. Keep the results folder outside the code
% folder and out of any repository.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

persistent currentArea          % remembered between calls in the same session
persistent tagAnnounced         % so the run tag is printed once per session

% Which analysis this is. Set in DYMO_runTag.m: changing it there moves every
% file and folder of the whole pipeline to a separate set of results, so two
% analyses (the 180 s and the 140 s windows) never mix.
tag = DYMO_runTag();
if isempty(tagAnnounced)
    fprintf('DYMO run tag: %s  (set in DYMO_runTag.m)\n', tag);
    % All the folder names below are RELATIVE, so they are created inside
    % MATLAB's current folder. Printing it once per session means a run can never
    % quietly write its results somewhere unintended.
    fprintf('Results go under: %s\n', pwd);
    tagAnnounced = true;
end

% ---- which main-script folder is running ----
if nargin > 0 && ~isempty(scriptArea)
    currentArea = scriptArea;          % set by the main script, at its top
elseif isempty(currentArea)
    currentArea = 'Other';             % no script set one: keep the output anyway
end

% ---- one results folder per main-script folder ----
areaFolder = @(a) [a '_Results_' tag];

F.Tag        = tag;                    % suffix DYMO_writeTable adds to table names
F.ScriptArea = currentArea;            % handy when printing where things went
F.AreaRoot   = areaFolder(currentArea);

F.DataRoot    = fullfile(F.AreaRoot, 'ProcessedData');   % "ProcessedData" rather
F.TablesRoot  = fullfile(F.AreaRoot, 'Tables');          % than "Data": derived from
F.FiguresRoot = fullfile(F.AreaRoot, 'Figures');         % the raw export, not raw

for folder = {F.DataRoot, F.TablesRoot}
    if ~exist(folder{1}, 'dir')
        mkdir(folder{1});
    end
end
% (DYMO_figureFolder creates the figure folders itself, one per kind of figure)

% ---- fixed addresses of the files that scripts share ----
% These do not depend on the area above, so any script can find them.
gtkData    = fullfile(areaFolder('TM_GTK'),           'ProcessedData');
manData    = fullfile(areaFolder('TM_MAN'),           'ProcessedData');
cycleData  = fullfile(areaFolder('Cycles_CycleData'), 'ProcessedData');
subData    = fullfile(areaFolder('Subgraphs'),        'ProcessedData');
sharedData = ['Shared_' tag];
if ~exist(sharedData, 'dir'); mkdir(sharedData); end

% ---- Temporal Mapper graphs: what every analysis script loads ----
% written by MainScripts/TM/*_TM_*.m
F.GTK_TM = fullfile(gtkData, ['GTK_Above3Min_Dyads_TM_Data_' tag '.mat']);   % GTK_AllDyads_GraphData
F.MAN_TM = fullfile(manData, ['MAN_Above3Min_Dyads_TM_Data_' tag '.mat']);   % MAN_AllDyads_GraphData

% ---- Cycles (written by MainScripts/Cycles/CycleData/Cycles_WinShannon_*.m)
F.GTK_Cycles = fullfile(cycleData, ['GTK_Above3Min_WinShanon_cycles_' tag '.mat']);   % GTKCycles, GTKVis
F.MAN_Cycles = fullfile(cycleData, ['MAN_Above3Min_WinShanon_cycles_' tag '.mat']);   % MANCycles, MANVis

% ---- Subgraphs (written by MainScripts/Subgraphs/*_SubGraphs_*.m)
F.GTK_Subgraphs = fullfile(subData, ['GTK_Above3MinSubGraphData_' tag '.mat']);
F.MAN_Subgraphs = fullfile(subData, ['MAN_Above3MinSubGraphData_' tag '.mat']);

% ---- Intermediate data the TM scripts write and reuse between sections ----
% (skeleton positions, joint angles, velocities, velocity categories)
F.GTK_Skeleton   = fullfile(gtkData, ['GTKallSkeletonData_' tag '.mat']);
F.MAN_Skeleton   = fullfile(manData, ['MANallSkeletonData_' tag '.mat']);
F.GTK_Angles     = fullfile(gtkData, ['GTKallAngles_' tag '.mat']);
F.MAN_Angles     = fullfile(manData, ['MANallAngles_' tag '.mat']);
F.GTK_Velocity   = fullfile(gtkData, ['GTKallVelocity_' tag '.mat']);
F.MAN_Velocity   = fullfile(manData, ['MANallVelocity_' tag '.mat']);
F.GTK_Categories = fullfile(gtkData, ['GTK_AllDyads_VelocityCategory_' tag '.mat']);
F.MAN_Categories = fullfile(manData, ['MAN_AllDyads_VelocityCategory_' tag '.mat']);

% ---- One .mat per dyad, in their own folder inside ProcessedData ----
F.GTK_PerDyadDir = fullfile(gtkData, ['GTK_AllDyads_FourColorGraphData_' tag]);
F.MAN_PerDyadDir = fullfile(manData, ['MAN_AllDyads_FourColorGraphData_' tag]);

% ---- Time table cache (written by FindGTKMANTimes, used by both TM scripts) ----
F.TimesCache = fullfile(sharedData, ['GTKMAN_Times_cache_' tag '.mat']);
end
