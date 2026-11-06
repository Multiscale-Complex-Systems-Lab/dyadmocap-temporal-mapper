function [row, fig] = tmFilterSensitivityOneDyad(dyadData, dyadLabel, CatUnfiltered, P)
%TMFILTERSENSITIVITYONEDYAD  Does a low-pass filter change this dyad's result?
%
%   [row, fig] = tmFilterSensitivityOneDyad(dyadData, dyadLabel, CatUnfiltered, P)
%
% Repeats the pipeline for ONE dyad with a zero-phase Butterworth low-pass
% applied to the marker coordinates BEFORE the angles and the derivative, and
% compares it with the unfiltered result the script already computed.
%
% WHY THIS EXISTS
% A numerical derivative amplifies the high-frequency jitter a low-pass filter
% is meant to remove. The pipeline applies no filter. This measures what a
% filter would change, so the choice can be argued from numbers rather than
% assumed.
%
% INPUTS
%   dyadData      : 1-by-2 cell, the two partners' recordings for this dyad
%                   (as in <grp>allDataFiles(d,:)), unfiltered.
%   dyadLabel     : e.g. 'GTK Dyad 3', used in the figure title.
%   CatUnfiltered : the categorizeVelocity struct from the unfiltered run.
%   P             : struct of parameters, with fields
%                     Fs, cutoffHz, filterOrder, k, dmap, texclude,
%                     thresholdMethod, nodesUnfiltered
%                   nodesUnfiltered is the node count of the unfiltered graph
%                   for this dyad, so the row can report both side by side.
%
% OUTPUTS
%   row : one-row table with
%           CategoryAgreement_pct  % of samples given the same category
%           Kappa                  Cohen's kappa of that agreement (1 = identical)
%           rMeanZVel_P1/P2        correlation of the frame-wise mean z-velocity
%           TMNodes_Unfiltered / TMNodes_Filtered
%           and the four category percentages of the FILTERED run
%   fig : figure comparing the two mean z-velocity traces (first 20 s), one
%         panel per person. Empty if the dyad could not be processed.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

row = table();
fig = gobjects(0);
if any(cellfun(@isempty, dyadData)) || isempty(CatUnfiltered)
    return
end

personColors = DYMO_personColors();

% ---- filter the coordinates, then redo angles and velocity ----
[bLP, aLP] = butter(P.filterOrder, P.cutoffHz / (P.Fs/2));
A = cell(1,2);
for s = 1:2
    X      = dyadData{s};
    Xf     = [X(:,1:2) filtfilt(bLP, aLP, X(:,3:end))];   % keep time and frame columns
    A{s}   = computeJointAngles(Xf);
end

fields = fieldnames(A{1});
nF     = numel(fields);
A1 = cell2mat(cellfun(@(f) A{1}.(f)(:), fields', 'UniformOutput', false));
A2 = cell2mat(cellfun(@(f) A{2}.(f)(:), fields', 'UniformOutput', false));
n  = min(size(A1,1), size(A2,1));

velocityF = diff([A1(1:n,:) A2(1:n,:)]) * P.Fs;
zVF  = zscoreSafe(velocityF);
zVF1 = zscoreSafe(velocityF(:,1:nF));
zVF2 = zscoreSafe(velocityF(:,nF+1:end));

% ---- same samples as the unfiltered run ----
N = numel(CatUnfiltered.colorvar);
if size(zVF1,1) < N
    N = size(zVF1,1);                 % filtered run is shorter: compare what exists
end
Cf = categorizeVelocity(zVF1(1:N,:), zVF2(1:N,:), P.thresholdMethod);

% ---- the filtered graph, for the node count ----
gF      = tknndigraph(zVF(1:N,:), P.k, (1:N)', 'reciprocal', true, ...
                      'timeExcludeSpace', true, 'timeExcludeRange', P.texclude, ...
                      'lowMemory', true);
gF_simp = filtergraph(gF, P.dmap, 'reciprocal', true);

% ---- agreement between the two runs ----
nCat  = numel(CatUnfiltered.BehaviouralCategory);
cu    = CatUnfiltered.colorvar(1:N);
cf    = Cf.colorvar(1:N);
agree = mean(cu(:) == cf(:));
pu    = histcounts(cu, 0.5:1:nCat+0.5) / N;
pf    = histcounts(cf, 0.5:1:nCat+0.5) / N;
pe    = sum(pu .* pf);                                   % agreement expected by chance
kappa = (agree - pe) / (1 - pe);
r1    = corr(CatUnfiltered.meanVelocity1(1:N), Cf.meanVelocity1(1:N));
r2    = corr(CatUnfiltered.meanVelocity2(1:N), Cf.meanVelocity2(1:N));

row = table(P.cutoffHz, N, 100*agree, kappa, r1, r2, ...
    P.nodesUnfiltered, numnodes(gF_simp), ...
    100*pf(1), 100*pf(2), 100*pf(3), 100*pf(4), ...
    'VariableNames', {'CutoffHz','Samples','CategoryAgreement_pct','Kappa', ...
                      'rMeanZVel_P1','rMeanZVel_P2','TMNodes_Unfiltered', ...
                      'TMNodes_Filtered','BothInactive_pct','BothActive_pct', ...
                      'P1Active_pct','P2Active_pct'});

% ---- figure: the first 20 s of mean z-velocity, filtered and not ----
tt  = (0:N-1)' / P.Fs;
win = tt <= min(20, tt(end));
fig = figure('Color', 'w', 'Position', [100 100 1400 800]);
tl  = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
mu  = {CatUnfiltered.meanVelocity1, CatUnfiltered.meanVelocity2};
mf  = {Cf.meanVelocity1, Cf.meanVelocity2};
rr  = [r1 r2];
for p = 1:2
    ax      = nexttile(tl);
    hUnfilt = plot(ax, tt(win), mu{p}(win), 'Color', personColors(p,:), 'LineWidth', 1);
    hold(ax, 'on');
    hFilt   = plot(ax, tt(win), mf{p}(win), 'Color', [0 0 0], 'LineStyle', '--', ...
                   'LineWidth', 1);
    hold(ax, 'off');
    ylabel(ax, 'Mean z-velocity');
    title(ax, sprintf('Person %d  (r = %.2f over the whole recording)', p, rr(p)));
    grid(ax, 'on');
    legend(ax, [hUnfilt hFilt], {'No filter (original)', ...
        sprintf('%g Hz low-pass', P.cutoffHz)}, 'Location', 'northeast', ...
        'AutoUpdate', 'off');
end
xlabel(tl, 'Time (s)');
title(tl, sprintf(['%s: frame-wise mean z-velocity with and without a %g Hz ' ...
    'low-pass (first 20 s shown)'], dyadLabel, P.cutoffHz), 'Interpreter', 'none');
end
