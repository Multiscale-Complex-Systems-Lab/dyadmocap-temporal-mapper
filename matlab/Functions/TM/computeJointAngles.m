function angles = computeJointAngles(dataArray)
%COMPUTEJOINTANGLES  All 11 joint-angle time series (degrees) of one recording.
%
%   angles = computeJointAngles(dataArray)
%
% dataArray : N-by-(2+3*J) numeric array [time, frame, x1 y1 z1, ...]
% angles    : struct with fields (in this order)
%             shoulder_left, shoulder_right, wrist_left, wrist_right,
%             elbow_left, elbow_right, knee_left, knee_right,
%             ankle_left, ankle_right, head_general      (each N-by-1)
%
% The vectors come from skeletonAngleGeometry (the single definition of
% every angle) and the angle from jointAngle:
%   acos( v1.v2 / (|v1||v2|) ) * 180/pi, with the cosine clipped to [-1,1].
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

G = skeletonAngleGeometry(dataArray);

angles = struct();
for k = 1:numel(G.names)
    a = G.(G.names{k});
    angles.(G.names{k}) = jointAngle(a.v1, a.v2);
end
end
