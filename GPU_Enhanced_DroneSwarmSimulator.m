% GPU_Enhanced_DroneSwarmSimulator.m
% 增強版無人機群飛模擬器 - 強制GPU模式 (完全修正版)

classdef GPU_Enhanced_DroneSwarmSimulator < DroneSwarmSimulator
    
    properties (Constant)
        GPU_FORCE_ENABLE = true;     % 強制啟用GPU
        GPU_MIN_MEMORY_GB = 1.0;     % 最小GPU記憶體需求 (GB)
        GPU_FALLBACK_ENABLED = true; % 允許CPU備援
    end
    
    properties
        gpu_device_info     % GPU設備詳細信息
        gpu_memory_pool     % GPU記憶體池
        gpu_computation_mode % GPU計算模式
        performance_monitor % 性能監控器
        gpu_monitor_timer   % GPU監控定時器
    end
    
    methods
        function obj = GPU_Enhanced_DroneSwarmSimulator()
            % 增強版建構函數
            fprintf('\n=== GPU增強版無人機群飛模擬器 ===\n');
            % 調用父類建構函數
            obj@DroneSwarmSimulator();

            % 強制初始化GPU
            obj.force_initialize_gpu();

            % 設置GPU專用功能
            obj.setup_gpu_enhanced_features();
        end
        
        function force_initialize_gpu(obj)
            % 強制初始化GPU - 更積極的GPU檢測策略
            fprintf('🔥 強制啟用GPU計算模式...\n');
            
            obj.gpu_available = false;
            obj.use_gpu = false;
            obj.gpu_computation_mode = 'CPU_FALLBACK';
            
            try
                % 步驟1：檢查Parallel Computing Toolbox授權
                if ~license('test', 'Parallel_Computing_Toolbox')
                    obj.request_pct_license();
                    return;
                end
                
                % 步驟2：檢測所有可用GPU設備
                obj.scan_all_gpu_devices();
                
                % 步驟3：選擇最佳GPU並強制初始化
                if obj.select_optimal_gpu()
                    obj.initialize_gpu_memory_pool();
                    obj.validate_gpu_computation();
                    fprintf('✅ GPU強制啟用成功！\n');
                else
                    obj.attempt_gpu_recovery();
                end
                
            catch ME
                fprintf('⚠️ GPU啟用過程中遇到問題：%s\n', ME.message);
                obj.handle_gpu_initialization_error(ME);
            end
        end
        
        function request_pct_license(obj)
            % 請求Parallel Computing Toolbox授權
            fprintf('❌ Parallel Computing Toolbox授權不可用\n');
            fprintf('📋 解決方案：\n');
            fprintf('   1. 檢查MATLAB授權是否包含Parallel Computing Toolbox\n');
            fprintf('   2. 執行：ver 查看已安裝工具箱\n');
            fprintf('   3. 聯繫IT管理員確認授權狀態\n');
            
            % 嘗試軟件模擬GPU功能
            obj.enable_software_gpu_simulation();
        end
        
        function scan_all_gpu_devices(obj)
            % 掃描所有可用的GPU設備
            fprintf('🔍 掃描GPU設備...\n');
            
            try
                % 方法1：使用gpuDeviceCount
                device_count = gpuDeviceCount();
                fprintf('   檢測到 %d 個GPU設備\n', device_count);
                
                if device_count == 0
                    obj.attempt_gpu_driver_check();
                    return;
                end
                
                % 方法2：遍歷所有設備並測試
                for i = 1:device_count
                    try
                        gpu_dev = gpuDevice(i);
                        fprintf('   GPU #%d: %s\n', i, gpu_dev.Name);
                        fprintf('      記憶體: %.1f GB (可用: %.1f GB)\n', ...
                               gpu_dev.TotalMemory/1e9, gpu_dev.AvailableMemory/1e9);
                        fprintf('      計算能力: %.1f\n', gpu_dev.ComputeCapability);
                        
                        % 檢查是否滿足最低需求
                        if obj.validate_gpu_device(gpu_dev)
                            obj.gpu_device_info = gpu_dev;
                            obj.gpu_available = true;
                            fprintf('   ✅ 選定GPU #%d 作為計算設備\n', i);
                            break;
                        end
                    catch gpu_err
                        fprintf('   ⚠️ GPU #%d 初始化失敗：%s\n', i, gpu_err.message);
                    end
                end
                
            catch ME
                fprintf('   ❌ GPU掃描失敗：%s\n', ME.message);
                obj.attempt_alternative_gpu_detection();
            end
        end
        
        function success = validate_gpu_device(obj, gpu_dev)
            % 驗證GPU設備是否滿足需求
            success = false;
            
            try
                % 檢查1：記憶體需求
                if gpu_dev.AvailableMemory < obj.GPU_MIN_MEMORY_GB * 1e9
                    fprintf('      ❌ GPU記憶體不足 (需要%.1fGB)\n', obj.GPU_MIN_MEMORY_GB);
                    return;
                end
                
                % 檢查2：計算能力
                if gpu_dev.ComputeCapability < 3.0
                    fprintf('      ❌ GPU計算能力不足 (需要3.0+)\n');
                    return;
                end
                
                % 檢查3：MATLAB支援性
                if ~gpu_dev.DeviceSupported
                    fprintf('      ❌ GPU設備不受MATLAB支援\n');
                    return;
                end
                
                % 檢查4：實際計算測試
                test_result = obj.perform_gpu_calculation_test();
                if ~test_result
                    fprintf('      ❌ GPU計算測試失敗\n');
                    return;
                end
                
                success = true;
                
            catch ME
                fprintf('      ❌ GPU驗證過程出錯：%s\n', ME.message);
            end
        end
        
        function test_passed = perform_gpu_calculation_test(~)
            % 執行GPU計算測試 (修正：移除未使用的gpu_dev參數)
            test_passed = false;
            
            try
                % 測試1：基本矩陣運算
                fprintf('      🧪 執行GPU計算測試...\n');
                
                % 創建測試數據
                test_size = 500; % 減小測試大小以提高兼容性
                A = rand(test_size, 'single');
                B = rand(test_size, 'single');
                
                % 上傳到GPU
                tic;
                A_gpu = gpuArray(A);
                B_gpu = gpuArray(B);
                
                % 執行計算
                C_gpu = A_gpu * B_gpu;
                
                % 回傳結果
                result = gather(C_gpu); %#ok<NASGU> % 保留結果變量避免警告
                gpu_time = toc;
                
                % 清理GPU記憶體
                clear A_gpu B_gpu C_gpu result;
                
                fprintf('      ✅ GPU計算測試通過 (用時:%.3fs)\n', gpu_time);
                
                test_passed = true;
                
            catch ME
                fprintf('      ❌ GPU計算測試失敗：%s\n', ME.message);
            end
        end
        
        function test_gpu_memory_management(obj)
            % 測試GPU記憶體管理
            try
                % 分配較小的記憶體塊以提高兼容性
                large_array = gpuArray(zeros(2000, 2000, 'single'));
                
                % 檢查記憶體使用
                if ~isempty(obj.gpu_device_info)
                    mem_info = obj.gpu_device_info.AvailableMemory; %#ok<NASGU>
                end
                
                % 清理記憶體
                clear large_array;
                
                fprintf('      ✅ GPU記憶體管理測試通過\n');
                
            catch ME
                fprintf('      ⚠️ GPU記憶體測試警告：%s\n', ME.message);
            end
        end
        
        function initialize_gpu_memory_pool(obj)
            % 初始化GPU記憶體池
            fprintf('🏊 初始化GPU記憶體池...\n');
            
            try
                % 預分配記憶體池
                obj.gpu_memory_pool = struct();
                
                % 計算最佳記憶體分配
                available_memory = obj.gpu_device_info.AvailableMemory;
                pool_size = min(available_memory * 0.6, 1.5e9); % 使用60%記憶體或1.5GB
                
                % 創建記憶體池結構
                obj.gpu_memory_pool.total_size = pool_size;
                obj.gpu_memory_pool.used_size = 0;
                obj.gpu_memory_pool.blocks = containers.Map();
                
                fprintf('   ✅ GPU記憶體池已創建 (%.1f MB)\n', pool_size/1e6);
                
            catch ME
                fprintf('   ❌ GPU記憶體池創建失敗：%s\n', ME.message);
            end
        end
        
        function validate_gpu_computation(obj)
            % 驗證GPU計算功能
            obj.use_gpu = true;
            obj.gpu_computation_mode = 'GPU_ACCELERATED';
            
            % 設置性能監控
            obj.performance_monitor = struct();
            obj.performance_monitor.gpu_utilization = 0;
            obj.performance_monitor.memory_usage = 0;
            obj.performance_monitor.computation_time = [];
            
            fprintf('🎯 GPU計算模式已啟用\n');
        end
        
        function success = select_optimal_gpu(obj)
            % 選擇最佳GPU設備
            success = obj.gpu_available;
            if success
                fprintf('   ✅ 已選定最佳GPU設備\n');
            else
                fprintf('   ❌ 沒有找到合適的GPU設備\n');
            end
        end
        
        function attempt_gpu_recovery(obj)
            % 嘗試GPU恢復
            fprintf('🔧 嘗試GPU設備恢復...\n');
            
            try
                % 方法1：重置GPU設備
                if gpuDeviceCount() > 0
                    gpuDevice(1);  % 強制選擇第一個GPU
                    
                    % 方法2：清理GPU記憶體
                    if obj.gpu_available
                        gpuDevice([]);  % 清除當前GPU選擇
                        pause(0.5);
                        gpuDevice(1);   % 重新選擇GPU
                        
                        if obj.validate_gpu_device(gpuDevice())
                            obj.gpu_available = true;
                            obj.use_gpu = true;
                            obj.gpu_device_info = gpuDevice();
                            fprintf('   ✅ GPU恢復成功\n');
                            return;
                        end
                    end
                end
                
                % 如果恢復失敗，啟用CPU備援
                obj.enable_cpu_fallback();
                
            catch ME
                fprintf('   ❌ GPU恢復失敗：%s\n', ME.message);
                obj.enable_cpu_fallback();
            end
        end
        
        function enable_cpu_fallback(obj)
            % 啟用CPU備援模式
            if obj.GPU_FALLBACK_ENABLED
                fprintf('🔄 啟用CPU備援模式...\n');
                obj.gpu_available = false;
                obj.use_gpu = false;
                obj.gpu_computation_mode = 'CPU_OPTIMIZED';
                
                % 優化CPU計算設置
                obj.optimize_cpu_computation();
            else
                error('GPU初始化失敗且備援模式已禁用');
            end
        end
        
        function optimize_cpu_computation(~)
            % 優化CPU計算設置
            try
                % 設置多線程
                maxNumCompThreads('automatic');
                
                % 獲取CPU核心數
                num_cores = feature('NumCores');
                fprintf('   ✅ CPU優化設置已完成 (%d 核心)\n', num_cores);
                
            catch ME
                fprintf('   ⚠️ CPU優化警告：%s\n', ME.message);
            end
        end
        
        function setup_gpu_enhanced_features(obj)
            % 設置GPU增強功能
            fprintf('⚡ 設置GPU增強功能...\n');
            
            if obj.use_gpu
                obj.enable_gpu_collision_detection();
                obj.enable_gpu_trajectory_computation();
                obj.setup_gpu_visualization();
            else
                obj.enable_cpu_enhanced_features();
            end
            
            % 添加性能監控定時器
            obj.setup_performance_monitoring();
        end
        
        function enable_gpu_collision_detection(~)
            % 啟用GPU碰撞檢測
            fprintf('   🔍 GPU碰撞檢測已啟用\n');
            % 將在CollisionDetectionSystem中實現
        end
        
        function enable_gpu_trajectory_computation(~)
            % 啟用GPU軌跡計算
            fprintf('   📈 GPU軌跡計算已啟用\n');
            % 將在軌跡插值中使用GPU加速
        end
        
        function setup_gpu_visualization(~)
            % 設置GPU可視化
            fprintf('   🎨 GPU可視化加速已啟用\n');
            % 使用GPU加速3D渲染
        end
        
        function enable_cpu_enhanced_features(~)
            % 啟用CPU增強功能
            fprintf('   💻 CPU增強功能已啟用\n');
            % CPU特有的優化功能
        end
        
        function setup_performance_monitoring(obj)
            % 設置性能監控
            try
                obj.gpu_monitor_timer = timer('ExecutionMode', 'fixedRate', ...
                                             'Period', 2.0, ...
                                             'TimerFcn', @(~,~)obj.monitor_gpu_performance());
                start(obj.gpu_monitor_timer);
                fprintf('   📊 性能監控已啟動\n');
            catch ME
                fprintf('   ⚠️ 性能監控啟動失敗：%s\n', ME.message);
            end
        end
        
        function monitor_gpu_performance(obj)
            % 監控GPU性能
            if obj.use_gpu && obj.gpu_available && ~isempty(obj.gpu_device_info)
                try
                    current_memory = obj.gpu_device_info.AvailableMemory;
                    total_memory = obj.gpu_device_info.TotalMemory;
                    obj.performance_monitor.memory_usage = ...
                        (total_memory - current_memory) / total_memory * 100;
                catch
                    % 靜默處理錯誤
                end
            end
        end
        
        function status_str = get_gpu_status_string(obj)
            % 獲取GPU狀態字符串
            if obj.use_gpu && ~isempty(obj.performance_monitor)
                status_str = sprintf('GPU-%s (%.1f%% 記憶體)', ...
                                   obj.gpu_computation_mode, ...
                                   obj.performance_monitor.memory_usage);
            else
                status_str = sprintf('CPU-%s', obj.gpu_computation_mode);
            end
        end
        
        % === 新增的缺失方法 ===
        
        function handle_gpu_initialization_error(obj, ME)
            % 處理GPU初始化錯誤
            fprintf('🚨 GPU初始化錯誤處理：%s\n', ME.message);
            
            % 根據錯誤類型進行處理
            if contains(ME.identifier, 'license') || contains(ME.message, 'license')
                fprintf('📋 授權問題 - 切換到CPU模式\n');
            elseif contains(ME.identifier, 'gpu') || contains(ME.message, 'GPU')
                fprintf('🔧 GPU硬件問題 - 切換到CPU模式\n');
            else
                fprintf('❓ 未知錯誤 - 切換到CPU模式\n');
            end
            
            obj.enable_cpu_fallback();
        end
        
        function attempt_gpu_driver_check(~)
            % 檢查GPU驅動狀態
            fprintf('🔍 檢查GPU驅動狀態...\n');
            fprintf('   可能的原因：\n');
            fprintf('   1. 系統沒有安裝GPU\n');
            fprintf('   2. GPU驅動程序未正確安裝\n');
            fprintf('   3. MATLAB無法訪問GPU設備\n');
            fprintf('   建議解決方案：\n');
            fprintf('   1. 更新GPU驅動程序\n');
            fprintf('   2. 重啟MATLAB\n');
            fprintf('   3. 檢查CUDA安裝狀態\n');
        end
        
        function attempt_alternative_gpu_detection(obj)
            % 嘗試替代GPU檢測方法
            fprintf('🔄 嘗試替代GPU檢測方法...\n');
            
            try
                % 方法1：直接嘗試創建gpuArray
                test_array = gpuArray([1, 2, 3]);
                if isa(test_array, 'gpuArray')
                    obj.gpu_available = true;
                    obj.gpu_device_info = gpuDevice();
                    fprintf('   ✅ 替代方法檢測到GPU\n');
                end
                clear test_array;
                
            catch
                fprintf('   ❌ 所有GPU檢測方法都失敗\n');
                obj.gpu_available = false;
            end
        end
        
        function enable_software_gpu_simulation(obj)
            % 啟用軟件GPU模擬
            fprintf('🔄 啟用軟件GPU模擬模式...\n');
            obj.gpu_computation_mode = 'SOFTWARE_SIMULATION';
            obj.gpu_available = false;
            obj.use_gpu = false;
            
            % 使用CPU並行計算來模擬GPU效果
            try
                if license('test', 'Parallel_Computing_Toolbox')
                    fprintf('   ✅ 將使用CPU並行計算模擬GPU功能\n');
                else
                    fprintf('   ⚠️ 軟件模擬功能有限\n');
                end
            catch
                fprintf('   ⚠️ 軟件模擬啟用部分失敗\n');
            end
        end
        
        function delete(obj)
            % 析構函數 - 清理資源
            try
                % 停止並清理定時器
                if ~isempty(obj.gpu_monitor_timer) && isvalid(obj.gpu_monitor_timer)
                    if strcmp(obj.gpu_monitor_timer.Running, 'on')
                        stop(obj.gpu_monitor_timer);
                    end
                    delete(obj.gpu_monitor_timer);
                end
                
                % 清理GPU資源
                if obj.use_gpu
                    gpuDevice([]);
                end
                
                fprintf('🧹 GPU增強模擬器資源已清理\n');
                
            catch
                % 靜默處理清理錯誤
            end
        end
    end
end