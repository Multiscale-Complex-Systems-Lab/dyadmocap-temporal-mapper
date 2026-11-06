%% ===== WITH STATE-PAIR ICONS =====
% Each figure of one state pair is saved in a folder ending in _WithIcons,
% without and with the state-pair icons (two coloured nodes and a grey arrow)
% above the panel headings (<name>_Icons, drawn by addStatePairIcons).
% No tables are written: the numbers are those of BothActiveBothInactive_14July26.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
% ========================================================

%% *Paired ttest Across dyads in Conflict vs Non Conflict*
% Figures are saved in Figures/NodeDistance_Correlation/BothActive_BothInactive_WithIcons/<figure name>/.
% Loads the TM data files named in DYMO_files.m (run DYMO_setup first).
% Hand-set axis limits are OFF by default (useFixedAxisLimits), since they
% can cut off points.

%%%==================== Both Active and Both Inactive ====== %%%%%%%%%%%%%%%%%

% In this file, we analyzes the data for the Get to Know Task   (non-Conflict 
% Condition).
%% 
% * Load the Temporal Mapper Graph Data (for GTK and MAN )
% * Calls the function for the velocity/behavioural categories
% * Calculates the paird ttest and creates bar plots for the results


%%
%%
%load GTK and MAN Temporal Mapper Graph Data
%load GTK and MAN Temporal Mapper Graph Data
%GTK
if ~exist('dyadCatDistance_weighted','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('NodeDistance_Correlation');
useFixedAxisLimits = false;   % true = use the hand-set xlim/ylim below
load(F.GTK_TM, 'GTK_AllDyads_GraphData')

%MAN
load(F.MAN_TM, 'MAN_AllDyads_GraphData')
%%
% We pick Category indices for both GTK and MAN
% Please note that both GTK and MAN use the same category Mapping

catName1 = 'Both Inactive'; %Black
catName2 = 'Both Active'; %Green

BehaviouralCategory = GTK_AllDyads_GraphData{find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1)}.BehaviouralCategory;  % first non-empty dyad

catIdx1 = find(strcmp(BehaviouralCategory, catName1));
catIdx2 = find(strcmp(BehaviouralCategory, catName2));

assert(~isempty(catIdx1) && ~isempty(catIdx2), ...
    'Category names not found in BehaviouralCategory');
%%
numDyads = numel(GTK_AllDyads_GraphData);

GTK_12 = nan(numDyads,1);   % Both Inactive → Both Active'
GTK_21 = nan(numDyads,1);   % Both Active' → Both Inactive

MAN_12 = nan(numDyads,1);
MAN_21 = nan(numDyads,1);

GTK_11 = nan(numDyads,1);  % Both Inactive → Both Inactive
GTK_22 = nan(numDyads,1);  % Both Active → Both Inactive

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

    % GTK_11(d)  = dyadCatDistance_within(GTK_AllDyads_GraphData{d},  catIdx1);
    % GTK_22(d)  = dyadCatDistance_within(GTK_AllDyads_GraphData{d},  catIdx2);
    % 
    % MAN_11(d) = dyadCatDistance_within(MAN_AllDyads_GraphData{d}, catIdx1);
    % MAN_22(d) = dyadCatDistance_within(MAN_AllDyads_GraphData{d}, catIdx2);
end
%%
% % Identify valid dyads (non-NaN in both sessions)
% valid12 = isfinite(GTK_12) & isfinite(MAN_12);   % P1 fast → P2 fast 
% valid21 = isfinite(GTK_21) & isfinite(MAN_21);   % P2 fast → P1 fast
% 
% valid11 = isfinite(GTK_11) & isfinite(MAN_11);   % P1 fast → P1 fast 
% valid22 = isfinite(GTK_22) & isfinite(MAN_22);   % P2 fast → P2 fast 
%%

% Identify valid dyads (non-NaN in both sessions)
valid12 = isfinite(GTK_12) & isfinite(MAN_12);   % Both fast → Both slow
valid21 = isfinite(GTK_21) & isfinite(MAN_21);   % Both slow → Both fast

valid11 = isfinite(GTK_11) & isfinite(MAN_11);   % Both fast → Both fast
valid22 = isfinite(GTK_22) & isfinite(MAN_22);   % Both slow → Both slow 


%%%%%%%%%===Peasrson Correlation Coefficient==============%%%%%%%%%%%%

% % --- Pearson Correlation between Both fast → Both slow  ---
% %[h12, p12, ci12, stats12] = ttest(GTK_12(valid12), MAN_12(valid12));
% [R12, P12] = corrcoef(GTK_12(valid12), MAN_12(valid12));
% %Extract the correlation coefficient and p-value
% r12 = R12(1,2)
% p12 = P12(1,2)

% %% This is simialr to the above because a correlation matrix is symmetric
% % r12 = R12(2,1);
% % p12 = P12(2,1);

 %% -----------------Spearmans correlation----------------
 [rho12, p12, CI12] = spearmanWithCI(GTK_12(valid12), MAN_12(valid12));


