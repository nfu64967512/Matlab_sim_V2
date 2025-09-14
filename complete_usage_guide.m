%% ========================================================================
%% 增強版無人機群飛模擬器 - 完整使用指南
%% ========================================================================
%
% 版本: v9.0 Professional Edition
% 作者: 無人機模擬專家團隊
% 日期: 2025年
%
% 本指南將詳細說明如何使用增強版無人機群飛模擬器的所有功能
%
%% ========================================================================

%% 1. 基本啟動方式
%% ========================================================================

% === 方法 1: 一鍵啟動 (推薦) ===
Enhanced_Drone_Simulator_Launcher();

% === 方法 2: 手動啟動 ===
% 如果需要自定義配置，可以手動逐步啟動
clear; clc; close all;

% 檢查系統需求
fprintf('🔍 檢查系統需求...\n');
if exist('GPU_Enhanced_DroneSwarmSimulator.m', 'file') == 2
    fprintf('✅ 找到GPU增強模擬器\n');
else
    fprintf('❌ 找不到GPU增強模擬器文件\n');
    return;
end

% 啟動增強模擬器
simulator = GPU_Enhanced_DroneSwarmSimulator();

%% 2. 物理參數配置示例
%% ========================================================================

% === 配置不同類型的無人機 ===

% DJI Phantom風格配置
fprintf('\n📐 配置DJI Phantom風格無人機...\n');
phantom_physics = EnhancedQuadrotorPhysics('phantom');
phantom_physics.print_configuration_summary();

% FPV競速機配置
fprintf('\n🏎️ 配置FPV競速機...\n');
racing_physics = EnhancedQuadrotorPhysics('racing');
racing_physics.print_configuration_summary();

% 載重貨運機配置
fprintf('\n📦 配置載重貨運機...\n');
cargo_physics = EnhancedQuadrotorPhysics('cargo');
cargo_physics.print_configuration_summary();

% === 自定義物理參數 ===
custom_physics = EnhancedQuadrotorPhysics('standard');

% 修改軸距 (從580mm改為450mm)
config_keys = custom_physics.airframe_config.keys;
if ~isempty(config_keys)
    config = custom_physics.airframe_config(config_keys{1});
    config.wheelbase = 0.45; % 450mm軸距
    config.arm_length = 0.225; % 對應的臂長
    custom_physics.airframe_config(config_keys{1}) = config;
    
    fprintf('✅ 軸距已修改為 %.0fmm\n', config.wheelbase * 1000);
end

% 修改螺旋槳規格 (從10英吋改為8英吋)
custom_physics.propulsion_system.prop_diameter = 0.2032; % 8英吋 = 203.2mm
custom_physics.propulsion_system.prop_pitch = 0.1016;   % 4英吋螺距

fprintf('✅ 螺旋槳規格已修改為 8×4 英吋\n');

% 修改電池容量 (從5000mAh改為6000mAh)
custom_physics.battery_system.capacity_mah = 6000;
custom_physics.battery_system.capacity_wh = custom_physics.battery_system.nominal_voltage * 6.0;

fprintf('✅ 電池容量已修改為 6000mAh\n');

%% 3. 3D視覺化配置示例
%% ========================================================================

% === 創建增強3D視覺化系統 ===
if exist('simulator', 'var') && isvalid(simulator)
    fprintf('\n🎨 配置3D視覺化系統...\n');
    
    % 創建增強視覺化系統
    enhanced_viz = Enhanced3DVisualizationSystem(simulator);
    
    % 配置渲染品質
    enhanced_viz.render_quality.level = 'high';           % 高品質渲染
    enhanced_viz.render_quality.shadows_enabled = true;   % 啟用陰影
    enhanced_viz.render_quality.anti_aliasing = 4;        % 4x抗鋸齒
    
    % 配置動畫設置
    enhanced_viz.animation_settings.propeller_rotation = true;    % 螺旋槳旋轉動畫
    enhanced_viz.animation_settings.smooth_interpolation = true;  % 平滑插值
    enhanced_viz.animation_settings.frame_rate = 60;              % 60 FPS
    
    % 配置LOD系統
    enhanced_viz.lod_system.enabled = true;
    enhanced_viz.lod_system.distances = [30, 100, 300]; % 米
    enhanced_viz.lod_system.models = {'detailed', 'simplified', 'icon'};
    
    % 配置視覺效果
    enhanced_viz.particle_systems('propwash').enabled = true;     % 螺旋槳下洗流
    enhanced_viz.particle_systems('propwash').particle_count = 100;
    
    enhanced_viz.trail_systems('default').enabled = true;         % 軌跡尾巴
    enhanced_viz.trail_systems('default').max_points = 200;
    enhanced_viz.trail_systems('default').fade_time = 15.0;       % 15秒漸隱
    
    % 替換模擬器的視覺化系統
    simulator.visualization = enhanced_viz;
    
    fprintf('✅ 3D視覺化系統配置完成\n');
