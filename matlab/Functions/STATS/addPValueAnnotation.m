function addPValueAnnotation(m,se,pValue,x,yLimits)

% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

% Add significance bracket + stars + p-value


yOffset = 0.05 * diff(yLimits);

% Height of the bracket
yBar = max(m + se) + yOffset;

% Make room above the bars for the bracket, the star and the p-value. This is
% unconditional, so a caller cannot undo it. 2.2*yOffset is enough for the
% annotation without stretching the y-axis further than the data need.
ylim([yLimits(1), max(yLimits(2), yBar + 2.2*yOffset)]);

% ----- Significance bracket -----
tick = 0.25*yOffset;

plot([x(1) x(1)], [yBar-tick yBar], 'k', 'LineWidth',4.5);   % left tick
plot([x(1) x(2)], [yBar yBar], 'k', 'LineWidth',4.5);         % top line
plot([x(2) x(2)], [yBar-tick yBar], 'k', 'LineWidth',4.5);   % right tick

% ----- Significance star and p-value -----
% One rule for the whole pipeline: DYMO_sigColor decides the colour from the
% p-value, so a non-significant p-value is greyed to match its 'n.s.', and
% DYMO_starAndP does the placement, positioning both glyphs by their ink rather
% than by their text boxes.
annTop = DYMO_starAndP(mean(x), yBar, pValue, 32, 30);

% Make room if the annotation reaches past the top of the axes.
yl = ylim;
if annTop + 0.3*yOffset > yl(2)
    ylim([yl(1), annTop + 0.3*yOffset]);
end

end