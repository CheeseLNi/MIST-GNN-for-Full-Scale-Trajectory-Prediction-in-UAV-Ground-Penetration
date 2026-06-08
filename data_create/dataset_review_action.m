function result = dataset_review_action(action, filePath, varargin)
%DATASET_REVIEW_ACTION 人工核实流程中的单文件操作接口。
% 支持 approve/delete/regenerate 三类动作；GUI 和脚本都可以复用。
    parser = inputParser;
    parser.addRequired("action", @(x)ischar(x) || isstring(x));
    parser.addRequired("filePath", @(x)ischar(x) || isstring(x));
    parser.addParameter("datasetRoot", fullfile("data", "dataset"), @(x)ischar(x) || isstring(x));
    parser.addParameter("unverifiedRoot", fullfile("data", "unverified_dataset"), @(x)ischar(x) || isstring(x));
    parser.addParameter("scenarioType", "", @(x)ischar(x) || isstring(x));
    parser.addParameter("startIndex", [], @(x)isempty(x) || (isnumeric(x) && isscalar(x)));
    parser.addParameter("overwrite", false, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("deleteSidecars", true, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("regenerateOptions", {}, @(x)iscell(x));
    parser.parse(action, filePath, varargin{:});
    opt = parser.Results;

    action = lower(string(action));
    filePath = char(filePath);

    result = struct("success", false, "action", char(action), ...
        "sourceFile", filePath, "targetFile", "", "generatedFiles", strings(0, 1), ...
        "scenarioType", "", "message", "");

    switch action
        case {"approve", "accept", "valid"}
            [scenarioType, ~, ~] = infer_review_context(filePath, opt.scenarioType, opt.unverifiedRoot);
            result.scenarioType = char(scenarioType);
            result.targetFile = approve_file(filePath, scenarioType, opt);
            result.success = true;
            result.message = "approved";

        case {"delete", "remove", "reject"}
            delete_review_file(filePath, logical(opt.deleteSidecars));
            result.success = true;
            result.message = "deleted";

        case {"regenerate", "regen"}
            [scenarioType, ~, outputRoot] = infer_review_context(filePath, opt.scenarioType, opt.unverifiedRoot);
            result.scenarioType = char(scenarioType);
            fileIndex = opt.startIndex;
            if isempty(fileIndex)
                fileIndex = trajectory_file_index(filePath);
            end
            result.generatedFiles = regenerate_file(scenarioType, fileIndex, outputRoot, opt.regenerateOptions);
            result.success = ~isempty(result.generatedFiles);
            result.message = "regenerated";

        otherwise
            error("dataset_review_action:UnknownAction", "未知核实动作: %s", action);
    end
end

function targetFile = approve_file(filePath, scenarioType, opt)
    if ~exist(filePath, "file")
        error("dataset_review_action:MissingFile", "待核实文件不存在: %s", filePath);
    end

    targetDir = scenario_output_dir(opt.datasetRoot, scenarioType);
    if ~exist(targetDir, "dir")
        mkdir(targetDir);
    end

    [~, name, ext] = fileparts(filePath);
    targetFile = fullfile(targetDir, [name, ext]);
    move_one_file(filePath, targetFile, logical(opt.overwrite));

    if logical(opt.deleteSidecars)
        sidecars = review_sidecar_paths(filePath);
        for i = 1:numel(sidecars)
            sidecar = sidecars(i);
            if exist(sidecar, "file") || exist(sidecar, "dir")
                [~, sideName, sideExt] = fileparts(sidecar);
                targetSidecar = fullfile(targetDir, sideName + sideExt);
                move_one_file(char(sidecar), char(targetSidecar), logical(opt.overwrite));
            end
        end
    end
end

function delete_review_file(filePath, deleteSidecars)
    if exist(filePath, "file")
        delete(filePath);
    end

    if deleteSidecars
        sidecars = review_sidecar_paths(filePath);
        for i = 1:numel(sidecars)
            sidecar = char(sidecars(i));
            if exist(sidecar, "file")
                delete(sidecar);
            elseif exist(sidecar, "dir")
                rmdir(sidecar, "s");
            end
        end
    end
end

function generatedFiles = regenerate_file(scenarioType, fileIndex, outputRoot, regenerateOptions)
    if isempty(fileIndex) || ~isfinite(fileIndex)
        error("dataset_review_action:MissingIndex", "无法从文件名推断重新生成编号。");
    end

    generatedFiles = generate_penetration_dataset(scenarioType, ...
        "numSamples", 1, ...
        "startIndex", fileIndex, ...
        "outputRoot", outputRoot, ...
        regenerateOptions{:});
    if isempty(generatedFiles)
        error("dataset_review_action:RegenerationFailed", ...
            "重新生成未产生有效样本，请调整参数或提高 maxAttempts。");
    end
end

function move_one_file(sourceFile, targetFile, overwrite)
    sourceFile = char(sourceFile);
    targetFile = char(targetFile);
    if exist(targetFile, "file") || exist(targetFile, "dir")
        if ~overwrite
            error("dataset_review_action:TargetExists", "目标已存在: %s", targetFile);
        end
        if exist(targetFile, "dir")
            rmdir(targetFile, "s");
        else
            delete(targetFile);
        end
    end
    [ok, msg] = movefile(sourceFile, targetFile, "f");
    if ~ok
        error("dataset_review_action:MoveFailed", "移动文件失败: %s", msg);
    end
end

function [scenarioType, scenarioDir, outputRoot] = infer_review_context(filePath, scenarioOverride, fallbackRoot)
    scenarioType = string(scenarioOverride);
    if strlength(scenarioType) == 0
        scenarioType = scenario_from_path(filePath);
    end
    if strlength(scenarioType) == 0
        scenarioType = scenario_from_record(filePath);
    end
    if strlength(scenarioType) == 0
        error("dataset_review_action:UnknownScenario", ...
            "无法判断场景类型，请传入 scenarioType 参数: %s", filePath);
    end

    scenarioDir = scenario_dir_from_path(filePath, scenarioType);
    if strlength(scenarioDir) == 0
        scenarioDir = scenario_output_dir(fallbackRoot, scenarioType);
    end
    outputRoot = fileparts(char(scenarioDir));
end

function scenarioType = scenario_from_path(filePath)
    scenarioType = "";
    known = ["static", "time_sensitive", "sudden", "dynamic", "fusion"];
    folder = fileparts(filePath);
    while ~isempty(folder)
        [parent, name] = fileparts(folder);
        if any(known == string(name))
            scenarioType = string(name);
            return;
        end
        if strcmp(parent, folder)
            return;
        end
        folder = parent;
    end
end

function scenarioType = scenario_from_record(filePath)
    scenarioType = "";
    if ~exist(filePath, "file")
        return;
    end
    loaded = load(filePath, "trajectory_data");
    if isfield(loaded, "trajectory_data") && isfield(loaded.trajectory_data, "scenarioType")
        scenarioType = string(loaded.trajectory_data.scenarioType);
    end
end

function scenarioDir = scenario_dir_from_path(filePath, scenarioType)
    scenarioDir = "";
    folder = fileparts(filePath);
    while ~isempty(folder)
        [parent, name] = fileparts(folder);
        if string(name) == string(scenarioType)
            scenarioDir = string(folder);
            return;
        end
        if strcmp(parent, folder)
            return;
        end
        folder = parent;
    end
end

function fileIndex = trajectory_file_index(filePath)
    [~, name] = fileparts(filePath);
    token = regexp(name, "^trajectory_data_(\d+)$", "tokens", "once");
    if isempty(token)
        fileIndex = [];
    else
        fileIndex = str2double(token{1});
    end
end

function sidecars = review_sidecar_paths(filePath)
    [folder, name] = fileparts(filePath);
    sidecars = [
        string(fullfile(folder, name + ".gif"))
        string(fullfile(folder, name + ".png"))
        string(fullfile(folder, name + "_variable_plots"))
    ];
end
