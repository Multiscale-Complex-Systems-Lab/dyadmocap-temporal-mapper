function fig = plotCorrWholeBar(rho, ciLo, ciHi, pRho, titleText, yLimits)
%PLOTCORRWHOLEBAR  The whole-graph partner of a plotCorrPairBars figure: one
%bar, the whole-graph Spearman rho between Casual Chat and Conflict, with its
%BCa 95% CI and a star (or grey n.s.) for rho different from 0.
%
%   fig = plotCorrWholeBar(rho, ciLo, ciHi, pRho, titleText, yLimits)
%
%   yLimits : the y-limits of the matching by-state figure, so the two can be
%             placed side by side on the same scale.
%
% Same drawing rules as plotCorrPairBars: purple bar (the colour for figures
% without states, DYMO_conditionColorsPurple row 1), plain black whisker, star
% sizes and spacing in rho units, the same y label, no tick numbers above 1.
% There are no brackets: the whole graph has no states to compare.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

purple = DYMO_conditionColorsPurple();

fig = figure('Units','inches', 'Position',[1 1 8 16], 'Color','w');   % narrow: one bar
hold on

bar(1, rho, 0.35, 'FaceColor',purple(1,:), 'EdgeColor','k', 'LineWidth',4.5);
errorbar(1, rho, rho - ciLo, ciHi - rho, 'k', 'LineStyle','none', ...
         'LineWidth',5.0, 'CapSize',12);
plot([0 2], [0 0], 'k-', 'LineWidth',2.5);

% star or n.s. above the whisker, placed as in plotCorrPairBars
top = max([ciHi rho 0]);
if isfinite(pRho) && isfinite(rho)
    if pRho < 0.05
        if pRho < 0.001,    st = '***';
        elseif pRho < 0.01, st = '**';
        else,               st = '*';
        end
        text(1, top - 0.03, st, 'HorizontalAlignment','center', ...
             'VerticalAlignment','bottom', 'FontSize',48, 'FontWeight','bold');
    else
        text(1, top + 0.015, 'n.s.', 'HorizontalAlignment','center', ...
             'VerticalAlignment','bottom', 'FontSize',30, 'FontWeight','bold', ...
             'Color',[0.6 0.6 0.6]);
    end
end

xlim([0.5 1.5]);
ylim(yLimits);
set(gca, 'XTick',1, 'XTickLabel',{'Whole graph'}, 'TickLabelInterpreter','none');
ylabel({'Interaction style consistency', ['across contexts (Spearman ' char(961) ')']}, ...
       'FontWeight','bold');
yt = get(gca, 'YTick');
set(gca, 'YTick', yt(yt <= 1 + 1e-9));
title(titleText, 'FontWeight','bold', 'Interpreter','none');
grid off   % no grid
box on
end