% % --- Pearson Correlation between % Both slow → Both fast --- 
% %[h21, p21, ci21, stats21] = ttest(GTK_21(valid21), MAN_21(valid21));
% [R21, P21] = corrcoef(GTK_21(valid21), MAN_21(valid21));
% %Extract the correlation coefficient and p-value
% r21 = R21(1,2)
% p21 = P21(1,2)

 %% -----------------Spearmans correlation----------------
 [rho21, p21, CI21] = spearmanWithCI(GTK_21(valid21), MAN_21(valid21));

% --- Pearson Correlation between % Both fast → Both fast  ---
% % [h11, p11, ci11, stats11] = ttest(GTK_11(valid11), MAN_11(valid11));
% [R11, P11] = corrcoef(GTK_11(valid11), MAN_11(valid11));
% %Extract the correlation coefficient and p-value
% r11 = R11(1,2)
% p11 = P11(1,2)

 %% -----------------Spearmans correlation----------------
 [rho11, p11, CI11] = spearmanWithCI(GTK_11(valid11), MAN_11(valid11));

% % --- Pearson Correlation between % Both slow → Both slow  ---
% % [h22, p22, ci22, stats22] = ttest(GTK_22(valid22), MAN_22(valid22));
% [R22, P22] = corrcoef(GTK_22(valid22), MAN_22(valid22));
% %Extract the correlation coefficient and p-value
% r22 = R22(1,2)
% p22 = P22(1,2)

 %% -----------------Spearmans correlation----------------
 [rho22, p22, CI22] = spearmanWithCI(GTK_22(valid22), MAN_22(valid22));

% Optional: Display results
fprintf('Both Inactive → Both Active:   rho=%.4f, p=%.4f\n', rho12, p12);

fprintf('Both Active → Both Inactive:  rho=%.4f, p=%.4f\n', rho21, p21);

fprintf('Both Inactive → Both Inactive: rho=%.4f, p=%.4f\n', rho11, p11);

fprintf('Both Active → Both Active: rho=%.4f, p=%.4f\n', rho22, p22);
%%
%  %% ---------- Bar colours ----------
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
%%
%% ===============================
% Figure 1: Between  Spearman
%% ===============================

figure;
%% ---- Both Inactive → Both Active ----

subplot(1,2,1)

plotSpearmanComparison(...
    GTK_12,...
    MAN_12,...
    rho12,...
    p12,...
    'Both Inactive → Both Active',...
    'Casual Chat',...
    'Conflict',...
    true);
if useFixedAxisLimits, xlim([0 40]); end
if useFixedAxisLimits, ylim([0 40]); end
%% ----Both Active → Both Inactive ----
subplot(1,2,2)

plotSpearmanComparison(...
    GTK_21,...
    MAN_21,...
    rho21,...
    p21,...
    'Both Active → Both Inactive',...
    'Casual Chat',...
    'Conflict',...
    false);
if useFixedAxisLimits, xlim([0 40]); end
if useFixedAxisLimits, ylim([0 40]); end
% ---- the key to the scatter, as its own figure ----
% The panels carry no legend.
% plotCorrLegendFigure draws the panel's own marks - a translucent filled
% circle, the 30 % grey CI band and the 2 pt fitted line - instead of the three
% bar swatches plotLegendFigure gave. It adds the CI and fit
% rows itself, so only the point series is passed in.
figLegend = plotCorrLegendFigure({'Dyads'}, [0 0.4470 0.7410]);
SavePublicationFigure('SeriesLegend', figLegend, ...
    DYMO_figureFolder('NodeDistance_Correlation', 'BothActive_BothInactive_WithIcons'), [13 10]);
close(figLegend);

SavePublicationFigure('VPSubplot_P12_Paired_Dyad_Comparison', gcf, ...
    DYMO_figureFolder('NodeDistance_Correlation', 'BothActive_BothInactive_WithIcons'));
addStatePairIcons(gcf, [1 2; 2 1], ...
    DYMO_figureFolder('NodeDistance_Correlation', 'BothActive_BothInactive_WithIcons'), 'VPSubplot_P12_Paired_Dyad_Comparison_Icons');
%%
%% ===============================
% Figure 2: Within-Person  Spearman
%% ===============================

figure;
%% ---- Both Inactive → Both Inactive ----

subplot(1,2,1)

plotSpearmanComparison(...
    GTK_11,...
    MAN_11,...
    rho11,...
    p11,...
    'Both Inactive → Both Inactive',...
    'Casual Chat',...
    'Conflict',...
    true);
if useFixedAxisLimits, xlim([0 40]); end
if useFixedAxisLimits, ylim([0 40]); end
%% ---- Both Active → Both Active ----
subplot(1,2,2)

plotSpearmanComparison(...
    GTK_22,...
    MAN_22,...
    rho22,...
    p22,...
    'Both Active → Both Active',...
    'Casual Chat',...
    'Conflict',...
    false);
