function simple_launcher()
    % 修正後的無人機群飛模擬器啟動腳本
    
    % 清理環境
    clear; clc; close all;
    
    % 顯示歡迎信息
    fprintf('\n=== 無人機群飛模擬器啟動 ===\n');
    
    % 正確的文件名檢查（文件名必須與類別名完全一致）
    required_files = {
        'DroneSwarmSimulator.m'
        'CoordinateSystem.m'
        'CollisionDetectionSystem.m'
        'VisualizationSystem.m'
        'QGCFileParser.m'
    };
    
    missing_files = {};
    for i = 1:length(required_files)
        if exist(required_files{i}, 'file') ~= 2
            missing_files{end+1} = required_files{i}; %#ok<AGROW>
        end
    end
    
    if ~isempty(missing_files)
        fprintf('❌ 缺少以下必要文件：\n');
        for i = 1:length(missing_files)
            fprintf('   - %s\n', missing_files{i});
        end
        fprintf('\n⚠️ 重要：文件名必須與類別名完全一致！\n');
        fprintf('請將以下文件重新命名：\n');
        fprintf('   drone_simulator_integrated.m    → DroneSwarmSimulator.m\n');
        fprintf('   coordinate_system_complete.m   → CoordinateSystem.m\n');
        fprintf('   collision_detection_complete.m → CollisionDetectionSystem.m\n');
        fprintf('   visualization_system_complete.m → VisualizationSystem.m\n');
        fprintf('   qgc_file_parser.m             → QGCFileParser.m\n');
        return;
    end
    
    fprintf('✅ 所有必要文件已找到\n');
    
    % 檢查MATLAB版本
    matlab_version = version('-release');
    fprintf('MATLAB版本: %s\n', matlab_version);
    
    % 修正GPU檢測邏輯
    gpu_available = false;
    try
        if license('test', 'Parallel_Computing_Toolbox')
            gpu_info = gpuDevice();
            if gpu_info.DeviceSupported
                gpu_available = true;
                fprintf('GPU: %s (%.1fGB) - 可用\n', gpu_info.Name, gpu_info.AvailableMemory/1e9);
            else
                fprintf('GPU: 檢測到但不支援MATLAB計算\n');
            end
        else
            fprintf('GPU: Parallel Computing Toolbox授權檢查失敗\n');
        end
    catch ME
        fprintf('GPU: 檢測失敗 (%s)\n', ME.message);
    end
    
    if ~gpu_available
        fprintf('將使用CPU模式運行\n');
    end
    
    % 確保路徑正確
    addpath(pwd);
    
    % 測試類別可用性
    fprintf('\n正在測試類別可用性...\n');
    
    % 測試各個類別是否可以實例化
    try
        % 測試座標系統
        fprintf('測試CoordinateSystem...');
        coord_test = CoordinateSystem();
        fprintf(' ✅\n');
        clear coord_test;
        
        % 測試一個簡單的模擬器結構
        fprintf('創建測試模擬器結構...');
        test_sim = create_test_simulator_struct();
        fprintf(' ✅\n');
        
        % 測試碰撞檢測系統
        fprintf('測試CollisionDetectionSystem...');
        collision_test = CollisionDetectionSystem(test_sim);
        fprintf(' ✅\n');
        clear collision_test;
        
        % 測試視覺化系統
        fprintf('測試VisualizationSystem...');
        vis_test = VisualizationSystem(test_sim);
        fprintf(' ✅\n');
        clear vis_test;
        
        % 測試QGC解析器
        fprintf('測試QGCFileParser...');
        qgc_test = QGCFileParser(test_sim);
        fprintf(' ✅\n');
        clear qgc_test;
        
        fprintf('所有組件測試通過！\n');
        
    catch ME
        fprintf('\n❌ 組件測試失敗\n');
        fprintf('錯誤: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('位置: %s (第%d行)\n', ME.stack(1).name, ME.stack(1).line);
        end
        fprintf('\n請檢查文件名是否正確\n');
        return;
    end
    
    % 啟動完整模擬器
    try
        fprintf('\n正在啟動完整模擬器...\n');
        
        % 注意：這裡只有一個輸出參數
        simulator = DroneSwarmSimulator();
        
        fprintf('\n=== 啟動成功 ===\n');
        fprintf('模擬器GUI已開啟\n');
        fprintf('請使用以下步驟：\n');
        fprintf('1. 點擊「創建演示數據」生成測試數據\n');
        fprintf('2. 點擊「分析碰撞」檢測軌跡衝突\n');
        fprintf('3. 點擊「開始模擬」觀察實時飛行\n');
        
        % 儲存到workspace供調試
        assignin('base', 'sim', simulator);
        fprintf('\n模擬器已保存到變量 "sim"\n');
        
        % 顯示一些調試信息
        fprintf('\n=== 調試信息 ===\n');
        fprintf('GPU可用: %s\n', mat2str(simulator.gpu_available));
        fprintf('使用GPU: %s\n', mat2str(simulator.use_gpu));
        fprintf('已載入無人機: %d\n', simulator.drones.Count);
        
    catch ME
        fprintf('\n❌ 模擬器啟動失敗\n');
        fprintf('錯誤: %s\n', ME.message);
        
        if ~isempty(ME.stack)
            fprintf('詳細錯誤位置:\n');
            for i = 1:min(3, length(ME.stack))
                fprintf('  %d. %s (第%d行)\n', i, ME.stack(i).name, ME.stack(i).line);
            end
        end
        
        fprintf('\n故障排除建議：\n');
        fprintf('1. 確認文件名與類別名完全一致\n');
        fprintf('2. 檢查文件內容是否完整\n');
        fprintf('3. 運行 clear classes 清理類別緩存\n');
        fprintf('4. 重新下載所有文件\n');
    end
end

function test_sim = create_test_simulator_struct()
    % 創建用於測試的模擬器結構
    test_sim = struct();
    test_sim.drones = containers.Map();
    test_sim.current_time = 0;
    test_sim.max_time = 100;
    test_sim.time_step = 0.1;
    test_sim.safety_distance = 5.0;
    test_sim.warning_distance = 8.0;
    test_sim.critical_distance = 3.0;
    
    % GPU設定
    test_sim.gpu_available = false;
    test_sim.use_gpu = false;
    
    try
        if license('test', 'Parallel_Computing_Toolbox')
            gpu_info = gpuDevice();
            if gpu_info.DeviceSupported
                test_sim.gpu_available = true;
                test_sim.use_gpu = true;
            end
        end
    catch
        % GPU不可用
    end
end

%% 修復文件名的輔助函數
function fix_filenames()
    % 幫助用戶修復文件名
    fprintf('正在檢查和修復文件名...\n');
    
    filename_mapping = {
        'drone_simulator_integrated.m', 'DroneSwarmSimulator.m';
        'coordinate_system_complete.m', 'CoordinateSystem.m';
        'collision_detection_complete.m', 'CollisionDetectionSystem.m';
        'visualization_system_complete.m', 'VisualizationSystem.m';
        'qgc_file_parser.m', 'QGCFileParser.m';
    };
    
    for i = 1:size(filename_mapping, 1)
        old_name = filename_mapping{i, 1};
        new_name = filename_mapping{i, 2};
        
        if exist(old_name, 'file') == 2
            try
                movefile(old_name, new_name);
                fprintf('✅ %s → %s\n', old_name, new_name);
            catch ME
                fprintf('❌ 無法重命名 %s: %s\n', old_name, ME.message);
            end
        end
    end
    
    fprintf('文件名修復完成！\n');
end

%% 清理函數
function clean_environment()
    % 清理MATLAB環境
    fprintf('正在清理環境...\n');
    
    % 清理類別
    clear classes;
    
    % 清理變量
    clear all;
    
    % 關閉圖形
    close all;
    
    % 清理命令視窗
    clc;
    
    fprintf('環境清理完成！\n');
end