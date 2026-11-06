function fig = plotCategoryPairedBars(XC, XS, catNames, cmap, titleText, xLabelText, yLabelText)
%PLOTCATEGORYPAIREDBARS  Grouped bars per behavioural category, Casual Chat
%(GTK, category colour) vs Conflict (MAN, lighter tint), with SEM, mean
%lines, paired t-test brackets and Symmetric / Asymmetric group headings.
%This is the subgraph figure from GTK_MAN_Subgraphstats_Pairedttest,
%moved into a function so the cycle scripts can use it too.
%
%   fig = plotCategoryPairedBars(XC, XS, catNames, cmap, titleText)
%   fig = plotCategoryPairedBars(..., xLabelText, yLabelText)
%
% XC, XS : numDyads-by-numCategories paired values (GTK, MAN)
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 6, xLabelText = ''; end
if nargin < 7, yLabelText = ''; end

numCategories = numel(catNames);

meanGTK = nan(1,numCategories);  semGTK = nan(1,numCategories);
meanMAN = nan(1,numCategories);  semMAN = nan(1,numCategories);
pvals   = nan(1,numCategories);

for c = 1:numCategories
    xC = XC(:,c);
    xS = XS(:,c);
    valid = isfinite(xC) & isfinite(xS);
    GTKvals = xC(valid);
    MANvals = xS(valid);
    if ~isempty(GTKvals)
        meanGTK(c) = mean(GTKvals);  semGTK(c) = std(GTKvals)/sqrt(numel(GTKvals));
        meanMAN(c) = mean(MANvals);  semMAN(c) = std(MANvals)/sqrt(numel(MANvals));
    end
    if numel(GTKvals) > 1
        [~, pvals(c)] = ttest(GTKvals, MANvals);
    end
end

fig = figure('Position',[200 200 900 500]);
Y = [meanGTK; meanMAN]';
b = bar(Y, 'grouped');
hold on

% bar colours
GTKCmap = cmap(1:numCategories,:);
MANCmap = min(GTKCmap + 0.7, 1);
b(1).FaceColor = 'flat';  b(1).CData = GTKCmap;
b(2).FaceColor = 'flat';  b(2).CData = MANCmap;
b(1).EdgeColor = 'k';     b(2).EdgeColor = 'k';
% Line weights and font sizes match the NodeDistance figures: bar edge 4.5,
% error bars 5.0 with CapSize 12, brackets 4.5, annotation text 28 pt and the
% group headings 30 pt.
b(1).LineWidth = 4.5;     b(2).LineWidth = 4.5;

% error bars
x = [b(1).XEndPoints(:), b(2).XEndPoints(:)];
errorbar(x(:,1), meanGTK, semGTK, 'k','LineStyle','none','LineWidth',5.0,'CapSize',12);
errorbar(x(:,2), meanMAN, semMAN, 'k','LineStyle','none','LineWidth',5.0,'CapSize',12);

% horizontal mean lines
lineLength = 0.25;
for kk = 1:2
    for c = 1:numCategories
        plot([x(c,kk)-lineLength/2 x(c,kk)+lineLength/2], [Y(c,kk) Y(c,kk)], 'r-','LineWidth',4.5);
    end
end

% significance brackets
yl = ylim;
ylim([yl(1) yl(2)*1.20]);
yOffset = 0.05 * diff(yl);
tick    = 0.25 * yOffset;
annTop  = -inf;    % highest point reached by any annotation, filled in below

for c = 1:numCategories
    p = pvals(c);

    yTop = max(meanGTK(c)+semGTK(c), meanMAN(c)+semMAN(c));
    if ~isfinite(yTop), continue; end
    yBar = yTop + yOffset;

    if yBar + 3*yOffset > yl(2)
        ylim([yl(1), yBar + 5.0*yOffset]);
        yl      = ylim;
        yOffset = 0.05 * diff(yl);
        tick    = 0.25 * yOffset;
        yBar    = yTop + yOffset;
    end

    x1 = x(c,1);  x2 = x(c,2);
    plot([x1 x1], [yBar-tick yBar], 'k','LineWidth',4.5);
    plot([x1 x2], [yBar yBar],      'k','LineWidth',4.5);
    plot([x2 x2], [yBar-tick yBar], 'k','LineWidth',4.5);

    % Star and p-value. Placement lives in DYMO_starAndP: the glyphs are
    % positioned by their INK, so the star sits a fixed small distance above the
    % bracket and the p-value a fixed small distance above the star, whatever the
    % font size or the figure size. The star is greyed and left small when the
    % result is not significant.
    annTop = max(annTop, DYMO_starAndP(mean([x1 x2]), yBar, p, 30, 28));
end

% ---- make sure nothing is crowded ----
% Metrics whose bars nearly fill the axes - edge density and embedded edge
% density in particular - would leave the p value pressed against the group
% headings above it, so the top of the axes is set from the tallest annotation
% rather than from the bars, and every metric gets the same breathing space.
yl = ylim;
if isfinite(annTop) && annTop + 1.5*yOffset > yl(2)
    ylim([yl(1), annTop + 1.5*yOffset]);
end

% group headings (categories 1-2 symmetric, 3-4 asymmetric)
if numCategories == 4
    groupNames = {'Symmetric Interaction','Asymmetric Interaction'};
    yl = ylim;
    % the headings go above every annotation, not at a fixed distance from the
    % top of the axes, so they cannot land on top of a p value
    yGroup = max(annTop + 0.6*yOffset, yl(2) - 0.06*diff(yl));
    if yGroup + 0.08*diff(yl) > yl(2)
        ylim([yl(1), yGroup + 0.10*diff(yl)]);
        yl = ylim;
    end
    plot([0.7 2.3], [yGroup yGroup], 'k','LineWidth',4.5)
    text(1.5, yGroup+0.001*diff(yl), groupNames{1}, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontWeight','bold','FontSize',30)
    plot([2.7 4.3], [yGroup yGroup], 'k','LineWidth',4.5)
    text(3.5, yGroup+0.001*diff(yl), groupNames{2}, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontWeight','bold','FontSize',30)
end

% A little room at both ends, so the outermost bars, their tick labels and the
% group heading lines (which run to 4.3 for four categories) never sit against
% the edge of the axes. MATLAB's default here is [0.5 numCategories+0.5], i.e.
% exactly flush.
xlim([0.5 - 0.20, numCategories + 0.5 + 0.20]);
set(gca, 'XTick',1:numCategories, 'XTickLabel',catNames);
if ~isempty(xLabelText), xlabel(xLabelText,'FontWeight','bold'); end
if ~isempty(yLabelText), ylabel(yLabelText); end
title(titleText, 'FontWeight','bold', 'Interpreter','none');
grid on
box on
end
