function AutoSavePublishableFigure(filename_base, fig_handle, outputFolder)
% Saves a figure as .fig, 300-DPI .png and vector .pdf.
% filename_base should be the desired file name without extension (e.g., 'MyPlot')
%
% drawnow is called once per figure (it forces a full render, the slowest part
% of saving), not once per axes.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

    % ---- Handle inputs ----
    if nargin < 2 || isempty(fig_handle)
        fig_handle = gcf;
    end
    if nargin < 3 || isempty(outputFolder)
        outputFolder = DYMO_figureFolder('Unsorted');
    end

    if ~isscalar(fig_handle) || ~ishandle(fig_handle) || ~strcmp(get(fig_handle,'Type'),'figure')
        error('Second input must be a valid figure handle.');
    end

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    basePath = fullfile(outputFolder, filename_base);

    % ---- Figure sizing (single unit system) ----
    set(fig_handle, 'Units', 'inches');
    set(fig_handle, 'Position', [1 1 14 8]);   % consistent wide layout

    % ---- Format all axes ----
    axes_list = findall(fig_handle, 'type', 'axes');
    for ax = axes_list'
        ax.FontSize   = 12;
        ax.LineWidth  = 1.5;
        ax.FontWeight = 'bold';

        ax.Title.FontSize  = 11;
        ax.XLabel.FontSize = 14;
        ax.YLabel.FontSize = 14;

        ax.TickLabelInterpreter = 'none';
        ax.XLabel.Interpreter   = 'none';
        ax.YLabel.Interpreter   = 'none';
        ax.Title.Interpreter    = 'none';

        if ~isempty(ax.Legend)
            ax.Legend.FontSize = 10;
        end
    end

    drawnow;   % once, so TightInset is up to date
    for ax = axes_list'
        ax.LooseInset = ax.TightInset + 0.02;
    end

    % ---- Match PDF page size to figure ----
    fig_pos = get(fig_handle, 'Position');   % inches
    set(fig_handle, 'PaperUnits', 'inches');
    set(fig_handle, 'PaperPosition', [0 0 fig_pos(3) fig_pos(4)]);
    set(fig_handle, 'PaperSize',     [fig_pos(3) fig_pos(4)]);

    % ---- Save outputs (.fig, .png and .pdf side by side) ----
    % Windows cannot write a path longer than 260 characters.
    if strlength(basePath) > 240
        warning('The figure path is %d characters long; Windows may refuse to write it:\n%s', ...
            strlength(basePath), basePath);
    end
    % A .fig remembers whether the figure was visible when it was saved. Some
    % figures are built with 'Visible','off' for speed, and a .fig saved that
    % way opens an invisible window when double-clicked, so it looks as if
    % nothing happened. Saving it as visible fixes that; the original state is
    % put back straight afterwards. (openfig('file.fig','visible') also works
    % for .fig files that were saved before this change.)
    wasVisible = get(fig_handle, 'Visible');
    set(fig_handle, 'Visible', 'on');
    saveFigureFile(@() savefig(fig_handle, [basePath '.fig']), [basePath '.fig']);
    set(fig_handle, 'Visible', wasVisible);
    saveFigureFile(@() print(fig_handle, [basePath '.png'], '-dpng', '-r300'), [basePath '.png']);
    saveFigureFile(@() print(fig_handle, [basePath '.pdf'], '-dpdf'), [basePath '.pdf']);
end