end

%% 4. GPU性能優化示例
%% ========================================================================

% === GPU性能測試和優化 ===
fprintf('\n⚡ GPU性能優化...\n');

% 創建性能優化器
if exist('simulator', 'var')
    optimizer = PerformanceOptimizer(simulator);
else
    optimizer = PerformanceOptimizer([]);
end

% 快速性能測試
fprintf('執行快速性能測試...\n');
run_quick_performance_test();

% 自動優化設置
fprintf('\n執行自動優化...\n');
optimized_settings = optimizer.auto_optimize_settings();

% 如果需要詳細的基準測試 (較耗時)
user_choice = input('\n是否執行完整基準測試？(y/n): ', 's');
if strcmpi(user_choice, 'y')
    fprintf('\n🏃 執行完整基準測試 (可能需要1-2分鐘)...\n');
    benchmark_results = optimizer.run_comprehensive_benchmark();
end

%% 5. 實際使用場景示例
%% ========================================================================

% === 場景 1: 創建並載入測試任務 ===
fprintf('\n🎯 場景 1: 創建測試任務\n');

if exist('simulator', 'var') && isvalid(simulator)
    try
        % 創建演示數據
        simulator.create_demo_data();
        fprintf('✅ 演示數據已創建\n');
        
        % 開始模擬
        pause(1);
        simulator.start_simulation();
        fprintf('✅ 模擬已開始\n');
        
        fprintf('💡 提示: 您現在可以在GUI中觀察無人機的飛行軌跡\n');
        fprintf('       • 使用滑鼠右鍵拖拽旋轉視角\n');
        fprintf('       • 使用滾輪縮放\n');
        fprintf('       • 點擊播放/暫停按鈕控制模擬\n');
        
    catch ME
        fprintf('❌ 演示創建失敗: %s\n', ME.message);
    end
end

% === 場景 2: 載入QGC任務文件 ===
fprintf('\n🎯 場景 2: 載入QGC任務 (示例)\n');

% 創建示例QGC任務文件
sample_qgc_file = create_sample_qgc_mission();
fprintf('✅ 示例QGC任務文件已創建: %s\n', sample_qgc_file);

if exist('simulator', 'var') && isvalid(simulator)
    try
        % 載入QGC文件 (如果存在)
        if exist(sample_qgc_file, 'file')
            % simulator.load_qgc_file(sample_qgc_file);  % 取消註釋以載入
            fprintf('💡 QGC文件已準備好載入\n');
        end
    catch ME
        fprintf('⚠️ QGC載入警告: %s\n', ME.message);
    end
end

% === 場景 3: 性能監控和調試 ===
fprintf('\n🎯 場景 3: 性能監控\n');

if exist('simulator', 'var') && simulator.use_gpu && simulator.gpu_available
    fprintf('監控GPU性能...\n');
    
    try
        gpu_info = gpuDevice();
        fprintf('   GPU型號: %s\n', gpu_info.Name);
        fprintf('   總記憶體: %.1f GB\n', gpu_info.TotalMemory / 1e9);
        fprintf('   可用記憶體: %.1f GB\n', gpu_info.AvailableMemory / 1e9);
        fprintf('   使用率: %.1f%%\n', (gpu_info.TotalMemory - gpu_info.AvailableMemory) / gpu_info.TotalMemory * 100);
    catch
        fprintf('   ⚠️ GPU狀態獲取失敗\n');
    end
else
    fprintf('當前使用CPU模式\n');
end

%% 6. 進階功能示例
%% ========================================================================

% === 自定義無人機模型 ===
fprintf('\n🔧 場景 4: 自定義無人機配置\n');

% 創建自定義配置
custom_config = struct();
custom_config.name = '自定義六軸無人機';
custom_config.mass = 2.8;                    % 2.8kg
custom_config.wheelbase = 0.70;              % 700mm軸距
custom_config.arm_length = 0.35;             % 350mm臂長
custom_config.motor_count = 6;               % 六軸配置

