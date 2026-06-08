function report = renumber_penetration_dataset(rootPath, varargin)
%RENUMBER_PENETRATION_DATASET 对数据集文件夹中的 trajectory_data_*.mat 自动重编号。
% 输入可以是某个场景子文件夹，也可以是包含多个场景子文件夹的根目录。
    parser = inputParser;
    parser.addRequired("rootPath", @(x)ischar(x) || isstring(x));
    parser.addParameter("startIndex", [], @(x)isempty(x) || (isnumeric(x) && isscalar(x)));
    parser.addParameter("recursive", true, @(x)islogical(x) || isnumeric(x));
    parser.addParameter("dryRun", false, @(x)islogical(x) || isnumeric(x));
    parser.parse(rootPath, varargin{:});
    opt = parser.Results;

    rootPath = char(rootPath);
    if ~exist(rootPath, "dir")
        error("renumber_penetration_dataset:MissingFolder", "文件夹不存在: %s", rootPath);
    end

    folders = folders_to_renumber(rootPath, logical(opt.recursive));
    folderReports = repmat(struct("folder", "", "startIndex", [], ...
        "totalFiles", 0, "oldFiles", strings(0, 1), "newFiles", strings(0, 1)), numel(folders), 1);

    totalFiles = 0;
    for i = 1:numel(folders)
        folderReports(i) = renumber_one_folder(folders(i), opt);
        totalFiles = totalFiles + folderReports(i).totalFiles;
    end

    report = struct();
    report.rootPath = rootPath;
    report.totalFolders = numel(folders);
    report.totalFiles = totalFiles;
    report.folderReports = folderReports;
end

function folders = folders_to_renumber(rootPath, recursive)
    if ~isempty(dir(fullfile(rootPath, "trajectory_data_*.mat")))
        folders = string(rootPath);
        return;
    end

    folders = strings(0, 1);
    if ~recursive
        return;
    end

    allFolders = collect_subfolders(rootPath);
    for i = 1:numel(allFolders)
        if ~isempty(dir(fullfile(allFolders(i), "trajectory_data_*.mat")))
            folders(end + 1, 1) = allFolders(i); %#ok<AGROW>
        end
    end
end

function folders = collect_subfolders(rootPath)
    folders = strings(0, 1);
    children = dir(rootPath);
    for i = 1:numel(children)
        if ~children(i).isdir || startsWith(children(i).name, ".")
            continue;
        end
        childPath = string(fullfile(rootPath, children(i).name));
        folders(end + 1, 1) = childPath; %#ok<AGROW>
        folders = [folders; collect_subfolders(childPath)]; %#ok<AGROW>
    end
end

function folderReport = renumber_one_folder(folder, opt)
    folder = char(folder);
    files = dir(fullfile(folder, "trajectory_data_*.mat"));
    [~, order] = sort_trajectory_files(files);
    files = files(order);

    startIndex = opt.startIndex;
    if isempty(startIndex)
        startIndex = default_start_index(folder);
    end

    oldFiles = strings(numel(files), 1);
    newFiles = strings(numel(files), 1);
    for i = 1:numel(files)
        oldFiles(i) = string(fullfile(folder, files(i).name));
        newFiles(i) = string(fullfile(folder, sprintf("trajectory_data_%d.mat", startIndex + i - 1)));
    end

    folderReport = struct("folder", string(folder), "startIndex", startIndex, ...
        "totalFiles", numel(files), "oldFiles", oldFiles, "newFiles", newFiles);
    if logical(opt.dryRun) || isempty(files)
        return;
    end

    tempBases = strings(numel(files), 1);
    stamp = char(java_free_stamp());
    for i = 1:numel(files)
        [~, oldBase] = fileparts(oldFiles(i));
        tempBase = sprintf("__renumber_tmp_%s_%04d", stamp, i);
        tempBases(i) = string(fullfile(folder, tempBase + ".mat"));
        move_base_files(folder, oldBase, tempBase, false);
    end

    for i = 1:numel(files)
        [~, tempBase] = fileparts(tempBases(i));
        [~, newBase] = fileparts(newFiles(i));
        move_base_files(folder, tempBase, newBase, true);
    end
end

function [indices, order] = sort_trajectory_files(files)
    indices = nan(numel(files), 1);
    for i = 1:numel(files)
        token = regexp(files(i).name, "^trajectory_data_(\d+)\.mat$", "tokens", "once");
        if ~isempty(token)
            indices(i) = str2double(token{1});
        end
    end
    fallback = (1:numel(files)).';
    [~, order] = sortrows([isnan(indices), indices, fallback], [1, 2, 3]);
end

function startIndex = default_start_index(folder)
    [~, scenarioName] = fileparts(folder);
    switch string(scenarioName)
        case "static"
            startIndex = 1;
        case "time_sensitive"
            startIndex = 10001;
        case "sudden"
            startIndex = 20001;
        case "dynamic"
            startIndex = 30001;
        case "fusion"
            startIndex = 40001;
        otherwise
            startIndex = 1;
    end
end

function move_base_files(folder, oldBase, newBase, overwrite)
    suffixes = [".mat", ".gif", ".png"];
    for i = 1:numel(suffixes)
        source = fullfile(folder, oldBase + suffixes(i));
        target = fullfile(folder, newBase + suffixes(i));
        if exist(source, "file")
            move_one(source, target, overwrite);
        end
    end

    sourceDir = fullfile(folder, oldBase + "_variable_plots");
    targetDir = fullfile(folder, newBase + "_variable_plots");
    if exist(sourceDir, "dir")
        move_one(sourceDir, targetDir, overwrite);
    end
end

function move_one(source, target, overwrite)
    if exist(target, "file") || exist(target, "dir")
        if ~overwrite
            error("renumber_penetration_dataset:TargetExists", "目标已存在: %s", target);
        end
        if exist(target, "dir")
            rmdir(target, "s");
        else
            delete(target);
        end
    end
    [ok, msg] = movefile(source, target, "f");
    if ~ok
        error("renumber_penetration_dataset:MoveFailed", "重命名失败: %s", msg);
    end
end

function stamp = java_free_stamp()
    stamp = string(sprintf("%0.0f", now * 86400000000));
end
