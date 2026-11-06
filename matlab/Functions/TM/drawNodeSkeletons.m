function drawNodeSkeletons(ax, node, members, repIdx, skeletonData, timeVel, Cat, showSpread, addLegend)
%DRAWNODESKELETONS  Draw the skeletons of ONE temporal mapper node in one axes.
%
%   drawNodeSkeletons(ax, node, members, repIdx, skeletonData, timeVel, Cat)
%   drawNodeSkeletons(..., showSpread, addLegend)
%
% This is the panel used by both exploreTMNodes (the clickable figure) and
% plotTMCategoryNodePanels (the static figure), so the two look identical.
%
% WHAT IS DRAWN
%   * In the person colours: the two partners at the node's representative
%     moment (repIdx), with the seat marker in yellow.
%   * In light grey: up to showSpread other moments belonging to the same node,
%     so the variation of posture inside the node is visible.
%   The title gives the node number, how many moments it holds, how long that
%   is in seconds, its behavioural category, and when those moments occurred.
%
% Remember that a node groups moments of similar angular VELOCITY, so this is
% the posture during a movement state, not "the posture of the node".
%
% INPUTS
%   ax           : axes to draw into.
%   node         : node number (used in the title).
%   members      : the velocity sample indices of THIS node (a vector).
%   repIdx       : the representative velocity sample of this node.
%   skeletonData : 1-by-2 cell, one per partner, frames-by-joints-by-3.
%   timeVel      : time vector of the velocity samples (s).
%   Cat          : struct from categorizeVelocity.
%   showSpread   : (optional) how many other moments to draw in grey. Default 5.
%   addLegend    : (optional) put a legend under the panel. Default true.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 8 || isempty(showSpread), showSpread = 5;    end
if nargin < 9 || isempty(addLegend),  addLegend  = true; end

personColors = DYMO_personColors();
dt           = median(diff(timeVel));        % one sample in seconds

cla(ax);
hold(ax, 'on');

% handles are kept so the legend is labelled by handle, never by plot order
hOther  = gobjects(0);
hPerson = gobjects(1,2);
hSeat   = gobjects(1,1);

% ---- other moments of this node, in light grey ----
if showSpread > 0 && numel(members) > 1
    others = members(members ~= repIdx);
    if numel(others) > showSpread                        % evenly spaced subset
        others = others(round(linspace(1, numel(others), showSpread)));
    end
    for f = others(:)'
        for sub = 1:2
            P = skeletonData{sub};
            if f <= size(P,1)
                hOther(end+1) = plot3(ax, P(f,:,1), P(f,:,2), P(f,:,3), 'o', ...
                    'MarkerSize', 4, 'MarkerFaceColor', [0.8 0.8 0.8], ...
                    'MarkerEdgeColor', 'none'); %#ok<AGROW>
            end
        end
    end
end

% ---- the representative moment, in the person colours ----
for sub = 1:2
    P = skeletonData{sub};
    f = min(repIdx, size(P,1));              % velocity sample i -> frame i
    hPerson(sub) = plot3(ax, P(f,:,1), P(f,:,2), P(f,:,3), 'o', 'MarkerSize', 6, ...
        'MarkerFaceColor', personColors(sub,:), 'MarkerEdgeColor', personColors(sub,:));
    hSeat = plot3(ax, P(f,1,1), P(f,1,2), P(f,1,3), 'o', 'MarkerSize', 8, ...
        'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
end

hold(ax, 'off');
axis(ax, 'equal');  axis(ax, 'off');
view(ax, 97.17, 1.99);

if addLegend
    hLeg   = [hPerson hSeat];
    legTxt = {'Person 1 (typical moment)', 'Person 2 (typical moment)', 'Seat'};
    if ~isempty(hOther)
        hLeg   = [hLeg hOther(1)];
        legTxt = [legTxt, {'other moments in this node'}];
    end
    % AutoUpdate off: anything drawn later cannot add 'data1' entries
    legend(ax, hLeg, legTxt, 'Location', 'southoutside', ...
        'Orientation', 'horizontal', 'FontSize', 8, 'AutoUpdate', 'off');
end

catOfNode = mode(Cat.colorvar(members));     % most common category in the node
title(ax, {sprintf('Node %d: %d moments (%.1f s in total)', node, numel(members), ...
                   numel(members)*dt), ...
           sprintf('%s   |   first at %.1f s, last at %.1f s', ...
                   Cat.BehaviouralCategory{catOfNode}, ...
                   min(timeVel(members)), max(timeVel(members)))}, ...
      'Interpreter', 'none');
end
