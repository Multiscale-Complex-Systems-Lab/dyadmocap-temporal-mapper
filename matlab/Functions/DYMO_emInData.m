function em = DYMO_emInData(ax, fontSizePt)
%DYMO_EMINDATA  One em of a given font size, expressed in y-axis data units.
%
%   em = DYMO_emInData(gca, 48)
%
% Font sizes are in points; bar heights, error bars and significance brackets
% are in data units. To place text a fixed distance above a glyph you need the
% conversion, and it depends on how tall the axes are on the page:
%
%   data units per point = (y-range) / (axes height in points)
%
% The axes height is read in points and put back, so the caller's own Units
% setting is untouched.
%
% Only valid for the y-range at the time of the call - re-call it if the caller
% changes ylim.
%
% Used by DYMO_starAndP.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 1 || isempty(ax), ax = gca; end

u = get(ax, 'Units');
set(ax, 'Units', 'points');
posPt = get(ax, 'Position');
set(ax, 'Units', u);

yl = ylim(ax);
em = fontSizePt * diff(yl) / posPt(4);
end
