% GPUComputeCore.m
% GPU加速計算核心 - 無人機群飛專用高性能計算模組

classdef GPUComputeCore < handle
    
    properties (Constant)
        VERSION = '2.0';
        MAX_BATCH_SIZE = 2048;
        COLLISION_THRESHOLD = 5.0; % 預設安全距離(米)
        INTERPOLATION_PRECISION = 1e-6;
    end
    
    properties
        gpu_device         % GPU設備句柄
        memory_manager     % 記憶體管理器
        compute_streams    % 計算流
        kernel_cache      % 內核函數快取
        
        % 計算設置
        batch_size        % 批次大小
        use_double_precision % 是否使用雙精度
        enable_profiling  % 是否啟用性能分析
        
        % 性能統計
        performance_stats % 性能統計資料
    end
    
    methods
        function obj = GPUComputeCore()
            % 建構函數
            fprintf('🔥 初始化GPU計算核心...\n');
            
            obj.initialize_gpu_environment();
            obj.setup_memory_management();
            obj.initialize_compute_kernels();
            obj.setup_performance_monitoring();
            
            fprintf('✅ GPU計算核心初始化完成\n');
        end
        
        function initialize_gpu_environment(obj)
            % 初始化GPU環境
            
            obj.gpu_device = [];
            obj.batch_size = 1024;
            obj.use_double_precision = false;
            obj.enable_profiling = true;
            
            try
                % 檢查並選擇最佳GPU
                if gpuDeviceCount() > 0
                    % 選擇計算能力最高的GPU
                    best_gpu = obj.select_best_gpu();
                    obj.gpu_device = gpuDevice(best_gpu);
                    
                    fprintf('   🎮 已選擇GPU: %s\n', obj.gpu_device.Name);
                    fprintf('   💾 GPU記憶體: %.1fGB\n', obj.gpu_device.AvailableMemory/1e9);
                    fprintf('   🔢 計算能力: %.1f\n', obj.gpu_device.ComputeCapability);
                    
                    % 設置GPU配置
                    obj.configure_gpu_settings();
                    
                else
                    fprintf('   ❌ 未檢測到GPU設備\n');
                    error('GPU計算核心需要GPU支援');
                end
                
            catch ME
                fprintf('   ❌ GPU初始化失敗: %s\n', ME.message);
                rethrow(ME);
            end
        end
        
        function best_gpu = select_best_gpu(obj)
            % 選擇最佳GPU設備
            
            gpu_count = gpuDeviceCount();
            best_gpu = 1;
            best_score = 0;
            
            for i = 1:gpu_count
                try
                    gpu = gpuDevice(i);
                    
                    if ~gpu.DeviceSupported
                        continue;
                    end
                    
                    % 計算GPU評分 (記憶體 + 計算能力)
                    memory_score = gpu.AvailableMemory / 1e9; % GB
                    compute_score = gpu.ComputeCapability * 10;
                    total_score = memory_score + compute_score;
                    
                    fprintf('   🎮 GPU #%d: %s (評分: %.1f)\n', i, gpu.Name, total_score);
                    
                    if total_score > best_score
                        best_score = total_score;
                        best_gpu = i;
                    end
                    
                catch
                    fprintf('   ⚠️ GPU #%d 檢測失敗\n', i);
                end
            end
            
            fprintf('   ✅ 選定GPU #%d (評分: %.1f)\n', best_gpu, best_score);
        end
        
        function configure_gpu_settings(obj)
            % 配置GPU設置
            
            % 根據GPU記憶體調整批次大小
            available_memory_gb = obj.gpu_device.AvailableMemory / 1e9;
            
            if available_memory_gb >= 8
                obj.batch_size = 2048;
            elseif available_memory_gb >= 4
                obj.batch_size = 1024;
            else
                obj.batch_size = 512;
            end
            
            % 根據計算能力決定精度
            if obj.gpu_device.ComputeCapability >= 6.0
                obj.use_double_precision = true;
            end
            
            fprintf('   ⚙️ 批次大小: %d\n', obj.batch_size);
            fprintf('   🔢 精度模式: %s\n', ...
                   obj.bool_to_str(obj.use_double_precision, '雙精度', '單精度'));
        end
        
        function setup_memory_management(obj)
            % 設置記憶體管理
            
            obj.memory_manager = struct();
            obj.memory_manager.allocated_blocks = containers.Map();
            obj.memory_manager.peak_usage = 0;
            obj.memory_manager.current_usage = 0;
            obj.memory_manager.allocation_count = 0;
            
            % 預分配常用記憶體塊
            obj.preallocate_gpu_memory();
        end
        
        function preallocate_gpu_memory(obj)
            % 預分配GPU記憶體塊
            
            if isempty(obj.gpu_device)
                return;
            end
            
            try
                % 預分配位置矩陣記憶體
                max_drones = 100;
                max_timepoints = 10000;
                
                if obj.use_double_precision
                    precision_type = 'double';
                else
                    precision_type = 'single';
                end
                
                % 無人機位置矩陣 [max_drones, 3, max_timepoints]
                positions_size = [max_drones, 3, max_timepoints];
                obj.memory_manager.allocated_blocks('positions') = ...
                    gpuArray.zeros(positions_size, precision_type);
                
                % 距離矩陣 [max_drones, max_drones]
                distances_size = [max_drones, max_drones];
                obj.memory_manager.allocated_blocks('distances') = ...
                    gpuArray.zeros(distances_size, precision_type);
                
                % 軌跡時間向量
                times_size = [max_timepoints, 1];
                obj.memory_manager.allocated_blocks('times') = ...
                    gpuArray.zeros(times_size, precision_type);
                
                obj.update_memory_usage();
                
                fprintf('   💾 GPU記憶體預分配完成\n');
                
            catch ME
                fprintf('   ⚠️ 記憶體預分配警告: %s\n', ME.message);
            end
        end
        
        function initialize_compute_kernels(obj)
            % 初始化計算內核
            
            obj.kernel_cache = containers.Map();
            
            % 檢查是否支援自定義CUDA核心
            if obj.gpu_device.ComputeCapability >= 3.5
                fprintf('   🔥 支援CUDA自定義核心\n');
                obj.setup_cuda_kernels();
            else
                fprintf('   📊 使用MATLAB內建GPU函數\n');
                obj.setup_builtin_gpu_functions();
            end
        end
        
        function setup_cuda_kernels(obj)
            % 設置CUDA自定義核心 (進階)
            
            % 這裡可以載入預編譯的CUDA核心
            % 或使用MATLAB的GPU Coder生成的核心
            
            obj.kernel_cache('distance_matrix') = @obj.cuda_distance_matrix_kernel;
            obj.kernel_cache('collision_detection') = @obj.cuda_collision_detection_kernel;
            obj.kernel_cache('trajectory_interpolation') = @obj.cuda_interpolation_kernel;
            
            fprintf('   ✅ CUDA核心已載入\n');
        end
        
        function setup_builtin_gpu_functions(obj)
            % 設置內建GPU函數
            
            obj.kernel_cache('distance_matrix') = @obj.builtin_distance_matrix;
            obj.kernel_cache('collision_detection') = @obj.builtin_collision_detection;
            obj.kernel_cache('trajectory_interpolation') = @obj.builtin_interpolation;
            
            fprintf('   ✅ GPU內建函數已設置\n');
        end
        
        function setup_performance_monitoring(obj)
            % 設置性能監控
            
            obj.performance_stats = struct();
            obj.performance_stats.kernel_times = containers.Map();
            obj.performance_stats.memory_transfers = 0;
            obj.performance_stats.total_operations = 0;
            obj.performance_stats.average_throughput = 0;
        end
        
        %% === 核心計算函數 ===
        
        function [conflicts, computation_time] = detect_collisions_gpu(obj, drone_positions, timestamps, safety_distance)
            % GPU加速碰撞檢測
            
            if nargin < 4
                safety_distance = obj.COLLISION_THRESHOLD;
            end
            
            start_time = tic;
            conflicts = [];
            
            try
                n_drones = length(drone_positions);
                n_times = length(timestamps);
                
                if n_drones < 2
                    computation_time = toc(start_time);
                    return;
                end
                
                fprintf('   🔍 GPU碰撞檢測: %d架無人機, %d時間點\n', n_drones, n_times);
                
                % 準備GPU數據
                [positions_gpu, times_gpu] = obj.prepare_gpu_collision_data(drone_positions, timestamps);
                
                % 執行批次碰撞檢測
                conflicts = obj.execute_batch_collision_detection(positions_gpu, times_gpu, safety_distance);
                
                computation_time = toc(start_time);
                
                % 更新性能統計
                obj.update_collision_detection_stats(computation_time, n_drones, n_times);
                
                fprintf('   ✅ 檢測完成: 發現%d個潛在衝突 (用時%.3fs)\n', ...
                       length(conflicts), computation_time);
                
            catch ME
                computation_time = toc(start_time);
                fprintf('   ❌ GPU碰撞檢測失敗: %s\n', ME.message);
                
                % 降級到CPU計算
                conflicts = obj.fallback_cpu_collision_detection(drone_positions, timestamps, safety_distance);
            end
        end
        
        function [positions_gpu, times_gpu] = prepare_gpu_collision_data(obj, drone_positions, timestamps)
            % 準備GPU碰撞檢測數據
            
            n_drones = length(drone_positions);
            n_times = length(timestamps);
            
            % 檢查預分配記憶體是否足夠
            if obj.check_preallocated_memory_size(n_drones, n_times)
                positions_gpu = obj.memory_manager.allocated_blocks('positions');
                times_gpu = obj.memory_manager.allocated_blocks('times');
            else
                % 動態分配記憶體
                if obj.use_double_precision
                    positions_gpu = gpuArray.zeros([n_drones, 3, n_times], 'double');
                    times_gpu = gpuArray.zeros([n_times, 1], 'double');
                else
                    positions_gpu = gpuArray.zeros([n_drones, 3, n_times], 'single');
                    times_gpu = gpuArray.zeros([n_times, 1], 'single');
                end
            end
            
            % 填充位置數據
            drone_ids = keys(drone_positions);
            for i = 1:n_drones
                drone_id = drone_ids{i};
                traj = drone_positions(drone_id);
                
                % 插值到統一時間軸
                pos_interp = obj.interpolate_trajectory_gpu(traj, timestamps);
                positions_gpu(i, :, :) = permute(pos_interp, [3, 1, 2]);
            end
            
            % 填充時間數據
            times_gpu(1:n_times) = gpuArray(timestamps);
        end
        
        function conflicts = execute_batch_collision_detection(obj, positions_gpu, times_gpu, safety_distance)
            % 執行批次碰撞檢測
            
            conflicts = [];
            [n_drones, ~, n_times] = size(positions_gpu);
            
            % 使用對應的核心函數
            distance_kernel = obj.kernel_cache('distance_matrix');
            collision_kernel = obj.kernel_cache('collision_detection');
            
            % 批次處理時間點
            batch_size = min(obj.batch_size, n_times);
            
            for t_start = 1:batch_size:n_times
                t_end = min(t_start + batch_size - 1, n_times);
                t_indices = t_start:t_end;
                
                % 提取當前批次的位置數據
                batch_positions = positions_gpu(:, :, t_indices);
                batch_times = times_gpu(t_indices);
                
                % 計算距離矩陣
                distances = distance_kernel(batch_positions);
                
                % 檢測碰撞
                batch_conflicts = collision_kernel(distances, batch_times, safety_distance);
                
                % 合併結果
                conflicts = [conflicts; batch_conflicts]; %#ok<AGROW>
            end
        end
        
        function interpolated_positions = interpolate_trajectory_gpu(obj, trajectory, query_times)
            % GPU加速軌跡插值
            
            if isempty(trajectory) || length(query_times) < 1
                interpolated_positions = zeros(length(query_times), 3);
                return;
            end
            
            % 使用GPU插值核心
            interpolation_kernel = obj.kernel_cache('trajectory_interpolation');
            interpolated_positions = interpolation_kernel(trajectory, query_times);
        end
        
        %% === CUDA核心函數實現 ===
        
        function distances = cuda_distance_matrix_kernel(obj, positions)
            % CUDA距離矩陣計算核心
            
            [n_drones, ~, n_times] = size(positions);
            
            if obj.use_double_precision
                distances = gpuArray.zeros([n_drones, n_drones, n_times], 'double');
            else
                distances = gpuArray.zeros([n_drones, n_drones, n_times], 'single');
            end
            
            % 向量化計算所有無人機對之間的距離
            for t = 1:n_times
                pos_t = positions(:, :, t); % [n_drones, 3]
                
                % 廣播計算距離
                diff_x = pos_t(:, 1) - pos_t(:, 1)'; % [n_drones, n_drones]
                diff_y = pos_t(:, 2) - pos_t(:, 2)';
                diff_z = pos_t(:, 3) - pos_t(:, 3)';
                
                distances(:, :, t) = sqrt(diff_x.^2 + diff_y.^2 + diff_z.^2);
            end
        end
        
        function conflicts = cuda_collision_detection_kernel(obj, distances, times, safety_distance)
            % CUDA碰撞檢測核心
            
            conflicts = [];
            [n_drones, ~, n_times] = size(distances);
            
            % 找到所有小於安全距離的位置
            collision_mask = distances < safety_distance & distances > 0; % 排除自己
            
            % 提取衝突信息
            for t = 1:n_times
                [row_indices, col_indices] = find(collision_mask(:, :, t));
                
                % 避免重複 (只保留i < j的配對)
                valid_pairs = row_indices < col_indices;
                row_indices = row_indices(valid_pairs);
                col_indices = col_indices(valid_pairs);
                
                for k = 1:length(row_indices)
                    conflict = struct();
                    conflict.drone1_id = row_indices(k);
                    conflict.drone2_id = col_indices(k);
                    conflict.time = gather(times(t));
                    conflict.distance = gather(distances(row_indices(k), col_indices(k), t));
                    conflict.severity = (safety_distance - conflict.distance) / safety_distance;
                    
                    conflicts = [conflicts; conflict]; %#ok<AGROW>
                end
            end
        end
        
        function interpolated = cuda_interpolation_kernel(obj, trajectory, query_times)
            % CUDA軌跡插值核心
            
            n_query = length(query_times);
            interpolated = zeros(n_query, 3);
            
            if isempty(trajectory)
                return;
            end
            
            % 提取軌跡數據
            traj_times = [trajectory.time];
            traj_x = [trajectory.x];
            traj_y = [trajectory.y];
            traj_z = [trajectory.z];
            
            % 轉換為GPU陣列
            traj_times_gpu = gpuArray(traj_times);
            traj_x_gpu = gpuArray(traj_x);
            traj_y_gpu = gpuArray(traj_y);
            traj_z_gpu = gpuArray(traj_z);
            query_times_gpu = gpuArray(query_times);
            
            % GPU線性插值
            x_interp = interp1(traj_times_gpu, traj_x_gpu, query_times_gpu, 'linear', 'extrap');
            y_interp = interp1(traj_times_gpu, traj_y_gpu, query_times_gpu, 'linear', 'extrap');
            z_interp = interp1(traj_times_gpu, traj_z_gpu, query_times_gpu, 'linear', 'extrap');
            
            % 收集結果
            interpolated = gather([x_interp(:), y_interp(:), z_interp(:)]);
        end
        
        %% === 內建GPU函數實現 ===
        
        function distances = builtin_distance_matrix(obj, positions)
            % 使用MATLAB內建GPU函數計算距離矩陣
            
            [n_drones, ~, n_times] = size(positions);
            distances = gpuArray.zeros([n_drones, n_drones, n_times], class(positions));
            
            for t = 1:n_times
                pos = positions(:, :, t);
                
                % 使用pdist2計算成對距離
                distances(:, :, t) = sqrt(sum((pos - permute(pos, [2, 1, 3])).^2, 2));
            end
        end
        
        function conflicts = builtin_collision_detection(obj, distances, times, safety_distance)
            % 使用內建函數進行碰撞檢測
            
            conflicts = [];
            [n_drones, ~, n_times] = size(distances);
            
            for t = 1:n_times
                dist_matrix = distances(:, :, t);
                
                % 找到碰撞
                [i, j] = find(dist_matrix < safety_distance & dist_matrix > 0);
                valid = i < j; % 避免重複
                
                for k = find(valid)'
                    conflict = struct();
                    conflict.drone1_id = i(k);
                    conflict.drone2_id = j(k);
                    conflict.time = gather(times(t));
                    conflict.distance = gather(dist_matrix(i(k), j(k)));
                    conflict.severity = (safety_distance - conflict.distance) / safety_distance;
                    
                    conflicts = [conflicts; conflict]; %#ok<AGROW>
                end
            end
        end
        
        function interpolated = builtin_interpolation(obj, trajectory, query_times)
            % 使用MATLAB內建GPU函數進行插值
            
            interpolated = obj.cuda_interpolation_kernel(trajectory, query_times);
        end
        
        %% === 進階GPU計算功能 ===
        
        function optimized_trajectories = optimize_trajectories_gpu(obj, initial_trajectories, constraints)
            % GPU加速軌跡優化
            
            fprintf('   🎯 GPU軌跡優化...\n');
            start_time = tic;
            
            try
                n_drones = length(initial_trajectories);
                optimized_trajectories = containers.Map();
                
                % 轉換軌跡數據為GPU格式
                gpu_trajectories = obj.convert_trajectories_to_gpu(initial_trajectories);
                
                % 應用約束條件
                if nargin > 2 && ~isempty(constraints)
                    gpu_trajectories = obj.apply_trajectory_constraints_gpu(gpu_trajectories, constraints);
                end
                
                % 優化軌跡 (梯度下降或其他優化算法)
                optimized_gpu_trajectories = obj.run_trajectory_optimization_gpu(gpu_trajectories);
                
                % 轉換回MATLAB格式
                optimized_trajectories = obj.convert_trajectories_from_gpu(optimized_gpu_trajectories);
                
                optimization_time = toc(start_time);
                fprintf('   ✅ 軌跡優化完成 (用時%.3fs)\n', optimization_time);
                
            catch ME
                fprintf('   ❌ GPU軌跡優化失敗: %s\n', ME.message);
                optimized_trajectories = initial_trajectories; % 返回原始軌跡
            end
        end
        
        function wind_effects = simulate_wind_effects_gpu(obj, positions, wind_field, time_step)
            % GPU加速風場效應模擬
            
            if nargin < 4
                time_step = 0.1;
            end
            
            fprintf('   💨 GPU風場模擬...\n');
            start_time = tic;
            
            try
                % 將位置和風場數據上傳到GPU
                positions_gpu = gpuArray(positions);
                wind_field_gpu = obj.convert_wind_field_to_gpu(wind_field);
                
                % 計算風場對每個位置的影響
                wind_velocities = obj.interpolate_wind_field_gpu(positions_gpu, wind_field_gpu);
                
                % 計算風阻和推力影響
                wind_effects = obj.calculate_wind_forces_gpu(positions_gpu, wind_velocities, time_step);
                
                % 轉換回CPU
                wind_effects = gather(wind_effects);
                
                simulation_time = toc(start_time);
                fprintf('   ✅ 風場模擬完成 (用時%.3fs)\n', simulation_time);
                
            catch ME
                fprintf('   ❌ GPU風場模擬失敗: %s\n', ME.message);
                wind_effects = zeros(size(positions));
            end
        end
        
        function formation_commands = compute_formation_control_gpu(obj, current_positions, target_formation, control_gains)
            % GPU加速編隊控制計算
            
            fprintf('   ⭐ GPU編隊控制計算...\n');
            start_time = tic;
            
            try
                n_drones = size(current_positions, 1);
                
                % 上傳數據到GPU
                current_gpu = gpuArray(current_positions);
                target_gpu = gpuArray(target_formation);
                gains_gpu = gpuArray(control_gains);
                
                % 計算誤差
                position_errors = target_gpu - current_gpu;
                
                % 應用控制增益
                formation_commands = zeros(n_drones, 4, 'like', current_gpu); % [thrust, roll, pitch, yaw]
                
                for i = 1:n_drones
                    error = position_errors(i, :);
                    
                    % PID控制器 (簡化)
                    thrust_cmd = gains_gpu.kp_z * error(3);
                    roll_cmd = gains_gpu.kp_y * error(2);
                    pitch_cmd = gains_gpu.kp_x * error(1);
                    yaw_cmd = 0; % 保持航向
                    
                    formation_commands(i, :) = [thrust_cmd, roll_cmd, pitch_cmd, yaw_cmd];
                end
                
                % 轉換回CPU
                formation_commands = gather(formation_commands);
                
                control_time = toc(start_time);
                fprintf('   ✅ 編隊控制計算完成 (用時%.3fs)\n', control_time);
                
            catch ME
                fprintf('   ❌ GPU編隊控制計算失敗: %s\n', ME.message);
                formation_commands = zeros(size(current_positions, 1), 4);
            end
        end
        
        %% === 性能監控和優化 ===
        
        function update_collision_detection_stats(obj, computation_time, n_drones, n_times)
            % 更新碰撞檢測性能統計
            
            operations_count = n_drones * (n_drones - 1) / 2 * n_times;
            throughput = operations_count / computation_time;
            
            obj.performance_stats.kernel_times('collision_detection') = computation_time;
            obj.performance_stats.total_operations = obj.performance_stats.total_operations + operations_count;
            
            % 更新平均吞吐量
            if isfield(obj.performance_stats, 'collision_detection_throughput')
                obj.performance_stats.collision_detection_throughput = ...
                    (obj.performance_stats.collision_detection_throughput + throughput) / 2;
            else
                obj.performance_stats.collision_detection_throughput = throughput;
            end
        end
        
        function update_memory_usage(obj)
            % 更新記憶體使用統計
            
            if ~isempty(obj.gpu_device)
                current_free = obj.gpu_device.AvailableMemory;
                total_memory = obj.gpu_device.TotalMemory;
                used_memory = total_memory - current_free;
                
                obj.memory_manager.current_usage = used_memory;
                obj.memory_manager.peak_usage = max(obj.memory_manager.peak_usage, used_memory);
            end
        end
        
        function print_performance_summary(obj)
            % 打印性能摘要
            
            fprintf('\n📊 GPU計算核心性能摘要\n');
            fprintf('══════════════════════════════════════\n');
            
            if ~isempty(obj.gpu_device)
                fprintf('🎮 GPU設備: %s\n', obj.gpu_device.Name);
                fprintf('💾 記憶體使用: %.1fMB / %.1fGB\n', ...
                       obj.memory_manager.current_usage/1e6, ...
                       obj.gpu_device.TotalMemory/1e9);
                fprintf('📈 峰值記憶體: %.1fMB\n', obj.memory_manager.peak_usage/1e6);
            end
            
            if ~isempty(obj.performance_stats.kernel_times)
                fprintf('\n⏱️ 核心函數性能:\n');
                kernel_names = obj.performance_stats.kernel_times.keys;
                for i = 1:length(kernel_names)
                    kernel_name = kernel_names{i};
                    kernel_time = obj.performance_stats.kernel_times(kernel_name);
                    fprintf('   %s: %.3fs\n', kernel_name, kernel_time);
                end
            end
            
            if isfield(obj.performance_stats, 'collision_detection_throughput')
                fprintf('\n🔍 碰撞檢測吞吐量: %.0f ops/s\n', ...
                       obj.performance_stats.collision_detection_throughput);
            end
            
            fprintf('📊 總操作數: %d\n', obj.performance_stats.total_operations);
            fprintf('══════════════════════════════════════\n\n');
        end
        
        %% === 輔助函數 ===
        
        function is_sufficient = check_preallocated_memory_size(obj, n_drones, n_times)
            % 檢查預分配記憶體是否足夠
            
            is_sufficient = false;
            
            if obj.memory_manager.allocated_blocks.isKey('positions')
                pos_block = obj.memory_manager.allocated_blocks('positions');
                [max_drones, ~, max_times] = size(pos_block);
                is_sufficient = (n_drones <= max_drones) && (n_times <= max_times);
            end
        end
        
        function conflicts = fallback_cpu_collision_detection(obj, drone_positions, timestamps, safety_distance)
            % CPU備用碰撞檢測
            
            fprintf('   🔄 降級到CPU碰撞檢測...\n');
            conflicts = [];
            
            drone_ids = keys(drone_positions);
            n_drones = length(drone_ids);
            
            for i = 1:n_drones-1
                for j = i+1:n_drones
                    drone1 = drone_ids{i};
                    drone2 = drone_ids{j};
                    
                    traj1 = drone_positions(drone1);
                    traj2 = drone_positions(drone2);
                    
                    % 簡化距離檢查
                    for t_idx = 1:length(timestamps)
                        t = timestamps(t_idx);
                        
                        pos1 = obj.interpolate_trajectory_cpu(traj1, t);
                        pos2 = obj.interpolate_trajectory_cpu(traj2, t);
                        
                        if ~isempty(pos1) && ~isempty(pos2)
                            distance = norm([pos1.x - pos2.x, pos1.y - pos2.y, pos1.z - pos2.z]);
                            
                            if distance < safety_distance
                                conflict = struct();
                                conflict.drone1_id = drone1;
                                conflict.drone2_id = drone2;
                                conflict.time = t;
                                conflict.distance = distance;
                                conflict.severity = (safety_distance - distance) / safety_distance;
                                
                                conflicts = [conflicts; conflict]; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end
        
        function pos = interpolate_trajectory_cpu(obj, trajectory, time)
            % CPU軌跡插值
            
            pos = [];
            
            if isempty(trajectory)
                return;
            end
            
            times = [trajectory.time];
            
            if time <= times(1)
                pos = trajectory(1);
            elseif time >= times(end)
                pos = trajectory(end);
            else
                % 線性插值
                idx = find(times <= time, 1, 'last');
                if idx < length(times)
                    t1 = times(idx);
                    t2 = times(idx + 1);
                    ratio = (time - t1) / (t2 - t1);
                    
                    p1 = trajectory(idx);
                    p2 = trajectory(idx + 1);
                    
                    pos = struct();
                    pos.x = p1.x + ratio * (p2.x - p1.x);
                    pos.y = p1.y + ratio * (p2.y - p1.y);
                    pos.z = p1.z + ratio * (p2.z - p1.z);
                    pos.time = time;
                end
            end
        end
        
        function str_result = bool_to_str(obj, bool_val, true_str, false_str)
            % 布林值轉字符串
            if bool_val
                str_result = true_str;
            else
                str_result = false_str;
            end
        end
        
        function delete(obj)
            % 析構函數 - 清理GPU資源
            
            try
                if ~isempty(obj.memory_manager) && isfield(obj.memory_manager, 'allocated_blocks')
                    block_keys = obj.memory_manager.allocated_blocks.keys;
                    for i = 1:length(block_keys)
                        clear(obj.memory_manager.allocated_blocks(block_keys{i}));
                    end
                end
                
                if ~isempty(obj.gpu_device)
                    gpuDevice([]); % 重置GPU設備
                end
                
                fprintf('🧹 GPU計算核心資源已清理\n');
                
            catch ME
                fprintf('⚠️ GPU資源清理警告: %s\n', ME.message);
            end
        end
    end
