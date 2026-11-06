% %% ============================================================
% %% Pipeline for construction of TM graph networks in MAN
% %% ============================================================
%
% 1. Behavioural categories: the frame-wise MEAN of the normalised joint
%    velocities with a MEDIAN threshold, per person.
% 2. Temporal Mapper (tmapper2, put on the path by DYMO_setup): the velocity is
%    passed DIRECTLY to tknndigraph with 'lowMemory',true, so the N-by-N
%    distance matrix is never built. D_simp is computed block-wise
%    (computeDsimpLowMem), and the network is drawn with plottmgraph, so no
%    step needs an N-by-N matrix.
% 3. The sampling rate is MEASURED from the time column and reported with the %
%    of power above 2 Hz (diagnostic); every recording's inclusion/exclusion is
%    logged to the MAN_DyadInclusionLog table. The >= 180 s rule is based on
%    seconds, not samples.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Run DYMO_setup.m once per MATLAB session before running this script.
% Each section can still be run on its own (it re-loads what it needs).

%% ==================== SETTINGS (edit here) ====================
if ~exist('tknndigraph','file') || ~exist('categorizeVelocity','file')
    error('Run DYMO_setup.m first (adds Functions/ and tmapper2 to the path).');
end

group      = "MAN";
% The recordings are listed in a dataset index (JSON; see
% dymo_config.example.ini in the repository folder). folderPath is the index
% file; DYMO_dataFile gives the marker file of a dyad, group and person.
cfg = DYMO_config();
folderPath = string(cfg.dataIndex);
subs       = [1 2];
marginSec  = 3;        % seconds trimmed from both ends of the common GTK/MAN window
minStableDur = 180;    % keep only recordings with >= 180 s of stable data
expectedDyadCount = [];   % [] = no check; or the number of dyads expected to pass
% ---- Sampling rate and filtering (see the data summary printed after loading) ----
% Fs = [] measures the sampling rate from the time column of the files
% (recommended), and the rate is reported.
Fs         = [];
FsExpected = [];       % optional check of the measured rate, e.g. 25 or 120 (Hz). [] = no check
% Optional zero-phase Butterworth low-pass of the marker coordinates, applied
% BEFORE the angles and the derivative. [] = no filter (the reported analysis).
% Set e.g. 2 (Hz) only for a sensitivity analysis of the effect of filtering
% before the derivative.
lowpassCutoffHz = [];  % [] = no filter; e.g. 2 (Hz) for a sensitivity analysis
lowpassOrder    = 2;   % filtfilt doubles the effective order
powerCheckHz    = 2;   % frequency used by the power-above diagnostic below
histColor  = [1 0.4 0.4];

% temporal mapper construction parameters
k        = 5;          % k nearest neighbours
dmap     = 3;          % compression (filtergraph distance)
texclude = 3;          % temporal exclusion window (samples)

% velocity category threshold: 'median' (default) or 'mean'
thresholdMethod = 'median';

% How each joint is normalised BEFORE the frame-wise activity score that
% decides the four behavioural categories. See Functions/TM/normalizeVelocity.m.
%   'zscore' : (v - mean)/SD of the SIGNED velocity.
%   'absz'   : |z|, the MAGNITUDE of the z-scored velocity - "active if the
%              average RATE OF CHANGE across the 11 joint angles is above the
%              median".
%   'median' : angular SPEED |v| divided by that joint's median speed, so the
%              typical speed is 1, nothing is negative and joints cannot cancel
%              when they are averaged (the reported analysis).
% 'absz' and 'median' both measure a rate of change and differ only in the
% normaliser (SD vs median). 'zscore' measures something else: the signed net
% velocity, which is not a rate of change.
% Changing this changes every category-dependent result, so run it under its
% own tag in DYMO_runTag.m and keep the two sets of results apart.
categoryNormalization = 'median';   % the reported analysis (run tag mednorm_180s)

% NOTE ON SCOPE: this setting affects only the CATEGORY score. The temporal
% mapper graph is built from whatever graphNormalization says, just below.
% The graph keeps the SIGNED velocity because a joint bending and a joint
% straightening are different states, while the categories are about amount
% only, where signs cancel. graphNormalization = 'median' (under its own run
% tag) tests whether direction matters to the graph.

% ---- normalisation of the TEMPORAL MAPPER's input (separate from the above) ----
% 'zscore' : (v - mean)/SD per joint, SIGNED (the reported analysis). Bending
%            and straightening are different states to the graph.
% 'median' : |v|/median(|v|) per joint - the same transform the categories use.
%            The SIGN IS DISCARDED, so a joint bending and a joint straightening
%            at the same speed look identical to the graph.
% Changing this rebuilds every graph, so every graph metric, node distance and
% cycle result changes with it. Run it under its own tag and its own results root.
graphNormalization = 'zscore';   % 'zscore' = reported; 'median' and 'abszscore' = tests (see graphInputVelocity)

% Number of samples used for the TM graph. Inf = ALL samples (of the uniform
% window below), which is what the analysis uses; it is possible because no
% N-by-N matrix is built.
maxSamples = Inf;

% ---- uniform analysis window ----
% The >= 180 s inclusion rule decides which dyads are kept: a dyad is kept only
% if its stable window holds at least minStableDur seconds. This setting decides
% how much of that window is analysed. With uniformWindowSec = 180 every kept
% dyad contributes exactly 180 s, so node counts, edge counts and cycle counts
% are comparable between dyads and between GTK and MAN instead of partly
% measuring how long a dyad happened to be recorded. Set uniformWindowSec = []
% to analyse each dyad's whole stable window.
% This supersedes maxSamples: with a uniform window the recordings are already
% the same length before the graph is built.
uniformWindowSec = 180;      % [] = whole stable window; 180 = 180 s for every dyad
uniformWindowPos = 'first';  % which 180 s: 'first', 'centre' or 'last' of the stable window

% Stop now if these settings do not match the run tag, rather than after an hour
% of computation has been written into the wrong analysis's folder. The pairs are
% listed in DYMO_checkSettings.m; add a row there for a new analysis.
DYMO_checkSettings(uniformWindowSec, categoryNormalization, graphNormalization);

% ---- which per-dyad figures to make ----
% Every figure is saved three times (.fig, .png, .pdf), and nearly all the run
% time goes on writing figures, not on the temporal mapper itself (the graph
% takes under 2 s per dyad). These switches decide which figures are produced. The DATA is saved either way, so a figure switched off
% here can be made later from the saved .mat files without rerunning anything.
makeSkeletonPlots       = true;    % 1 per dyad: both partners at frame 1
makeCategoryBarPlots    = true;    % 1 per dyad: time in each behavioural category
makeFourColorGraphPlots = true;    % 1 per dyad: the TM graph coloured by category

% ---- fast mode: build the temporal mapper and skip the heavy figures ----
% Set fastTMOnly = true to build the temporal mapper and the group summary only,
% skipping the roughly 25 per-dyad figures listed in the block further down.
% Nothing is lost by doing that: every figure can be made afterwards from the
% saved .mat files without rerunning the pipeline. (The skeleton animations,
% one MP4 per dyad, are commented out below.)
fastTMOnly = false;

