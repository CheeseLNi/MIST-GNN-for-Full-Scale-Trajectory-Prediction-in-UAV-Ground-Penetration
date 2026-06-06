# 无人机突防轨迹数据集生成说明

本文件夹只保留新的数据集生成工作流。未人工验证的数据默认写入
`data/unverified_dataset/<场景类型>`，不要直接覆盖 `data/dataset` 中已经验证的数据。

## 运行入口

常用单场景生成入口是 `generate_penetration_dataset.m`：

```matlab
addpath('data_create');
files = generate_penetration_dataset("static", "numSamples", 3, "seed", 20260605);
```

论文数据集复现入口是 `generate_mist_gnn_dataset.m`，默认按五类场景各生成 10000 条样本，并可透传 `dynamicThreatSpeedRange`、`numSuddenThreats` 等场景参数：

```matlab
files = generate_mist_gnn_dataset("numSamplesPerScenario", 2, "seed", 20260606);
```

同一场景一次生成多条样本时，程序会为每条样本派生不同随机种子；默认情况下防空单元数量、位置、半径和类别都会重新随机，不会出现多条样本共享同一套场景的问题。

## 主要文件

| 文件 | 作用 |
| --- | --- |
| `generate_mist_gnn_dataset.m` | MIST-GNN 论文数据集复现入口，默认按五类场景各生成 10000 条未验证样本，并可透传场景参数。 |
| `generate_penetration_dataset.m` | 数据集生成主入口，负责构造场景、调用 GPOPS 求解、检测轨迹并保存 `.mat`。 |
| `build_penetration_scenario.m` | 构造 `static`、`time_sensitive`、`sudden`、`dynamic`、`fusion` 五类场景。 |
| `assemble_trajectory_data.m` | 组装无人机、目标、威胁轨迹、威胁激活状态和检测概率。 |
| `sample_target_trajectory.m` | 按时间采样静止或移动目标的位置、速度和方向。 |
| `sample_threat_centers.m` | 按时间采样静态威胁和动态威胁中心。 |
| `sample_threat_activity.m` | 判断威胁是否生效；突发威胁按距离触发，触发后不再消失。 |
| `compute_detection_probability.m` | 计算雷达检测概率字段 `Pt`。 |
| `validate_penetration_trajectory.m` | 检测起点安全、终点距离、武器穿越和目标可达性。 |
| `plot_penetration_scene.m` | 绘制静态 PNG 或动态 GIF，也可显示一张可交互 `figure`。 |
| `plot_mat_variables.m` | 读取指定 `.mat` 文件中的变量并输出关键变量随时间变化图。 |
| `generate_behavior_showcase_scenarios.m` | 生成突发、动态和融合威胁展示样本，便于观察明显规避行为。 |

## 通用生成参数

| 参数 | 含义 |
| --- | --- |
| `scenarioTypes` | 场景类型：`"static"`、`"time_sensitive"`、`"sudden"`、`"dynamic"`、`"fusion"`；也可以传多个。 |
| `numSamples` | 每类场景生成多少条轨迹。 |
| `startIndex` | 输出编号起点，例如 `20001` 会生成 `trajectory_data_20001.mat`。 |
| `outputRoot` | 未验证数据输出根目录，默认 `data/unverified_dataset`。 |
| `seed` | 随机种子；批量生成时每条样本自动派生不同种子。 |
| `saveFailed` | 是否保存失败记录，默认 `false`。默认不会把无效轨迹写入数据集。 |
| `validateTrajectory` | 保存前是否做合理性检测，默认 `true`。 |
| `maxAttempts` | 单条样本最多重新随机生成/求解次数，默认 `10`；失败后跳过该编号并继续后续样本。 |
| `terminalTolerance` | 终点到目标终点的容差；为空时使用场景攻击半径，当前默认 `50 m`。 |
| `terminalTime` | 终端时间硬约束，常用于固定时敏目标的攻击窗口。 |
| `nlpSolver` | GPOPS-II 调用的 NLP 求解器，默认 `"snopt"`；也可根据本机环境配置为 `"ipopt"`。 |
| `startClearanceRadius` | 起点周围安全半径，默认 `2500 m`；任何威胁初始覆盖区不得压住该区域。 |
| `radarIntrusionWeight` | 进入雷达覆盖区的软惩罚权重，默认 `12`；雷达不是硬禁入区，但求解会尽量降低 `Pt` 积分并减少进入雷达范围。 |
| `weaponProximityWeight` | 靠近防空武器边界的软惩罚权重，默认 `4`；防空武器本身仍是硬禁入区。 |
| `weaponProximityBuffer` | 武器边界外侧的软规避缓冲裕度，默认 `0.35`，用于减少贴边穿过。 |

