function Pt = compute_detection_probability(scenario, time, state, control)
%COMPUTE_DETECTION_PROBABILITY 计算各雷达对无人机的探测概率。
% Pt 的列顺序对应 scenario.radarIndices，非雷达威胁不参与探测概率积分。

    time = time(:);
    if isempty(scenario.radarIndices)
        Pt = zeros(numel(time), 0);
        return;
    end

    x = state(:, 1);
    y = state(:, 2);
    z = state(:, 3);
    theta = state(:, 5);
    phi = state(:, 6);
    gama = control(:, 3);

    centers = sample_threat_centers(scenario, time, state);
    active = sample_threat_activity(scenario, time, state(:, 1:6));

    % 椭球 RCS 模型参数，沿用原始代码与论文第 3 章设置。
    a = 0.3172;
    b = 0.1784;
    c = 1.003;
    c1 = 1.01;
    c2 = 1.25e-18;

    Pt = zeros(numel(time), numel(scenario.radarIndices));
    for j = 1:numel(scenario.radarIndices)
        threatIndex = scenario.radarIndices(j);
        xr = centers(:, threatIndex, 1);
        yr = centers(:, threatIndex, 2);
        zr = zeros(size(xr));

        dx = x - xr;
        dy = y - yr;
        dz = z - zr;

        thetar = atan2(dy, dx);
        lambda = theta - phi + pi;
        r = sqrt(dx.^2 + dy.^2 + dz.^2);
        phir = atan2(dz, sqrt(dx.^2 + dy.^2));
        acosArg = max(-1, min(1, cos(thetar) .* cos(lambda)));
        lambdae = acos(acosArg);
        gamae = gama - atan2(tan(phir), tan(lambda));

        denom = a^2 .* sin(lambdae).^2 .* cos(gamae).^2 + ...
                b^2 .* sin(lambdae).^2 .* sin(gamae).^2 + ...
                c^2 .* cos(lambdae).^2;
        sigma = (pi * a^2 * b^2 * c^2) ./ max(realmin, denom).^2;

        Pt(:, j) = 1 ./ (1 + (c2 .* r.^4 ./ max(realmin, sigma)).^c1);
        Pt(:, j) = Pt(:, j) .* double(active(:, threatIndex));
    end
end
