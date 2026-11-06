function [pct, bandLabels, f, meanPSD] = powerInBands(X, Fs, edges)
%POWERINBANDS  How the power of a signal is spread over frequency bands.
%
%   [pct, bandLabels, f, meanPSD] = powerInBands(X, Fs, edges)
%
% INPUTS
%   X     : N-by-C signals, one column per channel (e.g. the angular
%           velocity of all 11 joint angles of one person).
%   Fs    : sampling rate in Hz. The highest frequency that exists in the
%           data is the Nyquist frequency, Fs/2 (25 Hz when Fs = 50 Hz);
%           nothing above it can be measured, so all bands stop there.
%   edges : band edges in Hz, increasing, e.g. [0 2 5 10]. The last band
%           always runs from edges(end) up to Nyquist, so [0 2 5 10] gives
%           the four bands 0-2, 2-5, 5-10 and 10-25 Hz at Fs = 50.
%
% OUTPUTS
%   pct        : 1-by-B percentages of the total power in each band. They
%                sum to 100. Power is summed over all columns, so a joint
%                that moves a lot counts more, exactly as it does in the
%                analysis.
%   bandLabels : 1-by-B strings such as "2-5 Hz", for tables and legends.
%   f          : frequency axis (Hz) of the one-sided spectrum, for plotting.
%   meanPSD    : power at each frequency in f, averaged over the columns.
%
% HOW IT WORKS
%   Each column is linearly detrended (removes the mean and any slow drift,
%   which would otherwise dominate the lowest band), then the power spectrum
%   is taken with an FFT and the power in each band is divided by the total
%   power between 0 (excluded) and Nyquist. No toolbox is needed.
%
% HOW TO READ THE RESULT FOR ANGULAR VELOCITY
%   Human joint movement is slow: nearly all of its power sits below about
%   5 Hz, and there is very little above 10 Hz. Marker jitter, in contrast,
%   is roughly independent from frame to frame, and taking a derivative
%   amplifies it more and more towards Nyquist. So:
%     * power concentrated in 0-5 Hz          -> the signal is movement;
%     * a large share in 10-Nyquist, and a
%       spectrum that RISES towards Nyquist   -> the signal is dominated by
%                                                measurement jitter, and a
%                                                low-pass filter is justified.
%   This function only reports the numbers; the reading above is the
%   interpretation to check against the plotted spectrum.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3 || isempty(edges)
    edges = [0 2 5 10];
end

nyquist = Fs / 2;
edges   = edges(edges < nyquist);      % drop any edge at or above Nyquist
edges   = [edges(:)' nyquist];         % close the last band at Nyquist

% ---- power spectrum of every column ----
X = detrend(X);                        % remove mean and slow drift
N = size(X, 1);
P = abs(fft(X)).^2;                    % power at each FFT frequency
f = (0:N-1)' * Fs / N;                 % frequency of each FFT bin (Hz)

keep    = f > 0 & f <= nyquist;        % one-sided spectrum, 0 Hz excluded
f       = f(keep);
P       = P(keep, :);
meanPSD = mean(P, 2);                  % averaged over columns, for plotting

% ---- share of the total power in each band ----
total      = sum(P, 'all');
nBands     = numel(edges) - 1;
pct        = zeros(1, nBands);
bandLabels = strings(1, nBands);

for b = 1:nBands
    % lower edge excluded, upper edge included, so the bands do not overlap
    inBand    = f > edges(b) & f <= edges(b+1);
    pct(b)    = 100 * sum(P(inBand, :), 'all') / total;
    bandLabels(b) = sprintf('%g-%g Hz', edges(b), edges(b+1));
end
end
