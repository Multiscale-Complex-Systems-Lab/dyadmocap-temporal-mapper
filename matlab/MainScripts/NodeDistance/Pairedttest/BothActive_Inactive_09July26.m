%% *Paired ttest Across dyads in Conflict vs Non Conflict*
% Figures are saved in Figures/NodeDistance_PairedTtest/BothActive_BothInactive/<figure name>/.
% Loads the TM data files named in DYMO_files.m (run DYMO_setup first).
% distYLimits = [] picks the axis limits from the data.
% In this file, we analyzes the data for the Get to Know Task   (non-Conflict 
% Condition).
%% 
% * Load the Temporal Mapper Graph Data (for GTK and MAN )
% * Calls the function for the velocity/behavioural categories
% * Calculates the paird ttest and creates bar plots for the results

% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

%%
%%
%load GTK and MAN Temporal Mapper Graph Data
%load GTK and MAN Temporal Mapper Graph Data
%GTK
if ~exist('dyadCatDistance_weighted','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('NodeDistance_Pairedttest');

% The final figure set replaces this script's
% figures with the purple node-distance figures with state-pair icons (*_Purple_Icons_29Oct26, NodeDistance_8Panel_Purple_30Oct26).
% This script is kept for its TABLES; its figures are made only if
% makeFigures = true.
makeFigures = false;

distYLimits = [];          % [] = automatic; e.g. [0 40] for the old fixed axis
load(F.GTK_TM, 'GTK_AllDyads_GraphData')

%MAN
load(F.MAN_TM, 'MAN_AllDyads_GraphData')
%%
%%
% We pick Category indices for both GTK and MAN
% Please note that both GTK and MAN use the same category Mapping

catName1 = 'Both Active'; %green
catName2 = 'Both Inactive'; %black

BehaviouralCategory = GTK_AllDyads_GraphData{find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1)}.BehaviouralCategory;  % first non-empty dyad

catIdx1 = find(strcmp(BehaviouralCategory, catName1));
catIdx2 = find(strcmp(BehaviouralCategory, catName2));

assert(~isempty(catIdx1) && ~isempty(catIdx2), ...
    'Category names not found in BehaviouralCategory');
%%
%%
numDyads = numel(GTK_AllDyads_GraphData);

GTK_12 = nan(numDyads,1);   %Both fast → Both slow
GTK_21 = nan(numDyads,1);   %Both slow → Both fast

MAN_12 = nan(numDyads,1);
MAN_21 = nan(numDyads,1);

GTK_11 = nan(numDyads,1);  %Both fast → Both fast
GTK_22 = nan(numDyads,1);  %Both slow → Both slow

MAN_11 = nan(numDyads,1);
MAN_22 = nan(numDyads,1);

for d = 1:numDyads
    GTK_12(d)  = dyadCatDistance_weighted(GTK_AllDyads_GraphData{d},  catIdx1, catIdx2);
    GTK_21(d)  = dyadCatDistance_weighted(GTK_AllDyads_GraphData{d},  catIdx2, catIdx1);

    MAN_12(d) = dyadCatDistance_weighted(MAN_AllDyads_GraphData{d}, catIdx1, catIdx2);
    MAN_21(d) = dyadCatDistance_weighted(MAN_AllDyads_GraphData{d}, catIdx2, catIdx1);

    GTK_11(d)  = dyadCatDistance_weighted(GTK_AllDyads_GraphData{d},  catIdx1, catIdx1);
    GTK_22(d)  = dyadCatDistance_weighted(GTK_AllDyads_GraphData{d},  catIdx2, catIdx2);

    MAN_11(d) = dyadCatDistance_weighted(MAN_AllDyads_GraphData{d}, catIdx1, catIdx1);
    MAN_22(d) = dyadCatDistance_weighted(MAN_AllDyads_GraphData{d}, catIdx2, catIdx2);
end
%%
%%
% Identify valid dyads (non-NaN in both sessions)
valid12 = isfinite(GTK_12) & isfinite(MAN_12);   % Both fast → Both slow 
valid21 = isfinite(GTK_21) & isfinite(MAN_21);   % Both slow → Both fast

