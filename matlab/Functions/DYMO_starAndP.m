function annTop = DYMO_starAndP(xMid, yBar, pValue, starBase, pSize)
%DYMO_STARANDP  Significance star and p-value above a comparison bracket,
%positioned from the GLYPH INK rather than from the text line box.
%
%   annTop = DYMO_starAndP(xMid, yBar, pValue, starBase, pSize)
%
%   xMid     : x of the bracket's midpoint
%   yBar     : y of the bracket's top line - the star sits just above it
%   pValue   : the p-value; decides the star text, its colour and its size
%   starBase : font size for a non-significant star ('n.s.'); a significant
%              star is drawn 60 % larger
%   pSize    : font size for the "p = ..." text
%
%   annTop   : the y of the top of the p-value's ink, for the caller to set
%              the axes limit or place group headings above
%
% WHY THIS FUNCTION EXISTS
% The three paired-bar plotters each placed the star and the p-value at fixed
% multiples of yOffset. That cannot work: font size is in points, yOffset is in
% data units, so the height of a 48 pt star in data units depends on the
% rendered figure size. Measuring the star's Extent does not help either, because
% Extent is the whole text LINE BOX, not the ink in it:
%
%        +-----------------+  <- Extent top        (empty)
%        |        *        |  <- the asterisk ink sits high in the box
%        |                 |     (empty - a quarter of the box)
%        |                 |     (empty - half the box, below the ink)
%        +-----------------+  <- Extent bottom = the 'bottom' anchor
%
% Anchoring the box bottom at the bracket therefore leaves the star floating well
% above the bracket, and anchoring the p-value at the box top leaves a wide gap
% between the star and the p-value.
%
% HOW IT IS PLACED
% One em is converted from points to data units exactly, from the axes height
% in points and the current y-range - no assumption about line spacing. The
% glyphs are then placed by their ink, using standard font metrics as fractions
% of an em (cap height 0.72, x-height 0.52, descender 0.21, and the asterisk
% spanning about 0.46 to 0.72 - it reaches the cap line and stops a quarter of
% an em below it):
%
%   star ink bottom = yBar + GAP_BRACKET + (the STARBOT safety margin)
%   p-value ink bottom = star ink top + GAP_STARP (in ems of the p-value, so
%                        the star and the 'n.s.' are spaced alike)
%
% so the two gaps are the gaps you actually see, and they scale with the star.
%
% Note that em is taken from the y-range at the moment of drawing. If the caller
% widens the axes afterwards the text keeps its position in data units and the
% gaps grow slightly - which is the safe direction, never an overlap.
%
% Used by plotCategoryPairedBars, plotWholePairedBar and addPValueAnnotation.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 4 || isempty(starBase), starBase = 30; end
if nargin < 5 || isempty(pSize),    pSize    = 28; end

% ---- the two gaps; the only numbers to tune ----
GAP_BRACKET = 0.30;   % star ink above the bracket line: enough to keep the
                      % bracket line clear while keeping the star close to
                      % the p-value above it.
GAP_STARP   = 0.04;   % p-value ink above the star ink. Measured in ems of the
                      % P-VALUE, not of the star: in ems of the star, a 48 pt
                      % significant star would put the p-value 1.7 times
                      % further away than a 30 pt 'n.s.' does. The p-value
                      % font is the same in both cases, so this gives both the
                      % same gap.

% ---- font metrics, as fractions of one em ----
CAP     = 0.72;   % cap height - the top of digits in 'p = ...'
STARTOP = 0.68;   % top of the asterisk. Slightly below the cap line: assuming
                  % it reached the cap line added a gap above the significant
                  % star that the 'n.s.' case did not have.
XHEIGHT = 0.52;   % top of lower-case 'n' in 'n.s.'
DESCEND = 0.21;   % how far the tail of 'p' drops below the baseline
STARBOT = 0.20;   % bottom of the asterisk, above the baseline - DELIBERATELY
                  % LOW. The true value is font-dependent and is not readable
                  % from MATLAB: Extent gives the text box, not the ink. 0.46 em
                  % (measured from Helvetica) is too high for other fonts and
                  % places the star too low, below the bracket. Under-estimating
                  % it can only push the star UP, which is the safe error: the
                  % star clears the bracket by 0.20-0.36 em for any plausible
                  % font instead of risking a dip below it.

ax  = gca;
sig = getSignificanceText(pValue);
[col, isSig] = DYMO_sigColor(pValue);

starSize = starBase * (1 + 0.6*isSig);   % a significant star is 60 % larger

emStar = DYMO_emInData(ax, starSize);
emP    = DYMO_emInData(ax, pSize);

% ---- the star, anchored by its baseline so the ink can be placed exactly ----
% '*' ink runs from STARBOT to STARTOP above the baseline; 'n.s.' from the baseline
% (the full stops) to XHEIGHT. So the ink bottom and top differ by case.
if isSig
    inkBot = STARBOT * emStar;
    inkTop = STARTOP * emStar;
else
    inkBot = 0;
    inkTop = XHEIGHT * emStar;
end

starBaseline = yBar + GAP_BRACKET*emStar - inkBot;   % may sit below yBar: the
                                                     % ink is what must clear it
hStar = text(xMid, starBaseline, sig, ...
    'HorizontalAlignment','center', 'VerticalAlignment','baseline', ...
    'FontSize',starSize, 'FontWeight','bold', 'Color',col);

starInkTop = starBaseline + inkTop;

% ---- the p-value, its lowest ink (the tail of 'p') clearing the star ----
% PGAP halves the computed gap. The em above is measured from
% the axes as it is WHEN THE TEXT IS DRAWN, but SavePublicationFigure resizes
% the figure to figSizeInches before saving. The axes then covers more points
% while the font size stays fixed, so a real em is smaller than the one measured
% here and every gap computed from it comes out wider in the saved figure than
% intended. PGAP is the empirical correction; raise it towards 1 if a p-value
% ever sits too close to its star.
PGAP = 0.5;
pBaseline = starInkTop + PGAP*(GAP_STARP + DESCEND)*emP;

text(xMid, pBaseline, DYMO_pText(pValue), ...
    'HorizontalAlignment','center', 'VerticalAlignment','baseline', ...
    'FontSize',pSize, 'FontWeight','bold', 'Color',col);

% digits reach the cap line, so this is the top of the annotation's ink
annTop = pBaseline + CAP*emP;   % digits reach the cap line

% keep the handle from cluttering the caller's workspace checks
clear hStar
end