% 自定義推進系統
custom_config.propulsion = struct();
custom_config.propulsion.motor_kv = 700;                  % 700KV電機
custom_config.propulsion.prop_diameter = 0.3048;          % 12英吋螺旋槳
custom_config.propulsion.max_thrust_per_motor = 8.0;      % 每電機8N推力

% 自定義電池系統
custom_config.battery = struct();
custom_config.battery.cell_count = 8;                     % 8S電池
custom_config.battery.capacity_mah = 10000;               % 10000mAh
custom_config.battery.max_discharge_rate = 25;            % 25C放電

fprintf('✅ 自定義六軸無人機配置已創建\n');
fprintf('   總重: %.1fkg\n', custom_config.mass);
fprintf('   軸距: %.0fmm\n', custom_config.wheelbase * 1000);
fprintf('   電機數: %d個\n', custom_config.motor_count);
fprintf('   螺旋槳: %.1f英吋\n', custom_config.propulsion.prop_diameter * 39.37);

% === 碰撞檢測設置調整 ===
fprintf('\n⚠️ 場景 5: 碰撞檢測配置\n');

if exist('simulator', 'var') && isvalid(simulator)
    % 調整安全參數
    original_safety = simulator.safety_distance;
    simulator.safety_distance = 8.0;      % 8米安全距離
    simulator.warning_distance = 12.0;    % 12米警告距離
    simulator.critical_distance = 4.0;    % 4米危險距離
    
    fprintf('✅ 碰撞檢測參數已調整\n');
    fprintf('   安全距離: %.1fm (原%.1fm)\n', simulator.safety_distance, original_safety);
    fprintf('   警告距離: %.1fm\n', simulator.warning_distance);
    fprintf('   危險距離: %.1fm\n', simulator.critical_distance);
end

%% 7. 故障排除和優化建議
%% ========================================================================

fprintf('\n🛠️ 故障排除和優化建議:\n');
fprintf('════════════════════════════════════════\n');

% 檢查常見問題
fprintf('📋 系統檢查:\n');

% MATLAB版本檢查
matlab_version = version('-release');
matlab_year = str2double(matlab_version(1:4));
if matlab_year >= 2019
    fprintf('   ✅ MATLAB版本: %s (支援)\n', matlab_version);
else
    fprintf('   ❌ MATLAB版本: %s (需要2019b+)\n', matlab_version);
end

% 工具箱檢查
if license('test', 'Parallel_Computing_Toolbox')
    fprintf('   ✅ Parallel Computing Toolbox: 可用\n');
else
    fprintf('   ⚠️ Parallel Computing Toolbox: 不可用\n');
    fprintf('      → GPU功能將被禁用\n');
end

% 記憶體檢查
try
    if ispc
        [~, sys_info] = memory;
        available_gb = sys_info.PhysicalMemory.Available / 1e9;
        if available_gb >= 4
            fprintf('   ✅ 可用記憶體: %.1fGB (充足)\n', available_gb);
        else
            fprintf('   ⚠️ 可用記憶體: %.1fGB (偏少)\n', available_gb);
            fprintf('      → 建議關閉其他應用程式\n');
        end
    end
catch
    fprintf('   ⚠️ 記憶體狀態: 無法獲取\n');
end

% 性能優化建議
fprintf('\n💡 性能優化建議:\n');
fprintf('   🎨 視覺化優化:\n');
fprintf('      • 降低渲染品質: render_quality.level = ''medium''\n');
fprintf('      • 關閉視覺效果: particle_systems(''propwash'').enabled = false\n');
fprintf('      • 調整LOD距離: lod_system.distances = [25, 50, 100]\n');
fprintf('\n   ⚡ 計算優化:\n');
fprintf('      • 增大時間步長: time_step = 0.02\n');
fprintf('      • 減少軌跡點數: 限制軌跡長度\n');
fprintf('      • 使用批次處理: 啟用GPU批次運算\n');
fprintf('\n   💾 記憶體優化:\n');
fprintf('      • 定期清理: clear unused variables\n');
fprintf('      • 限制歷史數據: 限制軌跡歷史長度\n');
fprintf('      • 使用single精度: 減少記憶體使用\n');

%% 8. 常用命令快速參考
%% ========================================================================

