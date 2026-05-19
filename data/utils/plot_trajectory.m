%% 画图
clear all
close all
clc
i = randi([5001,6000])
% 指定文件夹和文件名
folder_name = 'trajectory_data_new';
file_name = sprintf('trajectory_data_%d.mat', i);
% 构建完整的文件路径
full_file_path = fullfile(folder_name, file_name);

% 加载数据
load(full_file_path);

% 无人机
rx = trajectory_data.aircraft_position_x;
ry = trajectory_data.aircraft_position_y;
rz = trajectory_data.aircraft_position_z;
t  = trajectory_data.time;
v  = trajectory_data.v;
theta = trajectory_data.theta;
phi   = trajectory_data.phi;
D  = trajectory_data.D;
nx = trajectory_data.nx;
nz = trajectory_data.nz;
gama = trajectory_data.gama;
% Pt1  = trajectory_data.Pt1;
% Pt2  = trajectory_data.Pt2;

% 障碍物
numCircles    = trajectory_data.numCircles;
circleCenters = trajectory_data.circleCenters;
circleRadii   = trajectory_data.circleRadii;
circleClass   = trajectory_data.circleClass;

% 目标
xt = trajectory_data.xt;
yt = trajectory_data.yt;
zt = trajectory_data.zt;
vt = trajectory_data.vt;
thetat = trajectory_data.thetat;

t(121, 1)

if (t <= 21)
    print('这条轨迹有错误！')
else
    % 无人机各参数
    lineW=1;
    figure(2);
    subplot(3,1,1);
    plot(t,rx,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('x (m)');
    subplot(3,1,2);
    plot(t,ry,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('y (m)');
    subplot(3,1,3);
    plot(t,rz,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('z (m)');
    figure(3);
    subplot(4,1,1);
    plot(t,v,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('V (m/s)');
    subplot(4,1,2);
    plot(t,theta/pi*180,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('倾斜角theta (°)');
    subplot(4,1,3);
    plot(t,phi/pi*180,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('方位角phi (°)');
    subplot(4,1,4);
    plot(t(2:end),D,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('distance(m)');
    % 控制量
    figure(4);
    subplot(3,1,1);
    plot(t,nx,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('nx ( )');
    subplot(3,1,2);
    plot(t,nz,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('nz ( )');
    subplot(3,1,3);
    plot(t,gama/pi*180,'o-','LineWidth', lineW);
    xlabel('time (s)'); ylabel('gama (°)');
%     % RCS威胁概率
%     figure(5);
%     Pt1 = load('pt1.txt');
%     Pt1 = [0;Pt1];
%     Pt2 = load('pt2.txt');
%     Pt2 = [0;Pt2];
%     subplot(2,1,1);
%     plot(t,Pt1,'o-','LineWidth', lineW);
%     xlabel('time (s)'); ylabel('Pt1 ');
%     subplot(2,1,2);
%     plot(t,Pt2,'o-','LineWidth', lineW);
%     xlabel('time (s)'); ylabel('Pt2 ');
    % 轨迹
    figure(1);
    [x,y,z] = sphere(50);
    z(z<0) = nan; % 假设所有球体都只显示上半部分
    
    % 初始化图例字符串列表
    legendStrings = {};
    airDefenseWeaponsAdded = false;
    airDefenseRadarAdded = false;
    
    % 假设 numCircles, circleClass, circleRadii, circleCenters 已经定义
    for i = 1:numCircles
        if circleClass(i) == 1 && ~airDefenseWeaponsAdded
            surf(circleRadii(i)*(x+circleCenters(i,1)/circleRadii(i)), ...
                 circleRadii(i)*(y+circleCenters(i,2)/circleRadii(i)), ...
                 circleRadii(i)*z, 'FaceColor','#77AC30');
            legendStrings{end+1} = 'Air defense weapons';

            airDefenseWeaponsAdded = true;
        elseif ~circleClass(i) && ~airDefenseRadarAdded
            surf(circleRadii(i)*(x+circleCenters(i,1)/circleRadii(i)), ...
                 circleRadii(i)*(y+circleCenters(i,2)/circleRadii(i)), ...
                 circleRadii(i)*z, 'FaceColor','interp');
            legendStrings{end+1} = 'Air defense radar';
            airDefenseRadarAdded = true;
        % 如果已经添加了图例，则不需要再次添加相同的图形，但可以通过hold on保持图形显示
        else
            if circleClass(i) == 1
                 surf(circleRadii(i)*(x+circleCenters(i,1)/circleRadii(i)), ...
                     circleRadii(i)*(y+circleCenters(i,2)/circleRadii(i)), ...
                     circleRadii(i)*z, 'FaceColor','#77AC30', 'HandleVisibility','off'); % 不显示图例的图形句柄设置为不可见
            else
                surf(circleRadii(i)*(x+circleCenters(i,1)/circleRadii(i)), ...
                     circleRadii(i)*(y+circleCenters(i,2)/circleRadii(i)), ...
                     circleRadii(i)*z, 'FaceColor','interp', 'HandleVisibility','off'); % 不显示图例的图形句柄设置为不可见
            end
        end
        hold on;
    end
    
    % 绘制其他轨迹
    plot3(rx,ry,rz,'o-r','LineWidth',1, 'MarkerSize', 5);
    legendStrings{end+1} = 'UAV penetration trajectory';
    plot3(xt, yt, zt, 'kp', 'MarkerSize', 18, 'MarkerFaceColor', 'r', ...
          'MarkerEdgeColor', 'k', 'LineWidth', 2);
    legendStrings{end+1} = 'Target trajectory';
    
    % 设置轴范围和网格，添加图例
    axis([0 30000 0 30000]);
    grid on;
%     set(gca, 'XTick', [], 'YTick', [], 'ZTick', []);
    box on;
    lgd = legend(legendStrings, ...
    'Location','southoutside', ...
    'Orientation','horizontal', ...
    'NumColumns',4, ...
    'FontSize',12, ...
    'Box','off');
 end
