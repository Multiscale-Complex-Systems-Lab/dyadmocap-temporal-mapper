function window = getCommonWindow(gtkTime, manTime, marginSec)

% Written by Patience Akatuhwera.

% getCommonWindow
% Computes the stable overlapping middle window for GTK and MAN.
% Inputs:
%   gtkTime  – total duration of GTK (seconds)
%   manTime – total duration of MAN (seconds)
%   marginSec – seconds trimmed from BOTH ends of the common time
%
% Output (struct):
%   window.DurationCommonOriginal
%   window.DurationStable
%   window.Gtk.Start
%   window.Gtk.End
%   window.Man.Start
%   window.Man.End

    % 1. Find the shorter duration (common)
    D_common = min(gtkTime, manTime);

    % 2. Remove margins at both ends
    D_stable = D_common - 2*marginSec;

    if D_stable <= 0
        error('Margin too large: no stable middle window remains.');
    end

    % ==== Compute middle window for GTK ====
    mid_GTK = gtkTime / 2;
    start_GTK = mid_GTK - D_stable/2;
    end_GTK   = mid_GTK + D_stable/2;

    % ==== Compute middle window for MAN ====
    mid_MAN = manTime / 2;
    start_MAN = mid_MAN - D_stable/2;
    end_MAN   = mid_MAN + D_stable/2;

    % Store results
    window.DurationCommonOriginal = D_common;
    window.DurationStable = D_stable;

    window.Gtk.Start = start_GTK;
     window.Gtk.End  =end_GTK;

    window.Man.Start = start_MAN;
    window.Man.End   = end_MAN;
end