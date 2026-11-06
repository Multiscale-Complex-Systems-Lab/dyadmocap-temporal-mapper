function  plotSpearmanComparison(x,y,rho,pValue,titleText,xLabelText,yLabelText,showLegend,pointColor)

% Plots one correlation: the dyads, the fitted line and its 95% CI band.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

arguments
    x (:,1) double
    y (:,1) double
    rho (1,1) double
    pValue (1,1) double
    titleText
    xLabelText
    yLabelText
    showLegend (1,1) logical = false
    pointColor (1,3) double = [0 0.4470 0.7410]
end
% function  plotSpearmanComparison(x,y,rho,pValue,pointColor,titleText,xLabelText,yLabelText,showLegend)

%% ---------------- Remove invalid pairs ----------------
validIdx = isfinite(x) & isfinite(y);

x = x(validIdx);
y = y(validIdx);


%% ---------------- Scatter plot ----------------
hold on

scatter(x,...
        y,...
        45,...
        pointColor,...
        'filled',...
        'MarkerFaceAlpha',0.7);

% scatterColor = [0.2 0.45 0.7];
% 
% scatter(x,...
%         y,...
%         45,...
%         scatterColor,...
%         'filled',...
%         'MarkerFaceAlpha',0.7);


%% ---------------- Regression line ----------------

% fitLine = polyfit(x,y,1);
% 
% xFit = linspace(min(x),max(x),100);
% 
% yFit = polyval(fitLine,xFit);
% 
% plot(xFit,...
%      yFit,...
%      'k-',...
%      'LineWidth',2);

%% ---------------- Regression line + 95% CI ----------------

% A variable that is constant across dyads gives a rank-deficient design
% matrix: the slope is undefined and the line and band would be meaningless.
% MATLAB only warns about it, so this decides explicitly.
canFit = std(x) > 0 && std(y) > 0;

if canFit
    mdl  = fitlm(x,y);
    xFit = linspace(min(x),max(x),100)';
    [yFit, yCI] = predict(mdl,xFit);
end


% Confidence interval band
% THE BAND AND THE LINE TAKE THE SERIES COLOUR
% One rule holds for every correlation figure in the pipeline: the points, the
% confidence band and the fitted line are the SAME colour, the one belonging to
% that series, so no colour appears that nothing in the data stands for. The
% alpha (0.20) and the line width (2.5) are those of the per-category panels, so
% the two families are identical in style and one key (plotCorrLegendFigure)
% describes both.
if canFit
    fill([xFit; flipud(xFit)],...
         [yCI(:,1); flipud(yCI(:,2))],...
         pointColor,...
         'FaceAlpha',0.20,...
         'EdgeColor','none');

    % Regression line, in the same colour as the points
    plot(xFit,...
         yFit,...
         '-',...
         'Color',pointColor,...
         'LineWidth',2.5);
else
    text(0.05, 0.05, 'no variation: no line fitted', 'Units','normalized', ...
        'FontSize',26, 'FontWeight','bold', 'Color',[0.4 0.4 0.4]);
end


%% ---------------- Correlation annotation ----------------
% 
% text(0.05,...
%      0.95,...
%      sprintf('\\rho = %.3f\np = %.3g',rho,pValue),...
%      'Units','normalized',...
%      'HorizontalAlignment','left',...
%      'VerticalAlignment','top',...
%      'FontSize',12,...
%      'FontWeight','bold');

text(0.05,...
     0.95,...
     sprintf('Spearman \\rho = %s\n%s', DYMO_numText(rho), DYMO_pText(pValue)),...
     'Units','normalized',...
     'HorizontalAlignment','left',...
     'VerticalAlignment','top',...
     'FontSize',30,...
     'FontWeight','bold',...
     'Color',DYMO_sigColor(pValue));%12 %20 %26 %28


%% ---------------- Formatting ----------------

xlabel(xLabelText);

ylabel(yLabelText);

title(titleText);

box on

grid on

%% ---------------- Axis Limits ----------------
% 
% % allData = [x; y];
% % 
% % pad = 0.05 * range(allData);
% % 
% % lims = [min(allData)-pad, max(allData)+pad];
% % 
% % xlim(lims)
% % ylim(lims)
% % axis square
% % 
% % plot(lims, lims, '--', 'Color', [0.6 0.6 0.6]);
% if isempty(axisLimits)
%     allData = [x; y];
%     pad = 0.05 * range(allData);
%     axisLimits = [min(allData)-pad, max(allData)+pad];
% end
% 
% xlim(axisLimits)
% ylim(axisLimits)
% axis square


%% ---------------- Optional legend ----------------

% No legend inside the figure: points, CI band and fitted line are the same in
% every panel, so the key is saved once as its own figure by plotLegendFigure.
% showLegend is still accepted as an input.

end