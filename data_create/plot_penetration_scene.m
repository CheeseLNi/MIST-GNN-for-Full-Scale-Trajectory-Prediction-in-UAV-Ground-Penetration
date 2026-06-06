function [outputFile, fig] = plot_penetration_scene(dataOrFile, varargin)
%PLOT_PENETRATION_SCENE 绘制无人机突防场景，可保存 PNG/GIF 或显示交互 figure。
% 输入可以是 trajectory_data 结构体，也可以是包含 trajectory_data 的 .mat 文件。
%
% 示例：
%   plot_penetration_scene(files(1));
%   plot_penetration_scene(files(1), "showFigure", true, "saveOutput", false);

    parser = inputParser;
    parser.addRequired("dataOrFile");
    parser.addParameter("outputFile", "", @(x)ischar(x) || isstring(x));
    parser.addParameter("frameStep", [], @(x)isempty(x) || (isscalar(x) && x >= 1));
    parser.addParameter("frameIndex", [], @(x)isempty(x) || (isscalar(x) && x >= 1));
    parser.addParameter("showFigure", false, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("saveOutput", true, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("makeGif", [], @(x)isempty(x) || islogical(x) || isnumeric(x));
    parser.addParameter("visible", [], @(x)isempty(x) || islogical(x) || isnumeric(x));
    parser.parse(dataOrFile, varargin{:});
    opt = parser.Results;

    showFigure = logical(opt.showFigure);
    if ~isempty(opt.visible)
        % 兼容少量旧脚本中的 visible 参数；新代码建议使用 showFigure。
        showFigure = logical(opt.visible);
    end
    saveOutput = logical(opt.saveOutput);

    [trajectory_data, sourcePath] = load_trajectory_input(dataOrFile);
    nFrames = numel(trajectory_data.time);
    selectedFrame = sanitize_frame_index(opt.frameIndex, nFrames);

    makeAnimation = should_make_animation(trajectory_data);
    if ~isempty(opt.makeGif)
        makeAnimation = logical(opt.makeGif);
    end

    outputFile = "";
    if saveOutput
        outputFile = resolve_output_file(trajectory_data, sourcePath, opt.outputFile, makeAnimation);
        ensure_output_folder(outputFile);
    end

    fig = [];
    if showFigure
        fig = create_scene_figure(true);
        ax = axes(fig);
        draw_scene_frame(trajectory_data, selectedFrame, ax, true);
        drawnow;
    end

    if saveOutput
        if makeAnimation
            write_scene_gif(trajectory_data, outputFile, opt.frameStep);
        elseif showFigure
            saveas(fig, outputFile);
        else
            write_scene_png(trajectory_data, outputFile);
        end
        fprintf("Scene saved to %s\n", outputFile);
    elseif ~showFigure
        warning("plot_penetration_scene:NoOutput", ...
            "saveOutput=false 且 showFigure=false，未生成图像输出。");
    end
end

function [trajectory_data, sourcePath] = load_trajectory_input(dataOrFile)
    sourcePath = "";
    if isstruct(dataOrFile)
        trajectory_data = dataOrFile;
        return;
    end

    sourcePath = string(dataOrFile);
    loaded = load(sourcePath);
    if ~isfield(loaded, "trajectory_data")
        error("文件中未找到 trajectory_data 变量：%s", sourcePath);
    end
    trajectory_data = loaded.trajectory_data;
end

function frameIndex = sanitize_frame_index(frameIndex, nFrames)
%SANITIZE_FRAME_INDEX 交互显示默认展示最后一帧，便于检查最终突防结果。
    if isempty(frameIndex)
        frameIndex = nFrames;
        return;
    end
    frameIndex = min(max(round(frameIndex), 1), nFrames);
end

function tf = should_make_animation(td)
%SHOULD_MAKE_ANIMATION 目标、威胁位置或威胁激活状态变化时默认输出动图。
    tf = false;
    if isfield(td, "circleCentersDynamic") && size(td.circleCentersDynamic, 1) > 1
        firstCenters = squeeze(td.circleCentersDynamic(1, :, :));
        lastCenters = squeeze(td.circleCentersDynamic(end, :, :));
        tf = tf || any(abs(firstCenters(:) - lastCenters(:)) > 1e-9);
    end
    if isfield(td, "threatActive") && size(td.threatActive, 1) > 1
        tf = tf || any(any(td.threatActive ~= td.threatActive(1, :)));
    end
    if isfield(td, "xt") && numel(td.xt) > 1
        tf = tf || any(abs(td.xt(:) - td.xt(1)) > 1e-9) || ...
             any(abs(td.yt(:) - td.yt(1)) > 1e-9);
    end
end

function outputFile = resolve_output_file(td, sourcePath, requestedFile, makeAnimation)
    if strlength(string(requestedFile)) > 0
        outputFile = char(join(string(requestedFile), ""));
        return;
    end

    if strlength(sourcePath) > 0
        [folder, name] = fileparts(sourcePath);
    else
        folder = pwd;
        if isfield(td, "scenarioType")
            name = "scene_" + string(td.scenarioType);
        else
            name = "scene";
        end
    end

    if makeAnimation
        outputFile = fullfile(folder, name + ".gif");
    else
        outputFile = fullfile(folder, name + ".png");
    end
    outputFile = char(outputFile);
end

function ensure_output_folder(outputFile)
    outDir = fileparts(outputFile);
    if ~isempty(outDir) && ~exist(outDir, "dir")
        mkdir(outDir);
    end
end

function write_scene_png(td, outputFile)
    fig = create_scene_figure(false);
    cleanupFig = onCleanup(@()close_open_figure(fig));
    ax = axes(fig);
    draw_scene_frame(td, numel(td.time), ax, true);
    saveas(fig, outputFile);
end

function write_scene_gif(td, outputFile, frameStep)
    n = numel(td.time);
    if isempty(frameStep)
        frameStep = max(1, floor(n / 60));
    end
    frameIds = unique([1:frameStep:n, n]);
    outDir = fileparts(outputFile);
    if isempty(outDir)
        outDir = pwd;
    end
    if ~exist(outDir, "dir")
        mkdir(outDir);
    end
    tempFile = [tempname(outDir), '.gif'];

    fig = create_scene_figure(false);
    cleanupFig = onCleanup(@()close_open_figure(fig));
    ax = axes(fig);

    try
        for ii = 1:numel(frameIds)
            cla(ax, "reset");
            draw_scene_frame(td, frameIds(ii), ax, false);
            drawnow;

            frame = getframe(fig);
            [im, map] = rgb2ind(frame2im(frame), 256);
            if ii == 1
                imwrite(im, map, tempFile, "gif", "LoopCount", inf, ...
                    "DelayTime", 0.12, "DisposalMethod", "restoreBG");
            else
                imwrite(im, map, tempFile, "gif", "WriteMode", "append", ...
                    "DelayTime", 0.12, "DisposalMethod", "restoreBG");
            end
        end

        movefile(tempFile, outputFile, "f");
    catch ME
        if exist(tempFile, "file")
            delete(tempFile);
        end
        rethrow(ME);
    end
end

function close_open_figure(fig)
    if isgraphics(fig, "figure")
        close(fig);
    end
end

function fig = create_scene_figure(showFigure)
    if showFigure
        visibility = "on";
    else
        visibility = "off";
    end
    fig = figure("Color", "w", "Visible", visibility, "Position", [600, 300, 1200, 1000]);
end

function draw_scene_frame(td, k, ax, showDynamicArrows)
%DRAW_SCENE_FRAME 按指定帧绘制半球威胁、无人机历史轨迹和目标位置。
    if nargin < 4
        showDynamicArrows = true;
    end
    hold(ax, "on");
    grid(ax, "on");
    box(ax, "on");

    [sx, sy, sz] = sphere(50);
    sz(sz < 0) = nan;

    centers = centers_at_frame(td, k);
    active = active_at_frame(td, k);
    legendAdded = struct("weapon", false, "radar", false, "inactive", false, ...
        "moveArrow", false, "suddenTrigger", false, "dynamicTrack", false);

    for i = 1:td.numCircles
        radius = td.circleRadii(i);
        cx = centers(i, 1);
        cy = centers(i, 2);
        threatInfo = threat_info_at_index(td, i);
        [faceColor, faceAlpha, edgeColor, lineWidth, legendName, legendKey] = ...
            threat_style(td.circleClass(i), active(i), threatInfo);
        showLegend = ~legendAdded.(legendKey);
        legendAdded.(legendKey) = true;

        draw_threat_surface(ax, sx, sy, sz, cx, cy, radius, faceColor, faceAlpha, ...
            edgeColor, lineWidth, legendName, showLegend);
    end

    legendAdded = draw_sudden_annotations(td, k, ax, legendAdded);
    legendAdded = draw_dynamic_threat_tracks(td, k, ax, legendAdded);
    if showDynamicArrows
        legendAdded = draw_dynamic_arrows(td, k, ax, legendAdded);
    end
    draw_uav_and_target(td, k, ax);

    axis(ax, [0, 30000, 0, 30000]);
    zlim(ax, [0, max(6000, max(td.aircraft_position_z(:)) + 500)]);
    view(ax, 2);
    xlabel(ax, "X(m)");
    ylabel(ax, "Y(m)");
    zlabel(ax, "Z(m)");
    set(ax, "FontSize", 30);
    title(ax, frame_title(td, k), "Interpreter", "none", "FontSize", 24);

    lgd = legend(ax, "Location", "southoutside", "Orientation", "horizontal");
    set(lgd, "FontSize", 14, "NumColumns", 3);
end

function draw_threat_surface(ax, sx, sy, sz, cx, cy, radius, faceColor, faceAlpha, ...
    edgeColor, lineWidth, legendName, showLegend)
    xData = radius * sx + cx;
    yData = radius * sy + cy;
    zData = radius * sz;

    if showLegend
        surf(ax, xData, yData, zData, "FaceColor", faceColor, "FaceAlpha", faceAlpha, ...
            "EdgeColor", edgeColor, "LineWidth", lineWidth, "DisplayName", legendName);
    else
        surf(ax, xData, yData, zData, "FaceColor", faceColor, "FaceAlpha", faceAlpha, ...
            "EdgeColor", edgeColor, "LineWidth", lineWidth, "HandleVisibility", "off");
    end
end

function legendAdded = draw_sudden_annotations(td, k, ax, legendAdded)
%DRAW_SUDDEN_ANNOTATIONS 标出突发威胁及其首次触发点。
    if ~isfield(td, "scenarioConfig") || ~isfield(td.scenarioConfig, "threats")
        return;
    end
    activeMatrix = threat_active_matrix(td);
    if isempty(activeMatrix)
        return;
    end

    threats = td.scenarioConfig.threats;
    centers = centers_at_frame(td, k);
    suddenCount = 0;
    for i = 1:min(numel(threats), td.numCircles)
        if ~startsWith(string(threats(i).name), "sudden")
            continue;
        end
        suddenCount = suddenCount + 1;
        label = sprintf("Sudden %s %d", threat_class_label(threats(i).class), suddenCount);
        text(ax, centers(i, 1), centers(i, 2), td.circleRadii(i) + 350, label, ...
            "Color", [0.15, 0.15, 0.15], "FontSize", 12, ...
            "FontWeight", "bold", "HorizontalAlignment", "center", ...
            "BackgroundColor", "w", "Margin", 1, "HandleVisibility", "off");

        triggerIndex = find(logical(activeMatrix(:, i)), 1, "first");
        if isempty(triggerIndex) || triggerIndex > k
            continue;
        end

        if ~legendAdded.suddenTrigger
            visibilityArgs = {"DisplayName", "Sudden trigger point"};
            legendAdded.suddenTrigger = true;
        else
            visibilityArgs = {"HandleVisibility", "off"};
        end
        accentColor = [0.9290, 0.6940, 0.1250];
        accentTextColor = [0.6275, 0.3529, 0.0000];
        scatter3(ax, td.aircraft_position_x(triggerIndex), ...
            td.aircraft_position_y(triggerIndex), td.aircraft_position_z(triggerIndex), ...
            170, accentColor, 'd', "filled", "LineWidth", 1.4, visibilityArgs{:});
        text(ax, td.aircraft_position_x(triggerIndex), td.aircraft_position_y(triggerIndex), ...
            td.aircraft_position_z(triggerIndex) + 300, "Sudden trigger", ...
            "Color", accentTextColor, "FontSize", 11, "FontWeight", "bold", ...
            "BackgroundColor", "w", "Margin", 1, "HandleVisibility", "off");
    end
end

function legendAdded = draw_dynamic_threat_tracks(td, k, ax, legendAdded)
%DRAW_DYNAMIC_THREAT_TRACKS 标出动态威胁及其已经运动过的轨迹。
    if ~isfield(td, "scenarioConfig") || ~isfield(td.scenarioConfig, "threats") || ...
            ~isfield(td, "circleCentersDynamic")
        return;
    end

    threats = td.scenarioConfig.threats;
    k = min(k, size(td.circleCentersDynamic, 1));
    dynamicCount = 0;
    for i = 1:min(numel(threats), td.numCircles)
        if ~is_dynamic_motion_threat(threats(i))
            continue;
        end
        dynamicCount = dynamicCount + 1;
        xHistory = squeeze(td.circleCentersDynamic(1:k, i, 1));
        yHistory = squeeze(td.circleCentersDynamic(1:k, i, 2));
        xPath = xHistory(:);
        yPath = yHistory(:);
        zPath = td.circleRadii(i) * ones(size(xPath));

        if ~legendAdded.dynamicTrack
            visibilityArgs = {"DisplayName", "Dynamic threat trajectory"};
            legendAdded.dynamicTrack = true;
        else
            visibilityArgs = {"HandleVisibility", "off"};
        end
        accentColor = [0.9290, 0.6940, 0.1250];
        accentTextColor = [0.6275, 0.3529, 0.0000];
        plot3(ax, xPath, yPath, zPath, "--", "Color", accentColor, ...
            "LineWidth", 2.5, visibilityArgs{:});
        text(ax, xPath(end), yPath(end), zPath(end) + 350, ...
            sprintf("Dynamic %s %d", threat_class_label(threats(i).class), dynamicCount), ...
            "Color", accentTextColor, "FontSize", 12, "FontWeight", "bold", ...
            "HorizontalAlignment", "center", "BackgroundColor", "w", ...
            "Margin", 1, "HandleVisibility", "off");
    end
end

function legendAdded = draw_dynamic_arrows(td, k, ax, legendAdded)
%DRAW_DYNAMIC_ARROWS 用红色箭头标出动态威胁的运动方向；突发威胁不画箭头。
    if ~isfield(td, "scenarioConfig") || ~isfield(td.scenarioConfig, "threats")
        return;
    end
    if ~is_dynamic_scene(td)
        return;
    end

    threats = td.scenarioConfig.threats;
    for i = 1:numel(threats)
        if ~is_dynamic_motion_threat(threats(i))
            continue;
        end
        [startCenter, delta] = dynamic_arrow_from_record(td, i, k, threats(i));
        if norm(delta) < 1e-9
            continue;
        end

        if ~legendAdded.moveArrow
            visibilityArgs = {"DisplayName", "Movement direction of dynamic threat"};
            legendAdded.moveArrow = true;
        else
            visibilityArgs = {"HandleVisibility", "off"};
        end

        z0 = td.circleRadii(i);
        quiver3(ax, startCenter(1), startCenter(2), z0, delta(1), delta(2), 0, 0.9, ...
            "LineWidth", 3, "MaxHeadSize", 0.8, "Color", "r", visibilityArgs{:});
    end
end

function [startCenter, delta] = dynamic_arrow_from_record(td, i, k, threat)
    startCenter = threat.center0;
    delta = threat.centerFinal - threat.center0;
    if ~isfield(td, "circleCentersDynamic") || isempty(td.circleCentersDynamic)
        return;
    end

    k = min(k, size(td.circleCentersDynamic, 1));
    centers = squeeze(td.circleCentersDynamic(1:k, i, :));
    if size(centers, 2) ~= 2
        centers = centers.';
    end
    if size(centers, 1) < 2
        return;
    end

    moved = sqrt(sum((centers - centers(1, :)).^2, 2));
    firstMoved = find(moved > 1e-6, 1, "first");
    if isempty(firstMoved)
        return;
    end
    startIndex = max(1, firstMoved - 1);
    startCenter = centers(startIndex, :);
    delta = centers(k, :) - startCenter;
end

function draw_uav_and_target(td, k, ax)
    rx = td.aircraft_position_x(:);
    ry = td.aircraft_position_y(:);
    rz = td.aircraft_position_z(:);
    n = numel(rx);
    k = min(max(k, 1), n);

    % 动图逐帧展示已经飞过的历史轨迹，最后一帧展示完整无人机轨迹。
    plot3(ax, rx(1:k), ry(1:k), rz(1:k), "o-r", ...
        "LineWidth", 1, "MarkerSize", 5, "DisplayName", "UAV trajectory");
    scatter3(ax, rx(k), ry(k), rz(k), 120, "r", "o", ...
        "filled", "LineWidth", 1.2, "HandleVisibility", "off");

    if isfield(td, "xt")
        xt = td.xt(:);
        yt = td.yt(:);
        zt = td.zt(:);
        targetK = min(k, numel(xt));
        targetMoves = any(abs(xt - xt(1)) > 1e-9) || any(abs(yt - yt(1)) > 1e-9);
        if targetMoves && targetK > 1
            plot3(ax, xt(1:targetK), yt(1:targetK), zt(1:targetK), ...
                "c", "LineWidth", 3, "DisplayName", "target trajectory");
        end
        scatter3(ax, xt(targetK), yt(targetK), zt(targetK), 250, "r", "p", ...
            "filled", "LineWidth", 1.5, "DisplayName", "target");
    end
end

function tf = is_dynamic_scene(td)
    tf = false;
    if isfield(td, "scenarioType")
        scenarioType = string(td.scenarioType);
        tf = scenarioType == "dynamic" || scenarioType == "fusion";
    end
end

function tf = is_dynamic_motion_threat(threat)
%IS_DYNAMIC_MOTION_THREAT 只给动态机动威胁画箭头，突发威胁没有移动方向。
    tf = isfield(threat, "isMoving") && threat.isMoving && ...
        ~startsWith(string(threat.name), "sudden");
end

function centers = centers_at_frame(td, k)
    if isfield(td, "circleCentersDynamic") && ~isempty(td.circleCentersDynamic)
        k = min(k, size(td.circleCentersDynamic, 1));
        centers = squeeze(td.circleCentersDynamic(k, :, :));
        if size(centers, 1) ~= td.numCircles
            centers = centers.';
        end
    else
        centers = td.circleCenters;
    end
end

function active = active_at_frame(td, k)
    activeMatrix = threat_active_matrix(td);
    if ~isempty(activeMatrix)
        k = min(k, size(activeMatrix, 1));
        active = logical(activeMatrix(k, :));
    else
        active = true(1, td.numCircles);
    end
end

function activeMatrix = threat_active_matrix(td)
%THREAT_ACTIVE_MATRIX 绘图时对突发威胁做锁存，兼容旧 mat 中的闪烁激活记录。
    activeMatrix = [];
    if ~isfield(td, "threatActive") || isempty(td.threatActive)
        return;
    end

    activeMatrix = logical(td.threatActive);
    for i = 1:size(activeMatrix, 2)
        threat = threat_info_at_index(td, i);
        if is_sudden_threat(threat)
            activeMatrix(:, i) = logical(cummax(double(activeMatrix(:, i) | ...
                recompute_sudden_trigger(td, threat, i))));
        end
    end
end

function triggered = recompute_sudden_trigger(td, threat, i)
%RECOMPUTE_SUDDEN_TRIGGER 根据无人机到突发威胁的距离重算触发，避免旧数据中激活列闪烁。
    triggered = false(size(td.time(:)));
    if ~isfield(threat, "triggerDistance") || ~isfinite(threat.triggerDistance)
        return;
    end
    centers = centers_over_time(td, i);
    if isempty(centers)
        return;
    end
    dx = td.aircraft_position_x(:) - centers(:, 1);
    dy = td.aircraft_position_y(:) - centers(:, 2);
    triggered = sqrt(dx.^2 + dy.^2) <= threat.triggerDistance;
end

function centers = centers_over_time(td, i)
    centers = [];
    if isfield(td, "circleCentersDynamic") && ~isempty(td.circleCentersDynamic)
        centers = squeeze(td.circleCentersDynamic(:, i, :));
        if size(centers, 2) ~= 2
            centers = centers.';
        end
        return;
    end
    if isfield(td, "circleCenters") && size(td.circleCenters, 1) >= i
        centers = repmat(td.circleCenters(i, :), numel(td.time), 1);
    end
end

function threat = threat_info_at_index(td, i)
    threat = struct("name", "");
    if isfield(td, "scenarioConfig") && isfield(td.scenarioConfig, "threats") && ...
            numel(td.scenarioConfig.threats) >= i
        threat = td.scenarioConfig.threats(i);
        return;
    end
    if isfield(td, "threatTrajectory") && isfield(td.threatTrajectory, "names") && ...
            numel(td.threatTrajectory.names) >= i
        threat.name = td.threatTrajectory.names{i};
    end
end

function [faceColor, faceAlpha, edgeColor, lineWidth, legendName, legendKey] = threat_style(classId, isActive, threat)
%THREAT_STYLE 只有未触发的突发威胁为灰色；动态威胁仍按武器/雷达颜色显示。
    isSuddenThreat = is_sudden_threat(threat);
    if ~isActive && isSuddenThreat
        faceColor = [0.5, 0.5, 0.5];
        faceAlpha = 0.25;
        edgeColor = "k";
        lineWidth = 1;
        legendName = "Sudden threat before activation";
        legendKey = "inactive";
    elseif classId == 1
        faceColor = "#77AC30";
        faceAlpha = 0.7;
        edgeColor = "k";
        lineWidth = 0.5;
        legendName = "Air defense weapons";
        legendKey = "weapon";
    else
        faceColor = "interp";
        faceAlpha = 0.7;
        edgeColor = "k";
        lineWidth = 0.5;
        legendName = "Air defense radar";
        legendKey = "radar";
    end
end

function tf = is_sudden_threat(threat)
    tf = isfield(threat, "name") && startsWith(string(threat.name), "sudden");
end

function label = threat_class_label(classId)
    if classId == 0
        label = "radar";
    else
        label = "weapon";
    end
end

function textValue = frame_title(td, k)
    if isfield(td, "scenarioType")
        scenarioType = string(td.scenarioType);
    else
        scenarioType = "unknown";
    end
    textValue = sprintf("%s scene, t = %.1f s", scenarioType, td.time(k));
end
