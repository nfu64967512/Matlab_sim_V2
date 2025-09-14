classdef QGCFileParser < handle
    % QGC文件解析器類別
    % 負責解析QGroundControl waypoint文件和CSV座標文件
    
    properties
        simulator      % 主模擬器引用
        supported_formats  % 支援的文件格式
    end
    
    methods
        function obj = QGCFileParser(simulator)
            obj.simulator = simulator;
            obj.supported_formats = {'.waypoints', '.txt', '.csv'};
            fprintf('QGC文件解析器已初始化\n');
        end
        
        function load_qgc_files(obj)
            % 載入QGC文件
            [filenames, pathname] = uigetfile({
                '*.waypoints;*.txt', 'QGC Waypoint Files (*.waypoints, *.txt)';
                '*.csv', 'CSV座標文件 (*.csv)';
                '*.*', 'All Files (*.*)'
            }, '選擇無人機任務文件', 'MultiSelect', 'on');
            
            if isequal(filenames, 0)
                return;
            end
            
            if ischar(filenames)
                filenames = {filenames};
            end
            
            % 清理現有數據
            obj.simulator.drones.remove(obj.simulator.drones.keys);
            obj.simulator.current_time = 0.0;
            
            loaded_count = 0;
            colors = {'r', 'g', 'b', 'y', 'm', 'c'};
            
            for i = 1:min(length(filenames), 6) % 最多6架無人機
                try
                    full_filepath = fullfile(pathname, filenames{i});
                    [~, ~, ext] = fileparts(filenames{i});
                    
                    if strcmp(ext, '.csv')
                        drone_data = obj.parse_csv_file(full_filepath, i);
                    else
                        drone_data = obj.parse_qgc_file(full_filepath, i);
                    end
                    
                    if ~isempty(drone_data)
                        drone_id = sprintf('Drone_%d', i);
                        drone_data.color = colors{i};
                        drone_data.drone_number = i;
                        
                        % 設置座標原點（第一架無人機）
                        if i == 1 && ~isempty(drone_data.waypoints)
                            obj.simulator.coordinate_system.set_origin(...
                                drone_data.waypoints(1).lat, drone_data.waypoints(1).lon);
                        end
                        
                        % 計算軌跡
                        drone_data.trajectory = obj.calculate_trajectory(drone_data.waypoints);
                        
                        obj.simulator.drones(drone_id) = drone_data;
                        loaded_count = loaded_count + 1;
                        
                        fprintf('%s 載入成功: %d 個航點\n', drone_id, length(drone_data.waypoints));
                    end
                    
                catch ME
                    fprintf('錯誤: 載入文件 %s 失敗: %s\n', filenames{i}, ME.message);
                end
            end
            
            if loaded_count > 0
                % 更新模擬器狀態
                obj.simulator.update_max_time();
                
                % 立即更新3D視覺化顯示
                if ~isempty(obj.simulator.visualization)
                    obj.simulator.visualization.update_3d_plot();
                end
                
                % 更新狀態顯示
                obj.simulator.update_status_display();
                
                % 如果有多架無人機，執行軌跡分析
                if loaded_count > 1
                    obj.simulator.collision_system.analyze_trajectory_conflicts();
                end
                
                msgbox(sprintf('成功載入 %d 架無人機任務\n軌跡已顯示在3D視圖中', loaded_count), '載入完成', 'help');
            else
                msgbox('未能載入任何有效的無人機任務', '載入失敗', 'error');
            end
        end
        
        function drone_data = parse_qgc_file(obj, file_path, drone_id)
            % 解析QGC waypoint文件
            drone_data = struct();
            drone_data.waypoints = [];
            drone_data.original_lines = {};
            drone_data.file_path = file_path;
            
            try
                % 讀取文件
                fid = fopen(file_path, 'r', 'n', 'UTF-8');
                if fid == -1
                    error('無法打開文件: %s', file_path);
                end
                
                lines = {};
                while ~feof(fid)
                    line = fgetl(fid);
                    if ischar(line)
                        lines{end+1} = line; %#ok<AGROW>
                    end
                end
                fclose(fid);
                
                drone_data.original_lines = lines;
                
                % 解析航點
                for i = 2:length(lines) % 跳過標題行
                    line = strtrim(lines{i});
                    if isempty(line) || startsWith(line, '#')
                        continue;
                    end
                    
                    waypoint = obj.parse_qgc_line(line, i);
                    if ~isempty(waypoint)
                        drone_data.waypoints = [drone_data.waypoints; waypoint];
                    end
                end
                
                fprintf('QGC文件解析完成: %d 個航點\n', length(drone_data.waypoints));
                
            catch ME
                fprintf('QGC文件解析失敗: %s\n', ME.message);
                drone_data = [];
            end
        end
        
        function waypoint = parse_qgc_line(~, line, line_index)
            % 解析單行QGC數據
            waypoint = [];
            
            parts = strsplit(line, '\t');
            if length(parts) < 12
                return;
            end
            
            try
                seq = str2double(parts{1});
                cmd = str2double(parts{4});
                lat = str2double(parts{9});
                lon = str2double(parts{10});
                alt = str2double(parts{11});
                
                % 檢查數據有效性
                if isnan(seq) || isnan(cmd) || isnan(lat) || isnan(lon) || isnan(alt)
                    return;
                end
                
                % 只處理有效的航點命令
                if ismember(cmd, [16, 179, 22, 20, 19, 21]) && lat ~= 0 && lon ~= 0
                    waypoint = struct();
                    waypoint.seq = seq;
                    waypoint.lat = lat;
                    waypoint.lon = lon;
                    waypoint.alt = alt;
                    waypoint.cmd = cmd;
                    waypoint.line_index = line_index;
                    
                    % 添加命令參數
                    if length(parts) >= 8
                        waypoint.param1 = str2double(parts{5});
                        waypoint.param2 = str2double(parts{6});
                        waypoint.param3 = str2double(parts{7});
                        waypoint.param4 = str2double(parts{8});
                    end
                end
                
            catch
                % 忽略解析錯誤的行
            end
        end
        
        function drone_data = parse_csv_file(obj, file_path, drone_id)
            % 解析CSV座標文件
            drone_data = struct();
            drone_data.waypoints = [];
            drone_data.file_path = file_path;
            drone_data.original_lines = {};
            
            try
                % 讀取CSV文件
                data = readtable(file_path);
                
                % 檢查必要的列
                required_cols = {'lat', 'lon', 'alt'};
                available_cols = lower(data.Properties.VariableNames);
                
                col_indices = zeros(1, 3);
                for i = 1:3
                    idx = find(contains(available_cols, required_cols{i}), 1);
                    if isempty(idx)
                        error('CSV文件缺少必要的列: %s', required_cols{i});
                    end
                    col_indices(i) = idx;
                end
                
                % 轉換數據為waypoints
                n_points = height(data);
                for i = 1:n_points
                    waypoint = struct();
                    waypoint.seq = i - 1;
                    waypoint.lat = data{i, col_indices(1)};
                    waypoint.lon = data{i, col_indices(2)};
                    waypoint.alt = data{i, col_indices(3)};
                    
                    % 設置命令類型
                    if i == 1
                        waypoint.cmd = 179; % HOME
                    elseif i == 2
                        waypoint.cmd = 22;  % TAKEOFF
                    elseif i == n_points
                        waypoint.cmd = 20;  % RTL
                    else
                        waypoint.cmd = 16;  % WAYPOINT
                    end
                    
                    waypoint.param1 = 0;
                    waypoint.param2 = 0;
                    waypoint.param3 = 0;
                    waypoint.param4 = 0;
                    
                    drone_data.waypoints = [drone_data.waypoints; waypoint];
                end
                
                fprintf('CSV文件解析完成: %d 個航點\n', length(drone_data.waypoints));
                
            catch ME
                fprintf('CSV文件解析失敗: %s\n', ME.message);
                drone_data = [];
            end
        end
        
        function create_demo_data(obj)
            % 創建演示數據
            fprintf('正在創建演示數據...\n');
            
            % 清理現有數據
            obj.simulator.drones.remove(obj.simulator.drones.keys);
            obj.simulator.current_time = 0.0;
            
            % 基準位置（台灣斗六）
            base_lat = 23.7121;
            base_lon = 120.5363;
            base_alt = 50.0;
            
            % 設置座標原點
            obj.simulator.coordinate_system.set_origin(base_lat, base_lon);
            
            colors = {'r', 'g', 'b', 'y'};
            
            % 創建4架無人機的演示任務
            for i = 1:4
                drone_id = sprintf('Drone_%d', i);
                
                % 創建會產生衝突的航點
                waypoints = obj.create_demo_waypoints(base_lat, base_lon, base_alt, i);
                
                drone_data = struct();
                drone_data.waypoints = waypoints;
                drone_data.trajectory = obj.calculate_trajectory(waypoints);
                drone_data.color = colors{i};
                drone_data.file_path = sprintf('演示任務_%d', i);
                drone_data.original_lines = {};
                drone_data.drone_number = i;
                
                obj.simulator.drones(drone_id) = drone_data;
                
                fprintf('已創建 %s 演示任務: %d 個航點\n', drone_id, length(waypoints));
            end
            
            msgbox('演示數據創建完成！包含潛在衝突點，可測試避撞算法', '創建成功', 'help');
        end
        
        function waypoints = create_demo_waypoints(~, base_lat, base_lon, base_alt, drone_id)
            % 創建演示航點（會產生衝突）
            waypoints = [];
            
            % 每架無人機的偏移量
            lat_offset = (drone_id - 1) * 0.0005;
            lon_offset = (drone_id - 1) * 0.0005;
            
            start_lat = base_lat + lat_offset;
            start_lon = base_lon + lon_offset;
            
            % HOME點
            wp = struct();
            wp.seq = 0;
            wp.lat = start_lat;
            wp.lon = start_lon;
            wp.alt = base_alt;
            wp.cmd = 179;
            wp.param1 = 0; wp.param2 = 0; wp.param3 = 0; wp.param4 = 0;
            waypoints = [waypoints; wp];
            
            % TAKEOFF點
            wp = struct();
            wp.seq = 1;
            wp.lat = start_lat;
            wp.lon = start_lon;
            wp.alt = base_alt + 15;
            wp.cmd = 22;
            wp.param1 = 0; wp.param2 = 0; wp.param3 = 0; wp.param4 = 0;
            waypoints = [waypoints; wp];
            
            % 創建交叉路徑以產生衝突
            if drone_id <= 2
                % 前兩架無人機向右飛
                path_points = [
                    start_lat, start_lon + 0.002, base_alt + 15;
                    start_lat + 0.001, start_lon + 0.002, base_alt + 15;
                    start_lat + 0.001, start_lon, base_alt + 15;
                ];
            else
                % 後兩架無人機向左飛（產生交叉）
                path_points = [
                    start_lat, start_lon - 0.001, base_alt + 15;
                    start_lat + 0.001, start_lon - 0.001, base_alt + 15;
                    start_lat + 0.001, start_lon + 0.001, base_alt + 15;
                ];
            end
            
            % 添加路徑點
            for i = 1:size(path_points, 1)
                wp = struct();
                wp.seq = i + 1;
                wp.lat = path_points(i, 1);
                wp.lon = path_points(i, 2);
                wp.alt = path_points(i, 3) + drone_id; % 輕微高度差
                wp.cmd = 16;
                wp.param1 = 0; wp.param2 = 0; wp.param3 = 0; wp.param4 = 0;
                waypoints = [waypoints; wp];
            end
            
            % RTL點
            wp = struct();
            wp.seq = length(waypoints);
            wp.lat = start_lat;
            wp.lon = start_lon;
            wp.alt = base_alt;
            wp.cmd = 20;
            wp.param1 = 0; wp.param2 = 0; wp.param3 = 0; wp.param4 = 0;
            waypoints = [waypoints; wp];
        end
        
        function trajectory = calculate_trajectory(obj, waypoints)
            % 計算軌跡
            trajectory = [];
            
            if isempty(waypoints)
                return;
            end
            
            current_time = 0;
            cruise_speed = 8.0; % m/s
            climb_rate = 3.0;   % m/s
            
            for i = 1:length(waypoints)
                wp = waypoints(i);
                
                try
                    % GPS轉本地座標
                    [x, y] = obj.simulator.coordinate_system.lat_lon_to_meters(wp.lat, wp.lon);
                    z = wp.alt;
                    
                    % 計算飛行時間
                    if i > 1
                        prev_traj = trajectory(end);
                        
                        dx = x - prev_traj.x;
                        dy = y - prev_traj.y;
                        dz = z - prev_traj.z;
                        
                        horizontal_distance = sqrt(dx^2 + dy^2);
                        vertical_distance = abs(dz);
                        
                        horizontal_time = horizontal_distance / cruise_speed;
                        vertical_time = vertical_distance / climb_rate;
                        
                        travel_time = max(horizontal_time, vertical_time);
                        travel_time = max(travel_time, 1.0); % 最少1秒
                        
                        current_time = current_time + travel_time;
                    end
                    
                    % 創建軌跡點
                    traj_point = struct();
                    traj_point.time = current_time;
                    traj_point.x = x;
                    traj_point.y = y;
                    traj_point.z = z;
                    traj_point.phase = obj.determine_phase(wp.cmd);
                    traj_point.waypoint_index = i;
                    traj_point.speed = cruise_speed;
                    
                    trajectory = [trajectory; traj_point]; %#ok<AGROW>
                    
                catch ME
                    fprintf('航點 %d 計算失敗: %s\n', i, ME.message);
                end
            end
        end
        
        function phase = determine_phase(~, cmd)
            % 確定飛行階段
            switch cmd
                case 22
                    phase = 'takeoff';
                case 16
                    phase = 'waypoint';
                case 179
                    phase = 'home';
                case 20
                    phase = 'rtl';
                case 19
                    phase = 'loiter';
                case 21
                    phase = 'landing';
                otherwise
                    phase = 'auto';
            end
        end
    end
end