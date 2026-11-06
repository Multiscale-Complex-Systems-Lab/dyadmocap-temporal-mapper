%% ==================== CYCLE ANALYSIS FOR GTK AND MAN ====================
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Saves to the file names the cycle analysis scripts load (DYMO_files:
% F.GTK_Cycles / F.MAN_Cycles). Cycle detection uses CycleCount2pFast (one
% shortest-path tree per node instead of two shortest-path searches per node
% PAIR); the first dyad is checked against CycleCount2p, and if the results ever
% differ the script falls back to CycleCount2p for everything.
%
%%%==============================================
%%%%  This code:
%%%==============================================
% 1. Detects all cycles in the graph.
% 2. Retrieves the behavioral category assigned to each node.
% 3. Computes a representative value (colorvar_nodes) for each node.
% 4. Determines how many behavioral categories exist.

if ~exist('CycleCount2p','file'), error('Run DYMO_setup.m first.'); end

verifyFastCycles = true;   % compare fast vs original cycle counting on dyad 1

F = DYMO_files('Cycles_CycleData');

tic;
load(F.GTK_TM, 'GTK_AllDyads_GraphData');   % GTK
load(F.MAN_TM, 'MAN_AllDyads_GraphData');   % MAN
toc;

%% ==================== DATASETS ====================
tic

Datasets(1).name = 'GTK';
Datasets(1).data = GTK_AllDyads_GraphData;

Datasets(2).name = 'MAN';
Datasets(2).data = MAN_AllDyads_GraphData;

useFast = true;

%% ==================== MAIN LOOP ====================
for ds = 1:numel(Datasets)

    datasetName = Datasets(ds).name;
    AllDyads    = Datasets(ds).data;
    numDyads    = numel(AllDyads);

    fprintf('Processing %s (%d dyads)\n', datasetName, numDyads);

    DatasetCycles = cell(1, numDyads);
    DatasetVis    = cell(1, numDyads); % visualization variables

    for d = 1:numDyads
        data = AllDyads{d};

        if isempty(data) || ~isstruct(data)
            continue
        end

        G = data.g_simp;
        A = full(adjacency(G));

        % --- Cycle detection ---
        if useFast
            [cycCount, cycLen, cycPath, allcycles] = CycleCount2pFast(A);

            if verifyFastCycles
                [cc0, cl0, ~, ac0] = CycleCount2p(A);
                if isequal(cc0, cycCount) && isequal(cl0, cycLen) && isequal(ac0, allcycles)
                    fprintf('   CycleCount2pFast matches CycleCount2p on %s dyad %d.\n', datasetName, d);
                else
                    warning(['CycleCount2pFast differs from CycleCount2p on %s dyad %d; ' ...
                             'using the original CycleCount2p for all dyads.'], datasetName, d);
                    useFast = false;
                    [cycCount, cycLen, cycPath, allcycles] = CycleCount2p(A);
                end
                verifyFastCycles = false;   % check once
            end
        else
            [cycCount, cycLen, cycPath, allcycles] = CycleCount2p(A);
        end

        % --- Visualization-related variables ---
        colorvar            = data.colorvar;
        cmap                = data.cmap;
        colorvarname        = data.colorvarname;
        BehaviouralCategory = data.BehaviouralCategory;
        members             = data.members;
        numNodes            = numnodes(G);

        % node category = mode of its time points (same as the TM plots)
        colorvar_nodes = findnodelabel(members, colorvar, 'labelmethod', 'mode');

        cycleDensity  = sum(cycCount) / numNodes;
        numCategories = numel(BehaviouralCategory);

        %===========================================
        % Cycle behavioural classification
        %===========================================
        numCycles = numel(allcycles);
        cycleCategoryCounts = zeros(numCycles, numCategories);
        for c = 1:numCycles
            cats = colorvar_nodes(allcycles{c});
            cycleCategoryCounts(c,:) = histcounts(cats, 1:(numCategories+1));
        end

        % 1. Winner-takes-all category (first maximum, as max() did before)
        [~, cycleWinnerCategory] = max(cycleCategoryCounts, [], 2);
        if isempty(cycleWinnerCategory), cycleWinnerCategory = zeros(0,1); end

        % 2. Shannon entropy (purity), natural log; 0*log(0) treated as 0
        P  = cycleCategoryCounts ./ sum(cycleCategoryCounts, 2);
        PL = P .* log(P);
        PL(P == 0) = 0;
        cycleEntropy = -sum(PL, 2);
        % To normalise to [0, 1]: cycleEntropy = cycleEntropy / log(numCategories);

        % --- Store results for this dyad ---
        DatasetCycles{d}.cycCount            = cycCount;
        DatasetCycles{d}.cycLen              = cycLen;
        DatasetCycles{d}.cycPath             = cycPath;
        DatasetCycles{d}.allcycles           = allcycles;
        DatasetCycles{d}.cycleWinnerCategory = cycleWinnerCategory;
        DatasetCycles{d}.cycleEntropy        = cycleEntropy;
        DatasetCycles{d}.cycleCategoryCounts = cycleCategoryCounts;

        DatasetVis{d}.colorvar_nodes      = colorvar_nodes;
        DatasetVis{d}.cycleDensity        = cycleDensity;
        DatasetVis{d}.BehaviouralCategory = BehaviouralCategory;
        DatasetVis{d}.numCategories       = numCategories;
        DatasetVis{d}.cmap                = cmap;
        DatasetVis{d}.colorvarname        = colorvarname;
    end

    % --- Summary statistics for this dataset ---
    S = [DatasetCycles{:}];
    if ~isempty(S)
        allCycCount = vertcat(S.cycCount);
        allCycLen   = vertcat(S.cycLen);
        fprintf('Dataset: %s\n', datasetName);
        fprintf('Total cycles: %d\n', sum(allCycCount));
        fprintf('Average cycle length: %.2f\n', mean(allCycLen));
        fprintf('Maximum cycle length: %d\n\n', max(allCycLen));
    else
        warning('No valid dyads processed for %s', datasetName);
    end

    % --- Save final dataset results ---
    if strcmp(datasetName,'GTK')
        GTKCycles = DatasetCycles;
        GTKVis    = DatasetVis;
        save(F.GTK_Cycles, 'GTKCycles', 'GTKVis', '-v7.3')
    else
        MANCycles = DatasetCycles;
        MANVis    = DatasetVis;
        save(F.MAN_Cycles, 'MANCycles', 'MANVis', '-v7.3')
    end
end
totalTime = toc;
fprintf('Total processing time: %.2f seconds\n', totalTime);