valid11 = isfinite(GTK_11) & isfinite(MAN_11);   % Both fast → Both fast 
valid22 = isfinite(GTK_22) & isfinite(MAN_22);   % Both slow → Both slow 

% --- Paired t-test Both fast → Both slow ---
[h12, p12, ci12, stats12] = ttest(GTK_12(valid12), MAN_12(valid12));

% --- Paired t-test Both slow → Both fast --- 
[h21, p21, ci21, stats21] = ttest(GTK_21(valid21), MAN_21(valid21));

% --- Paired t-test Both fast → Both fast ---
[h11, p11, ci11, stats11] = ttest(GTK_11(valid11), MAN_11(valid11));

% --- Paired t-test Both slow → Both slow ---
[h22, p22, ci22, stats22] = ttest(GTK_22(valid22), MAN_22(valid22));

% Optional: Display results
fprintf('Both Active → Both Inactive : t(%d)=%.2f, p=%.3f, mean GTK12=%.3f, mean MAN12=%.3f\n', ...
    stats12.df, stats12.tstat, p12, mean(GTK_12(valid12)), mean(MAN_12(valid12)));

fprintf('Both Inactive → Both Active: t(%d)=%.2f, p=%.3f, mean GTK21=%.3f, mean MAN21=%.3f\n', ...
    stats21.df, stats21.tstat, p21, mean(GTK_21(valid21)), mean(MAN_21(valid21)));

fprintf('Both Active → Both Active: t(%d)=%.2f, p=%.3f, mean GTK11=%.3f, mean MAN11=%.3f\n', ...
    stats11.df, stats11.tstat, p11, mean(GTK_11(valid11)), mean(MAN_11(valid11)));

fprintf('Both Inactive → Both Inactive: t(%d)=%.2f, p=%.3f, mean GTK22=%.3f, mean MAN22=%.3f\n', ...
    stats22.df, stats22.tstat, p22, mean(GTK_22(valid22)), mean(MAN_22(valid22)));
%%
% % %% ---------- Bar colours ----------
% cmap = GTK_AllDyads_GraphData{1}.cmap;
% % 
% % GTKColor      = cmap(catIdx1,:);
% % GTKLightColor = min(GTKColor + 0.7,1);
% % 
% % MANColor      = cmap(catIdx2,:);
% % MANLightColor = min(MANColor + 0.7,1);
% 
% % Grouping the colors
% colors.GTK       = cmap(catIdx1,:);
% colors.GTKLight  = min(colors.GTK + 0.7,1);
% 
% colors.MAN      = cmap(catIdx2,:);
% colors.MANLight = min(colors.MAN + 0.7,1);
condColors = DYMO_conditionColors();   % one place for the two condition colours
GTKColor = condColors(1,:); % colorChilled
MANColor = condColors(2,:); % colorNormal
% ---- the key to the two conditions, as its own figure ----
% The result figures carry no legend; the key is saved
% once here instead. The colours come from DYMO_conditionColors, the same
% function the bars use, so the two cannot drift apart.
if makeFigures   % see the note at the top
figLegend = plotLegendFigure({'Casual Chat','Conflict'}, DYMO_conditionColors(), 'Condition');
SavePublicationFigure('ConditionLegend', figLegend, DYMO_figureFolder('NodeDistance_PairedTtest', 'BothActive_BothInactive'), [13 10]);
close(figLegend);
end   % if makeFigures

%%
%% ============================================================
% Figure 1: Inter-category node distances
% ============================================================

if makeFigures   % see the note at the top
figure
%% Both Inactive → Both Active

subplot(1,2,1)
plotPairedComparison( ...
    GTK_21,...
    MAN_21,...
    p21,...
    GTKColor,...
    MANColor,....
    {'Both Inactive → Both Active'},...
    {'Weighted mean distance'},...
    distYLimits,...
    true);



