function BRMSavePublicationFigure(filename_base, fig_handle, outputFolder, figSizeInches)
% This function Autosaves Figures when called;
%
% It formats and saves the figure with SavePublicationFigure, so every figure
% in the pipeline is formatted and saved by ONE piece of code: same font scale
% (title 34, labels 32, ticks 28, legend 26), same frame weight, same title
% fitting, same equal margins, and the same retried .fig/.png/.pdf saving.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 2, fig_handle    = gcf; end
if nargin < 3, outputFolder  = ''; end
if nargin < 4, figSizeInches = []; end   % [] = the default 25 x 16 inches

SavePublicationFigure(filename_base, fig_handle, outputFolder, figSizeInches);
end
