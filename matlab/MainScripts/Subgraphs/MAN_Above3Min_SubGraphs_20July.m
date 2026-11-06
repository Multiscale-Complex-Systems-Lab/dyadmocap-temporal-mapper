% %% ============================================================
% %% MAN: (A) FOUR BehaviouralCategory SUBGRAPHS and
% %%      (B) CATEGORY HIGHLIGHTING ON THE ORIGINAL TM GRAPH
% %% ============================================================
%
% Both parts are switchable with runSubgraphs / runHighlight below. Networks are
% drawn with plottmgraph (plotTMGraphCategories). Loads the TM data file named
% in DYMO_files.m.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

% NOTE: these two lines were `clear;` and `clc;`. They are
% commented out because a script's `clear` empties the workspace of whatever ran
% it - the temporal mapper variables when run by hand, and the pipeline runner's
% own bookkeeping when run by DYMO_runAll - and `clc` erases the Command Window
% log of a run that takes hours. This script loads everything it needs from disk,
% so neither line was doing any work. Uncomment them only for a one-off run by
% hand.
% clear;
% clc;

if ~exist('plottmgraph','file'), error('Run DYMO_setup.m first.'); end

% Only part (B) is used: the whole TM graph with one category in its colour and
% the other three muted to grey (02_CategoryHighlighting). Part (A), which lifts
% a category's nodes out into a graph of its own (01_CategorySubgraphs), is not
% used, and nothing downstream reads the .mat it saves. Set runSubgraphs = true
% to run part (A).
runSubgraphs = false;   % (A) one subgraph per behavioural category - NOT used
runHighlight = true;    % (B) highlight each category on the whole graph, others grey

grp = 'MAN';
F   = DYMO_files('Subgraphs');

tic;
%% ---------------- Load existing data ----------------
S = load(F.([grp '_TM']), [grp '_AllDyads_GraphData']);
AllDyads = S.([grp '_AllDyads_GraphData']);
clear S
fprintf('Loaded %s\n', F.([grp '_TM']));

%% ============================================================
%% (A) CREATE FOUR BehaviouralCategory SUBGRAPHS
%% ============================================================
if runSubgraphs

    for d = 1:numel(AllDyads)

        if isempty(AllDyads{d})
            continue
        end
        fprintf('Processing Dyad %d\n', d);

        g_simp              = AllDyads{d}.g_simp;
        members             = AllDyads{d}.members;
        colorvar            = AllDyads{d}.colorvar;
        cmap                = AllDyads{d}.cmap;
        colorvarname        = AllDyads{d}.colorvarname;
        BehaviouralCategory = AllDyads{d}.BehaviouralCategory;

        for c = 1:4

            fprintf('   Category %d : %s\n', c, BehaviouralCategory{c});

            % Original frame indices for this category
            idxCat = find(colorvar == c);

            [g_sub, members_sub, origNodeIdx] = ...
                subgraphFromMembers(g_simp, members, idxCat);

            AllDyads{d}.Subgraphs(c).Name            = BehaviouralCategory{c};
            AllDyads{d}.Subgraphs(c).Graph           = g_sub;
            AllDyads{d}.Subgraphs(c).Members         = members_sub;
            AllDyads{d}.Subgraphs(c).OriginalNodeIdx = origNodeIdx;
            AllDyads{d}.Subgraphs(c).FrameIdx        = idxCat;

            if numnodes(g_sub) == 0
                continue   % nothing to draw
            end

            fig = plotTMGraphCategories(g_sub, colorvar, members_sub, cmap, ...
                BehaviouralCategory, colorvarname, ...
                {[grp ' Dyad ' num2str(d)], ['Subgraph : ' BehaviouralCategory{c}]});

            % one subfolder per category (Figures/Subgraphs_MAN/01_CategorySubgraphs/Both_Active, ...)
            catTag = regexprep(BehaviouralCategory{c},'\s+','_');
            SavePublicationFigure([grp '_Dyad_' num2str(d) '_' catTag '_Subgraph'], fig, ...
                DYMO_figureFolder(['Subgraphs_' grp], '01_CategorySubgraphs', catTag));
            close(fig)
        end
    end

    % Save updated master data
    Sout = struct();
    Sout.([grp '_AllDyads_GraphData']) = AllDyads;
    save(F.([grp '_Subgraphs']), '-struct', 'Sout', '-v7.3');
    clear Sout
    disp('Finished creating, plotting and saving BehaviouralCategory subgraphs.')
end

%% ============================================================
%% (B) HIGHLIGHT CATEGORY ON ORIGINAL TEMPORAL MAPPER GRAPH
%% ============================================================
if runHighlight

    gray = [0.75 0.75 0.75];

    for d = 1:numel(AllDyads)

        if isempty(AllDyads{d})
            continue
        end
        fprintf('\nProcessing Dyad %d\n', d);

        g_simp              = AllDyads{d}.g_simp;
        members             = AllDyads{d}.members;
        colorvar            = AllDyads{d}.colorvar;
        BehaviouralCategory = AllDyads{d}.BehaviouralCategory;
        cmap                = AllDyads{d}.cmap;
        colorvarname        = AllDyads{d}.colorvarname;

        for highlightCat = 1:4

            fprintf('   Highlighting: %s\n', BehaviouralCategory{highlightCat});

            % Keep original labels; non-selected categories drawn in gray
            highlightCmap = repmat(gray, 4, 1);
            highlightCmap(highlightCat,:) = cmap(highlightCat,:);

            fig = plotTMGraphCategories(g_simp, colorvar, members, highlightCmap, ...
                BehaviouralCategory, colorvarname, ...
                [string(grp) + " Dyad " + d, "Highlighted: " + BehaviouralCategory{highlightCat}]);

            % one subfolder per highlighted category
            catTag = regexprep(BehaviouralCategory{highlightCat},'\s+','_');
            SavePublicationFigure([grp '_Dyad_' num2str(d) '_Highlight_' catTag], fig, ...
                DYMO_figureFolder(['Subgraphs_' grp], '02_CategoryHighlighting', catTag));
            close(fig);
        end
    end
    disp('Finished creating all highlighted BehaviouralCategory graphs.')
end
toc;
