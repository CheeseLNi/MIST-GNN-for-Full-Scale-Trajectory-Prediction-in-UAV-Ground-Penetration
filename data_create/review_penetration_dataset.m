function appFigure = review_penetration_dataset(varargin)
%REVIEW_PENETRATION_DATASET 启动无人机突防数据集人工核实窗口。
% 核实通过的样本会移动到 data/dataset/<scenario>/；不合理样本可删除或按参数重新生成。
    parser = inputParser;
    parser.addParameter("unverifiedRoot", fullfile("data", "unverified_dataset"), @(x)ischar(x) || isstring(x));
    parser.addParameter("datasetRoot", fullfile("data", "dataset"), @(x)ischar(x) || isstring(x));
    parser.parse(varargin{:});
    opt = parser.Results;

    thisDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(thisDir);
    addpath(thisDir);

    state = struct();
    state.unverifiedRoot = resolve_review_path(opt.unverifiedRoot, repoRoot);
    state.datasetRoot = resolve_review_path(opt.datasetRoot, repoRoot);
    state.files = strings(0, 1);
    state.currentFile = "";
    state.currentIndex = 0;
    state.busyDepth = 0;
    state.previousPointer = "arrow";
    reviewControls = {};

    fig = uifigure("Name", "UAV Penetration Dataset Review", ...
        "Position", [30, 30, 1800, 980]);
    fig.CloseRequestFcn = @close_app;

    main = uigridlayout(fig, [1, 3]);
    main.ColumnWidth = {450, "1x", 500};
    main.RowHeight = {"1x"};

    left = uigridlayout(main, [9, 1]);
    left.RowHeight = {24, 36, 24, 36, 42, 24, "1x", 30, 42};
    left.Padding = [10, 10, 8, 10];

    uilabel(left, "Text", "未核实数据根目录");
    rootRow = uigridlayout(left, [1, 2]);
    rootRow.ColumnWidth = {"1x", 70};
    rootEdit = uieditfield(rootRow, "text", "Value", state.unverifiedRoot);
    chooseUnverifiedButton = uibutton(rootRow, "Text", "选择", "ButtonPushedFcn", @choose_unverified_root);

    uilabel(left, "Text", "场景类型");
    scenarioDrop = uidropdown(left, "Items", ["all", "static", "time_sensitive", "sudden", "dynamic", "fusion"], ...
        "Value", "all", "ValueChangedFcn", @refresh_file_list);
    chooseSingleButton = uibutton(left, "Text", "选择单个 .mat 文件", "ButtonPushedFcn", @choose_single_file);
    uilabel(left, "Text", "待核实样本列表");
    fileList = uilistbox(left, "ValueChangedFcn", @select_file_from_list);
    statusLabel = uilabel(left, "Text", "未加载", "FontColor", [0.2, 0.2, 0.2]);
    refreshListButton = uibutton(left, "Text", "刷新列表", "ButtonPushedFcn", @refresh_file_list);

    middle = uigridlayout(main, [5, 1]);
    middle.RowHeight = {32, "1x", 42, 36, 28};
    middle.Padding = [8, 10, 8, 10];
    currentLabel = uilabel(middle, "Text", "当前样本：未选择", "FontWeight", "bold");

    previewGrid = uigridlayout(middle, [1, 2]);
    previewGrid.ColumnWidth = {"1x", "1x"};
    previewGrid.RowHeight = {"1x"};
    previewGrid.Padding = [0, 0, 0, 0];

    figurePanel = uipanel(previewGrid, "Title", "Figure 交互绘图");
    figureGrid = uigridlayout(figurePanel, [1, 1]);
    figureGrid.Padding = [4, 4, 4, 4];
    sceneAxes = uiaxes(figureGrid);
    title(sceneAxes, "未选择样本");
    try
        sceneAxes.Toolbar.Visible = "on";
    catch
    end

    gifPanel = uipanel(previewGrid, "Title", "GIF 动态预览");
    gifGrid = uigridlayout(gifPanel, [1, 1]);
    gifGrid.Padding = [4, 4, 4, 4];
    gifView = uihtml(gifGrid);
    set_gif_html("选择样本后，可在本窗口生成 GIF 动态预览。");

    vizRow = uigridlayout(middle, [1, 3]);
    vizRow.ColumnWidth = {130, 150, 110};
    refreshFigureButton = uibutton(vizRow, "Text", "刷新 Figure", "ButtonPushedFcn", @draw_figure_preview);
    gifPreviewButton = uibutton(vizRow, "Text", "生成 GIF 预览", "ButtonPushedFcn", @generate_gif_preview);
    nextButton = uibutton(vizRow, "Text", "下一条", "ButtonPushedFcn", @show_next_file);

    frameRow = uigridlayout(middle, [1, 5]);
    frameRow.ColumnWidth = {80, 80, 90, 80, "1x"};
    uilabel(frameRow, "Text", "GIF 步长");
    frameStepSpinner = uispinner(frameRow, "Limits", [1, 200], "Value", 5, "RoundFractionalValues", "on");
    uilabel(frameRow, "Text", "Figure 帧");
    frameIndexEdit = uieditfield(frameRow, "text", "Value", "end");
    autoFigureCheck = uicheckbox(frameRow, "Text", "自动刷新 Figure", "Value", true);

    uilabel(middle, "Text", "提示：Figure 在本窗口内交互；GIF 预览不保存到样本目录，长轨迹会自动减少预览帧数。", ...
        "FontColor", [0.35, 0.35, 0.35]);

    right = uigridlayout(main, [12, 1]);
    right.RowHeight = {24, 36, 142, 46, 46, 24, 36, 36, 36, 36, 140, 200};
    right.Padding = [8, 10, 10, 10];

    uilabel(right, "Text", "已核实数据根目录");
    datasetRow = uigridlayout(right, [1, 2]);
    datasetRow.ColumnWidth = {"1x", 70};
    datasetEdit = uieditfield(datasetRow, "text", "Value", state.datasetRoot);
    chooseDatasetButton = uibutton(datasetRow, "Text", "选择", "ButtonPushedFcn", @choose_dataset_root);

    metadataArea = uitextarea(right, "Editable", "off", "Value", "未选择样本");

    approveRow = uigridlayout(right, [1, 3]);
    approveRow.ColumnWidth = {120, 120, 120};
    approveButton = uibutton(approveRow, "Text", "确认通过", "ButtonPushedFcn", @approve_current_file);
    deleteButton = uibutton(approveRow, "Text", "删除无效", "ButtonPushedFcn", @delete_current_file);
    regenerateButton = uibutton(approveRow, "Text", "重新生成", "ButtonPushedFcn", @regenerate_current_file);

    renumberRow = uigridlayout(right, [1, 2]);
    renumberRow.ColumnWidth = {180, 190};
    renumberCurrentButton = uibutton(renumberRow, "Text", "重编号当前文件夹", "ButtonPushedFcn", @renumber_current_folder);
    renumberDatasetButton = uibutton(renumberRow, "Text", "重编号对应 dataset", "ButtonPushedFcn", @renumber_dataset_folder);

    uilabel(right, "Text", "重生成参数");
    seedRow = uigridlayout(right, [1, 2]);
    seedRow.ColumnWidth = {120, "1x"};
    uilabel(seedRow, "Text", "seed");
    seedEdit = uieditfield(seedRow, "text", "Value", "");

    solverRow = uigridlayout(right, [1, 4]);
    solverRow.ColumnWidth = {75, "1x", 90, 80};
    uilabel(solverRow, "Text", "solver");
    solverEdit = uieditfield(solverRow, "text", "Value", "snopt");
    uilabel(solverRow, "Text", "maxAttempts");
    maxAttemptSpinner = uispinner(solverRow, "Limits", [1, 200], "Value", 20, "RoundFractionalValues", "on");

    tolRow = uigridlayout(right, [1, 2]);
    tolRow.ColumnWidth = {120, "1x"};
    uilabel(tolRow, "Text", "terminalTolerance");
    terminalTolEdit = uieditfield(tolRow, "text", "Value", "50");

    startRow = uigridlayout(right, [1, 2]);
    startRow.ColumnWidth = {120, "1x"};
    uilabel(startRow, "Text", "startIndex");
    startIndexEdit = uieditfield(startRow, "numeric", "Editable", "off");

    advancedArea = uitextarea(right, "Value", [ ...
        "dynamicThreatSpeedRange = [180,250]"; ...
        "% 其他参数按 name = value 逐行填写"], ...
        "Tooltip", "示例：numSuddenThreats = random 或 targetSpeedRange = [12,22]");
    statusPanel = uipanel(right, "Title", "当前操作状态");
    statusGrid = uigridlayout(statusPanel, [1, 1]);
    statusGrid.Padding = [6, 6, 6, 6];
    actionStatus = uitextarea(statusGrid, "Editable", "off", ...
        "Value", "等待操作。长时间操作期间会临时禁用主要按钮，避免重复触发。");

    reviewControls = {rootEdit, chooseUnverifiedButton, scenarioDrop, chooseSingleButton, ...
        fileList, refreshListButton, refreshFigureButton, gifPreviewButton, nextButton, ...
        frameStepSpinner, frameIndexEdit, autoFigureCheck, datasetEdit, chooseDatasetButton, ...
        approveButton, deleteButton, regenerateButton, renumberCurrentButton, ...
        renumberDatasetButton, seedEdit, solverEdit, maxAttemptSpinner, ...
        terminalTolEdit, advancedArea};

    refresh_file_list();

    if nargout > 0
        appFigure = fig;
    end

    function choose_unverified_root(~, ~)
        folder = uigetdir(state.unverifiedRoot, "选择 unverified_dataset 或其子文件夹");
        if isequal(folder, 0)
            return;
        end
        state.unverifiedRoot = folder;
        rootEdit.Value = folder;
        refresh_file_list();
    end

    function choose_dataset_root(~, ~)
        folder = uigetdir(state.datasetRoot, "选择 dataset 根目录");
        if isequal(folder, 0)
            return;
        end
        state.datasetRoot = folder;
        datasetEdit.Value = folder;
    end

    function choose_single_file(~, ~)
        [name, folder] = uigetfile("*.mat", "选择待核实 trajectory_data 文件", state.unverifiedRoot);
        if isequal(name, 0)
            return;
        end
        selected = string(fullfile(folder, name));
        state.files = selected;
        state.currentIndex = 1;
        fileList.Items = {char(selected)};
        fileList.Value = char(selected);
        load_current_file();
    end

    function refresh_file_list(~, ~)
        state.unverifiedRoot = rootEdit.Value;
        state.datasetRoot = datasetEdit.Value;
        files = collect_review_files(state.unverifiedRoot);
        scenarioFilter = string(scenarioDrop.Value);
        if scenarioFilter ~= "all"
            files = files(arrayfun(@(f)scenario_from_review_file(f) == scenarioFilter, files));
        end
        files = sort(files);
        state.files = files(:);

        if isempty(state.files)
            fileList.Items = "<无待核实样本>";
            fileList.Value = "<无待核实样本>";
            state.currentFile = "";
            state.currentIndex = 0;
            currentLabel.Text = "当前样本：无";
            metadataArea.Value = "当前文件夹下没有待核实 .mat 样本。";
            clear_scene_axes("当前文件夹下没有待核实样本");
            set_gif_html("当前文件夹下没有待核实样本。");
            statusLabel.Text = "0 条待核实";
            return;
        end

        items = relative_review_paths(state.files, state.unverifiedRoot);
        fileList.Items = cellstr(items);
        state.currentIndex = min(max(state.currentIndex, 1), numel(state.files));
        fileList.Value = fileList.Items{state.currentIndex};
        load_current_file();
    end

    function select_file_from_list(~, ~)
        if isempty(state.files)
            return;
        end
        idx = find(strcmp(fileList.Items, fileList.Value), 1);
        if isempty(idx)
            return;
        end
        state.currentIndex = idx;
        load_current_file();
    end

    function load_current_file()
        if isempty(state.files) || state.currentIndex < 1
            return;
        end
        state.currentFile = state.files(state.currentIndex);
        filePath = char(state.currentFile);
        currentLabel.Text = "当前样本：" + string(relative_review_path(filePath, state.unverifiedRoot));
        statusLabel.Text = sprintf("%d / %d", state.currentIndex, numel(state.files));
        startIndexEdit.Value = trajectory_file_index(filePath);
        metadataArea.Value = metadata_lines(filePath);
        update_status("已加载样本。");
        try
            currentLabel.Tooltip = filePath;
        catch
        end

        if autoFigureCheck.Value
            draw_figure_preview();
        else
            clear_scene_axes("已选择样本，点击“刷新 Figure”绘制");
        end
        set_gif_html("点击“生成 GIF 预览”在本窗口查看飞行过程。");
    end

    function draw_figure_preview(~, ~)
        filePath = current_file_or_warn();
        if strlength(filePath) == 0
            return;
        end
        begin_operation("正在刷新 Figure，请稍候...");
        try
            frameIndex = parse_frame_index(frameIndexEdit.Value, filePath);
            plot_penetration_scene(filePath, ...
                "parentAxes", sceneAxes, ...
                "showFigure", true, ...
                "saveOutput", false, ...
                "frameIndex", frameIndex);
            finish_operation("Figure 已在窗口内刷新。");
        catch ME
            finish_operation("");
            show_error(ME);
        end
    end

    function generate_gif_preview(~, ~)
        filePath = current_file_or_warn();
        if strlength(filePath) == 0
            return;
        end
        begin_operation("正在生成 GIF 预览，请稍候。预览生成期间主要按钮已临时禁用。");
        try
            drawnow limitrate;
            [html, info] = render_penetration_scene_gif_html(filePath, ...
                "frameStep", frameStepSpinner.Value, ...
                "title", relative_review_path(filePath, state.unverifiedRoot));
            gifView.HTMLSource = html;
            finish_operation(string(sprintf("GIF 预览已刷新：step=%d, frames=%d/%d。", ...
                info.frameStep, info.previewFrames, info.nFrames)));
        catch ME
            finish_operation("");
            show_error(ME);
        end
    end

    function approve_current_file(~, ~)
        filePath = current_file_or_warn();
        if strlength(filePath) == 0
            return;
        end
        state.datasetRoot = datasetEdit.Value;
        idx = state.currentIndex;
        begin_operation("正在确认通过并移动样本，请稍候...");
        try
            result = dataset_review_action("approve", filePath, ...
                "datasetRoot", state.datasetRoot);
            refresh_after_removing(idx);
            finish_operation(["确认通过，已移动到已核实数据目录。"; string(result.targetFile)]);
        catch ME
            finish_operation("");
            show_error(ME);
        end
    end

    function delete_current_file(~, ~)
        filePath = current_file_or_warn();
        if strlength(filePath) == 0
            return;
        end
        answer = uiconfirm(fig, "确认删除当前样本及同名 GIF/PNG？", ...
            "删除无效样本", "Options", ["删除", "取消"], "DefaultOption", 2, "CancelOption", 2);
        if answer ~= "删除"
            return;
        end
        idx = state.currentIndex;
        begin_operation("正在删除无效样本并刷新目录，请稍候...");
        try
            dataset_review_action("delete", filePath);
            refresh_after_removing(idx);
            finish_operation("无效样本已删除，目录已刷新。");
        catch ME
            finish_operation("");
            show_error(ME);
        end
    end

    function regenerate_current_file(~, ~)
        filePath = current_file_or_warn();
        if strlength(filePath) == 0
            return;
        end
        begin_operation("正在重新生成当前样本。该过程可能较慢，主要按钮已临时禁用。");
        try
            params = regenerate_options_from_ui();
            result = dataset_review_action("regenerate", filePath, ...
                "startIndex", trajectory_file_index(char(filePath)), ...
                "regenerateOptions", params);
            refresh_file_list();
            finish_operation(["重新生成完成，已覆盖原编号样本。"; string(result.generatedFiles)]);
        catch ME
            finish_operation("");
            show_error(ME);
        end
    end

    function renumber_current_folder(~, ~)
        filePath = current_file_or_warn();
        if strlength(filePath) == 0
            return;
        end
        folder = fileparts(char(filePath));
        begin_operation("正在重编号当前文件夹，请稍候...");
        [ok, message] = do_renumber(folder);
        refresh_file_list();
        if ok
            finish_operation(message);
        else
            finish_operation("");
        end
    end

    function renumber_dataset_folder(~, ~)
        filePath = current_file_or_warn();
        if strlength(filePath) == 0
            return;
        end
        scenarioType = scenario_from_review_file(filePath);
        state.datasetRoot = datasetEdit.Value;
        folder = scenario_output_dir(state.datasetRoot, scenarioType);
        begin_operation("正在重编号对应 dataset 文件夹，请稍候...");
        [ok, message] = do_renumber(folder);
        if ok
            finish_operation(message);
        else
            finish_operation("");
        end
    end

    function [ok, message] = do_renumber(folder)
        ok = false;
        message = strings(0, 1);
        if ~exist(folder, "dir")
            update_status(["文件夹不存在："; string(folder)]);
            return;
        end
        answer = uiconfirm(fig, "确认重编号该文件夹下所有 trajectory_data_*.mat？", ...
            "自动重编号", "Options", ["重编号", "取消"], "DefaultOption", 2, "CancelOption", 2);
        if answer ~= "重编号"
            return;
        end
        try
            report = renumber_penetration_dataset(folder);
            message = [sprintf("重编号完成：%d 个文件。", report.totalFiles); string(folder)];
            ok = true;
        catch ME
            show_error(ME);
        end
    end

    function refresh_after_removing(previousIndex)
        state.currentIndex = previousIndex;
        refresh_file_list();
        if isempty(state.files)
            return;
        end
    end

    function show_next_file(~, ~)
        if isempty(state.files)
            return;
        end
        state.currentIndex = min(state.currentIndex + 1, numel(state.files));
        fileList.Value = fileList.Items{state.currentIndex};
        load_current_file();
    end

    function params = regenerate_options_from_ui()
        params = {"maxAttempts", round(maxAttemptSpinner.Value), ...
            "nlpSolver", solverEdit.Value};
        if strlength(strtrim(seedEdit.Value)) > 0
            params = [params, {"seed", str2double(seedEdit.Value)}]; %#ok<AGROW>
        end
        if strlength(strtrim(terminalTolEdit.Value)) > 0
            params = [params, {"terminalTolerance", str2double(terminalTolEdit.Value)}]; %#ok<AGROW>
        end

        advancedParams = parse_advanced_params(advancedArea.Value);
        params = [params, advancedParams]; %#ok<AGROW>
    end

    function filePath = current_file_or_warn()
        filePath = state.currentFile;
        if strlength(filePath) == 0 || ~exist(filePath, "file")
            update_status("请先选择一个待核实样本。");
            filePath = "";
        end
    end

    function show_error(ME)
        update_status(["操作失败："; string(ME.message)]);
    end

    function begin_operation(message)
        if state.busyDepth == 0
            try
                state.previousPointer = string(fig.Pointer);
                fig.Pointer = "watch";
            catch
                state.previousPointer = "arrow";
            end
            set_review_controls_enabled("off");
        end
        state.busyDepth = state.busyDepth + 1;
        update_status(message);
        drawnow limitrate;
    end

    function finish_operation(message)
        state.busyDepth = max(0, state.busyDepth - 1);
        if state.busyDepth == 0
            set_review_controls_enabled("on");
            try
                fig.Pointer = state.previousPointer;
            catch
                fig.Pointer = "arrow";
            end
        end
        if strlength(strjoin(string(message), "")) > 0
            update_status(message);
        end
        drawnow limitrate;
    end

    function set_review_controls_enabled(enableState)
        for ii = 1:numel(reviewControls)
            control = reviewControls{ii};
            if isempty(control)
                continue;
            end
            try
                if isvalid(control)
                    control.Enable = enableState;
                end
            catch
                % 少数 UI 对象可能不支持 Enable 属性，直接跳过。
            end
        end
    end

    function update_status(message)
        message = string(message);
        message = message(:);
        if isempty(message)
            return;
        end
        message(1) = "[" + string(datetime("now", "Format", "HH:mm:ss")) + "] " + message(1);
        actionStatus.Value = message;
    end

    function close_app(~, ~)
        delete(fig);
    end

    function clear_scene_axes(message)
        cla(sceneAxes, "reset");
        grid(sceneAxes, "on");
        box(sceneAxes, "on");
        axis(sceneAxes, [0 30000 0 30000]);
        view(sceneAxes, 2);
        xlabel(sceneAxes, "X(m)");
        ylabel(sceneAxes, "Y(m)");
        title(sceneAxes, message, "Interpreter", "none");
    end

    function set_gif_html(message)
        gifView.HTMLSource = sprintf([ ...
            '<html><body style="margin:0;background:#f7f7f7;font-family:Arial;' ...
            'display:flex;align-items:center;justify-content:center;height:100%%;">' ...
            '<div style="color:#555;font-size:18px;text-align:center;padding:32px;">%s</div>' ...
            '</body></html>'], html_escape(message));
    end
