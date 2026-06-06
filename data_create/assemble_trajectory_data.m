function trajectory_data = assemble_trajectory_data(scenario, time, state, control, Pt, varargin)
%ASSEMBLE_TRAJECTORY_DATA 组装并返回统一的轨迹数据结构。
% 旧字段仍保留，方便沿用已有数据读取代码；新增字段保存动态目标/威胁元数据。

    parser = inputParser;
    parser.addParameter("solverStatus", "success", @(x)ischar(x) || isstring(x));
    parser.addParameter("objective", nan, @isnumeric);
    parser.parse(varargin{:});
    opt = parser.Results;

    time = time(:);
    if size(state, 1) ~= numel(time)
        error("state 行数必须与 time 长度一致。");
    end
    if size(state, 2) < 6
        error("state 至少需要 6 列：[x y z v theta phi]。");
    end
    if size(control, 1) ~= numel(time) || size(control, 2) < 3
        error("control 必须为 numel(time) x 3，列为 [nx nz gama]。");
    end

    if nargin < 5 || isempty(Pt)
        Pt = zeros(numel(time), scenario.numRadars);
    end
    if size(Pt, 1) ~= numel(time)
        error("Pt 行数必须与 time 长度一致。");
    end

    target = sample_target_trajectory(scenario, time);
    threatCenters = sample_threat_centers(scenario, time, state(:, 1:6));
    threatActive = sample_threat_activity(scenario, time, state(:, 1:6));

    rx = state(:, 1);
    ry = state(:, 2);
    rz = state(:, 3);
    D = sqrt((rx - target.x).^2 + (ry - target.y).^2 + (rz - target.z).^2);

    trajectory_data = struct();

    % 无人机状态与控制量：字段名保持和已验证 data/dataset 数据一致。
    trajectory_data.aircraft_position_x = rx;
    trajectory_data.aircraft_position_y = ry;
    trajectory_data.aircraft_position_z = rz;
    trajectory_data.time = time;
    trajectory_data.v = state(:, 4);
    trajectory_data.theta = state(:, 5);
    trajectory_data.phi = state(:, 6);
    trajectory_data.D = D;
    trajectory_data.nx = control(:, 1);
    trajectory_data.nz = control(:, 2);
    trajectory_data.gama = control(:, 3);
    trajectory_data.Pt = Pt;

    % 旧版静态圆形威胁字段：动态/突发场景中表示初始状态。
    trajectory_data.numCircles = scenario.numCircles;
    trajectory_data.circleCenters = scenario.circleCenters0;
    trajectory_data.circleRadii = scenario.circleRadii;
    trajectory_data.circleClass = scenario.circleClass;

    % 目标轨迹字段：新代码修正为与 time 等长，便于后续绘图和训练检查。
    trajectory_data.xt = target.x;
    trajectory_data.yt = target.y;
    trajectory_data.zt = target.z;
    trajectory_data.vt = target.v;
    trajectory_data.thetat = target.theta;

    % 新增元数据字段：用于区分场景、动态绘图和排查生成过程。
    trajectory_data.scenarioType = char(scenario.type);
    trajectory_data.scenarioConfig = scenario;
    trajectory_data.targetTrajectory = target;
    trajectory_data.circleCentersDynamic = threatCenters;
    trajectory_data.threatActive = threatActive;
    trajectory_data.threatTrajectory = struct( ...
        "time", time, ...
        "centers", threatCenters, ...
        "active", threatActive, ...
        "radii", scenario.circleRadii, ...
        "class", scenario.circleClass, ...
        "names", {cellstr({scenario.threats.name})});
    trajectory_data.solverStatus = char(opt.solverStatus);
    trajectory_data.objective = opt.objective;
end
