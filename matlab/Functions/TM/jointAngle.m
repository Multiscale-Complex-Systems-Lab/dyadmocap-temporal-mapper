function ang = jointAngle(v1, v2)
%JOINTANGLE  Frame-wise angle (degrees) between two N-by-3 vector series.
%
%   ang = jointAngle(v1, v2)
%
% The formula is
%   acos( sum(v1.*v2,2) ./ (|v1| .* |v2|) ) * 180/pi,
% except that the cosine is clipped to [-1, 1] first. Without the clip,
% round-off can give a cosine of 1.0000000001 for (nearly) parallel
% vectors, and acos then returns a COMPLEX number that silently propagates
% into the velocities.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

c   = sum(v1 .* v2, 2) ./ (sqrt(sum(v1.^2, 2)) .* sqrt(sum(v2.^2, 2)));
c   = min(max(c, -1), 1);
ang = acos(c) * (180/pi);
end
