function centers = sample_threat_centers(scenario, t, state)
%SAMPLE_THREAT_CENTERS 采样每个威胁在各时刻的二维中心位置。
% 输出尺寸为 [numel(t), scenario.numCircles, 2]。当传入无人机 state 时，
% 动态威胁按“距离远运动快、距离近运动慢”的响应规则更新中心位置。
    if nargin < 3
        state = [];
    end

    t = t(:);
    n = numel(t);
    if ~isempty(state)
        if size(state, 1) == 1 && n > 1
            state = repmat(state, n, 1);
        end
        if size(state, 1) ~= n || size(state, 2) < 2
            error("state 必须为空或与 time 等长，且至少包含 [x y] 两列。");
        end
    end

    centers = zeros(n, scenario.numCircles, 2);

    for i = 1:scenario.numCircles
        threat = scenario.threats(i);
        if threat.isMoving
            if is_distance_coupled(threat) && ~isempty(state)
                xy = distance_coupled_centers(threat, t, state);
            else
                xy = linear_moving_centers(threat, t);
            end
        else
            xy = repmat(threat.center0, n, 1);
        end

        centers(:, i, 1) = xy(:, 1);
        centers(:, i, 2) = xy(:, 2);
    end
end

function xy = linear_moving_centers(threat, t)
    denom = max(eps, threat.moveEnd - threat.moveStart);
    alpha = (t - threat.moveStart) ./ denom;
    alpha = min(max(alpha, 0), 1);
    xy = threat.center0 + alpha .* (threat.centerFinal - threat.center0);
end

function xy = distance_coupled_centers(threat, t, state)
    n = numel(t);
    xy = repmat(threat.center0, n, 1);
    triggered = false;
    triggerTime = nan;
    moveDirection = [cos(threat.heading), sin(threat.heading)];
    interceptPoint = threat.center0;
    maxTravel = 0;
    uavXY = state(:, 1:2);

    for k = 1:n
        distanceToUav = norm(uavXY(k, :) - threat.center0);
        distanceTriggered = distanceToUav < threat.motionTriggerDistance;
        timeTriggered = t(k) > threat.moveStart;
        if ~triggered && (distanceTriggered || timeTriggered)
            triggered = true;
            triggerTime = t(k);
            uavVelocity = uav_horizontal_velocity(state, t, k);
            interceptPoint = predict_intercept_point(threat.center0, uavXY(k, :), uavVelocity, threat.speed);
            moveDirection = unit_vector_local(interceptPoint - threat.center0);
            maxTravel = norm(interceptPoint - threat.center0);
        end

        if triggered
            elapsed = max(0, t(k) - triggerTime);
            travel = min(maxTravel, threat.speed * elapsed);
            xy(k, :) = threat.center0 + travel * moveDirection;
        else
            xy(k, :) = threat.center0;
        end
    end
end

function velocity = uav_horizontal_velocity(state, t, index)
    if size(state, 2) >= 6
        speed = state(index, 4);
        theta = state(index, 5);
        phi = state(index, 6);
        velocity = speed * cos(theta) * [cos(phi), sin(phi)];
        return;
    end

    if index > 1 && t(index) > t(index - 1)
        velocity = (state(index, 1:2) - state(index - 1, 1:2)) ./ (t(index) - t(index - 1));
    elseif index < numel(t) && t(index + 1) > t(index)
        velocity = (state(index + 1, 1:2) - state(index, 1:2)) ./ (t(index + 1) - t(index));
    else
        velocity = [0, 0];
    end
end

function point = predict_intercept_point(threatStart, uavPosition, uavVelocity, threatSpeed)
    relativePosition = uavPosition - threatStart;
    a = dot(uavVelocity, uavVelocity) - threatSpeed ^ 2;
    b = 2 * dot(relativePosition, uavVelocity);
    c = dot(relativePosition, relativePosition);

    times = [];
    if abs(a) < eps
        if abs(b) > eps
            times = -c / b;
        end
    else
        discriminant = b ^ 2 - 4 * a * c;
        if discriminant >= 0
            root = sqrt(discriminant);
            times = [(-b - root) / (2 * a), (-b + root) / (2 * a)];
        end
    end

    times = times(isfinite(times) & times >= 0);
    if ~isempty(times)
        point = uavPosition + min(times) * uavVelocity;
        return;
    end

    % 当固定速度无法精确相交时，沿无人机前进方向选择前置拦截点。
    fallbackTime = norm(relativePosition) / max(eps, threatSpeed);
    point = uavPosition + fallbackTime * uavVelocity;
end

function vector = unit_vector_local(vector)
    n = norm(vector);
    if n < eps
        vector = [1, 0];
    else
        vector = vector ./ n;
    end
end

function tf = is_distance_coupled(threat)
    tf = isfield(threat, "distanceCoupledMotion") && threat.distanceCoupledMotion && ...
        isfield(threat, "motionTriggerDistance") && isfinite(threat.motionTriggerDistance);
end