if useFixedAxisLimits, xlim([0 40]); end
if useFixedAxisLimits, ylim([0 40]); end
SavePublicationFigure('VPSubplot_P22_Paired_Dyad_Comparison', gcf, ...
    DYMO_figureFolder('NodeDistance_Correlation', 'BothActive_BothInactive_WithIcons'));
addStatePairIcons(gcf, [1 1; 2 2], ...
    DYMO_figureFolder('NodeDistance_Correlation', 'BothActive_BothInactive_WithIcons'), 'VPSubplot_P22_Paired_Dyad_Comparison_Icons');
%%
% %% ===============================
% % Figure 3: Averaged directions
% %% ===============================
% 
% figure;
% 
% 
% %% ---- Averaged inter-category ----
% 
% validAvg = isfinite(GTK_avg) & isfinite(MAN_avg);
% 
% [rho_avg,p_avg] = corr(...
%     GTK_avg(validAvg),...
%     MAN_avg(validAvg),...
%     'Type','Spearman');
% 
% 
% subplot(1,2,1)
% 
% plotSpearmanComparison(...
%     GTK_avg,...
%     MAN_avg,...
%     rho_avg,...
%     p_avg,...
%     'Average inter-category distance',...
%     'Casual Chat',...
%     'Conflict',...
%     false);
% 
% 
% 
% %% ---- Averaged intra-category ----
% 
% validAvgSim = isfinite(GTK_avg_sim) & isfinite(MAN_avg_sim);
% 
% [rho_avg_sim,p_avg_sim] = corr(...
%     GTK_avg_sim(validAvgSim),...
%     MAN_avg_sim(validAvgSim),...
%     'Type','Spearman');
% 
% 
% subplot(1,2,2)
% 
% plotSpearmanComparison(...
%     GTK_avg_sim,...
%     MAN_avg_sim,...
%     rho_avg_sim,...
%     p_avg_sim,...
%     'Average intra-category distance',...
%     'Casual Chat',...
%     'Conflict',...
%     false);

%% ==================== RESULTS TABLE ====================
% One row per comparison, written to the Tables folder so the numbers live on
% disk and not only in the Command Window. No figure is added by this block.
%
% The labels are built from catName1 and catName2 rather than typed out, so a
% row always names the direction that was actually tested: "_12" is
% catName1 -> catName2, the order passed to
% dyadCatDistance_weighted(data, catIdx1, catIdx2). Medians are reported
% because a Spearman correlation is a rank statistic.
comparisons = { ...
    [catName1 ' -> ' catName2], GTK_12(valid12), MAN_12(valid12), rho12, CI12; ...
    [catName2 ' -> ' catName1], GTK_21(valid21), MAN_21(valid21), rho21, CI21; ...
    [catName1 ' -> ' catName1], GTK_11(valid11), MAN_11(valid11), rho11, CI11; ...
    [catName2 ' -> ' catName2], GTK_22(valid22), MAN_22(valid22), rho22, CI22};

nRows     = size(comparisons,1);
Name      = strings(nRows,1);
N_dyads   = nan(nRows,1);   MedianGTK = nan(nRows,1);   MedianMAN = nan(nRows,1);
Rho       = nan(nRows,1);   CI_Lower  = nan(nRows,1);
CI_Upper  = nan(nRows,1);   Verdict   = strings(nRows,1);

for r = 1:nRows
    a = comparisons{r,2};   b = comparisons{r,3};

    Name(r)      = string(comparisons{r,1});
    N_dyads(r)   = numel(a);            % dyads with a finite value in both conditions
    MedianGTK(r) = median(a);
    MedianMAN(r) = median(b);
    Rho(r)       = comparisons{r,4};
    ci           = comparisons{r,5};
    CI_Lower(r)  = ci(1);
    CI_Upper(r)  = ci(2);
    Verdict(r)   = DYMO_ciVerdict(ci, 'Positive association', ...
                           'Negative association', 'No significant association');
end

% ONE FORMAT FOR EVERY CORRELATION TABLE
% rho, its bootstrap interval, and the verdict that interval implies. The
% p-value is no longer reported: the confidence interval is the inference
% throughout this pipeline, and where the two disagreed - as they did for two
% cycles rows, p < .05 with an interval straddling zero - the reader was left
% to choose between them.
NodeDistanceCorr = table(Name, N_dyads, MedianGTK, MedianMAN, Rho, ...
    CI_Lower, CI_Upper, Verdict, ...
    'VariableNames', {'Comparison','N_dyads','MedianGTK','MedianMAN', ...
                      'SpearmanRho','CI_Lower','CI_Upper','Verdict'});
disp(NodeDistanceCorr);
NodeDistanceCorr = DYMO_roundTable(NodeDistanceCorr);   % 3 significant figures, p to 3 dp (APA)
% (not written in this copy) DYMO_writeTable(NodeDistanceCorr, 'NodeDist_BothActiveInactive_SpearmanCorr.csv');