end

%% === 獨立GPU工具函數 ===

function test_gpu_compute_core()
    % 測試GPU計算核心功能
    
    fprintf('🧪 測試GPU計算核心...\n');
    
    try
        % 創建GPU計算核心
        gpu_core = GPUComputeCore();
        
        % 創建測試軌跡數據
        n_drones = 5;
        n_timepoints = 1000;
        
        test_trajectories = containers.Map();
        timestamps = linspace(0, 100, n_timepoints);
        
        for i = 1:n_drones
            drone_id = sprintf('TestDrone_%d', i);
            
            trajectory = struct();
            trajectory.time = timestamps;
            trajectory.x = 100 * cos(timestamps * 0.1 + i) + i * 50;
            trajectory.y = 100 * sin(timestamps * 0.1 + i) + i * 50;
            trajectory.z = 50 + 10 * sin(timestamps * 0.05);
            
            % 轉換為結構體陣列格式
            traj_array = [];
            for j = 1:length(timestamps)
                point = struct();
                point.time = trajectory.time(j);
                point.x = trajectory.x(j);
                point.y = trajectory.y(j);
                point.z = trajectory.z(j);
                traj_array = [traj_array; point]; %#ok<AGROW>
            end
            
            test_trajectories(drone_id) = traj_array;
        end
        
        % 測試碰撞檢測
        fprintf('   測試GPU碰撞檢測...\n');
        [conflicts, detection_time] = gpu_core.detect_collisions_gpu(test_trajectories, timestamps, 20.0);
        
        fprintf('   結果: 檢測到%d個衝突，用時%.3fs\n', length(conflicts), detection_time);
        
        % 打印性能摘要
        gpu_core.print_performance_summary();
        
        % 清理
        delete(gpu_core);
        
        fprintf('✅ GPU計算核心測試完成\n');
        
    catch ME
        fprintf('❌ GPU計算核心測試失敗: %s\n', ME.message);
        fprintf('堆疊追蹤:\n');
        for i = 1:length(ME.stack)
            fprintf('   %s (第%d行)\n', ME.stack(i).file, ME.stack(i).line);
        end
    end
end