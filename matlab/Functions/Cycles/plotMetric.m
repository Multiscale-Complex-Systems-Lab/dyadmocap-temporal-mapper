function fig = plotMetric(Results, metric, Vis, yLabelText, titleText, outputFolder)
%PLOTMETRIC  Per-category cycle metric, Casual Chat vs Conflict.
%
%   plotMetric(Results, 'winnerProp', GTKVis, 'Winner Proportion', 'Title')
%   plotMetric(..., outputFolder)
%
% Draws one cycle metric per behavioural state, Casual Chat vs Conflict, in
% the grouped-bar style of the subgraph figures (plotCategoryPairedBars). Used
% by EntroWinner_Cycle_Category_Visualization.
%
% Results.(metric).rawGtk / rawMan : numDyads-by-numCategories.
% Vis supplies the category names and colours. Saved with
% BRMSavePublicationFigure into outputFolder (default Figures/Cycles_PairedTtest/PerCategory).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 6 || isempty(outputFolder)
    outputFolder = DYMO_figureFolder('Cycles_PairedTtest','PerCategory');
end

first    = find(~cellfun(@isempty, Vis), 1);
catNames = Vis{first}.BehaviouralCategory;
cmap     = Vis{first}.cmap;

R   = Results.(metric);
fig = plotCategoryPairedBars(R.rawGtk, R.rawMan, catNames, cmap, titleText, ...
                             Vis{first}.colorvarname, yLabelText);

BRMSavePublicationFigure(['CatCycle_' metric], fig, outputFolder);
close(fig);
end
