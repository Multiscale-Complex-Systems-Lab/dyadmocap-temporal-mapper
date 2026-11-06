function SavePublicationFigure(filename_base, fig_handle, outputFolder, figSizeInches)

% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

% ---- Handle inputs ----
if nargin < 2 || isempty(fig_handle)
    fig_handle = gcf;
end

if nargin < 3 || isempty(outputFolder)
    outputFolder = DYMO_figureFolder('Unsorted');
end

% Figure size in inches. The default, 25 x 16, suits a figure with two panels
% side by side. A figure holding a single pair of bars looks far too wide at
% that size, so a script can ask for a narrower canvas, e.g.
% SavePublicationFigure(name, fig, folder, [13 16]).
if nargin < 4 || isempty(figSizeInches)
    figSizeInches = [25 16];
end

if ~isscalar(fig_handle) || ~ishandle(fig_handle) || ...
        ~strcmp(get(fig_handle,'Type'),'figure')
    error('Second input must be a valid figure handle.');
end

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

basePath = fullfile(outputFolder,filename_base);

%% -----------------------------------------------------------------------
% Figure size (optimized for publications and PowerPoint)
%% -----------------------------------------------------------------------
set(fig_handle,'Units','inches');
set(fig_handle,'Position',[1 1 figSizeInches(1) figSizeInches(2)]);
set(fig_handle,'Color','w');

%% -----------------------------------------------------------------------
% Font sizes and spacing, all in one place
%% -----------------------------------------------------------------------
% The title, the legend and the colour bar are sized separately from the axes,
% and the spacing is set after drawnow (in fitFigureLayout), so the space
% reserved for labels, title and colour bar is measured with the final fonts.
% Everything is scaled from one number, so the order of importance is always
% title > axis labels > tick numbers > legend.
baseFontSize      = 30;
otherFontBump     = 4;      % +4 pt on everything except the title
titleFontSize     = round(1.15*baseFontSize);                   % 34 - the largest text
labelFontSize     = round(0.95*baseFontSize) + otherFontBump;   % 32 - x and y labels
tickFontSize      = round(0.80*baseFontSize) + otherFontBump;   % 28 - axis numbers
legendFontSize    = round(0.75*baseFontSize) + otherFontBump;   % 26
colorbarFontSize  = round(0.75*baseFontSize) + otherFontBump;   % 26 - the category names
% The frame matches the outline of the data drawn inside it: 4.5, the same
% barEdgeWidth that plotPairedComparison uses for the bars and histogram
% outlines, so the box and the bars are drawn with one weight.
axisLineWidth     = 4.5;
tightenAxes       = false;  % true = trim the margins further (it can clip
                            % the title; only use it for figures with no title)

%% -----------------------------------------------------------------------
% Format all axes
%% -----------------------------------------------------------------------
axes_list = findall(fig_handle,'Type','axes');

for ax = axes_list'

    % General formatting
    ax.FontName   = 'Arial';
    ax.FontSize   = tickFontSize;     % axis numbers
    ax.FontWeight = 'bold';
    ax.LineWidth  = axisLineWidth;

    % Titles and labels
    ax.Title.FontSize   = titleFontSize;   % the heading of the panel
    ax.Title.FontWeight = 'bold';

    ax.XLabel.FontSize = labelFontSize;
    ax.YLabel.FontSize = labelFontSize;

    %% -----------------------------------------------------------------------
% Format figure-wide title (sgtitle), if present
%% -----------------------------------------------------------------------

    sg = findall(fig_handle,'Type','Text','Tag','suptitle');

    if ~isempty(sg)
        sg.FontSize = titleFontSize;
        sg.FontWeight = 'bold';
    
        pos = sg.Position;
        pos(2) = pos(2) + 0.01;   % move title upward
        sg.Position = pos;
    end

    % No grid lines on any figure. Done here, once, so every figure the
    % pipeline saves follows it; the plotting functions that say 'grid on'
    % are overruled at saving time.
    grid(ax, 'off');

    % Keep literal text
    ax.TickLabelInterpreter = 'none';
    ax.XLabel.Interpreter   = 'none';
    ax.YLabel.Interpreter   = 'none';
    ax.Title.Interpreter    = 'none';

    % Format existing legend only
    if ~isempty(ax.Legend)
        ax.Legend.FontSize = legendFontSize;
        ax.Legend.Box = 'off';
    end

    % Thicken existing plotted lines
    lines = findall(ax,'Type','Line');
    for k = 1:numel(lines)
        lines(k).LineWidth = max(lines(k).LineWidth,5);

        if lines(k).Marker ~= "none"
            lines(k).MarkerSize = max(lines(k).MarkerSize,25);
        end
    end

end

%% -----------------------------------------------------------------------
% Layout: colour bar font, title fitting and equal margins
%% -----------------------------------------------------------------------
% All of this is in fitFigureLayout, which BRMSavePublicationFigure also calls,
% so both savers lay a figure out the same way. It must run AFTER the fonts
% above: everything it does depends on measuring the text as finally drawn.
fitFigureLayout(fig_handle, axes_list, titleFontSize, colorbarFontSize, tightenAxes);

disp('Finished formatting')

