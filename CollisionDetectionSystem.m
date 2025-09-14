classdef CollisionDetectionSystem < handle
    % 先進碰撞檢測與避免系統
    % 支援GPU/CPU自適應計算的實時碰撞檢測
    
    properties
        simulator               % 主模擬器引用
        collision_warnings      % 即時碰撞警告列表
        trajectory_conflicts    % 軌跡衝突列表
        performance_metrics     % 性能指標
        gpu_functional          % GPU功能狀態
        last_collision_check    % 上次碰撞檢查時間
    end
    
    methods
        function obj = CollisionDetectionSystem(simulator)
            % 建構函數
            obj.simulator = simulator;
            obj.collision_warnings = {};
            obj.trajectory_conflicts = {};
            obj.performance_metrics = struct();
            obj.last_collision_check = 0.0;
            
            % 測試GPU功能
            obj.gpu_functional = obj.test_gpu_functionality();
            
            mode_text = obj.get_compute_mode_text();
            fprintf('碰撞檢測系統已初始化 (%s)\n', mode_text);
        end
        
        function is_functional = test_gpu_functionality(obj)
            % 測試GPU功能是否正常
            is_functional = false;
            
            if ~obj.simulator.gpu_available || ~obj.simulator.use_gpu
                return;
            end
            
            try
                % 測試基本GPU計算
                test_data = gpuArray(ones(100, 3, 'single'));
                test_result = sum(test_data, 'all');
                
                % 清理測試數據
                clear test_data test_result;
                
                is_functional = true;
                fprintf('GPU功能測試通過\n');
                
            catch ME
                fprintf('GPU功能測試失敗: %s\n', ME.message);
                is_functional = false;
            end
        end
        
        function mode_text = get_compute_mode_text(obj)
            % 獲取計算模式文字
            if obj.gpu_functional && obj.simulator.use_gpu
                mode_text = 'GPU加速';
            else
                mode_text = 'CPU模式';
            end
        end
        
        function analyze_trajectory_conflicts(obj)
            % 分析軌跡衝突的主要入口函數
            if obj.simulator.drones.Count < 2
                fprintf('無需進行軌跡衝突分析（無人機數量 < 2）\n');
                return;
            end
            
            tic;
            
            if obj.gpu_functional && obj.simulator.use_gpu
                conflicts = obj.analyze_conflicts_gpu();
            else
                conflicts = obj.analyze_conflicts_cpu();
            end
            
            computation_time = toc;
            
            obj.trajectory_conflicts = conflicts;
            obj.update_performance_metrics(computation_time);
            
            fprintf('軌跡衝突分析完成: 發現 %d 個衝突，耗時 %.3f 秒 (%s)\n', ...
                    length(conflicts), computation_time, obj.get_compute_mode_text());
            
            if ~isempty(conflicts)
                obj.generate_avoidance_strategies(conflicts);
            end
        end
        
        function conflicts = analyze_conflicts_gpu(obj)
            % GPU加速的軌跡衝突分析
            conflicts = {};
            
            try
                drone_keys = obj.simulator.drones.keys;
                n_drones = length(drone_keys);
                
                if n_drones < 2
                    return;
                end
                
                % 設定時間檢查點（每0.5秒檢查一次）
                max_time = obj.simulator.max_time;
                time_step = 0.5;
                check_times = 0:time_step:max_time;
                
                fprintf('GPU模式：檢查 %d 個時間點，%d 架無人機...\n', ...
                        length(check_times), n_drones);
                
                % 為每個時間點計算所有無人機位置
                positions_matrix = zeros(length(check_times), n_drones, 3);
                
                for t_idx = 1:length(check_times)
                    current_time = check_times(t_idx);
                    
                    for d_idx = 1:n_drones
                        drone_id = drone_keys{d_idx};
                        drone_data = obj.simulator.drones(drone_id);
                        
                        pos = obj.interpolate_position(drone_data.trajectory, current_time);
                        if ~isempty(pos)
                            positions_matrix(t_idx, d_idx, :) = [pos.x, pos.y, pos.z];
                        end
                    end
                end
                
                % 轉移到GPU
                gpu_positions = gpuArray(single(positions_matrix));
                
                % 計算距離矩陣並檢測衝突
                conflicts = obj.detect_conflicts_batch_gpu(gpu_positions, check_times, drone_keys);
                
                % 清理GPU記憶體
                clear gpu_positions;
                
            catch ME
                fprintf('GPU衝突分析失敗，回退到CPU模式: %s\n', ME.message);
                conflicts = obj.analyze_conflicts_cpu();
            end
        end
        
        function conflicts = detect_conflicts_batch_gpu(obj, gpu_positions, check_times, drone_keys)
            % GPU批量衝突檢測
            conflicts = {};
            
            [n_times, n_drones, ~] = size(gpu_positions);
            safety_distance = obj.simulator.safety_distance;
            
            fprintf('GPU批量檢測中...\n');
            
            % 計算所有時間點的距離矩陣
            for t = 1:n_times
                current_positions = squeeze(gpu_positions(t, :, :)); % [n_drones, 3]
                
                % 計算所有配對的距離
                for i = 1:n_drones
                    for j = (i+1):n_drones
                        pos_i = current_positions(i, :);
                        pos_j = current_positions(j, :);
                        
                        diff = pos_i - pos_j;
                        distance = sqrt(sum(diff.^2));
                        
                        % 轉回CPU檢查（小量數據）
                        distance_cpu = gather(distance);
                        
                        if distance_cpu < safety_distance
                            conflict = struct();
                            conflict.time = check_times(t);
                            conflict.drone1 = drone_keys{i};
                            conflict.drone2 = drone_keys{j};
                            conflict.distance = distance_cpu;
                            conflict.severity = obj.calculate_severity(distance_cpu);
                            conflict.type = 'trajectory_conflict';
                            
                            conflicts{end+1} = conflict; %#ok<AGROW>
                        end
                    end
                end
            end
            
            fprintf('GPU檢測到 %d 個軌跡衝突\n', length(conflicts));
        end
        
        function conflicts = analyze_conflicts_cpu(obj)
            % CPU版本的軌跡衝突分析
            conflicts = {};
            
            drone_keys = obj.simulator.drones.keys;
            n_drones = length(drone_keys);
            
            if n_drones < 2
                return;
            end
            
            fprintf('CPU模式：分析 %d 架無人機的軌跡衝突...\n', n_drones);
            
            % 時間檢查點
            max_time = obj.simulator.max_time;
            time_step = 0.5;
            check_times = 0:time_step:max_time;
            
            % 檢查每個時間點的所有無人機配對
            for t_idx = 1:length(check_times)
                current_time = check_times(t_idx);
                
                % 獲取當前時間所有無人機位置
                positions = containers.Map();
                for d_idx = 1:n_drones
                    drone_id = drone_keys{d_idx};
                    drone_data = obj.simulator.drones(drone_id);
                    pos = obj.interpolate_position(drone_data.trajectory, current_time);
                    if ~isempty(pos)
                        positions(drone_id) = pos;
                    end
                end
                
                % 檢查所有配對
                for i = 1:n_drones
                    for j = (i+1):n_drones
                        drone_i = drone_keys{i};
                        drone_j = drone_keys{j};
                        
                        if positions.isKey(drone_i) && positions.isKey(drone_j)
                            pos_i = positions(drone_i);
                            pos_j = positions(drone_j);
                            
                            distance = obj.calculate_distance_3d(pos_i, pos_j);
                            
                            if distance < obj.simulator.safety_distance
                                conflict = struct();
                                conflict.time = current_time;
                                conflict.drone1 = drone_i;
                                conflict.drone2 = drone_j;
                                conflict.distance = distance;
                                conflict.severity = obj.calculate_severity(distance);
                                conflict.type = 'trajectory_conflict';
                                
                                conflicts{end+1} = conflict; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
            
            fprintf('CPU檢測到 %d 個軌跡衝突\n', length(conflicts));
        end
        
        function pos = interpolate_position(~, trajectory, target_time)
            % 在軌跡中插值計算指定時間的位置
            pos = [];
            
            if isempty(trajectory)
                return;
            end
            
            % 提取時間序列
            times = [trajectory.time];
            
            % 邊界條件處理
            if target_time <= times(1)
                pos = trajectory(1);
                return;
            elseif target_time >= times(end)
                pos = trajectory(end);
                return;
            end
            
            % 找到插值區間
            idx = find(times <= target_time, 1, 'last');
            if idx == length(times)
                pos = trajectory(end);
                return;
            end
            
            % 線性插值
            t1 = times(idx);
            t2 = times(idx + 1);
            
            if t2 > t1
                ratio = (target_time - t1) / (t2 - t1);
            else
                ratio = 0;
            end
            
            pos1 = trajectory(idx);
            pos2 = trajectory(idx + 1);
            
            pos = struct();
            pos.time = target_time;
            pos.x = pos1.x + ratio * (pos2.x - pos1.x);
            pos.y = pos1.y + ratio * (pos2.y - pos1.y);
            pos.z = pos1.z + ratio * (pos2.z - pos1.z);
            pos.phase = pos1.phase;
            if isfield(pos1, 'speed')
                pos.speed = pos1.speed + ratio * (pos2.speed - pos1.speed);
            else
                pos.speed = 8.0; % 預設速度
            end
        end
        
        function distance = calculate_distance_3d(~, pos1, pos2)
            % 計算兩個3D位置之間的距離
            dx = pos1.x - pos2.x;
            dy = pos1.y - pos2.y;
            dz = pos1.z - pos2.z;
            distance = sqrt(dx^2 + dy^2 + dz^2);
        end
        
        function severity = calculate_severity(obj, distance)
            % 計算衝突嚴重程度
            if distance <= obj.simulator.critical_distance
                severity = 'critical';
            elseif distance <= obj.simulator.safety_distance * 0.7
                severity = 'high';
            elseif distance <= obj.simulator.safety_distance * 0.85
                severity = 'medium';
            else
                severity = 'low';
            end
        end
        
        function [warnings, loiter_commands] = check_real_time_collisions(obj, current_time)
            % 實時碰撞檢測
            warnings = {};
            loiter_commands = containers.Map();
            
            % 限制檢查頻率以提高性能
            if current_time - obj.last_collision_check < 0.1
                warnings = obj.collision_warnings;
                return;
            end
            
            obj.last_collision_check = current_time;
            
            % 獲取當前所有無人機位置
            current_positions = obj.get_current_positions(current_time);
            
            if length(current_positions.keys) < 2
                obj.collision_warnings = warnings;
                return;
            end
            
            % 執行碰撞檢測
            if obj.gpu_functional && obj.simulator.use_gpu && length(current_positions.keys) >= 4
                [warnings, loiter_commands] = obj.check_collisions_gpu(current_positions, current_time);
            else
                [warnings, loiter_commands] = obj.check_collisions_cpu(current_positions, current_time);
            end
            
            obj.collision_warnings = warnings;
        end
        
        function current_positions = get_current_positions(obj, current_time)
            % 獲取當前時間所有無人機的位置
            current_positions = containers.Map();
            
            drone_keys = obj.simulator.drones.keys;
            for i = 1:length(drone_keys)
                drone_id = drone_keys{i};
                drone_data = obj.simulator.drones(drone_id);
                
                if ~isempty(drone_data.trajectory)
                    pos = obj.interpolate_position(drone_data.trajectory, current_time);
                    if ~isempty(pos)
                        current_positions(drone_id) = pos;
                    end
                end
            end
        end
        
        function [warnings, loiter_commands] = check_collisions_gpu(obj, positions, current_time)
            % GPU版本的實時碰撞檢測
            warnings = {};
            loiter_commands = containers.Map();
            
            try
                drone_keys = positions.keys;
                n_drones = length(drone_keys);
                
                % 準備位置矩陣
                pos_matrix = zeros(n_drones, 3, 'single');
                for i = 1:n_drones
                    pos = positions(drone_keys{i});
                    pos_matrix(i, :) = [pos.x, pos.y, pos.z];
                end
                
                % 轉移到GPU
                gpu_positions = gpuArray(pos_matrix);
                
                % 計算距離矩陣
                gpu_distances = obj.compute_distance_matrix_gpu(gpu_positions);
                
                % 轉回CPU
                distances = gather(gpu_distances);
                
                % 檢測碰撞
                safety_distance = obj.simulator.safety_distance;
                warning_distance = obj.simulator.warning_distance;
                
                for i = 1:n_drones
                    for j = (i+1):n_drones
                        distance = distances(i, j);
                        
                        if distance < warning_distance
                            warning = struct();
                            warning.time = current_time;
                            warning.drone1 = drone_keys{i};
                            warning.drone2 = drone_keys{j};
                            warning.distance = distance;
                            warning.severity = obj.calculate_severity(distance);
                            warning.type = 'real_time_collision';
                            
                            warnings{end+1} = warning; %#ok<AGROW>
                            
                            % 如果距離過近，生成LOITER命令
                            if distance < safety_distance
                                wait_time = obj.calculate_loiter_time(distance);
                                % 編號大的無人機等待
                                if str2double(drone_keys{j}(end)) > str2double(drone_keys{i}(end))
                                    loiter_commands(drone_keys{j}) = wait_time;
                                else
                                    loiter_commands(drone_keys{i}) = wait_time;
                                end
                            end
                        end
                    end
                end
                
                % 清理GPU記憶體
                clear gpu_positions gpu_distances;
                
            catch ME
                fprintf('GPU實時碰撞檢測失敗: %s\n', ME.message);
                [warnings, loiter_commands] = obj.check_collisions_cpu(positions, current_time);
            end
        end
        
        function [warnings, loiter_commands] = check_collisions_cpu(obj, positions, current_time)
            % CPU版本的實時碰撞檢測
            warnings = {};
            loiter_commands = containers.Map();
            
            drone_keys = positions.keys;
            n_drones = length(drone_keys);
            
            safety_distance = obj.simulator.safety_distance;
            warning_distance = obj.simulator.warning_distance;
            
            for i = 1:n_drones
                for j = (i+1):n_drones
                    pos1 = positions(drone_keys{i});
                    pos2 = positions(drone_keys{j});
                    
                    distance = obj.calculate_distance_3d(pos1, pos2);
                    
                    if distance < warning_distance
                        warning = struct();
                        warning.time = current_time;
                        warning.drone1 = drone_keys{i};
                        warning.drone2 = drone_keys{j};
                        warning.distance = distance;
                        warning.severity = obj.calculate_severity(distance);
                        warning.type = 'real_time_collision';
                        
                        warnings{end+1} = warning; %#ok<AGROW>
                        
                        if distance < safety_distance
                            wait_time = obj.calculate_loiter_time(distance);
                            % 編號大的無人機等待
                            if str2double(drone_keys{j}(end)) > str2double(drone_keys{i}(end))
                                loiter_commands(drone_keys{j}) = wait_time;
                            else
                                loiter_commands(drone_keys{i}) = wait_time;
                            end
                        end
                    end
                end
            end
        end
        
        function gpu_distances = compute_distance_matrix_gpu(~, gpu_positions)
            % 在GPU上計算距離矩陣
            [n_drones, ~] = size(gpu_positions);
            gpu_distances = zeros(n_drones, n_drones, 'single', 'gpuArray');
            
            for i = 1:n_drones
                for j = 1:n_drones
                    if i ~= j
                        diff = gpu_positions(i, :) - gpu_positions(j, :);
                        gpu_distances(i, j) = sqrt(sum(diff.^2));
                    end
                end
            end
        end
        
        function wait_time = calculate_loiter_time(~, distance)
            % 根據距離計算等待時間
            if distance <= 2.0
                wait_time = 10.0; % 非常接近，等待10秒
            elseif distance <= 3.0
                wait_time = 5.0;  % 較近，等待5秒
            else
                wait_time = 2.0;  % 一般，等待2秒
            end
        end
        
        function generate_avoidance_strategies(obj, conflicts)
            % 生成避撞策略
            if isempty(conflicts)
                return;
            end
            
            fprintf('正在生成 %d 個衝突的避撞策略...\n', length(conflicts));
            
            % 按時間排序衝突
            conflict_times = cellfun(@(c) c.time, conflicts);
            [~, sort_idx] = sort(conflict_times);
            sorted_conflicts = conflicts(sort_idx);
            
            % 為每個衝突生成避撞命令
            for i = 1:min(length(sorted_conflicts), 5) % 最多顯示前5個
                conflict = sorted_conflicts{i};
                
                % 決定哪架無人機需要等待（編號大的等待編號小的）
                drone1_num = str2double(conflict.drone1(end));
                drone2_num = str2double(conflict.drone2(end));
                
                if drone2_num > drone1_num
                    waiting_drone = conflict.drone2;
                    passing_drone = conflict.drone1;
                else
                    waiting_drone = conflict.drone1;
                    passing_drone = conflict.drone2;
                end
                
                % 計算等待時間
                wait_time = obj.calculate_loiter_time(conflict.distance);
                
                fprintf('衝突 %d: 時間 %.1fs, %s <-> %s, 距離 %.1fm, %s 等待 %.1fs\n', ...
                        i, conflict.time, conflict.drone1, conflict.drone2, ...
                        conflict.distance, waiting_drone, wait_time);
            end
            
            if length(sorted_conflicts) > 5
                fprintf('... 還有 %d 個衝突未顯示\n', length(sorted_conflicts) - 5);
            end
        end
        
        function update_performance_metrics(obj, computation_time)
            % 更新性能指標
            if obj.gpu_functional && obj.simulator.use_gpu
                obj.performance_metrics.gpu_computation_time = computation_time;
                obj.performance_metrics.cpu_computation_time = 0;
            else
                obj.performance_metrics.gpu_computation_time = 0;
                obj.performance_metrics.cpu_computation_time = computation_time;
            end
            
            obj.performance_metrics.last_update = datetime('now');
            obj.performance_metrics.total_conflicts = length(obj.trajectory_conflicts);
            obj.performance_metrics.current_warnings = length(obj.collision_warnings);
        end
        
        function metrics = get_performance_summary(obj)
            % 獲取性能摘要
            metrics = obj.performance_metrics;
            
            if isfield(metrics, 'gpu_computation_time') && isfield(metrics, 'cpu_computation_time')
                if metrics.gpu_computation_time > 0
                    metrics.compute_mode = 'GPU';
                    metrics.computation_time = metrics.gpu_computation_time;
                else
                    metrics.compute_mode = 'CPU';
                    metrics.computation_time = metrics.cpu_computation_time;
                end
            end
        end
    end
end