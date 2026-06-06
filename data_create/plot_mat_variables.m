function outputFiles = plot_mat_variables(matFile, varargin)
%PLOT_MAT_VARIABLES 读取 .mat 文件并绘制其中变量随时间变化的可视化图。
% 若文件中包含 trajectory_data，则优先展开该结构体；否则分析顶层变量。
%
% 示例：
%   plot_mat_variables("data/unverified_dataset/static/trajectory_data_1.mat");
%   plot_mat_variables(file, "showFigure", false, "outputFolder", "analysis_figures");

    parser = inputParser;
    parser.addRequired("matFile", @(x)ischar(x) || isstring(x));
    parser.addParameter("outputFolder", "", @(x)ischar(x) || isstring(x));
    parser.addParameter("showFigure", true, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("saveOutput", true, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("maxSeriesPerFigure", 8, @(x)isnumeric(x) && isscalar(x) && x >= 1);
    parser.parse(matFile, varargin{:});
    opt = parser.Results;

    matFile = char(matFile);
    loaded = load(matFile);
    [data, dataName] = select_data_to_plot(loaded);
    time = infer_time_vector(data);
    outputFolder = resolve_output_folder(matFile, opt.outputFolder);
    if logical(opt.saveOutput) && ~exist(outputFolder, "dir")
        mkdir(outputFolder);
    end

    outputFiles = strings(0, 1);
    series = collect_time_series(data, time);
    matrixSeries = collect_time_matrices(data, time);

    outputFiles = [outputFiles; plot_time_series_pages(series, time, dataName, outputFolder, opt)];
    outputFiles = [outputFiles; plot_matrix_series(matrixSeries, time, dataName, outputFolder, opt)];
    outputFiles = [outputFiles; plot_xy_overview(data, dataName, outputFolder, opt)];
end

function [data, dataName] = select_data_to_plot(loaded)
    if isfield(loaded, "trajectory_data") && isstruct(loaded.trajectory_data)
        data = loaded.trajectory_data;
        dataName = "trajectory_data";
        return;
    end
    data = loaded;
    dataName = "mat_variables";
end

function time = infer_time_vector(data)
    if isstruct(data) && isfield(data, "time") && isnumeric(data.time)
        time = data.time(:);
        return;
    end
    fields = fieldnames(data);
    for i = 1:numel(fields)
        value = data.(fields{i});
        if isnumeric(value) && isvector(value) && numel(value) > 1
            time = (1:numel(value)).';
            return;
        end
    end
    time = (1:1).';
end

function outputFolder = resolve_output_folder(matFile, requestedFolder)
    if strlength(string(requestedFolder)) > 0
        outputFolder = char(requestedFolder);
        return;
    end
    [folder, name] = fileparts(matFile);
    outputFolder = fullfile(folder, name + "_variable_plots");
    outputFolder = char(outputFolder);
end

function series = collect_time_series(data, time)
    series = struct("name", strings(0, 1), "value", {});
    if ~isstruct(data)
        return;
    end
    fields = fieldnames(data);
    for i = 1:numel(fields)
        value = data.(fields{i});
        if isnumeric(value) && isvector(value) && numel(value) == numel(time)
            series(end + 1).name = string(fields{i}); %#ok<AGROW>
            series(end).value = value(:);
        end
    end
end

function matrices = collect_time_matrices(data, time)
    matrices = struct("name", strings(0, 1), "value", {});
    if ~isstruct(data)
        return;
    end
    fields = fieldnames(data);
    for i = 1:numel(fields)
        value = data.(fields{i});
        if isnumeric(value) && ismatrix(value) && size(value, 1) == numel(time) && size(value, 2) > 1
            matrices(end + 1).name = string(fields{i}); %#ok<AGROW>
            matrices(end).value = value;
        end
    end
end

function outputFiles = plot_time_series_pages(series, time, dataName, outputFolder, opt)
    outputFiles = strings(0, 1);
    if isempty(series)
        return;
    end
    pageSize = round(opt.maxSeriesPerFigure);
    nPages = ceil(numel(series) / pageSize);
    for page = 1:nPages
        ids = (page - 1) * pageSize + 1:min(page * pageSize, numel(series));
        fig = create_analysis_figure(opt.showFigure);
        tiledlayout(fig, numel(ids), 1, "TileSpacing", "compact", "Padding", "compact");
        for j = 1:numel(ids)
            nexttile;
            plot(time, series(ids(j)).value, "LineWidth", 1.4);
            grid on;
            xlabel("time");
            ylabel(series(ids(j)).name, "Interpreter", "none");
            title(series(ids(j)).name, "Interpreter", "none");
        end
        sgtitle(sprintf("%s time-series variables page %d", dataName, page), "Interpreter", "none");
        outputFiles = [outputFiles; save_or_keep_figure(fig, outputFolder, "time_series_" + page, opt)]; %#ok<AGROW>
    end
end

function outputFiles = plot_matrix_series(matrices, time, dataName, outputFolder, opt)
    outputFiles = strings(0, 1);
    for i = 1:numel(matrices)
        fig = create_analysis_figure(opt.showFigure);
        value = matrices(i).value;
        tiledlayout(fig, 2, 1, "TileSpacing", "compact", "Padding", "compact");
        nexttile;
        plot(time, value, "LineWidth", 1.2);
        grid on;
        xlabel("time");
        ylabel(matrices(i).name, "Interpreter", "none");
        title(matrices(i).name + " columns", "Interpreter", "none");
        nexttile;
        imagesc(1:size(value, 2), time, value);
        axis tight;
        colorbar;
        xlabel("column");
        ylabel("time");
        title(matrices(i).name + " heatmap", "Interpreter", "none");
        sgtitle(sprintf("%s matrix variable: %s", dataName, matrices(i).name), "Interpreter", "none");
        outputFiles = [outputFiles; save_or_keep_figure(fig, outputFolder, "matrix_" + matrices(i).name, opt)]; %#ok<AGROW>
    end
end

function outputFile = plot_xy_overview(data, dataName, outputFolder, opt)
    outputFile = strings(0, 1);
    if ~isstruct(data) || ~all(isfield(data, ["aircraft_position_x", "aircraft_position_y"]))
        return;
    end
    fig = create_analysis_figure(opt.showFigure);
    plot(data.aircraft_position_x, data.aircraft_position_y, "r-o", "LineWidth", 1.3, ...
        "MarkerSize", 4, "DisplayName", "UAV");
    hold on;
    if all(isfield(data, ["xt", "yt"]))
        plot(data.xt, data.yt, "b-", "LineWidth", 1.6, "DisplayName", "target");
    end
    if isfield(data, "circleCenters")
        scatter(data.circleCenters(:, 1), data.circleCenters(:, 2), 80, "k", "filled", ...
            "DisplayName", "threat centers");
    end
    axis equal;
    grid on;
    xlabel("X(m)");
    ylabel("Y(m)");
    title(dataName + " XY overview", "Interpreter", "none");
    legend("Location", "best");
    outputFile = save_or_keep_figure(fig, outputFolder, "xy_overview", opt);
end

function fig = create_analysis_figure(showFigure)
    if logical(showFigure)
        visibility = "on";
    else
        visibility = "off";
    end
    fig = figure("Color", "w", "Visible", visibility, "Position", [200, 100, 1100, 850]);
end

function outputFile = save_or_keep_figure(fig, outputFolder, name, opt)
    outputFile = strings(0, 1);
    if logical(opt.saveOutput)
        safeName = regexprep(char(name), "[^\w\-]", "_");
        outputFile = string(fullfile(outputFolder, safeName + ".png"));
        saveas(fig, outputFile);
    end
    if ~logical(opt.showFigure)
        close(fig);
    end
end