%% Both Active → Both Inactive
subplot(1,2,2)
plotPairedComparison( ...
    GTK_12,...
    MAN_12,...
    p12,...
    GTKColor,...
    MANColor,...
    {'Both Active → Both Inactive'},...
    {'Weighted mean distance'},...
    distYLimits,...
    false);


SavePublicationFigure('VPSubplot_P12_Paired_Dyad_Comparison', gcf, ...
    DYMO_figureFolder('NodeDistance_PairedTtest', 'BothActive_BothInactive'));
end   % if makeFigures
%%
% %% ============================================================
% % Figure 1: Inter-category node distances
% % ============================================================
% 
% figure
% %% Both Inactive → Both Active
% % 
% % subplot(1,2,1)
% plotPairedComparison( ...
%     GTK_21,...
%     MAN_21,...
%     p21,...
%     GTKColor,...
%     MANColor,....
%     {'Both Inactive → Both Active'},...
%     {'Weighted mean distance'},...
%     distYLimits,...
%     false);
% 
% SavePublicationFigure( ...
%     'BothInactiveActive')
% 
% 
% 
% %% Both Active → Both Inactive
% % subplot(1,2,2)
% plotPairedComparison( ...
%     GTK_12,...
%     MAN_12,...
%     p12,...
%     GTKColor,...
%     MANColor,...
%     {'Both Active → Both Inactive'},...
%     {'Weighted mean distance'},...
%     distYLimits,...
%     false);
% SavePublicationFigure( ...
%     'BothActiveInactive')
% 
% 
% % SavePublicationFigure( ...
% %     'VPSubplot_P12_Paired_Dyad_Comparison')
%%
%% ============================================================
% Figure 2: Within-category node distances
% ============================================================

if makeFigures   % see the note at the top
figure

%% Both Inactive → Both Inactive

subplot(1,2,1)

plotPairedComparison( ...
    GTK_22,...
    MAN_22,...
    p22,...
    GTKColor,...
    MANColor,...
    {'Both Inactive → Both Inactive'},...
    {'Weighted mean distance'},...
    distYLimits,...
    true);

%% Both Active → Both Active
subplot(1,2,2)

plotPairedComparison( ...
    GTK_11,...
    MAN_11,...
    p11,...
    GTKColor,...
    MANColor,...
    {'Both Active →  Both Active'},...
    {'Weighted mean distance',},...
    distYLimits,...
    false);


% SavePublicationFigure( ...
%     'VPSubplot_P22_Paired_Dyad_Comparison');

SavePublicationFigure('VPSubplot_SameCategory_Paired_Dyad_Comparison', gcf, ...
    DYMO_figureFolder('NodeDistance_PairedTtest', 'BothActive_BothInactive'));
end   % if makeFigures
%%
% Averaged Different Directions
validBoth = isfinite(GTK_12) & isfinite(MAN_12) & ...
            isfinite(GTK_21) & isfinite(MAN_21);

GTK_avg  = mean([GTK_12(validBoth), GTK_21(validBoth)],2);
MAN_avg = mean([MAN_12(validBoth), MAN_21(validBoth)],2);

[h_avg, p_avg, ci_avg, stats_avg] = ttest(GTK_avg, MAN_avg);
%%
%% Averaged Similar Directions
validBoth_similar = isfinite(GTK_11) & isfinite(GTK_22) & ...
                    isfinite(MAN_11) & isfinite(MAN_22);

GTK_avg_sim  = mean([GTK_11(validBoth_similar), ...
                       GTK_22(validBoth_similar)],2);

MAN_avg_sim = mean([MAN_11(validBoth_similar), ...
                       MAN_22(validBoth_similar)],2);

[h_avg_sim, p_avg_sim, ci_avg_sim, stats_avg_sim] = ...
    ttest(GTK_avg_sim, MAN_avg_sim);