## 威胁随机模式

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `baseThreatMode` | `"random"` | 基础防空单元生成模式。`"random"` 按规则随机数量、类别、位置和半径；`"reference"` 使用论文参考固定布局。 |
| `numCircles` | 随机 | 基础防空单元总数。为空时通常随机为 4 到 7 个。 |
| `numRadars` | 随机 | 基础雷达数量。为空时按基础单元数量随机选择，其余为防空武器。 |
| `suddenThreatMode` | `"random"` | 突发威胁生成模式。`"random"` 在起点到目标通道附近自动布设；`"reference"` 使用固定参考突发威胁。 |
| `numSuddenThreats` | 随机 | 突发威胁数量。为空、`"random"` 或 `[1,2]` 时随机生成 1 到 2 个；传 `1` 或 `2` 时固定数量。 |
| `suddenThreatClassMode` | `"random"` | 突发威胁类别模式：`"mixed"`、`"random"`、`"radar"`、`"weapon"`。突发威胁可以是雷达，也可以是防空武器。 |
| `suddenThreatClass` | 空 | 直接指定突发威胁类别，`0` 为雷达，`1` 为防空武器；可传标量或向量。 |
| `dynamicThreatMode` | `"random"` | 动态威胁生成模式。`"random"` 按拦截通道预置规则生成；`"reference"` 使用固定参考动态威胁。 |
| `numDynamicThreats` | 随机 | 动态威胁数量。为空、`"random"` 或 `[1,2]` 时随机生成 1 到 2 个；传 `1` 或 `2` 时固定数量。 |
| `dynamicThreatClassMode` | `"random"` | 动态威胁类别模式：`"mixed"`、`"random"`、`"radar"`、`"weapon"`。动态威胁可以是雷达，也可以是防空武器。 |
| `dynamicThreatClass` | 空 | 直接指定动态威胁类别，`0` 为雷达，`1` 为防空武器；可传标量或向量。 |

随机基础威胁会避开无人机起点安全区和目标攻击终点，并限制威胁之间的重叠程度，既避免无人机无法起飞和无法到达目标，也避免场景过于简单。
轨迹求解中，防空武器覆盖区是硬禁入约束；雷达覆盖区是软约束，会通过 `Pt` 积分和进入雷达半球的软惩罚尽量避开，但在无法完全绕开时允许进入。

## 运动和触发参数

| 参数 | 含义 |
| --- | --- |
| `targetSpeed` / `targetHeading` | 目标固定速度和方向，单位分别为 `m/s` 和 `rad`。 |
| `targetSpeedRange` / `targetHeadingRange` | 目标速度、方向随机范围 `[min,max]`；时敏目标默认速度 `[12,22] m/s`，方向 `[-pi,pi]`。 |
| `threatSpeedRange` / `threatHeadingRange` | 通用威胁运动速度、方向随机范围；场景专用参数为空时使用。 |
| `suddenTriggerDistanceRange` | 突发威胁触发距离范围，单位 `m`；可用 `2x2` 矩阵分别设置两个突发威胁。 |
| `suddenActiveStartRange` | 兼容旧字段，仅作为参考出现时间记录；当前突发威胁实际由无人机距离触发。 |
| `dynamicMoveStartRange` | 动态威胁时间触发阈值，单位 `s`；默认 `45 s`，即距离未触发时，时间大于该值后触发。 |
| `dynamicMoveDurationRange` | 动态威胁运动持续时间范围，单位 `s`。 |
| `dynamicThreatSpeedRange` | 动态威胁固定随机速度范围，单位 `m/s`；每个动态威胁生成一个固定速度，运动过程中不再随距离变化。默认 `[220,300]` 更强调强拦截；批量生成可改为 `[180,250]` 或 `[150,250]` 提高稳定性。 |
| `dynamicThreatHeadingRange` | 兼容旧参数；当前动态威胁在触发时刻根据无人机前进方向预判拦截地点，不再按随机方向运动。 |
| `dynamicResponseDistanceRange` | 动态威胁距离触发阈值，单位 `m`；默认 `10000 m`。无人机与动态威胁初始中心距离小于该值时触发。 |
| `dynamicLatestTriggerTimeRange` | 兼容旧参数；当前动态威胁实际启动时间由 `dynamicMoveStartRange` 控制，建议新生成任务不要再依赖该参数。 |

时敏目标会先随机速度和方向，再检测典型攻击窗口内目标是否越界或落入防空武器覆盖区；不合理则重新采样。突发威胁出现前不参与轨迹决策，距离触发后才激活且不再消失。动态威胁按预置拦截规则布设在通道附近，优先由距离触发，若距离一直未触发则由时间触发：无人机与动态威胁初始中心距离小于 10 km，或时间大于 45 s 时触发。触发后动态威胁按固定随机速度，根据触发时刻无人机前进方向预判拦截地点，运动到该拦截点后停止。

## 五类场景示例

