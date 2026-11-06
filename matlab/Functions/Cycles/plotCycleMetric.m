function fig = plotCycleMetric(Results, metric, Vis, yLabelText, titleText, outputFolder)
%PLOTCYCLEMETRIC  Whole-graph cycle metric, Casual Chat vs Conflict.
%
%   plotCycleMetric(Results, 'CycleCount', GTKVis, 'Cycle counts', 'Title')
%   plotCycleMetric(..., outputFolder)
%
% Draws one whole-graph cycle metric, Casual Chat vs Conflict, in the same
% figure style as the whole-graph paired t-test figures. Used by
% WholeGraphsCycles_Above3Min.
%
% Results.(metric) must contain rawGtk, rawMan (paired dyad values) and
% pvals (paired t-test p-value). Vis is accepted but not used. The figure is
% saved with
% BRMSavePublicationFigure into outputFolder (default: Figures/Cycles_PairedTtest/WholeGraph).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 6 || isempty(outputFolder)
    outputFolder = DYMO_figureFolder('Cycles_PairedTtest','WholeGraph');
end

R   = Results.(metric);
fig = plotWholePairedBar(R.rawGtk, R.rawMan, R.pvals, titleText, yLabelText);

% [13 16] inches: one pair of bars, like the whole-graph metric figures;
% 25 x 16 is for figures with two or more panels.
BRMSavePublicationFigure(['WGCycle_' metric], fig, outputFolder, [13 16]);
close(fig);
end
