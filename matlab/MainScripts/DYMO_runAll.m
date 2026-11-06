function T = DYMO_runAll(startStage)
%DYMO_RUNALL  Run the whole DYMO pipeline for the active tag, in order, timed.
%
%   DYMO_runAll          % run every stage, from the beginning
%   DYMO_runAll(6)       % resume at stage 6 (the list is printed at the start)
%   T = DYMO_runAll;     % also return the timing table
%
% WHAT IT DOES
% Runs the stages of the pipeline in the only order they can run in, times
% each one, prints a running total, and writes the timings to
%   <TM_GTK area>\Tables\PipelineTiming_<tag>.csv
% Stages 1-17: temporal mapper, subgraphs, cycles, node distances, graph
% metrics, correlations; 18-20: the mean path distance (hubness) analyses;
% 21-33: correlation bars, purple and icon figures, node size distribution, the
% 8-panel node distance figure, the largest nodes.
% If a stage fails, the timings collected so far are still written and the
% error names the stage, so the run can be resumed at that stage with
% DYMO_runAll(n).
%
% Each stage runs in its own workspace (see DYMO_runStage), so no stage can
% inherit a stale variable from the one before it.
%
% WHERE THE RESULTS GO
% The function changes MATLAB's current folder to the results folder from
% DYMO_config (outputs/matlab_results by default; set matlab_results_dir in
% dymo_config.ini), creating it if needed, and changes back at the end.
% Every output path is relative to that folder. For real participant data the
% results folder must be outside the repository.
%
% EXPECTED TIME
% For the simulated data (13 dyads included) about 1 hour; for about 30 dyads
% several hours, mostly the temporal mapper and the cycle search.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 1 || isempty(startStage), startStage = 1; end

if ~exist('DYMO_files', 'file') || ~exist('tknndigraph', 'file')
    error('DYMO_runAll:setup', 'Run DYMO_setup.m first (it adds Functions/ and tmapper2 to the path).');
end

tag = DYMO_runTag();

% ---- the results folder ----
cfg = DYMO_config();
if ~exist(cfg.resultsDir, 'dir'), mkdir(cfg.resultsDir); end
startFolder = pwd;
cd(cfg.resultsDir);
restoreFolder = onCleanup(@() cd(startFolder));

% ---- the TM scripts that belong to this tag ----
switch tag
    case 'mednorm_180s'
        tmGTK = 'GTK_TM_26June26';      tmMAN = 'MAN_TM_26June26';      win = 180;
    otherwise
        error('DYMO_runAll:unknownTag', ...
            ['Tag ''%s'' is not the analysis of this repository. Add it here and in ' ...
             'DYMO_checkSettings.m before running it.'], tag);
end

% ---- refuse to write results into the code folder ----
codeRoot = fileparts(fileparts(mfilename('fullpath')));      % ...\MainScripts\.. = code root
if strncmpi([pwd filesep], [codeRoot filesep], numel(codeRoot) + 1)
    error('DYMO_runAll:inCodeFolder', ...
        ['The current folder (%s) is inside the code folder. Results hold ' ...
         'participant-level data and must not be written there. cd to the results ' ...
         'folder for this analysis first.'], pwd);
end

% ---- the stages, in the only order they can run in ----
% TM builds the graphs; Subgraphs and the cycle detection need those graphs; every
% statistics stage needs the graphs, and the cycle statistics need the cycles.
stages = { ...
    tmGTK
    tmMAN
    'GTK_Above3Min_SubGraphs_20July'
    'MAN_Above3Min_SubGraphs_20July'
    'Cycles_WinShannon_03July'
    'BothActive_Inactive_09July26'
    'Person1_Person2_Active_09July26'
    'BothActiveBothInactive_14July26'
    'Person1Person2_SpCorr_10July26'
    'GTK_MAN_WholeStats_Pairedttest_8July26'
    'GTK_MAN_Subgraphstats_Pairedttest_8July26'
    'SpearCorr_WholeGraph_17July26'
    'SpearCorr_SubgraphStats_AsySymBoot_07July26'
    'WholeGraphsCycles_Above3Min_03July26'
    'EntroWinner_Cycle_Category_Visualization_03July26'
    'SpearCorr_CycWholeGraph_17July26'
    'EntroWinner_Cycle_Cat_SpCorr_17July'
    % mean path distance (hubness)
    'Hubness_Closeness_22Oct26'
    'Hubness_Roles_23Oct26'
    'RecordPathDistancePValues_05Nov26'
    % correlation bars, purple and icon figures, node size, 8-panel, largest nodes
    'CorrPairBars_PerCategory_28Oct26'
    'SpearCorr_WholeGraph_Bars_29Oct26'
    'SpearCorr_CycWholeGraph_Bars_29Oct26'
    'GTK_MAN_WholeStats_Purple_29Oct26'
    'WholeGraphsCycles_Purple_29Oct26'
    'NodeSizeDistribution_Purple_29Oct26'
    'BothActive_Inactive_Purple_Icons_29Oct26'
    'Person1_Person2_Active_Purple_Icons_29Oct26'
    'BothActiveBothInactive_SpCorr_Icons_29Oct26'
    'Person1Person2_SpCorr_Icons_29Oct26'
    'NodeDistanceIcons_29Oct26'
    'NodeDistance_8Panel_Purple_30Oct26'
    'TopNodes_26Oct26'
    };

