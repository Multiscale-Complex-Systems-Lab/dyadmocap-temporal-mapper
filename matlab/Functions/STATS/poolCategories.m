function [x, y] = poolCategories(XGTK, XMAN, idx)
%POOLCATEGORIES  Stack the paired (GTK, MAN) values of the given category
%columns, keeping finite pairs only (Symmetric = [1 2], Asymmetric = [3 4]).
%   [x, y] = poolCategories(Stats.GTK.(metric), Stats.MAN.(metric), [1 2])
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
x = []; y = [];
for c = idx
    xc = XGTK(:,c);
    yc = XMAN(:,c);
    v  = isfinite(xc) & isfinite(yc);
    x  = [x; xc(v)]; %#ok<AGROW>
    y  = [y; yc(v)]; %#ok<AGROW>
end
end
