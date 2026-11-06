function fig = plotWholePairedBar(xC, xS, p, titleText, yLabelText, condColors)
%PLOTWHOLEPAIREDBAR  Two-bar (Casual Chat vs Conflict) plot with SEM, mean
%lines and a significance bracket -- the whole-graph figure style from
%GTK_MAN_WholeStats_Pairedttest, moved into a function so the cycle
%scripts can use the same figure.
%
%   fig = plotWholePairedBar(xC, xS, p, titleText)
%   fig = plotWholePairedBar(xC, xS, p, titleText, yLabelText)
%   fig = plotWholePairedBar(..., condColors)   % 2-by-3, rows GTK and MAN
%
% xC, xS : paired dyad values (GTK, MAN); non-finite pairs are dropped.
% p      : p-value to annotate (NaN -> 'n.s.').
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 5, yLabelText = ''; end
% condColors: the two condition colours; purple (DYMO_conditionColorsPurple)
% for figures without states. Left out, the colours are DYMO_conditionColors.
if nargin < 6 || isempty(condColors), condColors = DYMO_conditionColors(); end

valid = isfinite(xC) & isfinite(xS);
xC = xC(valid);
xS = xS(valid);

meanGTK = mean(xC);  semGTK = std(xC)/sqrt(numel(xC));
meanMAN = mean(xS);  semMAN = std(xS)/sqrt(numel(xS));

fig = figure('Position',[200 200 900 500]);
hold on

% the two condition colours come from one place, so the figures and the
% standalone legend figure cannot drift apart
blue   = condColors(1,:);   % Casual Chat
orange = condColors(2,:);   % Conflict

x = [0.975 1.025];
barWidth = 0.03;

% Line weights and font sizes match plotPairedComparison (the NodeDistance
% figures): bar edge 4.5, error bars 5.0 with CapSize 20, bracket 4.5,
% annotation text 30 pt.
hBarGTK = bar(x(1), meanGTK, barWidth, 'FaceColor',blue,   'EdgeColor','k','LineWidth',4.5);
hBarMAN = bar(x(2), meanMAN, barWidth, 'FaceColor',orange, 'EdgeColor','k','LineWidth',4.5);

xlim([0.8 1.2])
yl = ylim;
ylim([yl(1), yl(2)*1.15])

% horizontal red mean lines: exactly as wide as the bar, not wider.
% lineLength is the HALF length, so barWidth/2 makes the red line span the bar.
lineLength = barWidth/2;
plot([x(1)-lineLength x(1)+lineLength], [meanGTK meanGTK], 'r-','LineWidth',4.5);
plot([x(2)-lineLength x(2)+lineLength], [meanMAN meanMAN], 'r-','LineWidth',4.5);

% error bars
errorbar(x(1), meanGTK, semGTK, 'k','LineStyle','none','LineWidth',5.0,'CapSize',20);
errorbar(x(2), meanMAN, semMAN, 'k','LineStyle','none','LineWidth',5.0,'CapSize',20);

% significance bracket
yl      = ylim;
yOffset = 0.07 * diff(yl);
yTop    = max(meanGTK + semGTK, meanMAN + semMAN);
yBar    = yTop + yOffset;
if yBar + 3.2*yOffset > yl(2)
    ylim([yl(1), yBar + 3.5*yOffset]);
    yl      = ylim;
    yOffset = 0.07 * diff(yl);
    yBar    = yTop + yOffset;
end
tick = 0.25 * yOffset;

plot([x(1) x(1)], [yBar-tick yBar], 'k', 'LineWidth', 4.5);
plot([x(1) x(2)], [yBar yBar],      'k', 'LineWidth', 4.5);
plot([x(2) x(2)], [yBar-tick yBar], 'k', 'LineWidth', 4.5);

% Star and p-value, positioned by their ink - see DYMO_starAndP.
% One call keeps this figure, the behavioural-category figures and
% addPValueAnnotation using identical spacing rules.
annTop = DYMO_starAndP(mean(x), yBar, p, 32, 30);

% make room if the annotation now reaches past the top of the axes
yl = ylim;
if annTop + 0.3*yOffset > yl(2)
    ylim([yl(1), annTop + 0.3*yOffset]);
end

set(gca,'XTick',[])
if ~isempty(yLabelText), ylabel(yLabelText); end
title(titleText, 'Interpreter','none')   % not sprintf: a '%' in the title would break it
grid on
box on

% No legend inside the figure: the key to the two conditions is saved once as
% its own figure, by plotLegendFigure.
end
