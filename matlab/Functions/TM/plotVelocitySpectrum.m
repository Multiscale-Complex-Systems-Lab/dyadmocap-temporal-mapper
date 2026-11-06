function fig = plotVelocitySpectrum(velocity, Fs, bandEdges, titleText)
%PLOTVELOCITYSPECTRUM  Spectrum of one dyad's angular velocity, one panel per person.
%
%   fig = plotVelocitySpectrum(velocity, Fs, bandEdges, titleText)
%
% Shows where the power of the angular velocity sits in frequency, which is how
% we tell movement from marker jitter: human joint movement is slow, so its
% power falls steeply with frequency, while jitter is roughly flat in position
% and therefore RISES towards the Nyquist frequency after differentiation. A
% curve that turns upward in the last few Hz is the jitter floor showing through.
%
% INPUTS
%   velocity  : N-by-(2*nAngles) angular velocity of the dyad, Person 1 in the
%               first half of the columns and Person 2 in the second.
%   Fs        : sampling rate (Hz). Nyquist is Fs/2.
%   bandEdges : band edges in Hz, e.g. [0 2 5 10]; drawn as dashed lines.
%   titleText : e.g. "GTK Dyad 3".
%
% The thick coloured line is a running mean over 101 frequency bins (Person 1
% blue, Person 2 red); the thin grey line behind it is the raw spectrum. The
% legend is made last and with AutoUpdate off, so the band lines cannot add
% themselves to it.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

personColors = DYMO_personColors();
nF           = size(velocity, 2) / 2;          % columns per person

fig = figure('Color', 'w', 'Position', [100 100 1400 600]);
tl  = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');

for p = 1:2
    if p == 1
        V = velocity(:, 1:nF);
    else
        V = velocity(:, nF+1:end);
    end

    [~, ~, f, meanPSD] = powerInBands(V, Fs, bandEdges);

    ax      = nexttile(tl);
    hRaw    = semilogy(ax, f, meanPSD, 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
    hold(ax, 'on');
    hSmooth = semilogy(ax, f, movmean(meanPSD, 101), 'Color', personColors(p,:), ...
        'LineWidth', 1.5);
    for b = 2:numel(bandEdges)
        xline(ax, bandEdges(b), 'k--', sprintf('%g Hz', bandEdges(b)));
    end
    hold(ax, 'off');

    xlim(ax, [0 Fs/2]);
    xlabel(ax, 'Frequency (Hz)');
    ylabel(ax, 'Power (mean over the angles)');
    title(ax, sprintf('Person %d', p));
    grid(ax, 'on');
    legend(ax, [hSmooth hRaw], {'running mean (101 bins)', 'raw spectrum'}, ...
        'Location', 'southwest', 'AutoUpdate', 'off');
end

title(tl, sprintf('%s: angular-velocity spectrum, unfiltered (Nyquist = %g Hz)', ...
    titleText, Fs/2), 'Interpreter', 'none');
end
