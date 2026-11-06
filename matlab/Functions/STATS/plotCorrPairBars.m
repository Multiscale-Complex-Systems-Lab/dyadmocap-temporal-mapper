function fig = plotCorrPairBars(rho, ciLo, ciHi, catNames, cmap, titleText, pairs, pRho)
%PLOTCORRPAIRBARS  Spearman rho per behavioural category as bars with BCa 95%
%CI whiskers, and a bracket with stars ONLY for the category pairs whose rho
%differ significantly.
%
%   fig = plotCorrPairBars(rho, ciLo, ciHi, catNames, cmap, titleText, pairs)
%
%   pairs : struct array from spearmanPairDelta (fields i, j, stars).
%           Pairs with stars = '' are not drawn.
%   pRho  : OPTIONAL p-value of each rho (rho different from 0). A star above
%           the bar when significant (* .05, ** .01, *** .001), a grey "n.s."
%           when not (n.s. as in the paired t-test figures). Left out,
%           nothing on the bars.
%
% So: a star ON a bar = that rho differs from 0; a star on a BRACKET = the two
% bars differ from each other.
%
% Brackets are stacked: the shortest spans sit lowest, and each bracket clears
% the whiskers and any bracket already drawn under it.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

rho = rho(:)';  ciLo = ciLo(:)';  ciHi = ciHi(:)';
nBars = numel(rho);
x = 1:nBars;

% made at the size SavePublicationFigure saves it, so text sizes in data units
% measured here are the ones in the saved figure
fig = figure('Units','inches', 'Position',[1 1 18 16], 'Color','w');   % 18 x 16 inches
hold on

b = bar(x, rho, 0.45);   % narrow bars
b.FaceColor = 'flat';
b.CData     = cmap(1:nBars,:);
b.EdgeColor = 'k';
b.LineWidth = 4.5;

% CI whiskers, plain black (inside the black Both Inactive bar the whisker is
% not visible, as in the paired bar figures).
errorbar(x, rho, rho - ciLo, ciHi - rho, 'k', 'LineStyle','none', ...
         'LineWidth',5.0, 'CapSize',12);
plot([0 nBars+1], [0 0], 'k-', 'LineWidth',2.5);

yBottom = min(-0.25, min(ciLo(isfinite(ciLo))) - 0.10);
if isempty(yBottom), yBottom = -0.25; end
xlim([0.5 - 0.20, nBars + 0.5 + 0.20]);

% ---- significant pairs, shortest span first ----
% Spacing in rho units, measured from the saved figures: a 48 pt star drawn
% with its text box bottom 0.03 below the bracket has its ink about 0.04 to
% 0.09 above the bracket.
GAP  = 0.06;    % bracket above a whisker or the star below it
TICK = 0.04;    % bracket legs
STAR = 0.11;    % room a star takes above its bracket
top  = max([ciHi; rho; zeros(1,nBars)], [], 1);   % highest ink over each bar
top(~isfinite(top)) = 0;

% ---- star on each bar: is this rho different from 0? ----
% Same levels as the brackets: * p < .05, ** p < .01, *** p < .001; no mark
% when not significant. Placed like the bracket stars: text box bottom 0.03
% below the whisker cap, so the star ink sits about 0.04 to 0.09 above it.
if nargin >= 8 && ~isempty(pRho)
    for k = 1:nBars
        if ~isfinite(pRho(k)), continue; end
        if pRho(k) >= 0.05
            % not significant: a small grey "n.s.", as in the paired t-test
            % figures
            text(x(k), top(k) + 0.015, 'n.s.', 'HorizontalAlignment','center', ...
                 'VerticalAlignment','bottom', 'FontSize',30, 'FontWeight','bold', ...
                 'Color',[0.6 0.6 0.6]);
            top(k) = top(k) + 0.10;
            continue
        end
        if pRho(k) < 0.001,    st = '***';
        elseif pRho(k) < 0.01, st = '**';
        else,                  st = '*';
        end
        text(x(k), top(k) - 0.03, st, 'HorizontalAlignment','center', ...
             'VerticalAlignment','bottom', 'FontSize',48, 'FontWeight','bold');
        top(k) = top(k) + STAR;
    end
end

if ~isempty(pairs)
    keep  = ~cellfun(@isempty, {pairs.stars});
    pairs = pairs(keep);
end
if ~isempty(pairs)
    span = abs([pairs.j] - [pairs.i]);
    [~, order] = sortrows([span(:) min([pairs.i; pairs.j],[],1)']);
    pairs = pairs(order);
end

for k = 1:numel(pairs)
    a = min(pairs(k).i, pairs(k).j);   c = max(pairs(k).i, pairs(k).j);
    yBr = max(top(a:c)) + GAP;
    plot([a a], [yBr-TICK yBr], 'k', 'LineWidth',4.5);
    plot([a c], [yBr yBr],      'k', 'LineWidth',4.5);
    plot([c c], [yBr-TICK yBr], 'k', 'LineWidth',4.5);
    text(mean([a c]), yBr - 0.03, pairs(k).stars, 'HorizontalAlignment','center', ...
         'VerticalAlignment','bottom', 'FontSize',48, 'FontWeight','bold');
    top(a:c) = yBr + STAR;
end

yTop = max(1.0, max(top) + 0.03);
ylim([yBottom, yTop]);
% y ticks left to MATLAB, as in the paired bar figures
set(gca, 'XTick',x, 'XTickLabel',catNames, 'TickLabelInterpreter','none');
xlabel('Behavioural Categories', 'FontWeight','bold');   % as in the paired bar figures
% SavePublicationFigure turns the TeX interpreter off for labels, so the Greek
% letter is written as the character itself, not as \rho
% y label in words: what the bar means for a reader - how consistent a dyad's
% interaction style is across the two conversations
ylabel({'Interaction style consistency', ['across contexts (Spearman ' char(961) ')']}, ...
       'FontWeight','bold');
% rho cannot exceed 1: the space above 1 is only room for the brackets, so
% no tick numbers are shown there
yt = get(gca, 'YTick');
set(gca, 'YTick', yt(yt <= 1 + 1e-9));
title(titleText, 'FontWeight','bold', 'Interpreter','none');
grid off   % no grid
box on
end
