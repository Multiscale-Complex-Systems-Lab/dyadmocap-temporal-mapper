function pct = powerAbovePct(X, Fs, fc)
%POWERABOVEPCT  Percentage of signal power above fc (Hz), up to Nyquist.
%
%   pct = powerAbovePct(X, Fs, fc)
%
% X  : N-by-C signals (e.g. all marker coordinates of one recording)
% Fs : sampling rate (Hz), fc : frequency threshold (Hz)
%
% Each column is linearly detrended, the power spectrum is taken with an FFT,
% and the power between fc and Fs/2 is divided by the power between 0 (excl.)
% and Fs/2, summed over all columns. Used in the TM scripts only as a
% reported DIAGNOSTIC of high-frequency content (e.g. marker jitter) in the
% raw coordinates; low-pass filtered data would give close to 0 %.
% No toolbox is needed.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

X = detrend(X);
N = size(X,1);
P = abs(fft(X)).^2;
f = (0:N-1)' * Fs / N;
band = f > 0 & f <= Fs/2;
hi   = f > fc & f <= Fs/2;
pct  = 100 * sum(P(hi,:), 'all') / sum(P(band,:), 'all');
end
