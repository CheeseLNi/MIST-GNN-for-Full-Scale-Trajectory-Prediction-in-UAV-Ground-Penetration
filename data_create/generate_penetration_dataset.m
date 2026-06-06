function savedFiles = generate_penetration_dataset(scenarioTypes, varargin)
%GENERATE_PENETRATION_DATASET 生成无人机突防轨迹数据集。
%
% 示例：
%   generate_penetration_dataset(["static","time_sensitive","sudden","dynamic"], ...
%       "numSamples", 3, "startIndex", 1);
%
% 新数据默认保存到 data/unverified_dataset/<scenario>/，不会写入已验证的 data/dataset。

    parser = inputParser;
    parser.addRequired("scenarioTypes", @(x)ischar(x) || isstring(x) || iscellstr(x));
    parser.addParameter("numSamples", 1, @(x)isnumeric(x) && isscalar(x) && x >= 0);
    parser.addParameter("startIndex", 1, @(x)isnumeric(x) && isscalar(x));
    parser.addParameter("outputRoot", fullfile("data", "unverified_dataset"), @(x)ischar(x) || isstring(x));
    parser.addParameter("seed", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("saveFailed", false, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("targetSpeed", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("targetHeading", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("targetSpeedRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("targetHeadingRange", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("numCircles", [], @(x)isempty(x) || (isscalar(x) && x >= 3));
    parser.addParameter("numRadars", [], @(x)isempty(x) || (isscalar(x) && x >= 1));
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
    parser.addParameter("terminalTime", [], @(x)isempty(x) || isnumeric(x));
    parser.addParameter("nlpSolver", "snopt", @(x)ischar(x) || isstring(x));
    parser.addParameter("solverFcn", [], @(x)isempty(x) || isa(x, "function_handle"));
    parser.addParameter("validateTrajectory", true, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("maxAttempts", 10, @(x)isnumeric(x) && isscalar(x) && x >= 1);
    parser.addParameter("terminalTolerance", [], @(x)isempty(x) || (isnumeric(x) && isscalar(x)));
    parser.parse(scenarioTypes, varargin{:});
    opt = parser.Results;

    scenarioTypes = string(scenarioTypes);
    savedFiles = strings(0, 1);
    if isempty(opt.solverFcn)
        solverFcn = @(scenario) solve_penetration_scenario(scenario, opt.nlpSolver);
    else
        solverFcn = opt.solverFcn;
    end

    thisDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(thisDir);
    gpopsRoot = fullfile(repoRoot, "gpops2");
    addpath(thisDir);
    if exist(gpopsRoot, "dir")
        addpath(genpath(gpopsRoot));
    end

    sampleCounter = 0;
    for s = 1:numel(scenarioTypes)
        scenarioType = scenarioTypes(s);
        outDir = scenario_output_dir(opt.outputRoot, scenarioType);
        if ~exist(outDir, "dir")
            mkdir(outDir);
        end

        for k = 1:opt.numSamples
            sampleCounter = sampleCounter + 1;
            fileIndex = opt.startIndex + k - 1;
            filename = sprintf("trajectory_data_%d.mat", fileIndex);
            outputPath = fullfile(outDir, filename);

            saved = false;
            lastME = [];
            lastScenario = [];
            for attempt = 1:opt.maxAttempts
                scenarioSeed = [];
                if ~isempty(opt.seed)
                    scenarioSeed = opt.seed + sampleCounter - 1 + (attempt - 1) * 100000;
                end

                scenario = build_scenario_from_options(scenarioType, opt, scenarioSeed);
                lastScenario = scenario;

                try
                    trajectory_data = solverFcn(scenario);
                    if logical(opt.validateTrajectory)
                        [isValid, validationReport] = validate_penetration_trajectory(trajectory_data, ...
                            "terminalTolerance", opt.terminalTolerance);
                        trajectory_data.validationReport = validationReport;
                        if ~isValid
                            error("generate_penetration_dataset:InvalidTrajectory", ...
                                "轨迹合理性检测未通过：%s", validationReport.summary);
                        end
                    end

                    save(outputPath, "trajectory_data");
                    savedFiles(end + 1, 1) = string(outputPath); %#ok<AGROW>
                    fprintf("Saved %s\n", outputPath);
                    saved = true;
                    break;
                catch ME
                    lastME = ME;
                    if attempt < opt.maxAttempts
                        warning("场景 %s 第 %d 条第 %d 次生成失败，重新随机生成：%s", ...
                            scenarioType, k, attempt, ME.message);
                    end
                end
            end

            if ~saved
                if ~opt.saveFailed
                    warning("场景 %s 第 %d 条在 %d 次尝试后仍未通过，未保存该编号并继续后续样本：%s", ...
                        scenarioType, k, opt.maxAttempts, lastME.message);
                    continue;
                end
                trajectory_data = failed_trajectory_record(lastScenario, lastME);
                save(outputPath, "trajectory_data");
                savedFiles(end + 1, 1) = string(outputPath); %#ok<AGROW>
                warning("场景 %s 第 %d 条在 %d 次尝试后仍失败，已保存失败记录：%s", ...
                    scenarioType, k, opt.maxAttempts, lastME.message);
            end
        end
    end
end

function tf = is_valid_threat_count_option(value)
    tf = isempty(value) || ischar(value) || isstring(value) || ...
        (isnumeric(value) && ~isempty(value) && all(value(:) >= 1));
end

function scenario = build_scenario_from_options(scenarioType, opt, scenarioSeed)
%BUILD_SCENARIO_FROM_OPTIONS 将生成入口参数传入场景构造器。
    scenario = build_penetration_scenario(scenarioType, ...
        "seed", scenarioSeed, ...
        "targetSpeed", opt.targetSpeed, ...
        "targetHeading", opt.targetHeading, ...
        "targetSpeedRange", opt.targetSpeedRange, ...
        "targetHeadingRange", opt.targetHeadingRange, ...
        "numCircles", opt.numCircles, ...
        "numRadars", opt.numRadars, ...
        "threatSpeedRange", opt.threatSpeedRange, ...
        "threatHeadingRange", opt.threatHeadingRange, ...
        "suddenActiveStartRange", opt.suddenActiveStartRange, ...
        "suddenThreatSpeedRange", opt.suddenThreatSpeedRange, ...
        "suddenThreatHeadingRange", opt.suddenThreatHeadingRange, ...
        "suddenMoveDurationRange", opt.suddenMoveDurationRange, ...
        "suddenTriggerDistanceRange", opt.suddenTriggerDistanceRange, ...
        "dynamicMoveStartRange", opt.dynamicMoveStartRange, ...
        "dynamicMoveDurationRange", opt.dynamicMoveDurationRange, ...
        "dynamicThreatSpeedRange", opt.dynamicThreatSpeedRange, ...
        "dynamicThreatHeadingRange", opt.dynamicThreatHeadingRange, ...
        "dynamicResponseDistanceRange", opt.dynamicResponseDistanceRange, ...
        "dynamicLatestTriggerTimeRange", opt.dynamicLatestTriggerTimeRange, ...
        "startClearanceRadius", opt.startClearanceRadius, ...
        "baseThreatMode", opt.baseThreatMode, ...
        "suddenThreatMode", opt.suddenThreatMode, ...
        "dynamicThreatMode", opt.dynamicThreatMode, ...
        "numSuddenThreats", opt.numSuddenThreats, ...
        "numDynamicThreats", opt.numDynamicThreats, ...
        "suddenThreatClassMode", opt.suddenThreatClassMode, ...
        "dynamicThreatClassMode", opt.dynamicThreatClassMode, ...
        "suddenThreatClass", opt.suddenThreatClass, ...
        "dynamicThreatClass", opt.dynamicThreatClass, ...
        "radarIntrusionWeight", opt.radarIntrusionWeight, ...
        "weaponProximityWeight", opt.weaponProximityWeight, ...
        "weaponProximityBuffer", opt.weaponProximityBuffer, ...
        "terminalTime", opt.terminalTime);
end

function trajectory_data = solve_penetration_scenario(scenario, nlpSolver)
%SOLVE_PENETRATION_SCENARIO 使用 GPOPS 求解单个场景。
    if nargin < 2
        nlpSolver = "snopt";
    end

    bounds = build_gpops_bounds(scenario);
    guess = build_gpops_guess(scenario, bounds);
    mesh = build_gpops_mesh();

    setup.name = 'UAVPenetration';
    setup.functions.continuous = @continuous;
    setup.functions.endpoint = @endpoint;
    setup.mesh = mesh;
    setup.bounds = bounds;
    setup.guess = guess;
    setup.nlp.solver = char(nlpSolver);
    setup.derivatives.supplier = 'sparseCD';
    setup.derivatives.derivativelevel = 'second';
    setup.mesh.method = 'hp-LiuRao-Legendre';
    setup.mesh.tolerance = 1e-3;
    setup.mesh.colpointsmin = 4;
    setup.mesh.colpointsmax = 16;
    setup.mesh.maxiterations = 10;

    output = gpops2(setup);
    solution = output.result.solution;

    time = solution.phase.time(:);
    state = solution.phase.state(:, 1:6);
    control = control_at_state_nodes(solution.phase.time, solution.phase.control, time);
    Pt = compute_detection_probability(scenario, time, state, control);

    objective = nan;
    if isfield(output.result, "objective")
        objective = output.result.objective;
    end
    trajectory_data = assemble_trajectory_data(scenario, time, state, control, Pt, ...
        "solverStatus", "success", "objective", objective);

    function phaseout = continuous(input)
        phaseout = penetration_continuous(input, scenario);
    end

    function outputEndpoint = endpoint(input)
        outputEndpoint = penetration_endpoint(input, scenario);
    end
end

function bounds = build_gpops_bounds(scenario)
%BUILD_GPOPS_BOUNDS 将场景参数转换为 GPOPS 边界。
    b = scenario.bounds;
    start = scenario.start;

    tfmin = 20;
    tfmax = 500;
    if ~isempty(scenario.terminalTime)
        tfmin = scenario.terminalTime;
        tfmax = scenario.terminalTime;
    end

    bounds.phase.initialtime.lower = 0;
    bounds.phase.initialtime.upper = 0;
    bounds.phase.finaltime.lower = tfmin;
    bounds.phase.finaltime.upper = tfmax;
    bounds.phase.initialstate.lower = [start.x, start.y, start.z, start.v, start.theta, start.phi];
    bounds.phase.initialstate.upper = [start.x, start.y, start.z, start.v, start.theta, start.phi];
    bounds.phase.state.lower = [b.x(1), b.y(1), b.z(1), b.v(1), b.theta(1), b.phi(1)];
    bounds.phase.state.upper = [b.x(2), b.y(2), b.z(2), b.v(2), b.theta(2), b.phi(2)];

    % 终端位置由目标函数中的距离项牵引，避免移动目标导致动态终端边界不可表达。
    bounds.phase.finalstate.lower = [b.x(1), b.y(1), b.z(1), 100, b.theta(1), b.phi(1)];
    bounds.phase.finalstate.upper = [b.x(2), b.y(2), b.z(2), b.v(2), b.theta(2), b.phi(2)];
    bounds.phase.control.lower = [b.nx(1), b.nz(1), b.gama(1)];
    bounds.phase.control.upper = [b.nx(2), b.nz(2), b.gama(2)];
    bounds.phase.path.lower = zeros(1, scenario.numCircles);
    bounds.phase.path.upper = 1e6 * ones(1, scenario.numCircles);
    bounds.phase.integral.lower = 0;
    bounds.phase.integral.upper = 1e5;
    bounds.eventgroup.lower = 0;
    bounds.eventgroup.upper = scenario.attackRadius;
end

function guess = build_gpops_guess(scenario, bounds)
%BUILD_GPOPS_GUESS 给 GPOPS 一个贴近目标方向的初值猜测。
    start = scenario.start;
    tfGuess = mean([bounds.phase.finaltime.lower, bounds.phase.finaltime.upper]);
    targetGuess = sample_target_trajectory(scenario, tfGuess);
    phiGuessEnd = atan2(targetGuess.y - start.y, targetGuess.x - start.x);

    guess.phase.time = [0; tfGuess];
    guess.phase.state = [
        start.x, start.y, start.z, start.v, start.theta, start.phi
        min(30000, targetGuess.x), min(30000, targetGuess.y), targetGuess.z, 0.8 * 340, 0, phiGuessEnd
    ];
    guess.phase.control = [
        0, 1, 0
        0, 1, 0
    ];
    guess.phase.integral = 10;
end

function mesh = build_gpops_mesh()
%BUILD_GPOPS_MESH 沿用原脚本的 hp-Radau 初始网格规模。
    nPhase = 30;
    mesh.phase.colpoints = 4 * ones(1, nPhase);
    mesh.phase.fraction = 1 / nPhase * ones(1, nPhase);
end

function phaseout = penetration_continuous(input, scenario)
%PENETRATION_CONTINUOUS 无人机运动方程、动态威胁约束和雷达探测积分。
    g = 9.807;

    x = input.phase.state(:, 1);
    y = input.phase.state(:, 2);
    z = input.phase.state(:, 3);
    v = input.phase.state(:, 4);
    theta = input.phase.state(:, 5);
    phi = input.phase.state(:, 6);

    nx = input.phase.control(:, 1);
    nz = input.phase.control(:, 2);
    gama = input.phase.control(:, 3);
    t = input.phase.time(:);

    xdot = v .* cos(theta) .* cos(phi);
    ydot = v .* cos(theta) .* sin(phi);
    zdot = v .* sin(theta);
    vdot = g .* (nx - sin(theta));
    thetadot = g .* (nz .* cos(gama) - cos(theta)) ./ max(1, v);
    phidot = g .* nz .* sin(gama) ./ max(1, v .* cos(theta));

    threatCenters = sample_threat_centers(scenario, t, input.phase.state(:, 1:6));
    threatActive = sample_threat_activity(scenario, t, input.phase.state(:, 1:6));
    obs = zeros(numel(t), scenario.numCircles);
    radarIntrusion = zeros(numel(t), 1);
    weaponProximity = zeros(numel(t), 1);

    for i = 1:scenario.numCircles
        cx = threatCenters(:, i, 1);
        cy = threatCenters(:, i, 2);
        r = scenario.circleRadii(i);
        value = (x - cx).^2 ./ r.^2 + (y - cy).^2 ./ r.^2 + z.^2 ./ r.^2 - 1;
        activeMask = double(threatActive(:, i));
        if scenario.circleClass(i) == 1
            % 防空武器为硬禁入区：激活后必须满足 value >= 0。
            obs(:, i) = activeMask .* value + double(~threatActive(:, i)) .* 1e6;
            weaponBuffer = 0.35;
            if isfield(scenario, "weaponProximityBuffer")
                weaponBuffer = scenario.weaponProximityBuffer;
            end
            weaponProximity = weaponProximity + activeMask .* max(0, weaponBuffer - value);
        else
            % 雷达不是硬禁入区；用软惩罚尽量避免进入，同时允许必要时穿越。
            obs(:, i) = 1e6;
            radarIntrusion = radarIntrusion + activeMask .* max(0, -value);
        end
    end

    Pt = compute_detection_probability(scenario, t, input.phase.state(:, 1:6), input.phase.control(:, 1:3));
    radarIntrusionWeight = 0.5;
    if isfield(scenario, "radarIntrusionWeight")
        radarIntrusionWeight = scenario.radarIntrusionWeight;
    end
    weaponProximityWeight = 4;
    if isfield(scenario, "weaponProximityWeight")
        weaponProximityWeight = scenario.weaponProximityWeight;
    end

    phaseout.path = obs;
    phaseout.dynamics = [xdot, ydot, zdot, vdot, thetadot, phidot];
    phaseout.integrand = sum(Pt, 2) + radarIntrusionWeight * radarIntrusion + ...
        weaponProximityWeight * weaponProximity;
end

function output = penetration_endpoint(input, scenario)
%PENETRATION_ENDPOINT 综合考虑突防时间、雷达探测概率和末端接近距离。
    finalTime = input.phase.finaltime;
    finalState = input.phase.finalstate;
    target = sample_target_trajectory(scenario, finalTime);
    terminalDistance = sqrt((finalState(1) - target.x).^2 + ...
                            (finalState(2) - target.y).^2 + ...
                            (finalState(3) - target.z).^2);

    timeWeight = 2;
    threatWeight = 35;
    distanceWeight = 1;
    output.objective = timeWeight * finalTime + threatWeight * input.phase.integral + ...
        distanceWeight * terminalDistance;
    output.eventgroup.event = terminalDistance;
end

function control = control_at_state_nodes(controlTime, rawControl, targetTime)
%CONTROL_AT_STATE_NODES 保证控制量与状态节点数量一致。
    if size(rawControl, 1) == numel(targetTime)
        control = rawControl(:, 1:3);
        return;
    end

    control = zeros(numel(targetTime), 3);
    for j = 1:3
        control(:, j) = interp1(controlTime(:), rawControl(:, j), targetTime(:), "linear", "extrap");
    end
end

function trajectory_data = failed_trajectory_record(scenario, ME)
%FAILED_TRAJECTORY_RECORD 保存失败样本的场景和初始状态，便于复现实验。
    t = 0;
    state = [scenario.start.x, scenario.start.y, scenario.start.z, scenario.start.v, scenario.start.theta, scenario.start.phi];
    control = [0, 0, 0];
    Pt = zeros(1, scenario.numRadars);
    trajectory_data = assemble_trajectory_data(scenario, t, state, control, Pt, ...
        "solverStatus", "failed", "objective", nan);
    trajectory_data.errorMessage = ME.message;
end
