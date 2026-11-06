%% ====== NODE DISTANCE: ALL 8 PAIRS IN ONE FIGURE (purple) ======
% One figure, two rows of four panels.
%   top row    (within the same behavioural state):
%       Both Inactive -> Both Inactive | Both Active -> Both Active |
%       Person 1 Active -> Person 1 Active | Person 2 Active -> Person 2 Active
%   bottom row (between different states):
%       Both Inactive -> Both Active | Both Active -> Both Inactive |
%       Person 1 Active -> Person 2 Active | Person 2 Active -> Person 1 Active
% Symmetric pairs on the left, asymmetric on the right. Only the panels and
% their headings: no panel letters, no row titles. The Casual Chat /
% Conflict key is the separate ConditionLegend figure.
%
% Each panel is EXACTLY the panel of the purple paired t-test scripts
% (BothActive_Inactive_Purple_Icons_29Oct26, Person1_Person2_Active_Purple_Icons_29Oct26):
% the same distances (dyadCatDistance_weighted), the same paired t-test, the
% same plotPairedComparison, purple colours. Nothing is recomputed differently.
%
% Saved in
%   NodeDistance_Pairedttest_Results_<tag>\Figures\NodeDistance_PairedTtest\EightPanel_Purple
%     NodeDistance_8Panel_Purple        (.png/.pdf/.fig) - as above
%     NodeDistance_8Panel_Purple_Icons  (.png/.pdf/.fig) - with the state-pair
%                                                         icons over the headings
% No tables are written: the numbers are those of the two paired t-test
% scripts (BothActive_Inactive_09July26, Person1_Person2_Active_09July26).
%
% BEFORE RUNNING
%   clear all; close all; clc
%   DYMO_setup
%   cfg = DYMO_config(); cd(cfg.resultsDir)   % the results folder (DYMO_runAll does this itself)
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('dyadCatDistance_weighted','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('NodeDistance_Pairedttest');
distYLimits = [];          % [] = automatic, as in the purple scripts

load(F.GTK_TM, 'GTK_AllDyads_GraphData')
load(F.MAN_TM, 'MAN_AllDyads_GraphData')

BehaviouralCategory = GTK_AllDyads_GraphData{find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1)}.BehaviouralCategory;
stateIdx = @(name) find(strcmp(BehaviouralCategory, name));

% the 8 panels, top row then bottom row, left to right: {from, to}
panels = { ...
    'Both Inactive',   'Both Inactive';
    'Both Active',     'Both Active';
    'Person 1 Active', 'Person 1 Active';
    'Person 2 Active', 'Person 2 Active';
    'Both Inactive',   'Both Active';
    'Both Active',     'Both Inactive';
    'Person 1 Active', 'Person 2 Active';
    'Person 2 Active', 'Person 1 Active'};

% state numbers for the icons (1 BI black, 2 BA green, 3 P1 blue, 4 P2 red)
iconNum = containers.Map({'Both Inactive','Both Active','Person 1 Active','Person 2 Active'}, {1,2,3,4});

condColors = DYMO_conditionColorsPurple();
GTKColor = condColors(1,:);   % Casual Chat - solid purple
MANColor = condColors(2,:);   % Conflict    - light purple

numDyads = numel(GTK_AllDyads_GraphData);
fig = figure('Color','w');
iconPairs = zeros(size(panels,1), 2);

fprintf('\n===== NODE DISTANCE, 8 PANELS: paired t-tests (aggregate only) =====\n');
for k = 1:size(panels,1)
    from = stateIdx(panels{k,1});
    to   = stateIdx(panels{k,2});
    assert(~isempty(from) && ~isempty(to), 'State name not found: %s / %s', panels{k,1}, panels{k,2});

    % distances, exactly as in the purple scripts
    G = nan(numDyads,1);  M = nan(numDyads,1);
    for d = 1:numDyads
        G(d) = dyadCatDistance_weighted(GTK_AllDyads_GraphData{d}, from, to);
        M(d) = dyadCatDistance_weighted(MAN_AllDyads_GraphData{d}, from, to);
    end
    valid = isfinite(G) & isfinite(M);
    [~, p, ~, st] = ttest(G(valid), M(valid));
    fprintf('%-34s t(%d) = %.2f, p = %.3f, mean Casual Chat = %.3f, mean Conflict = %.3f\n', ...
        [panels{k,1} ' -> ' panels{k,2}], st.df, st.tstat, p, mean(G(valid)), mean(M(valid)));

    subplot(2, 4, k)
    plotPairedComparison(G, M, p, GTKColor, MANColor, ...
        {[panels{k,1} ' → ' panels{k,2}]}, {'Weighted mean distance'}, distYLimits, false);

    iconPairs(k,:) = [iconNum(panels{k,1}), iconNum(panels{k,2})];
end
clear GTK_AllDyads_GraphData MAN_AllDyads_GraphData

outFolder = DYMO_figureFolder('NodeDistance_PairedTtest', 'EightPanel_Purple');

% the key, as in the purple scripts
figLegend = plotLegendFigure({'Casual Chat','Conflict'}, condColors, 'Condition');
SavePublicationFigure('ConditionLegend', figLegend, outFolder, [7 5]);
close(figLegend);

% four panels across, two rows: wider and taller than a two-panel figure
SavePublicationFigure('NodeDistance_8Panel_Purple', fig, outFolder, [40 26]);
addStatePairIcons(fig, iconPairs, outFolder, 'NodeDistance_8Panel_Purple_Icons');
fprintf('Figures in %s\n', outFolder);
