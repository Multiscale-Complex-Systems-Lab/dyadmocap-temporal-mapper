function plotSkeletonAngleVectors(personData, titlePrefix, outputFolder, filePrefix, frameIdx, personNames)
%PLOTSKELETONANGLEVECTORS  Draw the angle vectors on the skeletons of one
%dyad (both people in the same figure): one figure per joint group
%(Shoulder, Wrist, Elbow, Knee, Ankle, Head), each saved with
%AutoSavePublishableFigure.
%
%   plotSkeletonAngleVectors(personData, titlePrefix, outputFolder, filePrefix)
%   plotSkeletonAngleVectors(..., frameIdx, personNames)
%
% Inputs
%   personData   : 1-by-P cell of numeric recordings, e.g. GTKallDataFiles(d,:)
%                  (empty cells are skipped)
%   titlePrefix  : e.g. 'GTK Dyad 3'
%   outputFolder : parent folder; each joint group is saved in its own
%                  subfolder (outputFolder/Shoulder, outputFolder/Wrist, ...)
%   filePrefix   : e.g. 'GTK_Dyad_3'  -> 'GTK_Dyad_3_Shoulder_Angles_Skeleton'
%   frameIdx     : (optional) frame to draw, default 1
%   personNames  : (optional) legend entries, default {'Person 1','Person 2'}
%
% The vectors come from skeletonAngleGeometry, the same definitions the angle
% time series are computed from, so figure and data always agree. Joints are
% drawn with ONE plot3 call per person, and plotting does not touch any data.
% Head figure: the vertical reference [0 0 1] is drawn with the same length as
% the head vector (a 1-unit arrow would be invisible next to marker
% coordinates). The degree sign is added to the labels and the figure is
% closed after saving.
%
% Colours: green arrow = v1, magenta arrow = v2 (as before).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 5 || isempty(frameIdx),    frameIdx = 1; end
if nargin < 6 || isempty(personNames), personNames = {'Person 1','Person 2'}; end
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end

% Person 1 blue, Person 2 red, as explicit RGB triplets (see DYMO_personColors)
colors = DYMO_personColors();
deg    = char(176);

groups = { ...
    'Shoulder', {'shoulder_left','shoulder_right'}; ...
    'Wrist',    {'wrist_left','wrist_right'}; ...
    'Elbow',    {'elbow_left','elbow_right'}; ...
    'Knee',     {'knee_left','knee_right'}; ...
    'Ankle',    {'ankle_left','ankle_right'}; ...
    'Head',     {'head_general'}};

% geometry once per person (only the requested frame)
Gs = cell(size(personData));
for s = 1:numel(personData)
    if ~isempty(personData{s}) && size(personData{s},1) >= frameIdx
        Gs{s} = skeletonAngleGeometry(personData{s}, frameIdx);
    end
end
present = find(~cellfun(@isempty, Gs));
if isempty(present)
    return
end

for gi = 1:size(groups,1)

    groupName  = groups{gi,1};
    angleNames = groups{gi,2};

    fig = figure('Visible','off', 'Color','w');
    ax  = axes(fig);
    hold(ax, 'on');

    hLeg = gobjects(0);
    legTxt = {};

    for s = present
        G   = Gs{s};
        col = colors(mod(s-1, size(colors,1)) + 1, :);   % row 1 = Person 1, row 2 = Person 2
        J   = squeeze(G.joints(1,:,:));            % J-by-3

        % all joints (joint 1 = seat) + yellow seat marker
        h = plot3(ax, J(:,1), J(:,2), J(:,3), 'o', 'MarkerSize', 6, ...
                  'MarkerFaceColor', col, 'MarkerEdgeColor', col, 'LineStyle', 'none');
        plot3(ax, G.seat(1,1), G.seat(1,2), G.seat(1,3), 'ko', ...
              'MarkerSize', 8, 'MarkerFaceColor', 'y');
        hLeg(end+1)   = h; %#ok<AGROW>
        legTxt{end+1} = personNames{min(s, numel(personNames))}; %#ok<AGROW>

        for a = 1:numel(angleNames)
            A   = G.(angleNames{a});
            o   = A.origin(1,:);
            v1  = A.v1(1,:);
            v2  = A.v2(1,:);
            ang = jointAngle(v1, v2);

            if strcmp(angleNames{a}, 'head_general')
                v2 = v2 / norm(v2) * norm(v1);      % visible reference arrow
            end

            hV1 = quiver3(ax, o(1), o(2), o(3), v1(1), v1(2), v1(3), 0, 'Color', 'g', 'LineWidth', 2);
            hV2 = quiver3(ax, o(1), o(2), o(3), v2(1), v2(2), v2(3), 0, 'Color', 'm', 'LineWidth', 2);

            L = A.label(1,:);
            text(ax, L(1), L(2), L(3), sprintf('%s Angle: %.2f%s', A.text, ang, deg), ...
                 'Color', col, 'FontSize', 8);
        end
    end

    xlabel(ax, 'X'); ylabel(ax, 'Y'); zlabel(ax, 'Z');
    title(ax, sprintf('%s: 3D Skeletons with %s Angles (frame %d)', titlePrefix, groupName, frameIdx));
    axis(ax, 'equal');
    view(ax, 97.17, 1.99);
    grid(ax, 'off');
    axis(ax, 'off');
    % the legend lists the people AND what the two arrows of each angle are
    % (green = first vector, magenta = second; the angle is between them)
    if exist('hV1','var')
        hLeg   = [hLeg, hV1, hV2];
        legTxt = [legTxt, {'angle vector 1 (green)', 'angle vector 2 (magenta)'}];
    end
    legend(ax, hLeg, legTxt, 'Location', 'best', 'AutoUpdate', 'off');

    % one subfolder per joint group, so each folder holds one kind of figure
    groupFolder = fullfile(outputFolder, groupName);
    AutoSavePublishableFigure(sprintf('%s_%s_Angles_Skeleton', filePrefix, groupName), fig, groupFolder);
    close(fig);
end
end
