function test_dataset_review_actions()
%TEST_DATASET_REVIEW_ACTIONS 验证人工核实模块的核心文件操作。
    thisDir = fileparts(mfilename("fullpath"));
    addpath(thisDir);

    rootDir = tempname(tempdir);
    cleanup = onCleanup(@()cleanup_folder(rootDir));
    unverifiedRoot = fullfile(rootDir, "unverified_dataset");
    datasetRoot = fullfile(rootDir, "dataset");
    mkdir(fullfile(unverifiedRoot, "static"));
    mkdir(datasetRoot);

    sourceFile = fullfile(unverifiedRoot, "static", "trajectory_data_5.mat");
    write_minimal_record(sourceFile, "static");
    write_text_file(replace_extension(sourceFile, ".gif"), "gif-placeholder");

    result = dataset_review_action("approve", sourceFile, ...
        "datasetRoot", datasetRoot);
    assert(result.success);
    assert(~exist(sourceFile, "file"));
    assert(exist(fullfile(datasetRoot, "static", "trajectory_data_5.mat"), "file") == 2);
    assert(exist(fullfile(datasetRoot, "static", "trajectory_data_5.gif"), "file") == 2);

    deleteFile = fullfile(unverifiedRoot, "static", "trajectory_data_8.mat");
    write_minimal_record(deleteFile, "static");
    write_text_file(replace_extension(deleteFile, ".png"), "png-placeholder");
    result = dataset_review_action("delete", deleteFile);
    assert(result.success);
    assert(~exist(deleteFile, "file"));
    assert(~exist(replace_extension(deleteFile, ".png"), "file"));

    renumberDir = fullfile(rootDir, "dataset", "static");
    write_minimal_record(fullfile(renumberDir, "trajectory_data_20.mat"), "static");
    write_minimal_record(fullfile(renumberDir, "trajectory_data_30.mat"), "static");
    report = renumber_penetration_dataset(renumberDir, "startIndex", 1);
    assert(report.totalFiles == 3);
    assert(exist(fullfile(renumberDir, "trajectory_data_1.mat"), "file") == 2);
    assert(exist(fullfile(renumberDir, "trajectory_data_2.mat"), "file") == 2);
    assert(exist(fullfile(renumberDir, "trajectory_data_3.mat"), "file") == 2);

    fprintf("test_dataset_review_actions passed\n");
end

function write_minimal_record(filePath, scenarioType)
    trajectory_data = struct();
    trajectory_data.scenarioType = char(scenarioType);
    trajectory_data.time = [0; 1];
    trajectory_data.aircraft_position_x = [0; 1];
    trajectory_data.aircraft_position_y = [0; 1];
    trajectory_data.aircraft_position_z = [100; 100];
    trajectory_data.xt = [1; 1];
    trajectory_data.yt = [1; 1];
    trajectory_data.zt = [100; 100];
    save(filePath, "trajectory_data");
end

function write_text_file(filePath, textValue)
    fid = fopen(filePath, "w");
    assert(fid > 0);
    cleaner = onCleanup(@()fclose(fid));
    fprintf(fid, "%s", textValue);
end

function outputPath = replace_extension(filePath, newExt)
    [folder, name] = fileparts(filePath);
    outputPath = fullfile(folder, name + string(newExt));
end

function cleanup_folder(folder)
    if exist(folder, "dir")
        rmdir(folder, "s");
    end
end