%% -----------------------------------------------------------------------
% Match PDF page size exactly to figure
%% -----------------------------------------------------------------------
fig_pos = get(fig_handle,'Position');

set(fig_handle,'PaperUnits','inches');
set(fig_handle,'PaperPosition',[0 0 fig_pos(3) fig_pos(4)]);
set(fig_handle,'PaperSize',[fig_pos(3) fig_pos(4)]);


%% -----------------------------------------------------------------------
% Save
%% -----------------------------------------------------------------------
% The three saves go through saveFigureFile, which retries once a second up to
% 3 times and then stops with a message naming the file. A save can fail for a
% moment while a cloud-synced folder (e.g. OneDrive) syncs, or if the file is
% open in a viewer.
% The warning below means the path is close to Windows' 260-character limit;
% the node-distance figures run to about 205 characters, and the longest
% extension adds 4.
if numel(basePath) + 4 > 240
    warning(['The path of this figure is %d characters, close to the 260 ' ...
             'characters Windows allows:\n  %s\nIf a save fails, shorten the ' ...
             'results folder name.'], numel(basePath), basePath);
end

disp('Saving FIG')
% savefig stores the figure's visibility, so make it visible while saving:
% otherwise double-clicking the .fig opens an invisible window.
wasVisible = get(fig_handle,'Visible');
set(fig_handle,'Visible','on');
saveFigureFile(@() savefig(fig_handle,[basePath '.fig']), [basePath '.fig']);
set(fig_handle,'Visible',wasVisible);

% exportgraphics crops to the CONTENT by default ('Padding','tight'), and a
% frame line drawn on that boundary loses its outer half, so the right-hand
% side of the 4.5 pt axes box can come out cut. 'Padding','figure' exports the
% whole figure rectangle instead, so the frame and anything at the edge is
% complete. Not every release accepts the option (some reject it with "Illegal
% option 'padding' given"), so exportFigure below tries it once and remembers
% the answer, rather than guessing from the release number.
padArgs = {'Padding','figure'};

% The axes toolbar - the pan/zoom/datatip icons that appear on hover - belongs
% to the figure rectangle, so 'Padding','figure' includes it and exportgraphics
% warns "Exported image displays axes toolbar". Hiding it removes both the
% warning and the icons from the saved PNG and PDF; the on-screen figure is
% restored afterwards, so interactive use is unaffected.
figAxes = findall(fig_handle, 'Type', 'axes');
tbWas   = cell(numel(figAxes), 1);
for a = 1:numel(figAxes)
    if isprop(figAxes(a), 'Toolbar') && ~isempty(figAxes(a).Toolbar)
        tbWas{a} = figAxes(a).Toolbar.Visible;
        figAxes(a).Toolbar.Visible = 'off';
    end
end

disp('Saving PNG')
saveFigureFile(@() exportFigure(fig_handle, [basePath '.png'], ...
    {'Resolution',600,'BackgroundColor','white'}, padArgs), [basePath '.png']);

disp('Saving PDF')
saveFigureFile(@() exportFigure(fig_handle, [basePath '.pdf'], ...
    {'ContentType','vector','BackgroundColor','white'}, padArgs), [basePath '.pdf']);

% put the toolbars back
for a = 1:numel(figAxes)
    if ~isempty(tbWas{a})
        figAxes(a).Toolbar.Visible = tbWas{a};
    end
end

disp('Done')
end

% ---------------------------------------------------------------------------
function exportFigure(fig_handle, fileName, baseArgs, padArgs)
%EXPORTFIGURE  exportgraphics with 'Padding','figure', cropping tight if the
%option is unavailable.
%
% 'Padding','figure' stops exportgraphics cropping to the content and shaving
% the outer half of the 4.5 pt axes frame. Releases that do not accept the
% option raise "Illegal option 'padding' given".
%
% THE FALLBACK IS exportgraphics WITHOUT THE OPTION, NOT print
% print writes the whole figure rectangle and so keeps the frame whole, but that
% rectangle includes the figure's empty margins, which leaves wide white bands
% down the sides of the multi-panel figures. Dropping the option instead uses
% exportgraphics' default 'tight' padding, which crops to the content.
%
% The cost is the reason 'Padding' is used in the first place: a tight crop
% can shave the outer half of a frame line drawn exactly on the content
% boundary. Worth a look at the right-hand frame of one figure. If it is cut,
% the fix is to inset the axes slightly rather than to use print.
%
% The answer is remembered in a persistent, so the failure costs one attempt per
% MATLAB session rather than one per figure. Any error that is not about
% 'padding' is rethrown untouched - a locked or syncing file must still reach
% saveFigureFile's retry.

persistent padSupported
if isempty(padSupported), padSupported = true; end

if padSupported
    try
        exportgraphics(fig_handle, fileName, baseArgs{:}, padArgs{:});
        return
    catch ME
        if ~contains(lower(ME.message), 'padding')
            rethrow(ME);
        end
        padSupported = false;
        warning('SavePublicationFigure:noPadding', ...
            ['This MATLAB release does not accept the ''Padding'' option of ' ...
             'exportgraphics, so figures are cropped to their content. ' ...
             'Check that the axes frame is not cut.']);
    end
end

exportgraphics(fig_handle, fileName, baseArgs{:});   % default 'tight' padding
end
