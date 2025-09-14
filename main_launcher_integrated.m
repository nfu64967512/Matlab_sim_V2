function main_drone_simulator_launcher()
    % =================================================================
    % GPU加速無人機群飛模擬器 - 整合版啟動腳本
    % 
    % 主要功能：
    % - 統一的面向對象架構
    % - GPU加速碰撞檢測
    % - 實時軌跡分析與視覺化
    % - QGC文件導入與解析
    % - 智能避撞策略生成
    % =================================================================
    
    % 清理環境
    clear; clc; close all;
    cleanup_existing_timers();
    
    % 顯示歡迎信息
    display_welcome_message();
    
    % 檢查文件依賴
    if ~check_file_dependencies()
        return;
    end
    
    % 啟動模擬器
    try
        fprintf('正在啟動無人機群飛模擬器...\n');
        simulator = DroneSwarmSimulator();
        
        fprintf('=== 模擬器啟動成功 ===\n');
        fprintf('請使用控制面板操作：\n');
        fprintf('1. 載入QGC文件或創建演示數據\n');
        fprintf('2. 分析碰撞風險\n');
        fprintf('3. 開始模擬觀察避撞效果\n\n');
        
        % 顯示使用提示
        display_usage_tips();
        
        % 將模擬器對象存儲到base workspace供調試使用
        assignin('base', 'simulator', simulator);
        fprintf('模擬器對象已存儲到變量 ''simulator''\n');
        
    catch ME
        fprintf('錯誤：模擬器啟動失敗\n');
        fprintf('錯誤信息：%s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('錯誤位置：%s (第%d行)\n', ME.stack(1).file, ME.stack(1).line);
        end
        
        % 提供故障排除建議
        provide_troubleshooting_tips(ME);
    end
end

function cleanup_existing_timers()
    % 清理現有定時器
    timers = timerfind();
    if ~isempty(timers)
        stop(timers);
        delete(timers);
        fprintf('已清理 %d 個現有定時器\n', length(timers));
    end
end

function display_welcome_message()
    % 顯示歡迎信息
    fprintf('\n');
    fprintf('=================================================================\n');
    fprintf('    GPU加速無人機群飛模擬器 - 整合專業版 v8.0\n');
    fprintf('=================================================================\n');
    fprintf('🚁 先進無人機群飛模擬與碰撞避免\n');
    fprintf('⚡ GPU/CPU自適應計算架構\n');
    fprintf('🎯 李群幾何控制理論應用\n');
    fprintf('🛡️ 實時碰撞檢測與避撞策略\n');
    fprintf('📊 3D軌跡視覺化與分析\n');
    fprintf('🔧 統一的面向對象設計\n');
    fprintf('=================================================================\n\n');
end

function dependencies_ok = check_file_dependencies()
    % 檢查文件依賴
    dependencies_ok = true;
    
    fprintf('正在檢查文件依賴...\n');
    
    required_files = {
        'DroneSwarmSimulator.m', '主模擬器類別';
        'QGCFileParser.m', 'QGC文件解析器';
        'CollisionDetectionSystem.m', '碰撞檢測系統';
        'CoordinateSystem.m', '座標系統轉換器';
        'VisualizationSystem.m', '視覺化系統';
    };
    
    missing_files = {};
    
    for i = 1:size(required_files, 1)
        filename = required_files{i, 1};
        description = required_files{i, 2};
        
        if exist(filename, 'file') == 2
            fprintf('✅ %s - %s\n', filename, description);
        else
            fprintf('❌ %s - %s (缺失)\n', filename, description);
            missing_files{end+1} = filename; %#ok<AGROW>
            dependencies_ok = false;
        end
    end
    
    if ~dependencies_ok
        fprintf('\n⚠️ 缺少必要的文件，模擬器無法啟動\n');
        fprintf('缺失的文件：\n');
        for i = 1:length(missing_files)
            fprintf('  - %s\n', missing_files{i});
        end
        fprintf('\n請確保所有必要的.m文件都在MATLAB路徑中\n');
    else
        fprintf('✅ 所有文件依賴檢查通過\n\n');
    end
end

function display_usage_tips()
    % 顯示使用提示
    fprintf('=== 快速使用指南 ===\n');
    fprintf('📁 文件載入：\n');
    fprintf('   - 載入QGC文件：導入QGroundControl waypoint文件\n');
    fprintf('   - 創建演示數據：生成4架無人機的交叉飛行任務\n');
    fprintf('   - 支援格式：.waypoints, .txt, .csv\n\n');
    
    fprintf('🎮 模擬控制：\n');
    fprintf('   - 開始模擬：實時播放飛行軌跡\n');
    fprintf('   - 暫停/停止：控制模擬進度\n');
    fprintf('   - 分析碰撞：檢測軌跡衝突點\n\n');
    
    fprintf('⚙️ 參數調整：\n');
    fprintf('   - 安全距離：調整無人機間最小安全間距\n');
    fprintf('   - GPU模式：啟用/禁用GPU加速計算\n');
    fprintf('   - 播放速度：控制模擬播放速度\n\n');
    
    fprintf('📊 監控信息：\n');
    fprintf('   - 3D視圖：實時軌跡和碰撞警告顯示\n');
    fprintf('   - 狀態面板：無人機狀態和安全信息\n');
    fprintf('   - 紅色連線：碰撞警告指示\n\n');
    
    fprintf('🛡️ 安全功能：\n');
    fprintf('   - 軌跡衝突預測\n');
    fprintf('   - 實時碰撞警告\n');
    fprintf('   - 自動避撞策略生成\n');
    fprintf('   - LOITER等待命令\n\n');
end

function provide_troubleshooting_tips(ME)
    % 提供故障排除建議
    fprintf('\n=== 故障排除建議 ===\n');
    
    error_msg = ME.message;
    
    if contains(error_msg, 'Undefined')
        fprintf('🔧 類別或函數未定義錯誤：\n');
        fprintf('   - 檢查所有.m文件是否在MATLAB路徑中\n');
        fprintf('   - 運行 addpath(pwd) 將當前目錄加入路徑\n');
        fprintf('   - 檢查文件名是否與類別名一致\n\n');
    end
    
    if contains(error_msg, 'GPU') || contains(error_msg, 'gpuArray')
        fprintf('🖥️ GPU相關錯誤：\n');
        fprintf('   - 檢查Parallel Computing Toolbox是否安裝\n');
        fprintf('   - 運行 gpuDevice() 檢查GPU狀態\n');
        fprintf('   - 可以禁用GPU模式使用CPU計算\n\n');
    end
    
    if contains(error_msg, 'license')
        fprintf('📜 授權錯誤：\n');
        fprintf('   - 檢查相關工具箱授權\n');
        fprintf('   - 運行 license(''test'', ''toolbox_name'') 檢查\n\n');
    end
    
    fprintf('💡 通用解決方案：\n');
    fprintf('   1. 重啟MATLAB\n');
    fprintf('   2. 清理工作空間：clear all; close all; clc\n');
    fprintf('   3. 檢查MATLAB版本（建議2019b或更新）\n');
    fprintf('   4. 檢查內存是否足夠\n\n');
    
    fprintf('🆘 如果問題持續，請檢查：\n');
    fprintf('   - MATLAB版本兼容性\n');
    fprintf('   - 系統內存使用情況\n');
    fprintf('   - 防毒軟體是否阻止文件訪問\n');
end

%% =================================================================
%% 演示和測試函數
%% =================================================================

function run_demo()
    % 運行演示模式
    fprintf('=== 演示模式啟動 ===\n');
    
    try
        % 啟動模擬器
        simulator = DroneSwarmSimulator();
        
        % 創建演示數據
        simulator.create_demo_data();
        
        % 分析碰撞
        simulator.analyze_collisions();
        
        % 自動開始模擬
        pause(2); % 等待GUI穩定
        simulator.start_simulation();
        
        fprintf('演示模擬已開始，觀察避撞效果\n');
        
    catch ME
        fprintf('演示模式失敗: %s\n', ME.message);
    end
end

function run_performance_test()
    % 運行性能測試
    fprintf('=== 性能測試模式 ===\n');
    
    % 測試GPU vs CPU性能
    test_collision_detection_performance();
    
    % 測試軌跡計算性能
    test_trajectory_performance();
end

function test_collision_detection_performance()
    % 測試碰撞檢測性能
    fprintf('正在測試碰撞檢測性能...\n');
    
    n_drones_list = [2, 4, 8, 16];
    n_timepoints = 1000;
    
    fprintf('測試配置：%d 時間點\n', n_timepoints);
    fprintf('無人機數量\tCPU時間(s)\tGPU時間(s)\t加速比\n');
    fprintf('-----------------------------------------\n');
    
    for i = 1:length(n_drones_list)
        n_drones = n_drones_list(i);
        
        % 生成測試數據
        positions = rand(n_timepoints, n_drones, 3, 'single') * 1000;
        
        % CPU測試
        tic;
        cpu_conflicts = test_collision_cpu(positions);
        cpu_time = toc;
        
        % GPU測試
        gpu_time = NaN;
        speedup = NaN;
        
        if license('test', 'Parallel_Computing_Toolbox')
            try
                gpu_positions = gpuArray(positions);
                tic;
                gpu_conflicts = test_collision_gpu(gpu_positions);
                gpu_time = toc;
                speedup = cpu_time / gpu_time;
                clear gpu_positions;
            catch
                % GPU測試失敗
            end
        end
        
        % 顯示結果
        if isnan(gpu_time)
            fprintf('%d\t\t%.3f\t\tN/A\t\tN/A\n', n_drones, cpu_time);
        else
            fprintf('%d\t\t%.3f\t\t%.3f\t\t%.1fx\n', n_drones, cpu_time, gpu_time, speedup);
        end
    end
end

function conflicts = test_collision_cpu(positions)
    % CPU碰撞檢測測試
    [n_times, n_drones, ~] = size(positions);
    conflicts = 0;
    safety_distance = 5.0;
    
    for t = 1:n_times
        for i = 1:n_drones
            for j = (i+1):n_drones
                pos_i = squeeze(positions(t, i, :));
                pos_j = squeeze(positions(t, j, :));
                
                distance = norm(pos_i - pos_j);
                if distance < safety_distance
                    conflicts = conflicts + 1;
                end
            end
        end
    end
end

function conflicts = test_collision_gpu(gpu_positions)
    % GPU碰撞檢測測試
    [n_times, n_drones, ~] = size(gpu_positions);
    conflicts = 0;
    safety_distance = 5.0;
    
    for t = 1:n_times
        current_positions = squeeze(gpu_positions(t, :, :));
        
        % 計算距離矩陣
        distance_matrix = zeros(n_drones, n_drones, 'gpuArray', 'single');
        for i = 1:n_drones
            for j = (i+1):n_drones
                diff = current_positions(i, :) - current_positions(j, :);
                distance_matrix(i, j) = sqrt(sum(diff.^2));
            end
        end
        
        % 統計衝突
        conflict_mask = distance_matrix < safety_distance & distance_matrix > 0;
        conflicts = conflicts + sum(conflict_mask, 'all');
    end
    
    conflicts = gather(conflicts);
end

function test_trajectory_performance()
    % 測試軌跡計算性能
    fprintf('\n正在測試軌跡計算性能...\n');
    
    n_waypoints_list = [10, 50, 100, 500];
    
    fprintf('航點數量\t計算時間(s)\n');
    fprintf('--------------------\n');
    
    for i = 1:length(n_waypoints_list)
        n_waypoints = n_waypoints_list(i);
        
        % 生成測試航點
        waypoints = generate_test_waypoints(n_waypoints);
        
        % 測試軌跡計算
        tic;
        trajectory = calculate_test_trajectory(waypoints);
        computation_time = toc;
        
        fprintf('%d\t\t%.3f\n', n_waypoints, computation_time);
    end
end

function waypoints = generate_test_waypoints(n)
    % 生成測試航點
    waypoints = [];
    
    base_lat = 23.7121;
    base_lon = 120.5363;
    base_alt = 50.0;
    
    for i = 1:n
        wp = struct();
        wp.seq = i - 1;
        wp.lat = base_lat + (i-1) * 0.0001;
        wp.lon = base_lon + (i-1) * 0.0001;
        wp.alt = base_alt + sin(i/10) * 20;
        wp.cmd = 16;
        wp.param1 = 0; wp.param2 = 0; wp.param3 = 0; wp.param4 = 0;
        
        waypoints = [waypoints; wp]; %#ok<AGROW>
    end
end

function trajectory = calculate_test_trajectory(waypoints)
    % 計算測試軌跡
    trajectory = [];
    current_time = 0;
    cruise_speed = 8.0;
    
    for i = 1:length(waypoints)
        wp = waypoints(i);
        
        traj_point = struct();
        traj_point.time = current_time;
        traj_point.x = (wp.lat - 23.7121) * 111111;
        traj_point.y = (wp.lon - 120.5363) * 111111 * cos(deg2rad(23.7121));
        traj_point.z = wp.alt;
        traj_point.phase = 'auto';
        traj_point.speed = cruise_speed;
        
        trajectory = [trajectory; traj_point]; %#ok<AGROW>
        
        if i > 1
            prev_point = trajectory(i-1);
            distance = sqrt((traj_point.x - prev_point.x)^2 + ...
                           (traj_point.y - prev_point.y)^2 + ...
                           (traj_point.z - prev_point.z)^2);
            current_time = current_time + distance / cruise_speed;
            trajectory(i).time = current_time;
        end
    end
end

%% =================================================================
%% 主要入口點
%% =================================================================

% 根據運行方式選擇執行模式
if ~exist('DroneSwarmSimulator', 'class')
    fprintf('警告：找不到DroneSwarmSimulator類別\n');
    fprintf('請確保所有相關的.m文件都在MATLAB路徑中\n');
    
    user_choice = questdlg('選擇運行模式：', '模擬器啟動', '演示模式', '性能測試', '退出', '演示模式');
    
    switch user_choice
        case '演示模式'
            fprintf('由於缺少核心文件，無法運行演示模式\n');
        case '性能測試'
            run_performance_test();
        case '退出'
            fprintf('程序退出\n');
        otherwise
            fprintf('程序退出\n');
    end
else
    % 正常啟動模擬器
    main_drone_simulator_launcher();
end