fprintf('\n📖 常用命令快速參考:\n');
fprintf('════════════════════════════════════════\n');
fprintf('🚀 啟動命令:\n');
fprintf('   Enhanced_Drone_Simulator_Launcher()           %% 一鍵啟動\n');
fprintf('   simulator = GPU_Enhanced_DroneSwarmSimulator() %% 手動啟動\n');
fprintf('\n📐 物理配置:\n');
fprintf('   physics = EnhancedQuadrotorPhysics(''phantom'')  %% DJI風格\n');
fprintf('   physics = EnhancedQuadrotorPhysics(''racing'')   %% 競速機\n');
fprintf('   physics = EnhancedQuadrotorPhysics(''cargo'')    %% 載重機\n');
fprintf('\n🎨 視覺化配置:\n');
fprintf('   viz = Enhanced3DVisualizationSystem(simulator)  %% 3D視覺化\n');
fprintf('   viz.render_quality.level = ''ultra''            %% 設置品質\n');
fprintf('\n⚡ 性能優化:\n');
fprintf('   optimizer = PerformanceOptimizer(simulator)     %% 性能優化器\n');
fprintf('   optimizer.auto_optimize_settings()             %% 自動優化\n');
fprintf('   run_quick_performance_test()                   %% 快速測試\n');
fprintf('\n🔧 調試命令:\n');
fprintf('   simulator.debug_mode = true                    %% 啟用調試\n');
fprintf('   gpuDevice()                                    %% GPU狀態\n');
fprintf('   memory                                         %% 記憶體狀態\n');

fprintf('\n✅ 設置完成！無人機群飛模擬器已準備就緒\n');
fprintf('🎯 開始您的無人機模擬之旅吧！\n\n');

%% ========================================================================
%% 輔助函數定義
%% ========================================================================

function sample_file = create_sample_qgc_mission()
    % 創建示例QGC任務文件
    
    sample_file = 'sample_mission.plan';
    
    % 創建基本的QGC任務結構
    mission = struct();
    mission.fileType = 'Plan';
    mission.version = 1;
    
    % 任務項目
    mission.mission = struct();
    mission.mission.cruiseSpeed = 15;
    mission.mission.firmwareType = 12;
    mission.mission.hoverSpeed = 5;
    mission.mission.items = [];
    
    % 添加起飛點
    takeoff_item = struct();
    takeoff_item.autoContinue = true;
    takeoff_item.command = 22; % MAV_CMD_NAV_TAKEOFF
    takeoff_item.coordinate = [24.7814, 120.9935, 50]; % 台灣座標示例
    takeoff_item.doJumpId = 1;
    takeoff_item.frame = 3;
    takeoff_item.params = [0, 0, 0, NaN, 24.7814, 120.9935, 50];
    takeoff_item.type = 'SimpleItem';
    
    mission.mission.items = [mission.mission.items, takeoff_item];
    
    % 添加航點
    for i = 1:3
        waypoint = struct();
        waypoint.autoContinue = true;
        waypoint.command = 16; % MAV_CMD_NAV_WAYPOINT
        waypoint.coordinate = [24.7814 + i*0.001, 120.9935 + i*0.001, 50];
        waypoint.doJumpId = i + 1;
        waypoint.frame = 3;
        waypoint.params = [0, 0, 0, NaN, waypoint.coordinate];
        waypoint.type = 'SimpleItem';
        
        mission.mission.items = [mission.mission.items, waypoint];
    end
    
    % 添加返航指令
    rtl_item = struct();
    rtl_item.autoContinue = true;
    rtl_item.command = 20; % MAV_CMD_NAV_RETURN_TO_LAUNCH
    rtl_item.doJumpId = 5;
    rtl_item.frame = 2;
    rtl_item.params = [0, 0, 0, 0, 0, 0, 0];
    rtl_item.type = 'SimpleItem';
    
    mission.mission.items = [mission.mission.items, rtl_item];
    
    try
        % 將任務寫入JSON文件
        json_str = jsonencode(mission);
        fid = fopen(sample_file, 'w');
        if fid ~= -1
            fprintf(fid, '%s', json_str);
            fclose(fid);
        else
            fprintf('警告: 無法創建示例QGC文件\n');
        end
    catch
        fprintf('警告: JSON編碼失敗，跳過QGC文件創建\n');
    end
end

%% ========================================================================
%% 結束
%% ========================================================================

% 顯示完成訊息
function display_completion_message()
    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                 🎉 設置完成！使用愉快！ 🎉                   ║\n');
    fprintf('╠══════════════════════════════════════════════════════════════╣\n');
    fprintf('║  如需技術支援，請參考:                                      ║\n');
    fprintf('║  • 故障排除指南                                             ║\n');
    fprintf('║  • 性能優化建議                                             ║\n');
    fprintf('║  • API參考文檔                                              ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n');
end

% 自動執行完成訊息
display_completion_message();