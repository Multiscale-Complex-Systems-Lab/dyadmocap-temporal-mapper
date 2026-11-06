function G = skeletonAngleGeometry(dataArray, frames)
%SKELETONANGLEGEOMETRY  The ONE place where the 11 joint angles are defined.
%
%   G = skeletonAngleGeometry(dataArray)          % all frames
%   G = skeletonAngleGeometry(dataArray, frames)  % e.g. frames = 1
%
% Both the angle CALCULATION (computeJointAngles) and the angle-vector
% PLOTS on the skeleton (plotSkeletonAngleVectors) use this function, so
% the plotted vectors are guaranteed to be exactly the vectors the angle
% time series are computed from.
%
% Input
%   dataArray : N-by-(2+3*J) numeric array, one recording
%               [time, frame, x1 y1 z1, x2 y2 z2, ...]  (as in *allDataFiles)
%   frames    : (optional) which rows to use (default: all rows)
%
% Coordinate transform:  X = x,  Y = -z,  Z = y
%
% Output struct G
%   G.names          : 1-by-11 cell, angle names IN THE ORDER USED
%                      EVERYWHERE (this order defines the velocity columns)
%   G.(name).origin  : F-by-3 vertex of the angle
%   G.(name).v1      : F-by-3 first vector  (from the vertex)
%   G.(name).v2      : F-by-3 second vector (from the vertex)
%   G.(name).label   : F-by-3 point where the angle label is written
%   G.(name).text    : display name, e.g. 'Left shoulder'
%   G.joints         : F-by-J-by-3 transformed joint positions; joint 1 is
%                      replaced by the seat (midpoint of joints 2 and 3)
%   G.seat           : F-by-3 seat position
%
% Angle definitions (joint numbers of the 42-marker set)
%   shoulder : vertex = mean(15,16) [L] / mean(30,31) [R]
%              v1 -> chest (5),        v2 -> elbow 10 [L] / 25 [R]
%   wrist    : vertex = mean(22,23) [L] / mean(37,38) [R]
%              v1 -> elbow 10 / 25,    v2 -> hand 11 / 26
%   elbow    : vertex = elbow 10 / 25
%              v1 -> shoulder (mean),  v2 -> wrist (mean)
%   knee     : vertex = knee 13 / 28
%              v1 -> thigh 17 / 32,    v2 -> shin 14 / 29
%   ankle    : vertex = ankle 9 / 24
%              v1 -> shin 14 / 29,     v2 -> mean toes (18,19,20) / (33,34,35)
%   head     : vertex = midpoint of the two shoulders
%              v1 -> head (mean 6,7,8), v2 = global vertical [0 0 1]
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 2 || isempty(frames)
    frames = 1:size(dataArray,1);
end

num_joints = floor((size(dataArray,2) - 2) / 3);
cols = 3 + (0:num_joints-1) * 3;
D    = dataArray(frames, :);

JX =  D(:, cols);
JY = -D(:, cols + 2);
JZ =  D(:, cols + 1);
P  = @(j) [JX(:,j), JY(:,j), JZ(:,j)];      % F-by-3 position of joint j

% ---- landmarks ----
chest          = P(5);
left_shoulder  = (P(15) + P(16)) / 2;       % Back + Top
right_shoulder = (P(30) + P(31)) / 2;
left_elbow     = P(10);
right_elbow    = P(25);
left_wrist     = (P(22) + P(23)) / 2;       % In + Out
right_wrist    = (P(37) + P(38)) / 2;
left_hand      = P(11);
right_hand     = P(26);
left_toe       = (P(18) + P(19) + P(20)) / 3;
right_toe      = (P(33) + P(34) + P(35)) / 3;
head           = (P(6) + P(7) + P(8)) / 3;
shoulder_mid   = (left_shoulder + right_shoulder) / 2;

% ---- angles (ORDER MATTERS: it sets the velocity column order) ----
G.names = {'shoulder_left','shoulder_right','wrist_left','wrist_right', ...
           'elbow_left','elbow_right','knee_left','knee_right', ...
           'ankle_left','ankle_right','head_general'};

G.shoulder_left  = mk(left_shoulder,  chest,         left_elbow,     P(16), 'Left shoulder');
G.shoulder_right = mk(right_shoulder, chest,         right_elbow,    P(31), 'Right shoulder');
G.wrist_left     = mk(left_wrist,     left_elbow,    left_hand,      P(23), 'Left wrist');
G.wrist_right    = mk(right_wrist,    right_elbow,   right_hand,     P(38), 'Right wrist');
G.elbow_left     = mk(left_elbow,     left_shoulder, left_wrist,     P(10), 'Left elbow');
G.elbow_right    = mk(right_elbow,    right_shoulder,right_wrist,    P(25), 'Right elbow');
G.knee_left      = mk(P(13),          P(17),         P(14),          P(13), 'Left knee');
G.knee_right     = mk(P(28),          P(32),         P(29),          P(28), 'Right knee');
G.ankle_left     = mk(P(9),           P(14),         left_toe,       P(9),  'Left ankle');
G.ankle_right    = mk(P(24),          P(29),         right_toe,      P(24), 'Right ankle');

% head: second vector is the global vertical itself (not a point)
G.head_general.origin = shoulder_mid;
G.head_general.v1     = head - shoulder_mid;
G.head_general.v2     = repmat([0 0 1], size(head,1), 1);
G.head_general.label  = head;
G.head_general.text   = 'Head';

% ---- joints for plotting (joint 1 = seat) ----
seat = (P(2) + P(3)) / 2;
G.joints = cat(3, JX, JY, JZ);
G.joints(:,1,:) = reshape(seat, [], 1, 3);
G.seat = seat;
end

function s = mk(origin, pointA, pointB, labelPoint, txt)
s.origin = origin;
s.v1     = pointA - origin;
s.v2     = pointB - origin;
s.label  = labelPoint;
s.text   = txt;
end
