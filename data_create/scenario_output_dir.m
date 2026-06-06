function outDir = scenario_output_dir(outputRoot, scenarioType)
%SCENARIO_OUTPUT_DIR 返回未验证数据集的场景子目录。

    rootDir = char(outputRoot);
    if ~is_absolute_path(rootDir)
        thisDir = fileparts(mfilename("fullpath"));
        repoRoot = fileparts(thisDir);
        rootDir = fullfile(repoRoot, rootDir);
    end

    outDir = fullfile(rootDir, char(lower(string(scenarioType))));
end

function tf = is_absolute_path(pathValue)
%IS_ABSOLUTE_PATH 兼容 Windows 盘符、UNC 路径和类 Unix 绝对路径。
    tf = ~isempty(regexp(pathValue, '^([A-Za-z]:[\\/]|\\\\|/)', 'once'));
end
