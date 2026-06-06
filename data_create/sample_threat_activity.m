function active = sample_threat_activity(scenario, t, state)
%SAMPLE_THREAT_ACTIVITY 采样每个威胁在各时刻是否生效。
% 突发威胁按距离触发并锁存；距离耦合动态威胁在响应距离内触发并锁存。
    if nargin < 3
        state = [];
    end

    t = t(:);
    n = numel(t);
    active = false(n, scenario.numCircles);

    if ~isempty(state)
        if size(state, 1) == 1 && n > 1
            state = repmat(state, n, 1);
        end
        if size(state, 1) ~= n || size(state, 2) < 2
            error("state 必须为空或与 time 等长，且至少包含 [x y] 两列。");
        end
    end

    centers = [];
    for i = 1:scenario.numCircles
        threat = scenario.threats(i);
        if has_distance_trigger(threat)
            if isempty(state)
                active(:, i) = false;
                continue;
            end
            if isempty(centers)
                centers = sample_threat_centers(scenario, t, state);
            end
            cx = centers(:, i, 1);
            cy = centers(:, i, 2);
            horizontalDistance = sqrt((state(:, 1) - cx).^2 + (state(:, 2) - cy).^2);
            active(:, i) = locked_activity(horizontalDistance <= threat.triggerDistance);
        elseif is_distance_coupled_motion(threat) && ~isempty(state)
            horizontalDistance = sqrt((state(:, 1) - threat.center0(1)).^2 + ...
                                      (state(:, 2) - threat.center0(2)).^2);
            startTime = threat.activeStart;
            if isfield(threat, "moveStart")
                startTime = threat.moveStart;
            end
            % 动态威胁由“距离小于阈值”或“到达启动时间”任一条件触发，触发后状态锁存。
            triggered = horizontalDistance < threat.motionTriggerDistance | t > startTime;
            active(:, i) = locked_activity(triggered);
        else
            active(:, i) = t >= threat.activeStart & t <= threat.activeEnd;
        end
    end
end

function activeColumn = locked_activity(triggered)
    activeColumn = logical(cummax(double(triggered(:))));
end

function tf = has_distance_trigger(threat)
    tf = isfield(threat, "triggerDistance") && isfinite(threat.triggerDistance);
end

function tf = is_distance_coupled_motion(threat)
    tf = isfield(threat, "distanceCoupledMotion") && threat.distanceCoupledMotion && ...
        isfield(threat, "motionTriggerDistance") && isfinite(threat.motionTriggerDistance);
end
