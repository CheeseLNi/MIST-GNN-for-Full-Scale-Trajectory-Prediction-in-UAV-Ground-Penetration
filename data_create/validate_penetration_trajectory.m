function [isValid, report] = validate_penetration_trajectory(trajectory_data, varargin)
%VALIDATE_PENETRATION_TRAJECTORY 检测生成轨迹和场景是否满足基本合理性。
% 检查项包括：终点接近目标终点、轨迹节点不穿越已激活防空武器覆盖区、
% 起点附近不被威胁覆盖，以及数值是否有限。

    parser = inputParser;
    parser.addParameter("terminalTolerance", [], @(x)isempty(x) || (isnumeric(x) && isscalar(x)));
    parser.addParameter("weaponMarginTolerance", -1e-4, @(x)isnumeric(x) && isscalar(x));
    parser.parse(varargin{:});
    opt = parser.Results;

    td = trajectory_data;
    x = td.aircraft_position_x(:);
    y = td.aircraft_position_y(:);
    z = td.aircraft_position_z(:);
    time = td.time(:);

    targetX = td.xt(:);
    targetY = td.yt(:);
    targetZ = td.zt(:);
    terminalDistance = sqrt((x(end) - targetX(end)).^2 + ...
                            (y(end) - targetY(end)).^2 + ...
                            (z(end) - targetZ(end)).^2);

    terminalTolerance = opt.terminalTolerance;
    if isempty(terminalTolerance)
        terminalTolerance = 150;
        if isfield(td, "scenarioConfig") && isfield(td.scenarioConfig, "attackRadius")
            terminalTolerance = td.scenarioConfig.attackRadius;
        end
    end

    centers = centers_from_record(td, time);
    active = active_from_record(td, time);
    radii = td.circleRadii(:);
    classes = td.circleClass(:);

    minWeaponMargin = inf;
    minThreatMargin = inf;
    minRadarMargin = inf;
    targetFinalWeaponMargin = inf;
    for i = 1:td.numCircles
        cx = centers(:, i, 1);
        cy = centers(:, i, 2);
        margin = (x - cx).^2 ./ radii(i).^2 + ...
                 (y - cy).^2 ./ radii(i).^2 + ...
                 z.^2 ./ radii(i).^2 - 1;
        activeMargin = margin(logical(active(:, i)));
        if ~isempty(activeMargin)
            minThreatMargin = min(minThreatMargin, min(activeMargin));
            if classes(i) == 1
                minWeaponMargin = min(minWeaponMargin, min(activeMargin));
            else
                minRadarMargin = min(minRadarMargin, min(activeMargin));
            end
        end
        if classes(i) == 1 && active(end, i)
            targetMargin = (targetX(end) - cx(end)).^2 ./ radii(i).^2 + ...
                           (targetY(end) - cy(end)).^2 ./ radii(i).^2 + ...
                           targetZ(end).^2 ./ radii(i).^2 - 1;
            targetFinalWeaponMargin = min(targetFinalWeaponMargin, targetMargin);
        end
    end

    startClearanceOk = true;
    if isfield(td, "scenarioConfig") && isfield(td.scenarioConfig, "startClearanceRadius")
        scenario = td.scenarioConfig;
        startXY = [scenario.start.x, scenario.start.y];
        baseCenters = vertcat(scenario.threats.center0);
        baseRadii = reshape([scenario.threats.radius], [], 1);
        distances = sqrt(sum((baseCenters - startXY).^2, 2));
        startClearanceOk = all(distances > baseRadii + scenario.startClearanceRadius);
    end

    finiteOk = all(isfinite([x; y; z; targetX; targetY; targetZ]));
    terminalOk = terminalDistance <= terminalTolerance;
    weaponOk = minWeaponMargin >= opt.weaponMarginTolerance;
    radarSoftOk = true;
    threatOk = weaponOk;
    targetFinalWeaponOk = targetFinalWeaponMargin >= opt.weaponMarginTolerance;

    isValid = finiteOk && terminalOk && weaponOk && ...
        targetFinalWeaponOk && startClearanceOk;

    report = struct();
    report.isValid = isValid;
    report.finiteOk = finiteOk;
    report.terminalOk = terminalOk;
    report.weaponOk = weaponOk;
    report.radarSoftOk = radarSoftOk;
    report.threatOk = threatOk;
    report.targetFinalWeaponOk = targetFinalWeaponOk;
    report.startClearanceOk = startClearanceOk;
    report.terminalDistance = terminalDistance;
    report.terminalTolerance = terminalTolerance;
    report.minWeaponMargin = minWeaponMargin;
    report.minRadarMargin = minRadarMargin;
    report.minThreatMargin = minThreatMargin;
    report.targetFinalWeaponMargin = targetFinalWeaponMargin;
    report.summary = validation_summary(report);
end

function centers = centers_from_record(td, time)
    if isfield(td, "circleCentersDynamic") && ~isempty(td.circleCentersDynamic)
        centers = td.circleCentersDynamic;
        return;
    end

    centers = zeros(numel(time), td.numCircles, 2);
    for i = 1:td.numCircles
        centers(:, i, 1) = td.circleCenters(i, 1);
        centers(:, i, 2) = td.circleCenters(i, 2);
    end
end

function active = active_from_record(td, time)
    if isfield(td, "threatActive") && ~isempty(td.threatActive)
        active = logical(td.threatActive);
    else
        active = true(numel(time), td.numCircles);
    end
end

function textValue = validation_summary(report)
    failed = strings(0, 1);
    if ~report.finiteOk
        failed(end + 1) = "存在非有限数值";
    end
    if ~report.terminalOk
        failed(end + 1) = sprintf("终端距离 %.2f m 超过 %.2f m", ...
            report.terminalDistance, report.terminalTolerance);
    end
    if ~report.weaponOk
        failed(end + 1) = sprintf("轨迹穿越防空武器覆盖区，最小裕度 %.4g", report.minWeaponMargin);
    end
    if isfield(report, "targetFinalWeaponOk") && ~report.targetFinalWeaponOk
        failed(end + 1) = sprintf("目标终点落入防空武器覆盖区，目标终点裕度 %.4g", report.targetFinalWeaponMargin);
    end
    if ~report.startClearanceOk
        failed(end + 1) = "无人机起点安全区被威胁覆盖";
    end

    if isempty(failed)
        textValue = "轨迹合理性检测通过";
    else
        textValue = strjoin(failed, "；");
    end
end