nStage = numel(stages);
if startStage < 1 || startStage > nStage
    error('DYMO_runAll:badStart', 'startStage must be between 1 and %d.', nStage);
end

fprintf('\n=================== DYMO_runAll ===================\n');
fprintf('Run tag          : %s\n', tag);
fprintf('Analysed window  : %g s\n', win);
fprintf('Results go under : %s\n', pwd);
fprintf('Stages           : %d to %d of %d\n', startStage, nStage, nStage);
fprintf('Started          : %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('===================================================\n');

Stage      = (startStage:nStage)';
Script     = stages(startStage:nStage);
Seconds    = nan(numel(Stage), 1);
Cumulative = nan(numel(Stage), 1);
Finished   = strings(numel(Stage), 1);

tAll    = tic;
failedAt = [];
for i = 1:numel(Stage)
    fprintf('\n---- stage %d of %d: %s ----\n', Stage(i), nStage, Script{i});
    try
        % Timed HERE, not inside DYMO_runStage: two stage scripts begin with a
        % bare `clear`, which empties the workspace of whatever runs them. This
        % function's workspace is out of their reach, so the timing is safe here.
        tStage = tic;
        DYMO_runStage(Script{i});
        Seconds(i) = toc(tStage);
    catch ME
        failedAt = i;
        fprintf(2, '\nStage %d (%s) FAILED: %s\n', Stage(i), Script{i}, ME.message);
        break
    end
    Cumulative(i) = toc(tAll);
    Finished(i)   = string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf('---- stage %d done in %s; elapsed %s ----\n', ...
        Stage(i), hms(Seconds(i)), hms(Cumulative(i)));
end

total = toc(tAll);

% ---- the timing table, written even if a stage failed ----
T = table(Stage, string(Script), Seconds, Cumulative, Finished, ...
    'VariableNames', {'Stage', 'Script', 'Seconds', 'CumulativeSeconds', 'FinishedAt'});
try
    DYMO_files('TM_GTK');                       % timings live with the TM results
    DYMO_writeTable(T, 'PipelineTiming.csv');   % the tag is added by DYMO_writeTable
catch ME
    warning('Could not write the timing table: %s', ME.message);
end

fprintf('\n=================== summary ===================\n');
for i = 1:numel(Stage)
    if isnan(Seconds(i))
        fprintf('  %2d  %-50s not run\n', Stage(i), Script{i});
    else
        fprintf('  %2d  %-50s %s\n', Stage(i), Script{i}, hms(Seconds(i)));
    end
end
fprintf('  %s\n', repmat('-', 1, 70));
fprintf('  TOTAL %.2f seconds = %s\n', total, hms(total));

if ~isempty(failedAt)
    fprintf(2, ['\nThe run stopped at stage %d. Fix the cause, then resume with\n' ...
                '    DYMO_runAll(%d)\n'], Stage(failedAt), Stage(failedAt));
    error('DYMO_runAll:stageFailed', 'Stage %d (%s) failed - see the message above.', ...
        Stage(failedAt), Script{failedAt});
end

fprintf(['\nAll %d stages completed. Results: %s\n' ...
         'To compare with the Python version: python tools/compare_matlab_python.py\n'], nStage, pwd);
end

% ------------------------------------------------------------------
function s = hms(seconds)
% seconds as h:mm:ss, so a six-hour run is readable at a glance
if isnan(seconds), s = '-'; return; end
h = floor(seconds / 3600);
m = floor(mod(seconds, 3600) / 60);
sec = round(mod(seconds, 60));
s = sprintf('%dh %02dm %02ds', h, m, sec);
end
