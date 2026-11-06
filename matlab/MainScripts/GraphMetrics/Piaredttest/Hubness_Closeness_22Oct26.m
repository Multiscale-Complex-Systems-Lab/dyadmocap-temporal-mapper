%% ==================== ARE BOTH ACTIVE NODES PERIPHERAL AND BOTH INACTIVE NODES CENTRAL? ====================
% One test: is the observation in the network figures statistically supported?
%
% THE OBSERVATION
% In most of the network figures the Both Active nodes (green) sit around the
% outside and the Both Inactive nodes (black) sit in the middle.
%
% THE MEASURE
% nodeClosenessByCategory: each node's mean distance to the rest of the whole
% graph (D_simp, both directions, unreachable pairs dropped), averaged over the
% nodes of each category. LOW = central, HIGH = peripheral. See that function
% for why this, and not degree or the induced-subgraph metrics, is the measure
% that matches the claim.
%
% THE TEST
% Within each dyad, Both Inactive against Both Active - the two categories are
% measured in the SAME graph, so graph size and dyad differences cancel. Paired
% across dyads, run separately in each condition, with the pipeline's
% usual machinery (pairedDiffStats: paired t-test plus a BCa bootstrap CI over
% 10,000 dyad resamples, fixed seed). The CI is the inference, as everywhere
% else here.
%
%   meanDiff = mean(Both Inactive) - mean(Both Active), in distance units
%
%   CI entirely BELOW 0 -> Both Inactive are closer to everything than Both
%                          Active are: Both Active more peripheral. SUPPORTS
%                          the observation.
%   CI entirely ABOVE 0 -> the opposite of the observation.
%   CI contains 0       -> no reliable difference; the sentence cannot stand on
%                          this evidence.
%
% A result that is significant in one condition only is not enough for a
% statement about the networks in general - it would need to name the condition.
%
% CAVEAT
% Categories come from a majority vote over each node's members, so if Both
% Inactive nodes are large and mixed while Both Active nodes are small and pure,
% part of any difference is node composition rather than network position.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('nodeClosenessByCategory','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Piaredttest');

tic;
load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');
toc;

first               = find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1);
BehaviouralCategory = GTK_AllDyads_GraphData{first}.BehaviouralCategory;
numCategories       = numel(BehaviouralCategory);

%% ==================== CLOSENESS PER CATEGORY ====================
tic;
[Close.GTK, nNodes.GTK] = nodeClosenessByCategory(GTK_AllDyads_GraphData, numCategories);
[Close.MAN, nNodes.MAN] = nodeClosenessByCategory(MAN_AllDyads_GraphData, numCategories);
toc;

% The two categories the claim is about. Found by name rather than by index, so
% a change to the category order cannot silently test the wrong pair.
iInactive = find(strcmpi(BehaviouralCategory, 'Both Inactive'), 1);
iActive   = find(strcmpi(BehaviouralCategory, 'Both Active'),   1);
if isempty(iInactive) || isempty(iActive)
    error(['Could not find "Both Inactive" and "Both Active" in ' ...
           'BehaviouralCategory: %s'], strjoin(BehaviouralCategory, ', '));
end
fprintf('\nComparing "%s" (central?) against "%s" (peripheral?)\n', ...
    BehaviouralCategory{iInactive}, BehaviouralCategory{iActive});

%% ==================== THE TEST, ONE ROW PER CONDITION ====================
conditions = {'Casual Chat', 'GTK'; 'Conflict', 'MAN'};
nC         = size(conditions, 1);

Condition = strings(nC,1);   N          = nan(nC,1);
MeanInact = nan(nC,1);       MeanActive = nan(nC,1);
MeanDiff  = nan(nC,1);       CI_Lower   = nan(nC,1);
CI_Upper  = nan(nC,1);       tStat      = nan(nC,1);
dfOut     = nan(nC,1);       pValue     = nan(nC,1);
dz        = nan(nC,1);       Verdict    = strings(nC,1);