end

function outputPath = resolve_review_path(pathValue, repoRoot)
    pathValue = char(pathValue);
    if isempty(regexp(pathValue, '^([A-Za-z]:[\\/]|\\\\|/)', "once"))
        outputPath = fullfile(repoRoot, pathValue);
    else
        outputPath = pathValue;
    end
end

function files = collect_review_files(rootPath)
    files = strings(0, 1);
    if ~exist(rootPath, "dir")
        return;
    end
    entries = dir(rootPath);
    for i = 1:numel(entries)
        if entries(i).isdir
            if startsWith(entries(i).name, ".")
                continue;
            end
            files = [files; collect_review_files(fullfile(rootPath, entries(i).name))]; %#ok<AGROW>
        elseif ~isempty(regexp(entries(i).name, "^trajectory_data_\d+\.mat$", "once"))
            files(end + 1, 1) = string(fullfile(rootPath, entries(i).name)); %#ok<AGROW>
        end
    end
end

function items = relative_review_paths(files, rootPath)
    items = strings(numel(files), 1);
    for i = 1:numel(files)
        items(i) = relative_review_path(files(i), rootPath);
    end
end

function rel = relative_review_path(filePath, rootPath)
    filePath = string(filePath);
    rootPath = string(rootPath);
    rel = erase(filePath, rootPath);
    rel = regexprep(rel, "^[\\/]+", "");