% Distance-matrix (recurrence) PLOTS only: the image is computed on at most
% this many evenly spaced samples, purely for display.
% Angle-vector plots on the skeletons (6 figures per dyad).
% angleSkeletonDyads = [] -> all dyads; e.g. [1 5] -> only dyads 1 and 5.
makeAngleSkeletonPlots = true;
angleSkeletonDyads     = [];
angleSkeletonFrame     = 1;

% Calculated angles over time (11 figures + 1 overview per dyad).
% angleTimeDyads = [] -> all dyads; e.g. [1 5] -> only dyads 1 and 5.
makeAngleTimePlots = true;
angleTimeDyads     = [];
makeAngleOverview  = true;

makeDistanceMatrixPlots = true;
maxPlotPoints = 4000;

% Group-level summary across all included dyads (last section before saving).
% Frequency bands for the angular-velocity summary; the last band runs up to
% the Nyquist frequency Fs/2 (25 Hz at 50 Hz).
makeGroupSummary = false;    % true = also the four across-dyad summary figures
bandEdges        = [0 2 5 10];

% ---- optional per-dyad figures (not part of the reported figure set) ----
makeVelocitySpectrumPlots = false;  % velocity spectrum of each dyad
makeNodeFigures           = false;  % node figures (CategoryNodeFigures,
                                    % CategoryNodePanels, NodeGallery); set true
                                    % to inspect nodes
nodeFigureDyads           = [];     % [] = every included dyad; e.g. [1 5] for two
galleryNumNodes           = 12;     % nodes shown in the gallery figure

% Filter sensitivity (2 Hz low-pass): it repeats angles, velocity and the graph,
% so it roughly doubles the time for each dyad it runs on, and it is run on the
% first sensitivityNumDyads dyads only. [] = off (the reported analysis); set 2
% to run it.
sensitivityCutoffHz   = [];
sensitivityNumDyads   = 5;
sensitivityFilterOrder = 2;

if fastTMOnly
    makeAngleSkeletonPlots    = false;   % 6 figures per dyad
    makeAngleTimePlots        = false;   % 12 figures per dyad
    makeDistanceMatrixPlots   = false;   % 1 per dyad
    makeFourColorGraphPlots   = false;   % 1 per dyad
    makeVelocitySpectrumPlots = false;   % 1 per dyad
    makeNodeFigures           = false;   % 6 per dyad
    sensitivityCutoffHz       = [];      % skips the 2 Hz rerun of the first dyads
    disp(['fastTMOnly = true: building the temporal mapper and the group summary, ' ...
          'skipping the per-dyad angle, distance-matrix, graph, spectrum and node figures.']);
end


% ---- where the outputs go ----
% Everything is written to the CURRENT MATLAB folder. Keep that folder OUTSIDE
% this code folder: the outputs include .mat files with marker coordinates and
% joint angles (participant-level data, which must stay in the data storage and
% out of any repository).
% Pressing Run in the editor and answering "Change Folder" is what puts you in
% the script's own folder; answer "Add to Path" instead, or cd to your results
% folder first and start the script by name.
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
if strncmpi([pwd filesep], [codeRoot filesep], numel(codeRoot)+1)
    warning(['You are running from inside the code folder:\n  %s\n' ...
             'Outputs (including .mat files with marker coordinates) would be ' ...
             'written here. cd to your results folder first.'], pwd);
end

% 'TM_MAN' names this script's results folder: TM_MAN_Results_mednorm_180s\ in the
% current folder, with ProcessedData, Tables and Figures inside it.
F = DYMO_files('TM_MAN');


%% === Load, trim, check sampling rate, and keep dyads with >= 180 s ===
% INCLUSION RULE: a recording is kept when its
% stable window (common GTK/MAN window minus marginSec at both ends, after
% calibration trimming) contains >= minStableDur seconds. The duration is
% measured from the TIME COLUMN of the file (seconds), so the rule does not
% depend on the sampling rate. Because both conditions use the same common
% window length, a dyad passes (or fails) in GTK and MAN alike.
% A dyad is kept only if BOTH partners pass, and every file's fate is written
% to the MAN_DyadInclusionLog table (duration, measured sampling rate, % power
% above powerCheckHz, and the reason for any exclusion).
tic;
Tymz = FindGTKMANTimes(folderPath, F.TimesCache);  % trimmed calibration times

dyadsMAN = unique(Tymz.Dyad(strcmp(Tymz.Group, group)));

MANallDataFiles = cell(length(dyadsMAN), length(subs));

opts = delimitedTextImportOptions("NumVariables",128);
opts.DataLines        = [2 Inf];
opts.Delimiter        = "\t";
opts.VariableTypes    = repmat("double",1,128);
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule    = "read";

nMax = length(dyadsMAN) * length(subs);
L = table(strings(nMax,1), repmat(string(group),nMax,1), zeros(nMax,1), false(nMax,1), ...
    nan(nMax,1), nan(nMax,1), zeros(nMax,1), nan(nMax,1), nan(nMax,1), false(nMax,1), strings(nMax,1), ...
    'VariableNames', {'Dyad','Group','Sub','FileFound','CommonWindow_s','StableDuration_s', ...
                      'Samples','FsMeasured_Hz','PowerAbove_pct','Included','Reason'});
iL = 0;

for d = 1:length(dyadsMAN)
    dyadID = dyadsMAN{d};

    % Get GTK + MAN trimmed times to compute the common stable window
    gtkRow = strcmp(Tymz.Dyad, dyadID) & Tymz.Group=="GTK";
    manRow = strcmp(Tymz.Dyad, dyadID) & Tymz.Group=="MAN";

    dur_GTK = max(Tymz.TrimMaxTime(gtkRow)) - min(Tymz.TrimMinTime(gtkRow));
    dur_MAN = max(Tymz.TrimMaxTime(manRow)) - min(Tymz.TrimMinTime(manRow));
    windowOK = any(gtkRow) && any(manRow) && isfinite(dur_GTK) && isfinite(dur_MAN) ...
               && min(dur_GTK,dur_MAN) > 2*marginSec;
    if windowOK
        W = getCommonWindow(dur_GTK, dur_MAN, marginSec);
    end

    for s = 1:length(subs)
        iL = iL + 1;
        L.Dyad(iL) = dyadID;
        L.Sub(iL)  = subs(s);

        if ~windowOK
            L.Reason(iL) = "no usable GTK/MAN common window (a condition missing or too short)";
            continue;
        end
        L.CommonWindow_s(iL) = W.DurationStable;

        fileName = DYMO_dataFile(dyadID, group, subs(s));   % from the dataset index
        if ~isfile(fileName)
            L.Reason(iL) = "file missing";
            continue;
        end
        L.FileFound(iL) = true;

        dataArray = readmatrix(fileName, opts);

        % Calibration trimming, then the stable window relative to the trimmed start
        rowIdx = strcmp(Tymz.Dyad, dyadID) & Tymz.Group==group & Tymz.Sub==subs(s);
        tTrimStart = min(Tymz.TrimMinTime(rowIdx));
        tTrimEnd   = max(Tymz.TrimMaxTime(rowIdx));
        tStart = tTrimStart + W.Man.Start;
        tEnd   = tTrimStart + W.Man.End;

        t = dataArray(:,1);
        keep = t >= tTrimStart & t <= tTrimEnd & t >= tStart & t <= tEnd;
        dataArray = dataArray(keep, :);

        if size(dataArray,1) < 2
            L.Reason(iL) = "no samples inside the stable window";
            continue;
        end

        % Interpolate missing values (column-wise, same as before)
        dataArray = fillmissing(dataArray, 'linear');

        stableDur = max(dataArray(:,1)) - min(dataArray(:,1));
        L.StableDuration_s(iL) = stableDur;
        L.Samples(iL)          = size(dataArray,1);

        % ---- sampling rate measured from the time column ----
        dt = diff(dataArray(:,1));
        FsFile = 1 / median(dt(dt > 0));
        L.FsMeasured_Hz(iL) = FsFile;

        % ---- diagnostic: high-frequency content of the raw coordinates ----
        % % of (detrended) marker-coordinate power above powerCheckHz. This
        % is reported only (it changes nothing). Low-pass filtered data would
        % give close to 0 %; marker jitter gives clearly more.
        L.PowerAbove_pct(iL) = powerAbovePct(dataArray(:,3:end), FsFile, powerCheckHz);

        % ---- optional low-pass filter (off by default) ----
        if ~isempty(lowpassCutoffHz)
            [bLP, aLP] = butter(lowpassOrder, lowpassCutoffHz / (FsFile/2));
            dataArray(:,3:end) = filtfilt(bLP, aLP, dataArray(:,3:end));
        end

        if stableDur < minStableDur
            L.Reason(iL) = sprintf("stable duration %.1f s < %d s", stableDur, minStableDur);
            continue;
        end

        L.Included(iL) = true;
        L.Reason(iL)   = "included";
        MANallDataFiles{d,s} = dataArray;
    end

    % ---- dyad-level rule: both partners must pass ----
    got = ~cellfun(@isempty, MANallDataFiles(d,:));
    if any(got) && ~all(got)
        MANallDataFiles(d,:) = {[]};
        rowsThisDyad = find(L.Dyad(1:iL) == dyadID);
        for r = rowsThisDyad(:)'
            if L.Included(r)
                L.Included(r) = false;
                L.Reason(r)   = "partner excluded (both partners must pass)";
            end
        end
    end