%%
% %% ============================================================
% % Figure 3: Averaged inter-category and intra-category distances
% % ============================================================
% 
% figure
% 
% 
% %% ------------------------------------------------------------
% % Averaged inter-category distance
% % ------------------------------------------------------------
% 
% subplot(1,2,1)
% 
% plotPairedComparison( ...
%     GTK_avg,...
%     MAN_avg,...
%     p_avg,...
%     GTKColor,...
%     MANColor,...
%     {'Paired dyad comparison of Average',...
%      'inter-category node distance'},...
%     {'Averaged inter-category Weighted',...
%      'mean distance'},...
%     distYLimits,...
%     false);
% 
% 
% 
% %% ------------------------------------------------------------
% % Averaged intra-category distance
% % ------------------------------------------------------------
% 
% subplot(1,2,2)
% 
% plotPairedComparison( ...
%     GTK_avg_sim,...
%     MAN_avg_sim,...
%     p_avg_sim,...
%     GTKColor,...
%     MANColor,...
%     {'Paired dyad comparison of Averaged',...
%      'intra-category node distance'},...
%     {'Averaged within inter-category',...
%      'Weighted mean distance'},...
%     distYLimits,...
%     false);
% 
% 
% SavePublicationFigure( ...
%     'VPPaired_same_Dyad_Comparison');

%% ==================== RESULTS TABLE ====================
% One row per comparison, written to the Tables folder so the numbers live on
% disk and not only in the Command Window. No figure is added by this block.
%
% The labels are built from catName1 and catName2 rather than typed out, so a
% row always names the direction that was actually tested: "_12" is
% catName1 -> catName2, the order passed to
% dyadCatDistance_weighted(data, catIdx1, catIdx2).
comparisons = { ...
    [catName1 ' -> ' catName2], GTK_12(valid12), MAN_12(valid12), p12, stats12, ci12; ...
    [catName2 ' -> ' catName1], GTK_21(valid21), MAN_21(valid21), p21, stats21, ci21; ...
    [catName1 ' -> ' catName1], GTK_11(valid11), MAN_11(valid11), p11, stats11, ci11; ...
    [catName2 ' -> ' catName2], GTK_22(valid22), MAN_22(valid22), p22, stats22, ci22; ...
    'Mean of the two between-category directions', GTK_avg,     MAN_avg,     p_avg,     stats_avg,     ci_avg; ...
    'Mean of the two within-category directions',  GTK_avg_sim, MAN_avg_sim, p_avg_sim, stats_avg_sim, ci_avg_sim};

nRows    = size(comparisons,1);
Name     = strings(nRows,1);
N_dyads  = nan(nRows,1);   MeanGTK  = nan(nRows,1);   MeanMAN = nan(nRows,1);
MeanDiff = nan(nRows,1);   tStat    = nan(nRows,1);   dfOut   = nan(nRows,1);
pValue   = nan(nRows,1);   CIlow    = nan(nRows,1);   CIhigh  = nan(nRows,1);

for r = 1:nRows
    a  = comparisons{r,2};   b  = comparisons{r,3};
    st = comparisons{r,5};   ci = comparisons{r,6};

    Name(r)     = string(comparisons{r,1});
    N_dyads(r)  = numel(a);              % dyads with a finite value in both conditions
    MeanGTK(r)  = mean(a);
    MeanMAN(r)  = mean(b);
    MeanDiff(r) = mean(a - b);           % positive = larger distances in GTK
    tStat(r)    = st.tstat;
    dfOut(r)    = st.df;
    pValue(r)   = comparisons{r,4};
    CIlow(r)    = ci(1);                 % 95 % CI of the mean difference
    CIhigh(r)   = ci(2);
end

NodeDistanceStats = table(Name, N_dyads, MeanGTK, MeanMAN, MeanDiff, ...
    tStat, dfOut, pValue, CIlow, CIhigh, ...
    'VariableNames', {'Comparison','N_dyads','MeanGTK','MeanMAN', ...
                      'MeanDiff_GTKminusMAN','t','df','p','CI95_low','CI95_high'});
disp(NodeDistanceStats);
NodeDistanceStats = DYMO_roundTable(NodeDistanceStats);   % 3 significant figures, p to 3 dp (APA)
DYMO_writeTable(NodeDistanceStats, 'NodeDist_BothActiveInactive_Pairedttest.csv');