end

function lines = metadata_lines(filePath)
    lines = strings(0, 1);
    try
        loaded = load(filePath, "trajectory_data");
        td = loaded.trajectory_data;
        lines(end + 1) = "文件: " + string(filePath);
        lines(end + 1) = "场景: " + scenario_from_review_file(filePath);
        if isfield(td, "time")
            lines(end + 1) = sprintf("时间节点: %d, 终端时间: %.2f s", numel(td.time), td.time(end));
        end
        if isfield(td, "D")
            lines(end + 1) = sprintf("终端距目标: %.2f m", td.D(end));
        end
        if isfield(td, "numCircles")
            lines(end + 1) = sprintf("威胁数量: %d", td.numCircles);
        end
        if isfield(td, "validationReport")
            lines(end + 1) = "检测摘要: " + string(td.validationReport.summary);
        end
    catch ME
        lines = ["读取失败: " + string(ME.message)];
    end
end

function scenarioType = scenario_from_review_file(filePath)
    scenarioType = "";
    known = ["static", "time_sensitive", "sudden", "dynamic", "fusion"];
    folder = fileparts(char(filePath));
    while ~isempty(folder)
        [parent, name] = fileparts(folder);
        if any(known == string(name))
            scenarioType = string(name);
            return;
        end
        if strcmp(parent, folder)
            break;
        end
        folder = parent;
    end
    try
        loaded = load(filePath, "trajectory_data");
        if isfield(loaded, "trajectory_data") && isfield(loaded.trajectory_data, "scenarioType")
            scenarioType = string(loaded.trajectory_data.scenarioType);
        end
    catch
        scenarioType = "";
    end
