function fitFigureLayout(fig_handle, axes_list, titleFontSize, colorbarFontSize, tightenAxes)
%FITFIGURELAYOUT  Final layout step shared by the two figure savers.
%
%   fitFigureLayout(fig, axes_list, titleFontSize, colorbarFontSize, tightenAxes)
%
% Called by SavePublicationFigure and BRMSavePublicationFigure after they have
% set their fonts, so the two savers lay figures out the same way even though
% they use different font sizes and figure sizes.
%
% It does four things, in this order:
%   1. Gives the colour bar a readable font. A colour bar is not an 'axes', so
%      the savers' axes loop never sees it, and on the temporal mapper figures
%      it carries the four category names.
%   2. Calls drawnow ONCE. Everything below measures text, and MATLAB reports
%      the old size until the figure has been redrawn; measured before drawnow,
%      the space reserved is that of the previous, smaller font, and titles
%      are cut off.
%   3. Shrinks a title that is wider than its own panel. MATLAB centres a title
%      and lets it overflow sideways, and TightInset reserves room for its
%      HEIGHT only, so in a two-panel figure the right panel's title can run off
%      the edge of the figure. If any title is too wide, every title in the
%      figure is reduced to the same smaller size, so the panels still match.
%   4. Gives every panel the same margin (the largest any panel needs).
%      Otherwise each panel reserves only what its own labels need, so a panel
%      with a longer y label comes out narrower than its neighbour and the
%      figure looks lopsided.
%
% tightenAxes = true applies a further margin trimming, which pushes each
% axes outward and removes the reserved white space. It gives a tighter figure
% but can clip a title, so it is meant for panels without titles.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

%% ---- 0. figures that lay themselves out ----
% A figure that positions its own axes by hand - the category key, for example -
% must not be re-laid out here: switching its axes to outer-position layout and
% applying LooseInset moves the axes partly outside the figure, which cuts the
% left-hand end of its labels. Such a figure sets fig.UserData.SkipLayout = true.
if isstruct(fig_handle.UserData) && isfield(fig_handle.UserData, 'SkipLayout') ...
        && fig_handle.UserData.SkipLayout
    drawnow;
    return
end

%% ---- 1. colour bars ----
for cb = findall(fig_handle, 'Type', 'ColorBar')'
    cb.FontSize             = colorbarFontSize;
    cb.FontWeight           = 'bold';
    cb.Label.FontSize       = colorbarFontSize;
    cb.TickLabelInterpreter = 'none';
end

%% ---- 2. render once with the final fonts ----
drawnow;

%% ---- 3. a title wider than its panel ----
titleScale = 1;
for ax = axes_list'
    if strlength(join(string(ax.Title.String), ' ')) == 0
        continue
    end
    oldUnits       = ax.Title.Units;
    ax.Title.Units = 'normalized';
    w              = ax.Title.Extent(3);   % width in units of the panel width
    ax.Title.Units = oldUnits;
    if w > 0.98
        titleScale = min(titleScale, 0.98/w);
    end
end

if titleScale < 1
    newTitleSize = max(10, floor(titleFontSize*titleScale));
    for ax = axes_list'
        ax.Title.FontSize = newTitleSize;
    end
    fprintf('Title font reduced from %d to %d pt so it fits inside the panel.\n', ...
        titleFontSize, newTitleSize);
    drawnow;
end

%% ---- 4. one margin for every panel ----
commonInset = [0 0 0 0];
for ax = axes_list'
    commonInset = max(commonInset, ax.TightInset);
end
% More slack left and right than top and bottom: TightInset measures the height
% of titles and the width of tick labels, but text can still overflow sideways
% (a centred heading, a wide tick label at the last tick), and that overflow is
% what gets cut at the figure edge.
commonInset = commonInset + [0.035 0.02 0.035 0.02];

for ax = axes_list'
    % LooseInset is only honoured when the axes is laid out by its OUTER
    % position; a subplot laid out by its inner position ignores it, and then a
    % large x label is simply cut off at the figure edge.
    if isprop(ax, 'PositionConstraint')
        ax.PositionConstraint = 'outerposition';        % R2020a and later
    elseif isprop(ax, 'ActivePositionProperty')
        ax.ActivePositionProperty = 'outerposition';    % older releases
    end

    if tightenAxes
        p      = ax.Position;
        margin = 0.01;
        ax.Position = [max(0,p(1)-margin),...
                       max(0,p(2)-margin),...
                       min(1,p(3)+2*margin),...
                       min(1,p(4)+2*margin)];
        ax.LooseInset = max(ax.TightInset,[0.01 0.01 0.01 0.01]);
    else
        ax.LooseInset = commonInset;
    end
end
drawnow;
end
