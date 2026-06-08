function [html, info] = render_penetration_scene_gif_html(dataOrFile, varargin)
%RENDER_PENETRATION_SCENE_GIF_HTML 生成可嵌入 uihtml 的轨迹 GIF 预览。
% GUI 只接收 base64 数据流，不会在样本目录下额外保存 GIF 文件。
    parser = inputParser;
    parser.addRequired("dataOrFile");
    parser.addParameter("frameStep", [], @(x)isempty(x) || (isscalar(x) && x >= 1));
    parser.addParameter("maxFrames", 70, @(x)isscalar(x) && x >= 2);
    parser.addParameter("title", "GIF 动态预览", @(x)ischar(x) || isstring(x));
    parser.parse(dataOrFile, varargin{:});
    opt = parser.Results;

    td = load_trajectory_data(dataOrFile);
    nFrames = numel(td.time);
    frameStep = choose_preview_frame_step(opt.frameStep, nFrames, opt.maxFrames);

    tempGif = char(string(tempname(tempdir)) + ".gif");
    cleanupFile = onCleanup(@()delete_if_exists(tempGif));

    plot_penetration_scene(td, ...
        "outputFile", tempGif, ...
        "showFigure", false, ...
        "saveOutput", true, ...
        "makeGif", true, ...
        "frameStep", frameStep);

    bytes = read_binary_file(tempGif);
    encoded = base64_encode_bytes(bytes);

    info = struct();
    info.nFrames = nFrames;
    info.frameStep = frameStep;
    info.previewFrames = numel(unique([1:frameStep:nFrames, nFrames]));

    html = sprintf([ ...
        '<html><head><style>' ...
        'html,body{margin:0;width:100%%;height:100%%;background:#f7f7f7;font-family:Arial,Helvetica,sans-serif;overflow:hidden;}' ...
        '.wrap{height:100%%;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:8px;box-sizing:border-box;}' ...
        '.title{font-size:14px;color:#333;margin-bottom:6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%%;}' ...
        'img{max-width:100%%;max-height:calc(100%% - 30px);object-fit:contain;border:1px solid #d0d0d0;background:white;}' ...
        '</style></head><body><div class="wrap">' ...
        '<div class="title">%s | step=%d | frames=%d/%d</div>' ...
        '<img src="data:image/gif;base64,%s">' ...
        '</div></body></html>'], ...
        html_escape(opt.title), info.frameStep, info.previewFrames, info.nFrames, encoded);
end

function td = load_trajectory_data(dataOrFile)
    if isstruct(dataOrFile)
        td = dataOrFile;
        return;
    end
    loaded = load(dataOrFile, "trajectory_data");
    if ~isfield(loaded, "trajectory_data")
        error("render_penetration_scene_gif_html:MissingTrajectory", ...
            "文件中未找到 trajectory_data 变量: %s", string(dataOrFile));
    end
    td = loaded.trajectory_data;
end

function frameStep = choose_preview_frame_step(requestedStep, nFrames, maxFrames)
%CHOOSE_PREVIEW_FRAME_STEP 限制预览帧数，避免 GUI 因长 GIF 生成而卡顿。
    if isempty(requestedStep)
        frameStep = max(1, ceil(nFrames / maxFrames));
    else
        frameStep = max(1, round(requestedStep));
        if numel(unique([1:frameStep:nFrames, nFrames])) > maxFrames
            frameStep = max(frameStep, ceil(nFrames / maxFrames));
        end
    end
end

function bytes = read_binary_file(filePath)
    fid = fopen(filePath, "r");
    if fid < 0
        error("render_penetration_scene_gif_html:ReadFailed", ...
            "无法读取临时 GIF 文件: %s", filePath);
    end
    cleanupFid = onCleanup(@()fclose(fid));
    bytes = fread(fid, Inf, "*uint8");
    clear cleanupFid;
end

function encoded = base64_encode_bytes(bytes)
    try
        encoded = char(matlab.net.base64encode(bytes));
    catch
        encoder = java.util.Base64.getEncoder();
        encoded = char(encoder.encodeToString(bytes));
    end
end

function delete_if_exists(filePath)
    if exist(filePath, "file")
        delete(filePath);
    end
end

function textValue = html_escape(textValue)
    textValue = string(textValue);
    textValue = replace(textValue, "&", "&amp;");
    textValue = replace(textValue, "<", "&lt;");
    textValue = replace(textValue, ">", "&gt;");
    textValue = char(textValue);
end