end
L = L(1:iL,:);

% ---- sampling rate used for all velocities ----
FsIncl = L.FsMeasured_Hz(L.Included);
if isempty(FsIncl)
    error('No recording passed the inclusion rule.');
end
if max(FsIncl) - min(FsIncl) > 0.01 * median(FsIncl)
    warning('Measured sampling rate differs between files (%.3f to %.3f Hz). See the inclusion log.', ...
        min(FsIncl), max(FsIncl));
end
if isempty(Fs)
    Fs = median(FsIncl);
elseif abs(Fs - median(FsIncl)) > 0.01 * median(FsIncl)
    warning(['Fs is set to %g Hz but the time column says %.3f Hz. The measured value is ' ...
             'what the data are; set Fs = [] to use it.'], Fs, median(FsIncl));
end
if ~isempty(FsExpected) && abs(FsExpected - median(FsIncl)) > 0.01 * FsExpected
    warning('Measured sampling rate %.3f Hz differs from FsExpected = %g Hz.', median(FsIncl), FsExpected);
end

% ---- cut every kept recording to the uniform analysis window ----
% Done here, before the angles and the velocities, so that every later section
% (angles, velocity, categories, the TM graph, the spectra, the figures) sees
% exactly the same samples. The inclusion decisions above are not revisited.
if ~isempty(uniformWindowSec)
    % + 1e-6, so that a measured rate of 49.99999999999999 Hz (round-off in the
    % time column) still gives 9,000 samples, not 8,999, as in the Python
    % version. It changes nothing when the rate is not a round-off away from a
    % whole number of samples.
    nWant   = floor(uniformWindowSec * Fs + 1e-6);          % 9,000 samples at 50 Hz
    haveAll = cellfun(@(x) size(x,1), {MANallDataFiles{~cellfun(@isempty, MANallDataFiles)}});
    nKeep   = min([nWant, haveAll]);
    if nKeep < nWant
        % Can happen if a recording passes the >= 180 s rule on its time column
        % but holds fewer samples than 180 s implies (dropped frames).
        warning(['The shortest kept recording has %d samples (%.2f s), fewer than the %d ' ...
                 'samples that %g s implies. Every dyad is cut to %d samples (%.2f s) ' ...
                 'instead, so they all still have the same length.'], ...
                 min(haveAll), min(haveAll)/Fs, nWant, uniformWindowSec, nKeep, nKeep/Fs);
    end

    % record in the log what was actually analysed, per recording
    L = addvars(L, nan(height(L),1), nan(height(L),1), ...
        'NewVariableNames', {'Analysed_Samples','Analysed_Duration_s'});

    for d = 1:size(MANallDataFiles,1)
        for s = 1:size(MANallDataFiles,2)
            X = MANallDataFiles{d,s};
            if isempty(X); continue; end
            switch lower(uniformWindowPos)
                case 'first'
                    i0 = 1;
                case 'centre'
                    i0 = 1 + floor((size(X,1) - nKeep)/2);
                case 'last'
                    i0 = size(X,1) - nKeep + 1;
                otherwise
                    error('uniformWindowPos must be ''first'', ''centre'' or ''last''.');
            end
            MANallDataFiles{d,s} = X(i0:i0+nKeep-1, :);

            r = find(strcmp(L.Dyad, dyadsMAN{d}) & L.Sub == subs(s), 1);
            if ~isempty(r)
                L.Analysed_Samples(r)    = nKeep;
                L.Analysed_Duration_s(r) = MANallDataFiles{d,s}(end,1) - MANallDataFiles{d,s}(1,1);
            end
        end
    end
    fprintf('Uniform analysis window: %s %d samples (%.2f s) of every kept recording.\n', ...
        lower(uniformWindowPos), nKeep, nKeep/Fs);
end

fprintf('\n===== MAN DATA SUMMARY =====\n');
fprintf('Sampling rate used           : %.3f Hz (dt = %.4f s), measured from the time column\n', Fs, 1/Fs);
fprintf('Recordings with data         : %d\n', sum(L.FileFound));
fprintf('Dyads included (>= %d s)    : %d\n', minStableDur, numel(unique(L.Dyad(L.Included))));
if ~isempty(uniformWindowSec)
    fprintf('Analysed window per dyad     : %d samples (%.2f s), the %s %g s of the stable window\n', ...
        nKeep, nKeep/Fs, lower(uniformWindowPos), uniformWindowSec);
else
    fprintf('Analysed window per dyad     : the whole stable window (it varies between dyads)\n');
end
fprintf('Median power above %g Hz      : %.2f %% of marker power', powerCheckHz, median(L.PowerAbove_pct(L.Included), 'omitnan'));
if isempty(lowpassCutoffHz)
    fprintf('  (no extra filter applied)\n');
else
    fprintf('  (before the %g Hz filter applied here)\n', lowpassCutoffHz);
end
fprintf('texclude = %d samples = %.3f s;  7,000 samples = %.1f s at this rate\n', texclude, texclude/Fs, 7000/Fs);
fprintf('============================\n\n');

DYMO_writeTable(L, 'MAN_DyadInclusionLog.csv');

% ---- check: the number of included dyads (>= 180 s) ----
includedDyads = unique(L.Dyad(L.Included));
fprintf('MAN: %d dyads included.\n', numel(includedDyads));
if ~isempty(expectedDyadCount) && numel(includedDyads) ~= expectedDyadCount
    warning(['MAN: %d dyads passed the >= %d s rule, but %d were expected. ' ...
             'Open the MAN_DyadInclusionLog table to see which dyads differ and why.'], ...
             numel(includedDyads), minStableDur, expectedDyadCount);
