function target = sample_target_trajectory(scenario, t)
%SAMPLE_TARGET_TRAJECTORY 按时间采样目标匀速直线运动轨迹。

    t = t(:);
    speed = scenario.target.speed;
    heading = scenario.target.heading;

    target = struct();
    target.time = t;
    target.x = scenario.target.x0 + speed * cos(heading) .* t;
    target.y = scenario.target.y0 + speed * sin(heading) .* t;
    target.z = scenario.target.z0 * ones(size(t));
    target.v = speed * ones(size(t));
    target.theta = heading * ones(size(t));
end