静态突防场景：

```matlab
files = generate_penetration_dataset("static", ...
    "numSamples", 10, ...
    "startIndex", 1, ...
    "seed", 20260605);
```

时敏目标场景：

```matlab
files = generate_penetration_dataset("time_sensitive", ...
    "numSamples", 10, ...
    "startIndex", 10001, ...
    "seed", 20260605, ...
    "targetSpeedRange", [12, 22], ...
    "targetHeadingRange", [-pi, pi]);
```

突发威胁场景：

```matlab
files = generate_penetration_dataset("sudden", ...
    "numSamples", 10, ...
    "startIndex", 20001, ...
    "seed", 20260605, ...
    "suddenThreatMode", "random", ...
    "numSuddenThreats", "random", ...
    "suddenThreatClassMode", "random", ...
    "suddenTriggerDistanceRange", [5500, 7500]);
```

动态威胁场景：

```matlab
files = generate_penetration_dataset("dynamic", ...
    "numSamples", 10, ...
    "startIndex", 30001, ...
    "seed", 20260605, ...
    "dynamicThreatMode", "random", ...
    "numDynamicThreats", "random", ...
    "dynamicThreatClassMode", "random", ...
    "dynamicMoveStartRange", [45, 45], ...
    "dynamicResponseDistanceRange", [10000, 10000], ...
    "dynamicMoveDurationRange", [60, 110], ...
    "dynamicThreatSpeedRange", [180, 250]); % 若更重视通过率，可用 [150,250]
```

融合场景：

```matlab
files = generate_penetration_dataset("fusion", ...
    "numSamples", 10, ...
    "startIndex", 40001, ...
    "seed", 20260605, ...
    "baseThreatMode", "random", ...
    "suddenThreatMode", "random", ...
    "dynamicThreatMode", "random");
```

批量生成一万条未验证样本时，可适当提高 `maxAttempts`，失败样本默认会跳过并继续：

```matlab
files = generate_penetration_dataset("dynamic", ...
    "numSamples", 10000, ...
    "startIndex", 30001, ...
    "seed", 20260605, ...
    "maxAttempts", 20, ...
    "saveFailed", false);
```

## 行为展示样本

如果需要优先观察“突发威胁导致改航”和“动态威胁拦截导致规避”的效果，可运行：

```matlab
addpath('data_create');
files = generate_behavior_showcase_scenarios( ...
    "seed", 20260605, ...
    "showFigure", true);
```

脚本会生成突发、动态和融合三类展示样本，并保存对应 GIF。展示参数会提高雷达软惩罚、武器近距惩罚，并让特殊威胁更靠近名义航路；它适合人工检查行为特征，不建议直接作为一万条数据集的唯一参数配置。

## 绘图

只显示一张可交互 `figure`，不保存：

```matlab
plot_penetration_scene(files(1), ...
    "showFigure", true, ...
    "saveOutput", false);
```

保存 PNG/GIF，并显示最后一帧供交互检查：

```matlab
plot_penetration_scene(files(1), ...
    "showFigure", true, ...
    "saveOutput", true, ...
    "frameStep", 5);
```

绘图约定：

- 防空武器为绿色带线半球，雷达为插值色带线半球。
- 图例统一放在图下方，避免遮挡场景信息。
- 突发威胁未触发前为灰色带线半球，触发后按自身类别恢复为雷达或防空武器样式，并标注 `Sudden radar/weapon` 和 `Sudden trigger point`。
- 动态威胁使用其本身类别颜色，不使用突发威胁灰色；额外标注 `Dynamic radar/weapon` 和 `Dynamic threat trajectory`。可交互 figure 中会显示动态威胁运动箭头，GIF 中不画箭头以减少遮挡。
- 动态 GIF 每帧只绘制动态威胁当前半球位置，同时用每一时刻中心点连线表示历史轨迹，不再把每一时刻的半球全部叠加。
- GIF 写入时每帧都会恢复背景，避免半透明突发威胁或动态威胁在下一帧留下残影。
- 无人机轨迹统一显示为 `UAV trajectory`，不再拆成历史、预测和真实轨迹。
- 动图会展示无人机飞行历史、目标移动过程、突发威胁出现过程和动态威胁移动过程。

## `.mat` 变量分析

读取指定 `.mat` 文件，绘制其中关键变量随时间变化、矩阵热力图和 XY 轨迹总览：

```matlab
outputFiles = plot_mat_variables("data/unverified_dataset/dynamic/trajectory_data_30001.mat", ...
    "showFigure", true, ...
    "saveOutput", true);
```

默认输出到该 `.mat` 文件同级目录下的 `<文件名>_variable_plots` 文件夹。脚本会优先识别 `trajectory_data` 结构体中的 `time`、无人机状态、目标状态、威胁激活状态、威胁动态中心和检测概率等字段。