end
% If a table of stable durations from an earlier run is in this folder, compare
% the dyad lists
oldCsv = 'MAN_StableDurations.csv';
if isfile(oldCsv)
    Told   = readtable(oldCsv, 'TextType', 'string');
    oldSet = unique(string(Told.Dyad));
    onlyOld = setdiff(oldSet, includedDyads);
    onlyNew = setdiff(includedDyads, oldSet);
    if isempty(onlyOld) && isempty(onlyNew)
        fprintf('MAN: included dyads are IDENTICAL to %s (earlier run).\n', oldCsv);
    else
        fprintf('MAN: dyads only in the old table: %s\n', strjoin(onlyOld, ', '));
        fprintf('MAN: dyads only in the new run  : %s\n', strjoin(onlyNew, ', '));
        for dd = onlyOld(:)'
            r = find(L.Dyad == dd);
            for rr = r(:)'
                fprintf('   %s Sub %d: %s\n', dd, L.Sub(rr), L.Reason(rr));
            end
        end
    end
end

% Per-recording durations of the included recordings
TrimTableMAN = L(L.Included, {'Dyad','Group','StableDuration_s'});
TrimTableMAN.Properties.VariableNames{'StableDuration_s'} = 'StableDuration';
DYMO_writeTable(TrimTableMAN, 'MAN_StableDurations.csv');
toc;

%% Stable durations per dyad (one value per dyad; both partners share the window)
% "All" = every dyad with data (before the >= 180 s rule); "Above180s" = included dyads.
[~, iaAll] = unique(L.Dyad(L.FileFound & isfinite(L.StableDuration_s)), 'stable');
durAll     = L.StableDuration_s(L.FileFound & isfinite(L.StableDuration_s));
durAll     = durAll(iaAll);
[~, iaInc] = unique(L.Dyad(L.Included), 'stable');
perDyadDurations = L.StableDuration_s(L.Included);
perDyadDurations = perDyadDurations(iaInc);

% Histogram: all dyads with data, with the 180 s cut-off marked
edges = 0:5:max(durAll)+5;
figure;
histogram(durAll, edges, 'FaceColor',histColor,'FaceAlpha',0.8,'Normalization','count');
xline(minStableDur, 'k--', sprintf('%d s', minStableDur), 'LineWidth', 2);
xlabel('Stable Duration (s)');
ylabel('Number of Dyads');
title(sprintf('MAN Stable Durations (all dyads with data, n = %d)', numel(durAll)));
grid on;
set(gcf,'Position',[100,100,1400,900]);
AutoSavePublishableFigure('MAN_StableTimeWindow', gcf, DYMO_figureFolder('TM_MAN','01_StableDurations','All'));

% Histogram (>=180s only)
edges = 170:5:max(perDyadDurations)+5;
figure;
histogram(perDyadDurations, edges, ...
    'FaceColor',histColor, ...
    'FaceAlpha',0.7, ...
    'Normalization','count');
xlabel('Stable Duration (s)');
ylabel('Number of Dyads');
title(sprintf('MAN Stable Durations (>= %d s, n = %d)', minStableDur, numel(perDyadDurations)));
grid on;
xlim([170 max(perDyadDurations)+5]);
set(gcf,'Position',[100,100,1400,900]);
AutoSavePublishableFigure('MAN_G180StableTimeWindow', gcf, DYMO_figureFolder('TM_MAN','01_StableDurations','Above180s'));

%% ==================== SKELETON POSITIONS (vectorised) ====================
tic;
if ~exist('MANallDataFiles','var')
    error('Run the first section (data loading) first.');
end

MANallSkeletonData = cell(size(MANallDataFiles));

for d = 1:size(MANallDataFiles,1)
    for s = 1:size(MANallDataFiles,2)
        dataCleaned = MANallDataFiles{d, s};
        if isempty(dataCleaned)
            continue;
        end

        num_joints = floor((size(dataCleaned, 2) - 2) / 3);
        cols = 3 + (0:num_joints-1) * 3;         % x columns

        skeletonPositions = zeros(size(dataCleaned,1), num_joints, 3);
        skeletonPositions(:,:,1) =  dataCleaned(:, cols);      % X
        skeletonPositions(:,:,2) = -dataCleaned(:, cols + 2);  % Y = -Z
        skeletonPositions(:,:,3) =  dataCleaned(:, cols + 1);  % Z =  Y

        % Seat position (joint 1) = midpoint of joints 2 and 3, every frame
        skeletonPositions(:,1,:) = (skeletonPositions(:,2,:) + skeletonPositions(:,3,:)) / 2;

        MANallSkeletonData{d, s} = skeletonPositions;
    end
end

save(F.MAN_Skeleton, 'MANallSkeletonData', '-v7.3');
toc;

%% ============ SKELETON PLOTS, frame 1 (optional: makeSkeletonPlots) ============
if makeSkeletonPlots
    if ~exist('MANallSkeletonData','var')
        if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
        load(F.MAN_Skeleton, 'MANallSkeletonData');
    end

    MANskeletonFolder = DYMO_figureFolder('TM_MAN','02_Skeletons_Frame1');
    if ~exist(MANskeletonFolder, 'dir')
        mkdir(MANskeletonFolder);
    end

    [numManDyads, numSubjects] = size(MANallSkeletonData);
    colors = {'b','r'};

    tic
    for d = 1:numManDyads
        if all(cellfun(@isempty, MANallSkeletonData(d,:)))
            continue;   % no empty figure for a skipped dyad
        end

        figure('Visible','on');
        hold on;

        for s = 1:numSubjects
            skeletonPositions = MANallSkeletonData{d, s};
            if isempty(skeletonPositions)
                continue;
            end

            X = squeeze(skeletonPositions(1, :, 1));
            Y = squeeze(skeletonPositions(1, :, 2));
            Z = squeeze(skeletonPositions(1, :, 3));

            plot3(X, Y, Z, 'o', 'MarkerSize', 6, ...
                  'MarkerFaceColor', colors{s}, ...
                  'MarkerEdgeColor', colors{s});

            % Seat marker
            plot3(X(1), Y(1), Z(1), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'y');
        end

        xlabel('X'); ylabel('Y'); zlabel('Z');
        grid off; axis equal; axis off;
        view(97.17, 1.99);
        title(['MAN Dyad ' num2str(d) ' Skeleton View - Frame 1']);

        AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_Skeleton_Plot'], gcf, MANskeletonFolder);
        close(gcf);
    end
    toc
    disp('All MAN dyad skeleton plots saved successfully.');
end