end

function fileIndex = trajectory_file_index(filePath)
    [~, name] = fileparts(filePath);
    token = regexp(name, "^trajectory_data_(\d+)$", "tokens", "once");
    if isempty(token)
        fileIndex = NaN;
    else
        fileIndex = str2double(token{1});
    end
end

function frameIndex = parse_frame_index(value, filePath)
    value = strtrim(string(value));
    if value == "" || lower(value) == "end"
        loaded = load(filePath, "trajectory_data");
        frameIndex = numel(loaded.trajectory_data.time);
    else
        frameIndex = str2double(value);
        if ~isfinite(frameIndex)
            frameIndex = [];
        end
    end
end

function params = parse_advanced_params(lines)
    params = {};
    lines = string(lines);
    for i = 1:numel(lines)
        line = strtrim(lines(i));
        if line == "" || startsWith(line, "%") || startsWith(line, "#")
            continue;
        end
        parts = regexp(line, "^\s*([A-Za-z]\w*)\s*=\s*(.*?)\s*$", "tokens", "once");
        if isempty(parts)
            continue;
        end
        params = [params, {parts{1}, parse_param_value(parts{2})}]; %#ok<AGROW>
    end
end

function value = parse_param_value(textValue)
    textValue = strtrim(char(textValue));
    if strcmp(textValue, "[]")
        value = [];
        return;
    end
    numericValue = str2num(textValue); %#ok<ST2NM>
    if ~isempty(numericValue)
        value = numericValue;
        return;
    end
    if any(strcmpi(textValue, ["true", "false"]))
        value = strcmpi(textValue, "true");
        return;
    end
    if (startsWith(textValue, '"') && endsWith(textValue, '"')) || ...
            (startsWith(textValue, "'") && endsWith(textValue, "'"))
        value = string(extractBetween(string(textValue), 2, strlength(string(textValue)) - 1));
    else
        value = string(textValue);
    end
end

function textValue = html_escape(textValue)
    textValue = string(textValue);
    textValue = replace(textValue, "&", "&amp;");
    textValue = replace(textValue, "<", "&lt;");
    textValue = replace(textValue, ">", "&gt;");
    textValue = char(textValue);
end
