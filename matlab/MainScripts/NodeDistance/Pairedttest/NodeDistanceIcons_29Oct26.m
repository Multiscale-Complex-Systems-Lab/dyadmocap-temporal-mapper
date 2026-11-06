%% ====== STATE-PAIR ICONS FOR THE NODE DISTANCE FIGURES ======
% Small icons (two coloured nodes joined by a grey arrow) to place on top of
% the headings of the node distance figures, e.g. the icon "black -> green"
% above "Both Inactive -> Both Active".
%
%   * the four colours and names are the behavioural states, in the usual
%     order: Both Inactive (black), Both Active (green), Person 1 Active
%     (blue), Person 2 Active (red) - the colours of the cmap stored with the
%     data
%   * no title on the icon (the figure heading already says the pair); set
%     SHOW_TITLE = true to add one
%   * saved as PNG, PDF and .fig in
%       <results>\NodeDistance_Pairedttest_Results_<tag>\Figures\
%                 NodeDistance_PairedTtest\StateIcons
%
% All 16 pairs are made: 12 between two states and 4 within one state
% (e.g. Both Active -> Both Active, for the same-category panels).
% No data are loaded; the icons are drawings only.
%
% BEFORE RUNNING
%   DYMO_setup
%   cfg = DYMO_config(); cd(cfg.resultsDir)   % the results folder (DYMO_runAll does this itself)
%
% OUTPUT: 16 small icons, StateIcon_01_BothInactive_to_BothInactive ...
% StateIcon_16_Person2Active_to_Person2Active, each in .png, .pdf and .fig.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

close all;

SHOW_TITLE = false;   % true = write "State -> State" above the icon

%% Node positions
X = [0 2];
Y = [0 0];

%% The four states, in the usual order, with their colours
stateColors = [
    0 0 0      % Both Inactive   - black
    0 1 0      % Both Active     - green
    0 0 1      % Person 1 Active - blue
    1 0 0      % Person 2 Active - red
];
stateNames = {'Both Inactive','Both Active','Person 1 Active','Person 2 Active'};
fileNames  = {'BothInactive','BothActive','Person1Active','Person2Active'};

%% Edge colour: grey
edgeColor = [0.5 0.5 0.5];

%% Output folder
% DYMO_files must be told the area first: without it the icons would go into
% the results folder of the last script run in the session.
F = DYMO_files('NodeDistance_Pairedttest');
outFolder = DYMO_figureFolder('NodeDistance_PairedTtest', 'StateIcons');

%% All 16 state pairs (from -> to)
numStates = numel(stateNames);
k = 0;

for s1 = 1:numStates
    for s2 = 1:numStates
        k = k + 1;

        %% Node coordinates
        x1 = X(1);  y1 = Y(1);
        x2 = X(2);  y2 = Y(2);

        %% Create figure
        fig = figure('Units','inches', 'Position',[2 2 4 4], 'Color','w');
        hold on;

        %% Draw grey edge
        plot([x1 x2], [y1 y2], 'Color', edgeColor, 'LineWidth', 4);

        %% Unfilled > arrowhead halfway along the edge
        xm = x1 + 0.50*(x2-x1);
        ym = y1 + 0.50*(y2-y1);
        arrowLength = 0.16;
        arrowWidth  = 0.10;
        plot([xm-arrowLength/2, xm, xm-arrowLength/2], ...
             [ym+arrowWidth, ym, ym-arrowWidth], ...
             'Color', edgeColor, 'LineWidth', 4);

        %% Coloured nodes (black edge, so a node shows on any background)
        scatter(x1, y1, 80^2/4, stateColors(s1,:), 'filled', 'MarkerEdgeColor','k');
        scatter(x2, y2, 80^2/4, stateColors(s2,:), 'filled', 'MarkerEdgeColor','k');

        %% Formatting
        axis off;
        axis equal;
        xlim([-0.2 2.2]);
        ylim([-0.3 0.3]);

        if SHOW_TITLE
            title(sprintf('%s \\rightarrow %s', stateNames{s1}, stateNames{s2}), ...
                  'FontSize', 12);
        end
        hold off;

        %% Save PNG, PDF and editable .fig
        filename = fullfile(outFolder, sprintf('StateIcon_%02d_%s_to_%s', ...
                            k, fileNames{s1}, fileNames{s2}));
        exportgraphics(fig, [filename '.png'], 'Resolution',600, 'BackgroundColor','white');
        exportgraphics(fig, [filename '.pdf'], 'ContentType','vector', 'BackgroundColor','white');
        savefig(fig, [filename '.fig']);
        close(fig);
    end
end

fprintf('%d state icons saved in %s\n', k, outFolder);
