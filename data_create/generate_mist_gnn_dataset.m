function files = generate_mist_gnn_dataset(varargin)
%GENERATE_MIST_GNN_DATASET 复现 MIST-GNN 论文使用的五类突防轨迹数据集。
% 默认每类场景生成 10000 条未人工验证样本，输出到 data/unverified_dataset。
% 调试时建议传入较小的 numSamplesPerScenario，例如 2 或 [2 2 2 2 2]。

    parser = inputParser;
    parser.KeepUnmatched = true;
    parser.addParameter("scenarioTypes", ["static", "time_sensitive", "sudden", "dynamic", "fusion"], ...
        @(x)ischar(x) || isstring(x) || iscellstr(x));
    parser.addParameter("numSamplesPerScenario", 10000, @(x)isnumeric(x) && ~isempty(x) && all(x(:) >= 0));
    parser.addParameter("startIndices", [1, 10001, 20001, 30001, 40001], ...
        @(x)isnumeric(x) && ~isempty(x));
    parser.addParameter("outputRoot", fullfile("data", "unverified_dataset"), @(x)ischar(x) || isstring(x));
    parser.addParameter("seed", 20260606, @(x)isempty(x) || isnumeric(x));
    parser.addParameter("maxAttempts", 20, @(x)isnumeric(x) && isscalar(x) && x >= 1);
    parser.addParameter("nlpSolver", "snopt", @(x)ischar(x) || isstring(x));
    parser.addParameter("saveFailed", false, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("terminalTolerance", 50, @(x)isnumeric(x) && isscalar(x) && x > 0);
    parser.parse(varargin{:});
    opt = parser.Results;
    passthroughOptions = unmatched_to_name_value(parser.Unmatched);

    scenarioTypes = string(opt.scenarioTypes);
    counts = expand_numeric_option(opt.numSamplesPerScenario, numel(scenarioTypes), "numSamplesPerScenario");
    startIndices = resolve_start_indices(opt.startIndices, scenarioTypes);

    addpath(fileparts(mfilename("fullpath")));
    files = strings(0, 1);

    for i = 1:numel(scenarioTypes)
        scenarioType = scenarioTypes(i);
        fprintf("Generating MIST-GNN %s dataset: %d samples\n", scenarioType, counts(i));
        generated = generate_penetration_dataset(scenarioType, ...
            "numSamples", counts(i), ...
            "startIndex", startIndices(i), ...
            "outputRoot", opt.outputRoot, ...
            "seed", scenario_seed(opt.seed, i), ...
            "maxAttempts", opt.maxAttempts, ...
            "saveFailed", logical(opt.saveFailed), ...
            "terminalTolerance", opt.terminalTolerance, ...
            "nlpSolver", opt.nlpSolver, ...
            passthroughOptions{:});
        files = [files; generated(:)]; %#ok<AGROW>
    end
end

function args = unmatched_to_name_value(unmatched)
    names = fieldnames(unmatched);
    args = cell(1, numel(names) * 2);
    for i = 1:numel(names)
        args{2 * i - 1} = names{i};
        args{2 * i} = unmatched.(names{i});
    end
end

function startIndices = resolve_start_indices(values, scenarioTypes)
    defaultScenarioTypes = ["static", "time_sensitive", "sudden", "dynamic", "fusion"];
    defaultStartIndices = [1, 10001, 20001, 30001, 40001];
    values = reshape(values, 1, []);
    if isequal(values, defaultStartIndices)
        startIndices = zeros(1, numel(scenarioTypes));
        for i = 1:numel(scenarioTypes)
            idx = find(defaultScenarioTypes == scenarioTypes(i), 1);
            if isempty(idx)
                error("generate_mist_gnn_dataset:UnknownScenarioType", ...
                    "未知场景类型：%s", scenarioTypes(i));
            end
            startIndices(i) = defaultStartIndices(idx);
        end
        return;
    end
    startIndices = expand_numeric_option(values, numel(scenarioTypes), "startIndices");
end

function values = expand_numeric_option(values, n, optionName)
    values = reshape(values, 1, []);
    if isscalar(values)
        values = repmat(values, 1, n);
    end
    if numel(values) ~= n
        error("generate_mist_gnn_dataset:InvalidOptionLength", ...
            "%s 必须为标量，或与 scenarioTypes 等长。", optionName);
    end
end

function seedValue = scenario_seed(baseSeed, index)
    if isempty(baseSeed)
        seedValue = [];
    else
        seedValue = baseSeed + (index - 1) * 1000000;
    end
end
