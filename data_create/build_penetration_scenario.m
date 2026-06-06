function scenario = build_penetration_scenario(scenarioType, varargin)
%BUILD_PENETRATION_SCENARIO 构造无人机突防数据集场景。
% 默认按预置随机规则生成防空单元和特殊威胁；如需复现论文参考场景，可将
% baseThreatMode / suddenThreatMode / dynamicThreatMode 设置为 "reference"。
    parser = inputParser;
    parser.addRequired("scenarioType", @(x)ischar(x) || isstring(x));
    parser.addParameter("seed", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("numCircles", [], @(x)isempty(x) || (isscalar(x) && x >= 3));
    parser.addParameter("numRadars", [], @(x)isempty(x) || (isscalar(x) && x >= 1));
    parser.addParameter("targetSpeed", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("targetHeading", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("targetSpeedRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("targetHeadingRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("threatSpeedRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("threatHeadingRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("suddenActiveStartRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("suddenThreatSpeedRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("suddenThreatHeadingRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("suddenMoveDurationRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("suddenTriggerDistanceRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("dynamicMoveStartRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("dynamicMoveDurationRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("dynamicThreatSpeedRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("dynamicThreatHeadingRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("dynamicResponseDistanceRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("dynamicLatestTriggerTimeRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("terminalTime", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("startClearanceRadius", 2500, @(x)isnumeric(x) && isscalar(x) && x >= 0);
    parser.addParameter("baseThreatMode", "random", @(x)ischar(x) || isstring(x));
    parser.addParameter("suddenThreatMode", "random", @(x)ischar(x) || isstring(x));
    parser.addParameter("dynamicThreatMode", "random", @(x)ischar(x) || isstring(x));
    parser.addParameter("numSuddenThreats", [], @is_valid_threat_count_option);
    parser.addParameter("numDynamicThreats", [], @is_valid_threat_count_option);
    parser.addParameter("suddenThreatClassMode", "random", @(x)ischar(x) || isstring(x));
    parser.addParameter("dynamicThreatClassMode", "random", @(x)ischar(x) || isstring(x));
    parser.addParameter("suddenThreatClass", [], @(x)isempty(x) || isnumeric(x) || islogical(x));
    parser.addParameter("dynamicThreatClass", [], @(x)isempty(x) || isnumeric(x) || islogical(x));
    parser.addParameter("radarIntrusionWeight", 12, @(x)isnumeric(x) && isscalar(x) && x >= 0);
    parser.addParameter("weaponProximityWeight", 4, @(x)isnumeric(x) && isscalar(x) && x >= 0);
    parser.addParameter("weaponProximityBuffer", 0.35, @(x)isnumeric(x) && isscalar(x) && x >= 0);
    parser.parse(scenarioType, varargin{:});
    opt = parser.Results;

    if ~isempty(opt.seed)
        rng(opt.seed);
    end

    scenarioType = lower(string(scenarioType));
    km = 1000;
    scenario = base_scenario_struct(scenarioType, km, opt);

    switch scenarioType
        case "static"
            scenario.description = "随机静态突防场景";
            scenario.target = random_static_target(km);
            scenario.threats = random_static_threats(opt.numCircles, opt.numRadars, ...
                scenario.rectX, scenario.rectY, scenario.start, scenario.startClearanceRadius, scenario.target);

        case "time_sensitive"
            scenario.description = "时敏目标场景：目标随机速度和随机方向运动";
            scenario.threats = build_base_threats(opt, scenario, []);
            scenario.target = safe_moving_target(opt, scenario.threats, scenario.rectX, scenario.rectY, km);

        case "sudden"
            scenario.description = "突发威胁场景：特殊威胁按距离触发，触发后不消失";
            scenario.target = pdf_reference_target(km);
            scenario.threats = build_base_threats(opt, scenario, scenario.target);
            suddenThreats = build_sudden_threats(opt, scenario, scenario.threats, scenario.target);
            scenario.threats = [scenario.threats; suddenThreats];

        case "dynamic"
            scenario.description = "动态威胁场景：移动威胁按预置拦截规则随机生成";
            scenario.target = pdf_reference_target(km);
            scenario.threats = build_base_threats(opt, scenario, scenario.target);
            dynamicThreats = build_dynamic_threats(opt, scenario, scenario.threats, scenario.target, false);
            scenario.threats = [scenario.threats; dynamicThreats];

        case "fusion"
            scenario.description = "融合场景：目标运动、突发威胁和动态威胁随机组合";
            [scenario.target, scenario.threats, scenario.fusionFeatures] = ...
                fusion_reference_scene(opt, scenario, km);

        otherwise
            error("未知场景类型: %s", scenarioType);
    end

    scenario = enforce_start_clearance(scenario);
    scenario = refresh_circle_fields(scenario);
end

function scenario = base_scenario_struct(scenarioType, km, opt)
    scenario = struct();
    scenario.type = scenarioType;
    scenario.rectX = [0, 30000];
    scenario.rectY = [0, 30000];
    scenario.start = struct( ...
        "x", 0, "y", 0, "z", 0.5 * km, ...
        "v", 0.6 * 340, "theta", 0, "phi", 0);
    scenario.bounds = default_uav_bounds();
    scenario.terminalTime = opt.terminalTime;
    scenario.attackRadius = 50;
    scenario.startClearanceRadius = opt.startClearanceRadius;
    scenario.radarIntrusionWeight = opt.radarIntrusionWeight;
    scenario.weaponProximityWeight = opt.weaponProximityWeight;
    scenario.weaponProximityBuffer = opt.weaponProximityBuffer;
    scenario.specialThreatClassDefaults = struct( ...
        "sudden", string(opt.suddenThreatClassMode), ...
        "dynamic", string(opt.dynamicThreatClassMode));
end

function bounds = default_uav_bounds()
%DEFAULT_UAV_BOUNDS 无人机状态和控制量边界。
    bounds.x = [0, 30000];
    bounds.y = [0, 30000];
    bounds.z = [100, 5000];
    bounds.v = [50, 0.9 * 340];
    bounds.theta = [-20, 20] * pi / 180;
    bounds.phi = [-180, 180] * pi / 180;
    bounds.nx = [-2, 2];
    bounds.nz = [-4, 4];
    bounds.gama = [-90, 90] * pi / 180;
    bounds.finalTheta = 0;
    bounds.finalPhi = 40 * pi / 180;
end

function target = random_static_target(km)
%RANDOM_STATIC_TARGET 静态目标保持在右上目标区。
    target = struct();
    target.x0 = (26 + rand * 3) * km;
    target.y0 = (26 + rand * 3) * km;
    target.z0 = (0.5 + rand * 1) * km;
    target.speed = 0;
    target.heading = rand * 2 * pi - pi;
end

function target = pdf_reference_target(km)
%PDF_REFERENCE_TARGET 参考目标点。
    target = struct();
    target.x0 = 25 * km;
    target.y0 = 25 * km;
    target.z0 = 0.5 * km;
    target.speed = 0;
    target.heading = 0;
end

function target = safe_moving_target(opt, threats, rectX, rectY, km)
%SAFE_MOVING_TARGET 为时敏目标采样随机速度/方向，并避免目标终点落入武器覆盖区。
    target = pdf_reference_target(km);
    speedRange = first_nonempty(opt.targetSpeedRange, [12, 22]);
    headingRange = first_nonempty(opt.targetHeadingRange, [-pi, pi]);
    safetyTimes = target_safety_times(opt.terminalTime);
    fixedSpeed = ~isempty(opt.targetSpeed);
    fixedHeading = ~isempty(opt.targetHeading);

    for attempt = 1:800
        target.speed = choose_random_scalar(opt.targetSpeed, speedRange, 15);
        target.heading = wrap_to_pi_local(choose_random_scalar(opt.targetHeading, headingRange, 0));
        if target_motion_is_safe(target, threats, rectX, rectY, safetyTimes)
            return;
        end
        if fixedSpeed && fixedHeading
            break;
        end
    end

    error("build_penetration_scenario:UnsafeMovingTarget", ...
        "时敏目标运动参数会使目标终点落入防空武器覆盖区或离开场景，请调整速度/方向范围。");
end

function times = target_safety_times(terminalTime)
    if ~isempty(terminalTime)
        times = terminalTime(:);
    else
        % 未固定攻击时间时，按典型突防到达窗口做先验筛选。
        times = linspace(80, 220, 8).';
    end
end

function ok = target_motion_is_safe(target, threats, rectX, rectY, times)
    x = target.x0 + target.speed * cos(target.heading) .* times;
    y = target.y0 + target.speed * sin(target.heading) .* times;
    z = target.z0 * ones(size(times));

    ok = all(x >= rectX(1) & x <= rectX(2) & y >= rectY(1) & y <= rectY(2));
    if ~ok
        return;
    end

    for i = 1:numel(threats)
        if threats(i).class ~= 1
            continue;
        end
        margin = sphere_margin(x, y, z, threats(i).center0, threats(i).radius);
        if any(margin <= 0.02)
            ok = false;
            return;
        end
    end
end

function threats = build_base_threats(opt, scenario, target)
%BUILD_BASE_THREATS 基础防空单元默认随机，支持 reference 模式复现固定布局。
    if lower(string(opt.baseThreatMode)) == "reference"
        threats = pdf_reference_base_threats();
        return;
    end
    threats = random_static_threats(opt.numCircles, opt.numRadars, ...
        scenario.rectX, scenario.rectY, scenario.start, scenario.startClearanceRadius, target);
end

function threats = pdf_reference_base_threats()
    threats = [
        make_threat("radar_1", 0, [15000, 5000], 5000)
        make_threat("radar_2", 0, [15000, 20000], 5000)
        make_threat("fixed_weapon", 1, [8500, 2000], 4500)
    ];
end

function threats = build_sudden_threats(opt, scenario, existingThreats, target)
    if lower(string(opt.suddenThreatMode)) == "reference"
        threats = reference_sudden_threats(opt);
        return;
    end
    threats = random_sudden_threats(opt, scenario, existingThreats, target);
end

function threats = reference_sudden_threats(opt)
    baseCenters = [17500, 12500; 24000, 16000];
    radii = [4000; 3000];
    defaultStarts = [90; 150];
    classes = special_class_sequence(opt.suddenThreatClass, opt.suddenThreatClassMode, 2);
    threats = repmat(make_threat("placeholder", 1, [0, 0], 1), 2, 1);
    for i = 1:2
        triggerDistance = choose_indexed_random_scalar(opt.suddenTriggerDistanceRange, i, 6500);
        activeStart = choose_indexed_random_scalar(opt.suddenActiveStartRange, i, defaultStarts(i));
        classId = classes(i);
        threats(i) = make_threat("sudden_" + special_class_name(classId) + "_" + i, ...
            classId, baseCenters(i, :), radii(i), ...
            "activeStart", activeStart, "triggerDistance", triggerDistance);
    end
end

function threats = random_sudden_threats(opt, scenario, existingThreats, target)
%RANDOM_SUDDEN_THREATS 在起点到目标的通道附近随机布设突发威胁。
    numThreats = choose_threat_count(opt.numSuddenThreats, [1, 2]);

    classes = special_class_sequence(opt.suddenThreatClass, opt.suddenThreatClassMode, numThreats);
    threats = repmat(make_threat("placeholder", 1, [0, 0], 1), numThreats, 1);
    allThreats = existingThreats(:);
    startXY = [scenario.start.x, scenario.start.y];
    targetXY = [target.x0, target.y0];

    for i = 1:numThreats
        accepted = false;
        for attempt = 1:1000
            radius = 2500 + rand * 2000;
            center = sample_corridor_point(startXY, targetXY, [0.38, 0.82], [2800, 6500], scenario.rectX, scenario.rectY);
            triggerDistance = choose_indexed_random_scalar(opt.suddenTriggerDistanceRange, i, radius + 1800 + 1400 * rand);
            if special_threat_is_reasonable(center, radius, allThreats, scenario, targetXY)
                activeStart = choose_indexed_random_scalar(opt.suddenActiveStartRange, i, 0);
                classId = classes(i);
                threats(i) = make_threat("sudden_" + special_class_name(classId) + "_" + i, ...
                    classId, center, radius, ...
                    "activeStart", activeStart, "triggerDistance", triggerDistance);
                allThreats = [allThreats; threats(i)]; %#ok<AGROW>
                accepted = true;
                break;
            end
        end
        if ~accepted
            error("build_penetration_scenario:SuddenThreatSamplingFailed", ...
                "突发威胁随机生成失败，请放宽约束或减少威胁数量。");
        end
    end
end

function threats = build_dynamic_threats(opt, scenario, existingThreats, target, fusionMode)
    if lower(string(opt.dynamicThreatMode)) == "reference" && ~fusionMode
        threats = reference_dynamic_threats(opt);
        return;
    end
    threats = random_dynamic_threats(opt, scenario, existingThreats, target, fusionMode);
end

function threats = reference_dynamic_threats(opt)
    movingStart = [23000, 18000];
    pdfMovingEnd = [15500, 15500];
    defaultMoveStart = 45;
    defaultMoveDuration = 85;
    defaultHeading = atan2(pdfMovingEnd(2) - movingStart(2), pdfMovingEnd(1) - movingStart(1));
    defaultSpeed = norm(pdfMovingEnd - movingStart) / defaultMoveDuration;
    moveStart = choose_random_scalar([], opt.dynamicMoveStartRange, defaultMoveStart);
    moveDuration = choose_random_scalar([], opt.dynamicMoveDurationRange, defaultMoveDuration);
    speedBounds = choose_speed_bounds(first_nonempty(opt.dynamicThreatSpeedRange, opt.threatSpeedRange), ...
        [220, 300]);
    speed = choose_random_scalar([], speedBounds, defaultSpeed);
    heading = defaultHeading;
    centerFinal = clipped_displacement(movingStart, speed, heading, moveDuration, [0, 30000], [0, 30000]);
    if isempty(opt.dynamicThreatSpeedRange) && isempty(opt.threatSpeedRange)
        centerFinal = pdfMovingEnd;
    end
    responseDistance = choose_random_scalar([], opt.dynamicResponseDistanceRange, 10000);
    latestTriggerTime = choose_random_scalar([], opt.dynamicLatestTriggerTimeRange, moveStart + 35);
    classId = special_class_sequence(opt.dynamicThreatClass, opt.dynamicThreatClassMode, 1);
    classId = classId(1);
    threats = make_threat("moving_" + special_class_name(classId) + "_vehicle", ...
        classId, movingStart, 3000, ...
        "activeStart", moveStart, "isMoving", true, "moveStart", moveStart, ...
        "moveEnd", moveStart + moveDuration, "centerFinal", centerFinal, ...
        "speed", speed, "heading", heading, ...
        "distanceCoupledMotion", true, ...
        "motionTriggerDistance", responseDistance, ...
        "latestTriggerTime", latestTriggerTime);
end

function threats = random_dynamic_threats(opt, scenario, existingThreats, target, fusionMode)
%RANDOM_DYNAMIC_THREATS 生成向名义航路机动的动态威胁，默认更早启动以形成拦截。
    if fusionMode && isempty(opt.numDynamicThreats)
        defaultRange = [1, 1];
    else
        defaultRange = [1, 2];
    end
    numThreats = choose_threat_count(opt.numDynamicThreats, defaultRange);

    classes = special_class_sequence(opt.dynamicThreatClass, opt.dynamicThreatClassMode, numThreats);
    threats = repmat(make_threat("placeholder", 1, [0, 0], 1), numThreats, 1);
    allThreats = existingThreats(:);
    startXY = [scenario.start.x, scenario.start.y];
    targetXY = [target.x0, target.y0];

    for i = 1:numThreats
        accepted = false;
        for attempt = 1:1200
            radius = 2400 + rand * 1300;
            intercept = sample_corridor_point(startXY, targetXY, [0.42, 0.74], [0, 1800], scenario.rectX, scenario.rectY);
            offsetDistance = 5200 + rand * 4200;
            directionSign = sign(rand - 0.5);
            if directionSign == 0
                directionSign = 1;
            end
            lineDirection = unit_vector(targetXY - startXY);
            normal = directionSign * [-lineDirection(2), lineDirection(1)];
            movingStart = clamp_xy(intercept + normal * offsetDistance + (rand - 0.5) * 2500 * lineDirection, ...
                scenario.rectX, scenario.rectY);

            % 动态威胁默认按 10 km 距离或 45 s 时间阈值触发。
            defaultMoveStart = 45;
            defaultMoveDuration = 70 + rand * 40;
            moveStart = choose_indexed_random_scalar(opt.dynamicMoveStartRange, i, defaultMoveStart);
            moveDuration = choose_indexed_random_scalar(opt.dynamicMoveDurationRange, i, defaultMoveDuration);
            responseDistance = choose_indexed_random_scalar(opt.dynamicResponseDistanceRange, i, 10000);
            latestTriggerTime = choose_indexed_random_scalar(opt.dynamicLatestTriggerTimeRange, i, moveStart + 22 + rand * 28);

            nominalHeading = atan2(intercept(2) - movingStart(2), intercept(1) - movingStart(1));
            nominalDistance = norm(intercept - movingStart);
            nominalSpeed = nominalDistance / max(1, moveDuration);
            speedBounds = choose_indexed_speed_bounds(first_nonempty(opt.dynamicThreatSpeedRange, opt.threatSpeedRange), ...
                i, [220, 300]);
            speed = choose_random_scalar([], speedBounds, nominalSpeed);
            heading = nominalHeading;
            centerFinal = clipped_displacement(movingStart, speed, heading, moveDuration, scenario.rectX, scenario.rectY);

            if dynamic_motion_is_reasonable(movingStart, centerFinal, radius, allThreats, scenario, targetXY, startXY)
                namePrefix = "moving_" + special_class_name(classes(i)) + "_vehicle_";
                if fusionMode
                    namePrefix = "fusion_" + namePrefix;
                end
                threats(i) = make_threat(namePrefix + i, classes(i), movingStart, radius, ...
                    "activeStart", moveStart, "isMoving", true, "moveStart", moveStart, ...
                    "moveEnd", moveStart + moveDuration, "centerFinal", centerFinal, ...
                    "speed", speed, "heading", heading, ...
                    "distanceCoupledMotion", true, ...
                    "motionTriggerDistance", responseDistance, ...
                    "latestTriggerTime", latestTriggerTime);
                allThreats = [allThreats; threats(i)]; %#ok<AGROW>
                accepted = true;
                break;
            end
        end
        if ~accepted
            error("build_penetration_scenario:DynamicThreatSamplingFailed", ...
                "动态威胁随机生成失败，请放宽约束或减少威胁数量。");
        end
    end
end

function [target, threats, features] = fusion_reference_scene(opt, scenario, km)
    featureMask = false(1, 3);
    enabled = randperm(3, randi([2, 3]));
    featureMask(enabled) = true;

    threats = build_base_threats(opt, scenario, []);
    if featureMask(1)
        target = safe_moving_target(opt, threats, scenario.rectX, scenario.rectY, km);
    else
        target = pdf_reference_target(km);
    end
    scenario.target = target;

    if featureMask(2)
        suddenThreats = build_sudden_threats(opt, scenario, threats, target);
        threats = [threats; suddenThreats];
    end
    if featureMask(3)
        dynamicThreats = build_dynamic_threats(opt, scenario, threats, target, true);
        threats = [threats; dynamicThreats];
    end

    features = struct( ...
        "movingTarget", featureMask(1), ...
        "suddenThreat", featureMask(2), ...
        "dynamicThreat", featureMask(3), ...
        "numEnabled", sum(featureMask));
end

function threats = random_static_threats(numCirclesIn, numRadarsIn, rectX, rectY, startState, startClearanceRadius, target)
%RANDOM_STATIC_THREATS 随机生成基础雷达/武器，避开起点安全区和目标区。
    if isempty(numCirclesIn)
        numCircles = randi([3, 6]);
    else
        numCircles = round(numCirclesIn);
    end

    if isempty(numRadarsIn)
        numRadars = randi([1, max(1, numCircles - 1)]);
        numRadars = min(numRadars, numCircles - 1);
    else
        numRadars = min(round(numRadarsIn), numCircles - 1);
    end

    minDistance = max(5500, 11200 - 900 * (numCircles - 3));
    startXY = [startState.x, startState.y];
    if isempty(target)
        targetXY = [25000, 25000];
        targetZ = 500;
    else
        targetXY = [target.x0, target.y0];
        targetZ = target.z0;
    end

    centers = zeros(numCircles, 2);
    radii = zeros(numCircles, 1);
    classes = ones(numCircles, 1);
    classes(1:numRadars) = 0;
    classes = classes(randperm(numCircles));

    for i = 1:numCircles
        accepted = false;
        for attempts = 1:6000
            center = [randi([rectX(1), rectX(2)]), randi([rectY(1), rectY(2)])];
            if classes(i) == 0
                radius = randi([4200, 6500]);
            else
                radius = randi([2600, 5200]);
            end

            if i > 1
                distances = sqrt((centers(1:i-1, 1) - center(1)).^2 + (centers(1:i-1, 2) - center(2)).^2);
                if any(distances < minDistance)
                    continue;
                end
            end
            if ~start_area_clear(center, radius, startXY, startClearanceRadius)
                continue;
            end
            if target_inside_threat(targetXY, targetZ, center, radius)
                continue;
            end
            accepted = true;
            break;
        end
        if ~accepted
            error("build_penetration_scenario:BaseThreatSamplingFailed", ...
                "基础威胁随机生成失败，请减少威胁数量或放宽约束。");
        end
        centers(i, :) = center;
        radii(i) = radius;
    end

    threats = repmat(make_threat("placeholder", 1, [0, 0], 1), numCircles, 1);
    radarCount = 0;
    weaponCount = 0;
    for i = 1:numCircles
        if classes(i) == 0
            radarCount = radarCount + 1;
            name = "radar_" + radarCount;
        else
            weaponCount = weaponCount + 1;
            name = "weapon_" + weaponCount;
        end
        threats(i) = make_threat(name, classes(i), centers(i, :), radii(i));
    end
end

function scenario = enforce_start_clearance(scenario)
    startXY = [scenario.start.x, scenario.start.y];
    clearance = scenario.startClearanceRadius;
    for i = 1:numel(scenario.threats)
        threat = scenario.threats(i);
        if start_area_clear(threat.center0, threat.radius, startXY, clearance)
            continue;
        end

        direction = threat.center0 - startXY;
        if norm(direction) < eps
            direction = [1, 0];
        else
            direction = direction ./ norm(direction);
        end
        newCenter = startXY + direction .* (threat.radius + clearance + 500);
        newCenter = clamp_xy(newCenter, scenario.rectX, scenario.rectY);
        displacement = newCenter - threat.center0;
        scenario.threats(i).center0 = newCenter;
        scenario.threats(i).centerFinal = threat.centerFinal + displacement;
    end
end

function tf = start_area_clear(center, radius, startXY, clearance)
    tf = norm(center - startXY) > radius + clearance;
end

function tf = target_inside_threat(targetXY, targetZ, center, radius)
    margin = sphere_margin(targetXY(1), targetXY(2), targetZ, center, radius);
    tf = margin <= 0.08;
end

function margin = sphere_margin(x, y, z, center, radius)
    margin = (x - center(1)).^2 ./ radius.^2 + ...
             (y - center(2)).^2 ./ radius.^2 + ...
             z.^2 ./ radius.^2 - 1;
end

function tf = special_threat_is_reasonable(center, radius, existingThreats, scenario, targetXY)
    startXY = [scenario.start.x, scenario.start.y];
    tf = start_area_clear(center, radius, startXY, scenario.startClearanceRadius) && ...
        ~target_inside_threat(targetXY, scenario.target.z0, center, radius) && ...
        center(1) >= scenario.rectX(1) && center(1) <= scenario.rectX(2) && ...
        center(2) >= scenario.rectY(1) && center(2) <= scenario.rectY(2);
    if ~tf
        return;
    end
    for j = 1:numel(existingThreats)
        d = norm(center - existingThreats(j).center0);
        if d < max(2200, 0.50 * (radius + existingThreats(j).radius))
            tf = false;
            return;
        end
    end
end

function tf = dynamic_motion_is_reasonable(center0, centerFinal, radius, existingThreats, scenario, targetXY, startXY)
    tf = special_threat_is_reasonable(center0, radius, existingThreats, scenario, targetXY) && ...
        ~target_inside_threat(targetXY, scenario.target.z0, centerFinal, radius) && ...
        point_to_segment_distance(0.5 * (startXY + targetXY), center0, centerFinal) <= radius + 4500;
end

function center = sample_corridor_point(startXY, targetXY, fractionRange, offsetRange, rectX, rectY)
    lineDirection = unit_vector(targetXY - startXY);
    normal = [-lineDirection(2), lineDirection(1)];
    fraction = fractionRange(1) + rand * diff(fractionRange);
    offset = offsetRange(1) + rand * diff(offsetRange);
    if rand < 0.5
        offset = -offset;
    end
    center = startXY + fraction * (targetXY - startXY) + offset * normal;
    center = clamp_xy(center, rectX, rectY);
end

function vector = unit_vector(vector)
    n = norm(vector);
    if n < eps
        vector = [1, 0];
    else
        vector = vector ./ n;
    end
end

function center = clamp_xy(center, rectX, rectY)
    center(1) = min(max(center(1), rectX(1)), rectX(2));
    center(2) = min(max(center(2), rectY(1)), rectY(2));
end

function distance = point_to_segment_distance(point, segStart, segEnd)
    segment = segEnd - segStart;
    if norm(segment) < eps
        distance = norm(point - segStart);
        return;
    end
    u = dot(point - segStart, segment) / dot(segment, segment);
    u = min(max(u, 0), 1);
    closest = segStart + u * segment;
    distance = norm(point - closest);
end

function classes = special_class_sequence(fixedClass, classMode, numThreats)
%SPECIAL_CLASS_SEQUENCE 为突发/动态特殊威胁生成雷达或武器类别。
% class=0 表示雷达，class=1 表示防空武器；mixed 模式在数量大于 1 时保证两类都出现。
    if ~isempty(fixedClass)
        classes = normalize_class_values(fixedClass, numThreats);
        return;
    end

    mode = lower(string(classMode));
    switch mode
        case {"weapon", "weapons", "sam", "missile"}
            classes = ones(numThreats, 1);
        case {"radar", "radars"}
            classes = zeros(numThreats, 1);
        case "mixed"
            if numThreats == 1
                classes = randi([0, 1], 1, 1);
            else
                classes = [0; 1; randi([0, 1], numThreats - 2, 1)];
                classes = classes(randperm(numThreats));
            end
        case "random"
            classes = randi([0, 1], numThreats, 1);
        otherwise
            error("build_penetration_scenario:InvalidThreatClassMode", ...
                "特殊威胁类别模式必须为 mixed/random/radar/weapon，当前为 %s。", classMode);
    end
end

function classes = normalize_class_values(value, numThreats)
    classes = double(value(:));
    if isscalar(classes)
        classes = repmat(classes, numThreats, 1);
    end
    if numel(classes) < numThreats
        classes = repmat(classes, ceil(numThreats / numel(classes)), 1);
    end
    classes = classes(1:numThreats);
    classes = double(classes ~= 0);
end

function name = special_class_name(classId)
    if classId == 0
        name = "radar";
    else
        name = "weapon";
    end
end

function threat = make_threat(name, classId, center0, radius, varargin)
%MAKE_THREAT 创建统一威胁结构。
    parser = inputParser;
    parser.addParameter("activeStart", 0, @isnumeric);
    parser.addParameter("activeEnd", inf, @isnumeric);
    parser.addParameter("isMoving", false, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("moveStart", 0, @isnumeric);
    parser.addParameter("moveEnd", 0, @isnumeric);
    parser.addParameter("centerFinal", center0, @isnumeric);
    parser.addParameter("triggerDistance", inf, @isnumeric);
    parser.addParameter("speed", 0, @isnumeric);
    parser.addParameter("heading", 0, @isnumeric);
    parser.addParameter("distanceCoupledMotion", false, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("motionTriggerDistance", inf, @isnumeric);
    parser.addParameter("latestTriggerTime", inf, @isnumeric);
    parser.parse(varargin{:});
    opt = parser.Results;

    threat = struct();
    threat.name = char(name);
    threat.class = classId;
    threat.center0 = reshape(center0, 1, 2);
    threat.radius = radius;
    threat.activeStart = opt.activeStart;
    threat.activeEnd = opt.activeEnd;
    threat.isMoving = logical(opt.isMoving);
    threat.moveStart = opt.moveStart;
    threat.moveEnd = opt.moveEnd;
    threat.centerFinal = reshape(opt.centerFinal, 1, 2);
    threat.triggerDistance = opt.triggerDistance;
    threat.speed = opt.speed;
    threat.heading = opt.heading;
    threat.distanceCoupledMotion = logical(opt.distanceCoupledMotion);
    threat.motionTriggerDistance = opt.motionTriggerDistance;
    threat.latestTriggerTime = opt.latestTriggerTime;
end

function scenario = refresh_circle_fields(scenario)
    threats = scenario.threats(:);
    scenario.numCircles = numel(threats);
    scenario.circleCenters0 = vertcat(threats.center0);
    scenario.circleRadii = reshape([threats.radius], [], 1);
    scenario.circleClass = reshape([threats.class], [], 1);
    scenario.numRadars = sum(scenario.circleClass == 0);
    scenario.radarIndices = find(scenario.circleClass == 0).';
end

function value = choose_random_scalar(value, valueRange, defaultValue)
    if ~isempty(value)
        return;
    end
    if isempty(valueRange)
        value = defaultValue;
        return;
    end
    if isscalar(valueRange)
        value = valueRange;
        return;
    end
    lo = valueRange(1);
    hi = valueRange(2);
    value = lo + rand * (hi - lo);
end

function value = choose_indexed_random_scalar(valueRange, rowIndex, defaultValue)
    if isempty(valueRange)
        value = defaultValue;
        return;
    end
    if isscalar(valueRange)
        value = valueRange;
        return;
    end
    if size(valueRange, 1) >= rowIndex && size(valueRange, 2) >= 2
        rangeRow = valueRange(rowIndex, 1:2);
    else
        rangeRow = reshape(valueRange(1:2), 1, 2);
    end
    value = choose_random_scalar([], rangeRow, defaultValue);
end

function bounds = choose_speed_bounds(valueRange, defaultRange)
    if isempty(valueRange)
        bounds = sort(defaultRange);
        return;
    end
    if isscalar(valueRange)
        bounds = [valueRange, valueRange];
        return;
    end
    bounds = sort(reshape(valueRange(1:2), 1, 2));
end

function bounds = choose_indexed_speed_bounds(valueRange, rowIndex, defaultRange)
    if isempty(valueRange)
        bounds = sort(defaultRange);
        return;
    end
    if isscalar(valueRange)
        bounds = [valueRange, valueRange];
        return;
    end
    if size(valueRange, 1) >= rowIndex && size(valueRange, 2) >= 2
        bounds = sort(reshape(valueRange(rowIndex, 1:2), 1, 2));
    else
        bounds = sort(reshape(valueRange(1:2), 1, 2));
    end
end

function tf = is_valid_threat_count_option(value)
    tf = isempty(value) || ischar(value) || isstring(value) || ...
        (isnumeric(value) && ~isempty(value) && all(value(:) >= 1));
end

function count = choose_threat_count(value, defaultRange)
%CHOOSE_THREAT_COUNT 支持留空、"random"、标量固定数量或 [min,max] 随机数量。
    if isempty(value)
        range = defaultRange;
    elseif ischar(value) || isstring(value)
        mode = lower(string(value));
        if mode ~= "random"
            error("build_penetration_scenario:InvalidThreatCount", ...
                "威胁数量字符串参数只支持 random，当前为 %s。", value);
        end
        range = defaultRange;
    elseif isscalar(value)
        count = max(1, round(value));
        return;
    else
        range = sort(round(reshape(value(1:2), 1, 2)));
    end

    lo = max(1, range(1));
    hi = max(lo, range(2));
    count = randi([lo, hi]);
end

function value = first_nonempty(primaryValue, fallbackValue)
    if ~isempty(primaryValue)
        value = primaryValue;
    else
        value = fallbackValue;
    end
end

function center = clipped_displacement(center0, speed, heading, duration, rectX, rectY)
    center = center0 + speed * duration * [cos(heading), sin(heading)];
    center = clamp_xy(center, rectX, rectY);
end

function angle = wrap_to_pi_local(angle)
    angle = mod(angle + pi, 2 * pi) - pi;
end