for k = 1:nC

    name  = conditions{k,1};
    fld   = conditions{k,2};

    a = Close.(fld)(:, iInactive);    % Both Inactive
    b = Close.(fld)(:, iActive);      % Both Active

    S = pairedDiffStats(a, b);        % paired t-test + BCa bootstrap CI

    Condition(k)  = string(name);
    N(k)          = S.N;
    MeanInact(k)  = S.meanA;
    MeanActive(k) = S.meanB;
    MeanDiff(k)   = S.meanDiff;
    CI_Lower(k)   = S.ciBoot(1);
    CI_Upper(k)   = S.ciBoot(2);
    tStat(k)      = S.t;
    dfOut(k)      = S.df;
    pValue(k)     = S.p;
    dz(k)         = S.dz;

    % meanDiff is Inactive minus Active in DISTANCE, so a negative difference
    % means Both Inactive sit closer to everything: they are the central ones.
    Verdict(k) = DYMO_ciVerdict(S.ciBoot, ...
        'Both Active more central', ...
        'Both Active more peripheral (supports the observation)');

    fprintf('\n%s (N = %d dyads)\n', name, S.N);
    fprintf('  mean distance to the rest of the graph\n');
    fprintf('    %-14s %.4g\n', BehaviouralCategory{iInactive}, S.meanA);
    fprintf('    %-14s %.4g\n', BehaviouralCategory{iActive},   S.meanB);
    fprintf('  difference (Inactive - Active) = %.4g,  95%% CI [%.4g, %.4g]\n', ...
        S.meanDiff, S.ciBoot(1), S.ciBoot(2));
    fprintf('  %s\n', Verdict(k));
end

Hubness = table(Condition, N, MeanInact, MeanActive, MeanDiff, ...
    CI_Lower, CI_Upper, tStat, dfOut, pValue, dz, Verdict, ...
    'VariableNames', {'Condition','N','Closeness_BothInactive', ...
                      'Closeness_BothActive','MeanDiff_InactiveMinusActive', ...
                      'CI_Lower','CI_Upper','t','df','p','dz','Verdict'});

Hubness = DYMO_roundTable(Hubness);   % 3 significant figures, p to 3 dp (APA)
DYMO_writeTable(Hubness, 'Hubness_Closeness.csv');
DYMO_writeTable(Hubness, 'Hubness_Closeness.xlsx');
disp(Hubness)

%% ==================== ALL FOUR CATEGORIES, FOR CONTEXT ====================
% Not a test - the descriptive picture behind the comparison above, so the two
% tested categories can be read against the other two rather than in isolation.
CatName = strings(numCategories*nC, 1);
CatCond = strings(numCategories*nC, 1);
CatMean = nan(numCategories*nC, 1);
CatSEM  = nan(numCategories*nC, 1);
CatN    = nan(numCategories*nC, 1);

row = 0;
for k = 1:nC
    X = Close.(conditions{k,2});
    for c = 1:numCategories
        row = row + 1;
        v   = X(:,c);
        v   = v(isfinite(v));
        CatCond(row) = string(conditions{k,1});
        CatName(row) = string(BehaviouralCategory{c});
        CatN(row)    = numel(v);
        if ~isempty(v)
            CatMean(row) = mean(v);
            CatSEM(row)  = std(v) / sqrt(numel(v));
        end
    end
end

ClosenessByCategory = table(CatCond, CatName, CatN, CatMean, CatSEM, ...
    'VariableNames', {'Condition','BehaviouralCategory','N_dyads', ...
                      'MeanClosenessDistance','SEM'});

ClosenessByCategory = DYMO_roundTable(ClosenessByCategory);
DYMO_writeTable(ClosenessByCategory, 'Hubness_ClosenessByCategory.csv');
DYMO_writeTable(ClosenessByCategory, 'Hubness_ClosenessByCategory.xlsx');
disp(ClosenessByCategory)

fprintf(['\nRead the Verdict column, not the p-value: the CI is the inference\n' ...
         'everywhere in this pipeline. If both conditions say "supports the\n' ...
         'observation", the manuscript sentence can stand with these numbers\n' ...
         'attached. If either contains zero, reword it or take it out.\n\n']);
