function addStatePairIcons(fig, pairs, outFolder, fileName)
%ADDSTATEPAIRICONS  Put a state-pair icon (two coloured nodes joined by a grey
%arrow) above the heading of each panel of a figure, and save the result.
%
%   addStatePairIcons(fig, pairs, outFolder, fileName)
%
%   pairs     : one row per panel, top row first, each row left to right:
%               [fromState toState], with
%               1 = Both Inactive (black), 2 = Both Active (green),
%               3 = Person 1 Active (blue), 4 = Person 2 Active (red)
%   outFolder : where to save; fileName without extension
%
% Call it AFTER SavePublicationFigure: that function sets the fonts and lays
% the panels out, so the titles are where they will finally be. Each panel is
% then made a little shorter at the top, the icon is drawn in the space freed
% above its title, and the figure is saved as <fileName>.png (600 dpi),
% .pdf (vector) and .fig, and the figure is closed. Nothing else in the figure
% changes.
%
% The icon (two nodes joined by an arrow, as in NodeDistanceIcons_29Oct26) is
% drawn in the state colours.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

stateColors = [0 0 0;     % Both Inactive   - black
               0 1 0;     % Both Active     - green
               0 0 1;     % Person 1 Active - blue
               1 0 0];    % Person 2 Active - red
edgeColor   = [0.5 0.5 0.5];

H = 0.09;   % share of the figure height freed above each panel for its icon

% panels, left to right
% (icon axes added earlier carry the tag 'StatePairIcon' and are skipped)
ax = findobj(fig, 'Type', 'axes', '-not', 'Tag', 'StatePairIcon');
% order: top row first, then left to right (a figure may have several rows,
% e.g. the 2 x 4 node distance figure)
pos = cell2mat(arrayfun(@(a) a.Position, ax, 'UniformOutput', false));
[~, order] = sortrows([-round(pos(:,2), 2), pos(:,1)]);
ax = ax(order);
if numel(ax) ~= size(pairs,1)
    error('addStatePairIcons: %d panels but %d pairs.', numel(ax), size(pairs,1));
end

set(fig, 'Units', 'inches');
figPos = get(fig, 'Position');      % [x y width height] in inches

% shorten every panel at the top, keeping its bottom where it is
for i = 1:numel(ax)
    a = ax(i);
    if isprop(a, 'PositionConstraint')
        a.PositionConstraint = 'innerposition';
    elseif isprop(a, 'ActivePositionProperty')
        a.ActivePositionProperty = 'position';
    end
    a.Units = 'normalized';
    p = a.Position;
    a.Position = [p(1) p(2) p(3) p(4)-H];
end
drawnow;

for i = 1:numel(ax)
    a = ax(i);
    p = a.Position;

    % the title's box, in figure units
    a.Title.Units = 'normalized';
    e = a.Title.Extent;                        % [x y width height] in panel units
    titleTop = p(2) + (e(2) + e(4)) * p(4);

    % the nodes go above the MIDDLE of the first and of the second state name.
    % The heading is "<state> -> <state>": each name is
    % measured in the title's own font, and its middle found from the title's
    % left and right edges.
    str   = strjoin(cellstr(a.Title.String), ' ');
    parts = strtrim(strsplit(str, char(8594)));     % split at the arrow
    if numel(parts) < 2                              % no arrow: first and last word
        words = strsplit(strtrim(str));
        parts = {words{1}, words{end}};
    end
    wFirst = textWidth(a, parts{1});
    wLast  = textWidth(a, parts{end});
    xFirst = p(1) + (e(1) + wFirst/2) * p(3);           % middle of the first name
    xLast  = p(1) + (e(1) + e(3) - wLast/2) * p(3);     % middle of the last name

    % icon from node to node, close above the heading
    h   = 0.70 * H;                            % icon height, share of the figure
    titleWidth = xLast - xFirst;               % node-to-node width
    iax = axes(fig, 'Units','normalized', ...
               'Position',[xFirst, titleTop + 0.02*H, titleWidth, h], ...
               'Tag','StatePairIcon');
    hold(iax, 'on');

    % aspect of the icon in inches, so the arrowhead keeps its shape
    wIn = titleWidth * figPos(3);
    hIn = h * figPos(4);

    % grey edge from node to node, with an open ">" arrowhead halfway along it.
    % The arrowhead is drawn LARGE compared with the line width, with a sharp
    % (mitred) tip, so it reads as an arrow and not as a small blob or diamond.
    % Sizes are in inches, so the shape is the same
    % whatever the length of the edge.
    plot(iax, [0 1], [0 0], 'Color', edgeColor, 'LineWidth', 5);
    armH = 0.22;                               % half-height of the ">" (inches)
    armL = 0.30;                               % length of the ">" (inches)
    aw = armH / (hIn/2);                       % in y units (axis runs -1 to 1)
    al = armL / wIn;                           % in x units (axis runs 0 to 1)
    plot(iax, [0.5+al/2-al, 0.5+al/2, 0.5+al/2-al], [aw, 0, -aw], ...
         'Color', edgeColor, 'LineWidth', 5, 'LineJoin','miter');

    % coloured nodes, diameter half the icon height, at the two ends
    d = 0.5 * hIn * 72;                        % in points
    s1 = pairs(i,1);  s2 = pairs(i,2);
    scatter(iax, 0, 0, d^2, stateColors(s1,:), 'filled', 'MarkerEdgeColor','k');
    scatter(iax, 1, 0, d^2, stateColors(s2,:), 'filled', 'MarkerEdgeColor','k');

    xlim(iax, [0 1]);
    ylim(iax, [-1 1]);
    axis(iax, 'off');
    set(iax.Children, 'Clipping','off');       % nodes at the ends are not cut
    hold(iax, 'off');
end
drawnow;

% save PNG, PDF and .fig, as the pipeline does
base = fullfile(outFolder, fileName);
exportgraphics(fig, [base '.png'], 'Resolution',600, 'BackgroundColor','white');
exportgraphics(fig, [base '.pdf'], 'ContentType','vector', 'BackgroundColor','white');
savefig(fig, [base '.fig']);
fprintf('Saved %s (.png/.pdf/.fig)\n', base);

% Close the figure. Left open, it could become MATLAB's current figure (gcf)
% again when a later legend figure is closed, so the next SavePublicationFigure
% would save it instead of the new figure.
close(fig);
end

% ---------------------------------------------------------------------------
function w = textWidth(ax, str)
%TEXTWIDTH  Width of a string in the axes' title font, in panel units.
t = text(ax, 0, 0, str, 'Units','normalized', 'Visible','off', ...
         'FontSize',ax.Title.FontSize, 'FontWeight',ax.Title.FontWeight, ...
         'FontName',ax.Title.FontName, 'Interpreter',ax.Title.Interpreter);
w = t.Extent(3);
delete(t);
end