%% ==================== MAN SKELETON ANIMATIONS (COMMENTED OUT: SLOW) ====================
% Commented out because writing one MP4 per dyad takes a long time.
% To run it: delete the two lines that contain only %{ and %} below
% then run this section (Ctrl+Enter). Put them back to switch it off again.
%
% The markers are drawn ONCE and only their X/Y/Z data are updated each frame;
% axis limits are fixed once, so every frame has the same framing; frameStep
% writes every n-th frame (frameStep = 2 halves the time; the playback
% FrameRate is adjusted so the video stays real time); the figure is off-screen
% with a fixed size, and dyads with no data are skipped.
%{
tic

frameStep   = 1;      % 1 = every frame; 2 = every 2nd frame (2x faster), ...
videoFs     = Fs;     % measured sampling rate (Hz)
colors      = {'b', 'r'};

if ~exist('MANallSkeletonData','var')
    if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
    load(F.MAN_Skeleton, 'MANallSkeletonData');
end

animationFolder = DYMO_figureFolder('TM_MAN','03_Skeleton_Animations');
if ~exist(animationFolder, 'dir')
    mkdir(animationFolder);
end

[numManDyads, numSubjects] = size(MANallSkeletonData);

for d = 1:numManDyads

    present = find(~cellfun(@isempty, MANallSkeletonData(d,:)));
    if isempty(present)
        continue;
    end

    % frames available for every present subject
    num_frames = min(cellfun(@(S) size(S,1), MANallSkeletonData(d,present)));
    frames     = 1:frameStep:num_frames;

    videoFilename = fullfile(animationFolder, ['MAN_Dyad' num2str(d) '_3D_Skeleton_Animation.mp4']);
    videoWriter = VideoWriter(videoFilename, 'MPEG-4');
    videoWriter.FrameRate = videoFs / frameStep;   % keeps playback in real time
    open(videoWriter);

    fig = figure('Visible','off', 'Color','w', 'Position',[100 100 960 720]);
    ax  = axes(fig);
    hold(ax, 'on');
    axis(ax, 'equal');
    axis(ax, 'off');
    view(ax, 97.17, 1.99);
    title(ax, ['3D Skeleton Animation - MAN Dyad ', num2str(d)], 'FontSize', 16);

    % fixed axis limits covering the whole recording (both people)
    allXYZ = cell2mat(cellfun(@(S) reshape(S(frames,:,:), [], 3), ...
                              MANallSkeletonData(d,present)', 'UniformOutput', false));
    lo = min(allXYZ, [], 1);
    hi = max(allXYZ, [], 1);
    pad = 0.05 * max(hi - lo);
    xlim(ax, [lo(1)-pad hi(1)+pad]);
    ylim(ax, [lo(2)-pad hi(2)+pad]);
    zlim(ax, [lo(3)-pad hi(3)+pad]);

    % create the markers once (joints + yellow seat marker per person)
    hJoint = gobjects(numSubjects,1);
    hSeat  = gobjects(numSubjects,1);
    for s = present
        P = MANallSkeletonData{d, s};
        hJoint(s) = plot3(ax, P(1,:,1), P(1,:,2), P(1,:,3), 'o', 'MarkerSize', 8, ...
                          'MarkerFaceColor', colors{s}, 'MarkerEdgeColor', colors{s});
        hSeat(s)  = plot3(ax, P(1,1,1), P(1,1,2), P(1,1,3), 'o', 'MarkerSize', 10, ...
                          'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
    end

    for frameIdx = frames
        for s = present
            P = MANallSkeletonData{d, s};
            set(hJoint(s), 'XData', P(frameIdx,:,1), 'YData', P(frameIdx,:,2), 'ZData', P(frameIdx,:,3));
            set(hSeat(s),  'XData', P(frameIdx,1,1), 'YData', P(frameIdx,1,2), 'ZData', P(frameIdx,1,3));
        end
        drawnow limitrate;
        writeVideo(videoWriter, getframe(fig));
    end

    close(videoWriter);
    close(fig);

    fprintf('Video saved for MAN Dyad %d (%d frames): %s\n', d, numel(frames), videoFilename);
end

toc
disp('All MAN dyad animations saved successfully.');
%}

%% ==================== JOINT ANGLES ====================
% All 11 angles are defined in ONE place, Functions/TM/skeletonAngleGeometry.m,
% which is also what the angle-vector skeleton plots below use.
tic
if ~exist('MANallDataFiles','var')
    error('Run the first section (data loading) first.');
end

[numManDyads, numSubjects] = size(MANallDataFiles);
MANallAngles = cell(numManDyads, numSubjects);

for d = 1:numManDyads
    for s = 1:numSubjects
        if ~isempty(MANallDataFiles{d, s})
            MANallAngles{d,s} = computeJointAngles(MANallDataFiles{d, s});
        end
    end
end

save(F.MAN_Angles,'MANallAngles','Fs','-v7.3');   % Fs = measured sampling rate
toc
disp('All MAN dyad angles saved successfully.');

%% ==================== ANGLE VECTORS ON SKELETONS (frame 1) ====================
% For each dyad: one figure per joint group (Shoulder, Wrist, Elbow, Knee,
% Ankle, Head) with both people, the two vectors of every angle
% (green = v1, magenta = v2) and the angle value. Uses the same angle
% definitions as the calculation above (skeletonAngleGeometry).
if makeAngleSkeletonPlots
    tic
    if ~exist('MANallDataFiles','var')
        error('Run the first section (data loading) first.');
    end

    angleSkeletonFolder = DYMO_figureFolder('TM_MAN','04_AngleVectorSkeletons');   % one subfolder per joint group

    dyadList = angleSkeletonDyads;
    if isempty(dyadList)
        dyadList = 1:size(MANallDataFiles,1);
    end

    for d = dyadList
        if all(cellfun(@isempty, MANallDataFiles(d,:)))
            continue;
        end
        plotSkeletonAngleVectors(MANallDataFiles(d,:), ...
            ['MAN Dyad ' num2str(d)], angleSkeletonFolder, ...
            ['MAN_Dyad_' num2str(d)], angleSkeletonFrame);
    end
    toc
    disp('All MAN angle-vector skeleton plots saved.');
end

%% ==================== CALCULATED ANGLES OVER TIME ====================
% For each dyad: one figure per angle (11) with both people, plus one
% overview figure with all 11 angles. Uses the angles computed above
% (MANallAngles), i.e. exactly the angles the velocities are made from.
if makeAngleTimePlots
    tic
    if ~exist('MANallAngles','var')
        if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
        load(F.MAN_Angles,'MANallAngles');
    end
    if ~exist('MANallDataFiles','var')
        error('Run the first section (data loading) first: the time column comes from it.');
    end

    angleTimeFolder = DYMO_figureFolder('TM_MAN','05_AngleTimeSeries');   % one subfolder per angle

    dyadList = angleTimeDyads;
    if isempty(dyadList)
        dyadList = 1:size(MANallAngles,1);
    end

    for d = dyadList
        if all(cellfun(@isempty, MANallAngles(d,:)))
            continue;
        end
        timeCells = cell(1, size(MANallDataFiles,2));
        for s = 1:numel(timeCells)
            if ~isempty(MANallDataFiles{d,s})
                timeCells{s} = MANallDataFiles{d,s}(:,1);   % time column (s)
            end
        end
        plotAngleTimeSeries(MANallAngles(d,:), timeCells, ...
            ['MAN Dyad ' num2str(d)], angleTimeFolder, ['MAN_Dyad_' num2str(d)], ...
            [], makeAngleOverview);
    end
    toc
    disp('All MAN angle time-series plots saved.');
end

%%% ==================== VELOCITY + Z-SCORE ====================
tic
if ~exist('MANallAngles','var')
    if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
    load(F.MAN_Angles,'MANallAngles','Fs');
end
[numManDyads, numSubjects] = size(MANallAngles);

MANallVelocity  = cell(numManDyads,1);
MANallZVelocity = cell(numManDyads,1);
MANallTime      = cell(numManDyads,1);

for d = 1:numManDyads

    if isempty(MANallAngles{d,1}) || isempty(MANallAngles{d,2})
        continue;
    end

    fields    = fieldnames(MANallAngles{d,1});
    numFields = numel(fields);

    % Columns = [Person1 angles | Person2 angles]
    A1 = cell2mat(cellfun(@(f) MANallAngles{d,1}.(f)(:), fields', 'UniformOutput', false));
    A2 = cell2mat(cellfun(@(f) MANallAngles{d,2}.(f)(:), fields', 'UniformOutput', false));

    if size(A1,1) ~= size(A2,1)
        warning('Dyad %d: Person 1 and Person 2 have different lengths (%d vs %d), skipping', ...
            d, size(A1,1), size(A2,1));
        continue;
    end
    combinedMatrix = [A1 A2];

    numRows = size(combinedMatrix,1);
    time    = (0:numRows-1)' / Fs;        % Fs = sampling rate measured from the files

    % Velocity (forward difference), time at midpoints
    velocity     = diff(combinedMatrix) * Fs;
    timeVelocity = time(1:end-1) + 1/(2*Fs);

    velocity1 = velocity(:,1:numFields);
    velocity2 = velocity(:,numFields+1:end);

    % The TM GRAPH input, normalised as graphNormalization says. With 'zscore'
    % this IS zscoreSafe(velocity). The variable keeps the name zVelocity because
    % the rest of the pipeline reads that field by name; the graphNormalization
    % field recorded below says what it actually holds, so a results folder is
    % never ambiguous about it.
    [zVelocity, nFixed, graphInfo] = graphInputVelocity(velocity, graphNormalization);
    zVelocity1 = zscoreSafe(velocity1);            % Person 1, kept for reference
    zVelocity2 = zscoreSafe(velocity2);            % Person 2, kept for reference

    % Inputs to the CATEGORY score, normalised as categoryNormalization says.
    % With 'zscore' these are the same as zVelocity1/zVelocity2 above.
    [catVelocity1, catInfo1] = normalizeVelocity(velocity1, categoryNormalization);
    [catVelocity2, catInfo2] = normalizeVelocity(velocity2, categoryNormalization);
    if catInfo1.nGuardedJoints > 0 || catInfo2.nGuardedJoints > 0
        warning(['Dyad %d: %d + %d joint(s) had no usable scale for the ' ...
                 '''%s'' normalisation and were set to 0 for this dyad.'], ...
                 d, catInfo1.nGuardedJoints, catInfo2.nGuardedJoints, ...
                 categoryNormalization);
    end

    % A dyad is NEVER dropped here (the >= 180 s dyads must all stay in).
    % A few NaN values are interpolated; an angle that is missing for the
    % whole window is set to 0 for that dyad. Reported so you can check.
    if nFixed > 0
        warning('Dyad %d: %d NaN/Inf velocity values were filled (kept in the analysis).', d, nFixed);
    end

    MANallVelocity{d}.velocity_all = velocity;
    MANallVelocity{d}.velocity1    = velocity1;
    MANallVelocity{d}.velocity2    = velocity2;
    MANallVelocity{d}.fields       = fields;

    MANallZVelocity{d}.zVelocity   = zVelocity;
    MANallZVelocity{d}.zVelocity1  = zVelocity1;
    MANallZVelocity{d}.zVelocity2  = zVelocity2;
    MANallZVelocity{d}.fields      = fields;

    % what the categories are actually computed from, and how it was scaled
    MANallZVelocity{d}.catVelocity1 = catVelocity1;
    MANallZVelocity{d}.catVelocity2 = catVelocity2;
    MANallZVelocity{d}.catNormalization = categoryNormalization;
    MANallZVelocity{d}.graphNormalization = graphNormalization;
    MANallZVelocity{d}.graphJointScale    = graphInfo.jointScale;
    MANallZVelocity{d}.catJointScale1   = catInfo1.jointScale;
    MANallZVelocity{d}.catJointScale2   = catInfo2.jointScale;

    MANallTime{d} = timeVelocity;
end

save(F.MAN_Velocity, 'MANallVelocity', 'MANallZVelocity', 'MANallTime', 'Fs', '-v7.3');
toc
disp('MAN Velocity and zVelocity computed and saved.');

%% ==================== DISTANCE MATRIX PLOTS (display only) ====================
% The TM graph does not need this matrix. The image is computed on at most
% maxPlotPoints evenly spaced samples (single precision) just for viewing.
if makeDistanceMatrixPlots
    tic;
    if ~exist('MANallZVelocity','var')
        if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
        load(F.MAN_Velocity,'MANallZVelocity','MANallTime');
    end

    recurrenceFolder = DYMO_figureFolder('TM_MAN','06_DistanceMatrices');
    if ~exist(recurrenceFolder, 'dir')
        mkdir(recurrenceFolder);
    end

    maxLimit = 50;    % uniform colour bar

    for d = 1:numel(MANallZVelocity)
        if isempty(MANallZVelocity{d})
            continue;
        end

        Z    = MANallZVelocity{d}.zVelocity;
        time = MANallTime{d};
        N    = min(size(Z,1), maxSamples);
        step = max(1, ceil(N / maxPlotPoints));
        idx  = 1:step:N;

        D = pdist2(single(Z(idx,:)), single(Z(idx,:)));   % Euclidean (L-2)

        fig = figure;
        imagesc(time(idx), time(idx), D);
        colormap hot;
        cb = colorbar;
        title(['MAN Dyad ' num2str(d) ' Distance Matrix ']);
        xlabel('time (s)');
        ylabel('time (s)');
        cb.Label.String = 'L-2 distance';
        clim([0 maxLimit]);
        axis square;

        AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_DistanceMatrix'], fig, recurrenceFolder);
        close(fig);
    end
    clear D Z
    toc;
    disp('All MAN distance matrix plots saved.');
end

%% ==================== VELOCITY CATEGORIES (SAVE FOR REUSE) ====================
% NEW METHOD: per-person frame-wise MEAN of the z-scored velocities,
% thresholded at that person's MEDIAN (no log, no absolute value).
if ~exist('MANallZVelocity','var')
    if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
    load(F.MAN_Velocity,'MANallZVelocity','MANallTime');
end
numManDyads = numel(MANallZVelocity);
MANVelocityCategoryAll = cell(numManDyads,1);

tic;
for d = 1:numManDyads

    if isempty(MANallZVelocity{d})
        continue
    end

    fprintf('[A] Processing dyad %d\n', d);

    % Categories are computed on exactly the samples used for the TM graph
    N = min(size(MANallZVelocity{d}.catVelocity1,1), maxSamples);

    C = categorizeVelocity(MANallZVelocity{d}.catVelocity1(1:N,:), ...
                           MANallZVelocity{d}.catVelocity2(1:N,:), ...
                           thresholdMethod);
    C.normalization = MANallZVelocity{d}.catNormalization;

    MANVelocityCategoryAll{d} = C;
end
toc;

save(F.MAN_Categories, 'MANVelocityCategoryAll', '-v7.3');
disp('All MAN dyads Velocity Categories saved in current folder.');

%% ======= FOUR COLOR CATEGORIES BAR PLOT (optional: makeCategoryBarPlots) =======
if makeCategoryBarPlots
    if ~exist('MANVelocityCategoryAll','var')
        if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
        load(F.MAN_Categories,'MANVelocityCategoryAll');
    end

    barplotFolder = DYMO_figureFolder('TM_MAN','07_TimePointCategoryBars');
    if ~exist(barplotFolder, 'dir')
        mkdir(barplotFolder);
    end
    disp(['MANTimePointCategoryBarPlots will be saved in: ', barplotFolder])

    tic;
    for d = 1:numel(MANVelocityCategoryAll)

        if isempty(MANVelocityCategoryAll{d})
            continue
        end

        C = MANVelocityCategoryAll{d};

        counts4_time  = histcounts(C.colorvar, 1:5);
        percent4_time = counts4_time / sum(counts4_time) * 100;

        fig = figure;
        b = bar(1:4, counts4_time, 'EdgeColor','k');
        xticks(1:4);
        xticklabels(C.BehaviouralCategory);
        xlabel('Behavioural Category');
        ylabel('Time points');
        title(['MAN Dyad ', num2str(d), ' Time Point Distribution']);
        grid on;

        b.FaceColor = 'flat';
        b.CData     = C.cmap;

        for i = 1:4
            text(i, counts4_time(i) + 0.5, sprintf('%.1f%%', percent4_time(i)), ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'FontWeight','bold');
        end

        AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_TimePointCategoryBars'], ...
            fig, barplotFolder);
        close(fig);   % close each figure: open figures slow the run down
    end
    toc;
    disp('All MAN dyads TimePoint Category BarPlots saved.');
end

%% ==================== ALL DYADS: FOUR-COLOR GRAPH PIPELINE ====================
% z-velocity goes straight into tknndigraph ('lowMemory',true): distances
% are computed block by block and the N-by-N matrix never exists. The
% graph is identical to the one built from pdist2(zVelocity,zVelocity).
if ~exist('MANallZVelocity','var')
    if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
    load(F.MAN_Velocity,'MANallZVelocity','MANallTime','Fs');
end
if ~exist('MANVelocityCategoryAll','var')
    if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
    load(F.MAN_Categories,'MANVelocityCategoryAll');
end

figureFolder = DYMO_figureFolder('TM_MAN','08_FourColorGraphs');
if ~exist(figureFolder,'dir'); mkdir(figureFolder); end

if ~exist('F','var'); F = DYMO_files(); end   % file names, in case this section is run on its own
dataFolder = F.MAN_PerDyadDir;   % per-dyad .mat data only (inside the Data folder)
if ~exist(dataFolder,'dir'); mkdir(dataFolder); end

MAN_AllDyads_GraphData = cell(numel(MANallZVelocity),1);

disp('Starting ALL dyads four-color graph pipeline...');
tTotal = tic;

for d = 1:numel(MANallZVelocity)

    if isempty(MANallZVelocity{d}) || isempty(MANVelocityCategoryAll{d})
        continue
    end

    tDyad = tic;
    C = MANVelocityCategoryAll{d};

    % ---- Dyad data (same samples as the categories) ----
    N    = numel(C.colorvar);
    X    = MANallZVelocity{d}.zVelocity(1:N,:);
    time = MANallTime{d}(1:N);

    % ==================== STEP 1: KNN GRAPH (from X directly) ====================
    tidx = (1:N)';
    g = tknndigraph(X, k, tidx, ...
        'reciprocal',       true, ...
        'timeExcludeSpace', true, ...
        'timeExcludeRange', texclude, ...
        'lowMemory',        true);

    % ==================== STEP 2: SIMPLIFIED GRAPH ====================
    % 3 outputs -> filtergraph uses its sparse reachability route (no N-by-N)
    [g_simp, members, nodesize] = filtergraph(g, dmap, 'reciprocal', true);

    % D_simp (used by the NodeDistance analyses), computed block-wise
    D_simp = computeDsimpLowMem(g, members);

    % ==================== STORE DATA (REUSABLE) ====================
    dyadData = struct();
    dyadData.g_simp              = g_simp;
    dyadData.D_simp              = D_simp;
    dyadData.members             = members;
    dyadData.nodesize            = nodesize;
    dyadData.time                = time;
    dyadData.colorvar            = C.colorvar;
    dyadData.colorvarname        = C.colorvarname;
    dyadData.threshold1          = C.threshold1;
    dyadData.threshold2          = C.threshold2;
    dyadData.thresholdMethod     = C.thresholdMethod;
    dyadData.categoryNormalization = categoryNormalization;
    dyadData.graphNormalization    = graphNormalization;
    dyadData.BehaviouralCategory = C.BehaviouralCategory;
    dyadData.cmap                = C.cmap;
    dyadData.k                   = k;
    dyadData.dmap                = dmap;
    dyadData.texclude            = texclude;
    dyadData.texcludeSec         = texclude / Fs;
    dyadData.Fs                  = Fs;
    dyadData.lowpassCutoffHz     = lowpassCutoffHz;
    dyadData.numSamples          = N;

    MAN_AllDyads_GraphData{d} = dyadData;

    save(fullfile(dataFolder, ['MAN_Dyad_', num2str(d), '_FourColorGraphData_' F.Tag '.mat']), ...
        '-struct','dyadData','-v7.3');

    % ==================== PLOTTING (optional, see makeFourColorGraphPlots) ====================
    if makeFourColorGraphPlots
        fig = plotTMGraphCategories(g_simp, C.colorvar, members, C.cmap, ...
            C.BehaviouralCategory, C.colorvarname, ...
            ["MAN Dyad " + d, "k=" + k + ", dmap=" + dmap, "texclude=" + texclude]);

        AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_FourColorGraph'], fig, figureFolder);
        close(fig);
    end

    fprintf('Dyad %d: N = %d samples -> %d nodes (%.1f s)\n', ...
        d, N, numnodes(g_simp), toc(tDyad));
    clear g X
end

fprintf('All MAN dyads completed in %.2f seconds\n', toc(tTotal));
nGraphs = nnz(~cellfun(@isempty, MAN_AllDyads_GraphData));
fprintf('MAN: TM graphs built for %d dyads.\n', nGraphs);
if ~isempty(expectedDyadCount) && nGraphs ~= expectedDyadCount
    warning('MAN: %d TM graphs but %d dyads expected. Check the MAN_DyadInclusionLog table and the warnings above.', ...
        nGraphs, expectedDyadCount);
end

%% ==================== SAVE MASTER DATA ====================
% This is the file every analysis script loads (name set in DYMO_files.m).
% It is saved HERE, straight after the graphs are built, and not at the end of
% the script: the sections below only make figures and summary tables, so an
% error in one of them cannot cost the master file.
if ~exist('F','var'); F = DYMO_files(); end
save(F.MAN_TM, 'MAN_AllDyads_GraphData', '-v7.3');
fprintf('MAN TM graphs stored in %s\n', F.MAN_TM);

%% ============ ANGULAR-VELOCITY SPECTRUM PER DYAD ============
% Where each dyad's angular-velocity power sits in frequency. Movement power
% falls steeply with frequency; marker jitter rises towards Nyquist after the
% derivative, so an upturn near Fs/2 is the jitter floor showing through.
% One figure per dyad, two panels (one per partner). See plotVelocitySpectrum.m.
if makeVelocitySpectrumPlots
    tic;
    if ~exist('F','var'); F = DYMO_files(); end
    if ~exist('MANallVelocity','var')
        load(F.MAN_Velocity, 'MANallVelocity', 'Fs');
    end

    spectrumFolder = DYMO_figureFolder('TM_MAN', '10_VelocitySpectrum');
    for d = 1:numel(MANallVelocity)
        if isempty(MANallVelocity{d}) || ~isfield(MANallVelocity{d}, 'velocity_all')
            continue
        end
        fig = plotVelocitySpectrum(MANallVelocity{d}.velocity_all, Fs, bandEdges, ...
            ['MAN Dyad ' num2str(d)]);
        AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_VelocitySpectrum'], fig, ...
            spectrumFolder);
        close(fig);
    end
    toc;
    disp('MAN per-dyad velocity spectra saved.');
end

%% ============ NODE FIGURES PER DYAD ============
% Static node figures for every dyad:
%   CategoryNodeFigures  one figure per behavioural category (node ringed in white)
%   CategoryNodePanels   all four categories in one figure
%   NodeGallery          grid of the largest nodes
% A node groups moments of similar angular VELOCITY, so these show the posture
% DURING a movement state, not "the posture of a node".
if makeNodeFigures
    tic;
    if ~exist('F','var'); F = DYMO_files(); end
    if ~exist('MAN_AllDyads_GraphData','var')
        load(F.MAN_TM, 'MAN_AllDyads_GraphData');
    end
    if ~exist('MANallSkeletonData','var')
        load(F.MAN_Skeleton, 'MANallSkeletonData');
    end
    if ~exist('MANallZVelocity','var')
        load(F.MAN_Velocity, 'MANallZVelocity', 'MANallTime');
    end
    if ~exist('MANVelocityCategoryAll','var')
        load(F.MAN_Categories, 'MANVelocityCategoryAll');
    end

    dyadList = nodeFigureDyads;
    if isempty(dyadList)
        dyadList = find(~cellfun(@isempty, MAN_AllDyads_GraphData))';
    end

    for d = dyadList
        D = MAN_AllDyads_GraphData{d};
        if isempty(D), continue; end
        label = ['MAN Dyad ' num2str(d)];
        skel  = MANallSkeletonData(d,:);
        tVel  = MANallTime{d};
        Cat   = MANVelocityCategoryAll{d};
        zVel  = MANallZVelocity{d}.zVelocity;

        % one figure per category
        [figs, ~] = plotTMCategoryNodeFigures(D.g_simp, D.members, skel, tVel, Cat, ...
            zVel, label, 5);
        catNames = Cat.BehaviouralCategory;
        for iCat = 1:numel(figs)
            if ~isgraphics(figs(iCat)); continue; end
            catTag = matlab.lang.makeValidName(catNames{iCat});
            AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_Cat' num2str(iCat) '_' catTag], ...
                figs(iCat), DYMO_figureFolder('TM_MAN', '11_NodeFigures', 'CategoryNodeFigures'));
            close(figs(iCat));
        end

        % all four categories in one figure
        fig = plotTMCategoryNodePanels(D.g_simp, D.members, skel, tVel, Cat, zVel, label, 5);
        AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_CategoryNodePanels'], fig, ...
            DYMO_figureFolder('TM_MAN', '11_NodeFigures', 'CategoryNodePanels'));
        close(fig);

        % grid of the largest nodes
        fig = plotTMNodeGallery(D.members, skel, tVel, Cat, zVel, galleryNumNodes, label);
        AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_NodeGallery'], fig, ...
            DYMO_figureFolder('TM_MAN', '11_NodeFigures', 'NodeGallery'));
        close(fig);
    end
    toc;
    disp('MAN per-dyad node figures saved.');
end

%% ============ FILTER SENSITIVITY ON THE FIRST FEW DYADS ============
% Repeats the pipeline with a 2 Hz low-pass on the coordinates and compares it
% with the unfiltered result: how many samples keep their category, Cohen's
% kappa, the correlation of the mean z-velocity, and the node counts. It needs
% the loaded recordings, so run the data-loading section first in this session.
% See tmFilterSensitivityOneDyad.m.
if ~isempty(sensitivityCutoffHz) && sensitivityNumDyads > 0
    tic;
    if ~exist('MANallDataFiles','var')
        error(['The filter sensitivity section needs the loaded recordings. ' ...
               'Run the data-loading section first (they are not saved to disk).']);
    end

    withGraph = find(~cellfun(@isempty, MAN_AllDyads_GraphData))';
    nUse      = min(sensitivityNumDyads, numel(withGraph));
    useDyads  = withGraph(1:nUse);

    P = struct('Fs', Fs, 'cutoffHz', sensitivityCutoffHz, ...
               'filterOrder', sensitivityFilterOrder, 'k', k, 'dmap', dmap, ...
               'texclude', texclude, 'thresholdMethod', thresholdMethod, ...
               'nodesUnfiltered', NaN);

    Sens = table();
    for d = useDyads
        P.nodesUnfiltered = numnodes(MAN_AllDyads_GraphData{d}.g_simp);
        [row, fig] = tmFilterSensitivityOneDyad(MANallDataFiles(d,:), ...
            ['MAN Dyad ' num2str(d)], MANVelocityCategoryAll{d}, P);
        if isempty(row), continue; end
        row = addvars(row, d, 'Before', 1, 'NewVariableNames', 'Dyad');
        Sens = [Sens; row]; %#ok<AGROW>
        if isgraphics(fig)
            AutoSavePublishableFigure(['MAN_Dyad_' num2str(d) '_FilterSensitivity'], fig, ...
                DYMO_figureFolder('TM_MAN', '12_FilterSensitivity'));
            close(fig);
        end
        fprintf('MAN dyad %d: %.1f %% of samples keep their category with a %g Hz filter\n', ...
            d, row.CategoryAgreement_pct, sensitivityCutoffHz);
    end

    if ~isempty(Sens)
        DYMO_writeTable(Sens, 'MAN_FilterSensitivity.csv');
        disp(Sens);
    end
    toc;
end

%% ============ GROUP-LEVEL SUMMARY (ALL INCLUDED DYADS) ============
% The sections above make one figure per dyad. This one adds the overall
% picture across all included dyads: time in each behavioural category, TM
% graph size, how much each joint angle varied, and where the angular-velocity
% power sits. Tables go to the Tables folder and figures to
% Figures/TM_MAN/09_GroupSummary, both inside TM_MAN_Results_mednorm_180s.
% See tmGroupSummary.m.
if makeGroupSummary
    tic;
    if ~exist('F','var'); F = DYMO_files(); end
    if ~exist('MANallAngles','var')
        load(F.MAN_Angles, 'MANallAngles');
    end
    if ~exist('MANallVelocity','var')
        load(F.MAN_Velocity, 'MANallVelocity');
    end

    GroupSummary = tmGroupSummary('MAN', MAN_AllDyads_GraphData, ...
        MANVelocityCategoryAll, MANallAngles, MANallVelocity, Fs, bandEdges);
    toc;
end

%% ==================== DONE ====================
% The master file was saved earlier (see "SAVE MASTER DATA" above), so nothing
% is written here. Everything from this script is now in
% TM_MAN_Results_mednorm_180s\ (ProcessedData, Tables, Figures) in the current folder.
fprintf('MAN finished: %d dyads, data in %s\n', nGraphs, F.MAN_TM);
