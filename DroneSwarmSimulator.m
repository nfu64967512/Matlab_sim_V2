classdef DroneSwarmSimulator < handle
    % =================================================================
    % 整合後的無人機群飛模擬器主類別
    % 結合了GUI控制、軌跡分析、碰撞檢測和視覺化功能
    % =================================================================
    
    properties
        % 核心組件
        coordinate_system   % 座標系統轉換器
        collision_system    % 碰撞檢測系統
        visualization       % 視覺化系統
        qgc_parser         % QGC文件解析器
        
        % 模擬狀態
        drones             % 無人機數據 (containers.Map)
        current_time       % 當前模擬時間
        max_time           % 最大模擬時間
        time_step          % 時間步長
        is_playing         % 是否正在播放
        playback_speed     % 播放速度
        
        % 安全參數
        safety_distance    % 安全距離
        warning_distance   % 警告距離
        critical_distance  % 危險距離
        
        % 系統設置
        use_gpu           % 是否使用GPU
        gpu_available     % GPU是否可用
        debug_mode        % 調試模式
        
        % GUI組件
        main_figure       % 主視窗
        control_panel     % 控制面板
        status_panel      % 狀態面板
        plot_axes         % 3D繪圖軸
        simulation_timer  % 模擬定時器
    end
    
    methods
        function obj = DroneSwarmSimulator()
            % 建構函數
            fprintf('正在初始化無人機群飛模擬器...\n');
            
            obj.initialize_properties();
            obj.check_system_requirements();
            obj.initialize_components();
            obj.setup_gui();
            
            fprintf('無人機群飛模擬器初始化完成\n');
        end
        
        function initialize_properties(obj)
            % 初始化屬性
            obj.drones = containers.Map();
            obj.current_time = 0.0;
            obj.max_time = 100.0;
            obj.time_step = 0.1;
            obj.is_playing = false;
            obj.playback_speed = 1.0;
            
            obj.safety_distance = 5.0;
            obj.warning_distance = 8.0;
            obj.critical_distance = 3.0;
            
            obj.debug_mode = true;
            
            % 檢查GPU可用性
            obj.gpu_available = obj.check_gpu_availability();
            obj.use_gpu = obj.gpu_available;
        end
        
        function gpu_available = check_gpu_availability(~)
            % 檢查GPU是否可用
            gpu_available = false;
            
            try
                if license('test', 'Parallel_Computing_Toolbox')
                    gpu_info = gpuDevice();
                    if gpu_info.DeviceSupported
                        gpu_available = true;
                        fprintf('GPU可用：%s (%.1fGB記憶體)\n', ...
                               gpu_info.Name, gpu_info.AvailableMemory/1e9);
                    end
                end
            catch
                fprintf('GPU不可用，將使用CPU模式\n');
            end
        end
        
        function check_system_requirements(~)
            % 檢查系統需求
            fprintf('正在檢查系統需求...\n');
            
            % 檢查MATLAB版本
            matlab_version = version('-release');
            matlab_year = str2double(matlab_version(1:4));
            
            if matlab_year >= 2019
                fprintf('✅ MATLAB版本：%s\n', matlab_version);
            else
                fprintf('⚠️ MATLAB版本過舊：%s (建議2019b或更新)\n', matlab_version);
            end
            
            % 檢查必要工具箱
            required_toolboxes = {'stats', 'images', 'signal'};
            for i = 1:length(required_toolboxes)
                if license('test', required_toolboxes{i})
                    fprintf('✅ 工具箱可用：%s\n', required_toolboxes{i});
                else
                    fprintf('⚠️ 工具箱不可用：%s\n', required_toolboxes{i});
                end
            end
        end
        
        function initialize_components(obj)
            % 初始化子系統組件
            obj.coordinate_system = CoordinateSystem();
            obj.collision_system = CollisionDetectionSystem(obj);
            obj.visualization = VisualizationSystem(obj);
            obj.qgc_parser = QGCFileParser(obj);
            
            fprintf('所有子系統組件已初始化\n');
        end
        
        function setup_gui(obj)
            % 設置GUI界面
            obj.create_main_figure();
            obj.create_control_panel();
            obj.create_status_panel();
            obj.create_plot_area();
            obj.setup_simulation_timer();
            
            fprintf('GUI界面設置完成\n');
        end
        
        function create_main_figure(obj)
            % 創建主視窗
            obj.main_figure = figure('Name', 'GPU加速無人機群飛模擬器 v8.0', ...
                                    'NumberTitle', 'off', ...
                                    'Position', [100, 100, 1600, 900], ...
                                    'Color', [0.1, 0.1, 0.1], ...
                                    'MenuBar', 'none', ...
                                    'ToolBar', 'none', ...
                                    'CloseRequestFcn', @(~,~)obj.cleanup_and_close());
        end
        
        function create_control_panel(obj)
            % 創建控制面板
            obj.control_panel = uipanel('Parent', obj.main_figure, ...
                                       'Title', '模擬控制', ...
                                       'TitlePosition', 'centertop', ...
                                       'FontSize', 12, ...
                                       'FontWeight', 'bold', ...
                                       'Position', [0.01, 0.65, 0.25, 0.34], ...
                                       'BackgroundColor', [0.15, 0.15, 0.15], ...
                                       'ForegroundColor', 'white');
            
            % 文件操作按鈕
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'pushbutton', ...
                     'String', '載入QGC文件', ...
                     'Position', [10, 260, 200, 35], ...
                     'FontSize', 11, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0, 0.5, 1], ...
                     'ForegroundColor', 'white', ...
                     'Callback', @(~,~)obj.load_qgc_files());
            
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'pushbutton', ...
                     'String', '創建演示數據', ...
                     'Position', [10, 220, 200, 35], ...
                     'FontSize', 11, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0, 0.7, 0.3], ...
                     'ForegroundColor', 'white', ...
                     'Callback', @(~,~)obj.create_demo_data());
            
            % 模擬控制按鈕
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'pushbutton', ...
                     'String', '開始模擬', ...
                     'Position', [10, 180, 95, 35], ...
                     'FontSize', 10, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0, 0.8, 0], ...
                     'ForegroundColor', 'white', ...
                     'Tag', 'start_button', ...
                     'Callback', @(~,~)obj.start_simulation());
            
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'pushbutton', ...
                     'String', '暫停', ...
                     'Position', [115, 180, 95, 35], ...
                     'FontSize', 10, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [1, 0.6, 0], ...
                     'ForegroundColor', 'white', ...
                     'Tag', 'pause_button', ...
                     'Callback', @(~,~)obj.pause_simulation());
            
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'pushbutton', ...
                     'String', '停止', ...
                     'Position', [10, 140, 95, 35], ...
                     'FontSize', 10, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0.8, 0.2, 0.2], ...
                     'ForegroundColor', 'white', ...
                     'Callback', @(~,~)obj.stop_simulation());
            
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'pushbutton', ...
                     'String', '分析碰撞', ...
                     'Position', [115, 140, 95, 35], ...
                     'FontSize', 10, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0.5, 0.5, 0.8], ...
                     'ForegroundColor', 'white', ...
                     'Callback', @(~,~)obj.analyze_collisions());
            
            % 參數控制
            obj.create_parameter_controls();
        end
        
        function create_parameter_controls(obj)
            % 創建參數控制組件
            % 安全距離控制
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'text', ...
                     'String', sprintf('安全距離: %.1f 公尺', obj.safety_distance), ...
                     'Position', [10, 100, 200, 20], ...
                     'FontSize', 10, ...
                     'BackgroundColor', [0.15, 0.15, 0.15], ...
                     'ForegroundColor', 'white', ...
                     'Tag', 'safety_distance_text');
            
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'slider', ...
                     'Min', 2, 'Max', 15, 'Value', obj.safety_distance, ...
                     'Position', [10, 80, 200, 20], ...
                     'Callback', @(src,~)obj.update_safety_distance(src));
            
            % GPU模式切換
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'checkbox', ...
                     'String', 'GPU加速模式', ...
                     'Position', [10, 50, 150, 25], ...
                     'Value', obj.use_gpu, ...
                     'FontSize', 10, ...
                     'BackgroundColor', [0.15, 0.15, 0.15], ...
                     'ForegroundColor', 'white', ...
                     'Enable', obj.get_gpu_enable_status(), ...
                     'Callback', @(src,~)obj.toggle_gpu_mode(src));
            
            % 播放速度控制
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'text', ...
                     'String', sprintf('播放速度: %.1fx', obj.playback_speed), ...
                     'Position', [10, 20, 200, 20], ...
                     'FontSize', 10, ...
                     'BackgroundColor', [0.15, 0.15, 0.15], ...
                     'ForegroundColor', 'white', ...
                     'Tag', 'playback_speed_text');
            
            uicontrol('Parent', obj.control_panel, ...
                     'Style', 'slider', ...
                     'Min', 0.1, 'Max', 5.0, 'Value', obj.playback_speed, ...
                     'Position', [10, 5, 200, 15], ...
                     'Callback', @(src,~)obj.update_playback_speed(src));
        end
        
        function create_status_panel(obj)
            % 創建狀態面板
            obj.status_panel = uipanel('Parent', obj.main_figure, ...
                                      'Title', '系統狀態', ...
                                      'TitlePosition', 'centertop', ...
                                      'FontSize', 12, ...
                                      'FontWeight', 'bold', ...
                                      'Position', [0.01, 0.01, 0.25, 0.63], ...
                                      'BackgroundColor', [0.1, 0.1, 0.1], ...
                                      'ForegroundColor', 'white');
        end
        
        function create_plot_area(obj)
            % 創建3D繪圖區域
            obj.plot_axes = axes('Parent', obj.main_figure, ...
                                'Position', [0.28, 0.05, 0.7, 0.9], ...
                                'Color', 'black');
            
            obj.visualization.setup_3d_axes(obj.plot_axes);
        end
        
        function setup_simulation_timer(obj)
            % 設置模擬定時器
            obj.simulation_timer = timer('ExecutionMode', 'fixedRate', ...
                                        'Period', obj.time_step, ...
                                        'TimerFcn', @(~,~)obj.update_simulation());
        end
        
        % 主要功能方法
        function load_qgc_files(obj)
            % 載入QGC文件
            obj.qgc_parser.load_qgc_files();
            obj.update_max_time();
            obj.update_status_display();
        end
        
        function create_demo_data(obj)
            % 創建演示數據
            obj.qgc_parser.create_demo_data();
            obj.update_max_time();
            obj.collision_system.analyze_trajectory_conflicts();
            obj.visualization.update_3d_plot();
            obj.update_status_display();
        end
        
        function start_simulation(obj)
            % 開始模擬（修正定時器重複啟動問題）
            if obj.drones.Count == 0
                msgbox('請先載入無人機任務文件', '無法開始模擬', 'warn');
                return;
            end
            
            % 檢查定時器狀態，避免重複啟動
            if ~isempty(obj.simulation_timer) && isvalid(obj.simulation_timer)
                timer_status = get(obj.simulation_timer, 'Running');
                if strcmp(timer_status, 'on')
                    fprintf('定時器已在運行中\n');
                    obj.is_playing = true;
                    obj.update_ui_state();
                    return;
                else
                    % 定時器存在但未運行，啟動它
                    obj.is_playing = true;
                    start(obj.simulation_timer);
                end
            else
                % 定時器不存在，重新創建
                obj.setup_simulation_timer();
                obj.is_playing = true;
                if ~isempty(obj.simulation_timer) && isvalid(obj.simulation_timer)
                    start(obj.simulation_timer);
                end
            end
            
            obj.visualization.start_animation();
            
            fprintf('模擬開始 - 總時間: %.1f 秒\n', obj.max_time);
            obj.update_ui_state();
        end
        
        function pause_simulation(obj)
            % 暫停模擬
            obj.is_playing = false;
            
            if ~isempty(obj.simulation_timer) && isvalid(obj.simulation_timer)
                stop(obj.simulation_timer);
            end
            
            obj.visualization.stop_animation();
            
            fprintf('模擬已暫停在時間: %.1f 秒\n', obj.current_time);
            obj.update_ui_state();
        end
        
        function stop_simulation(obj)
            % 停止並重置模擬
            obj.is_playing = false;
            obj.current_time = 0.0;
            
            if ~isempty(obj.simulation_timer) && isvalid(obj.simulation_timer)
                stop(obj.simulation_timer);
            end
            
            obj.visualization.stop_animation();
            obj.visualization.update_3d_plot();
            obj.update_status_display();
            obj.update_ui_state();
            
            fprintf('模擬已停止並重置\n');
        end
        
        function analyze_collisions(obj)
            % 分析軌跡碰撞
            if obj.drones.Count < 2
                msgbox('至少需要2架無人機才能分析碰撞', '無法分析', 'warn');
                return;
            end
            
            obj.collision_system.analyze_trajectory_conflicts();
            obj.visualization.update_3d_plot();
            obj.update_status_display();
        end
        
        function update_simulation(obj)
            % 模擬更新循環
            if ~obj.is_playing
                return;
            end
            
            % 更新時間
            obj.current_time = obj.current_time + obj.time_step * obj.playback_speed;
            
            % 檢查是否結束
            if obj.current_time >= obj.max_time
                obj.pause_simulation();
                msgbox('模擬完成', '模擬結束', 'help');
                return;
            end
            
            % 實時碰撞檢測
            obj.collision_system.check_real_time_collisions(obj.current_time);
            
            % 更新視覺化
            obj.visualization.update_3d_plot();
            obj.update_status_display();
        end
        
        % 輔助方法
        function update_max_time(obj)
            % 更新最大模擬時間
            max_time = 0;
            drone_keys = obj.drones.keys;
            
            for i = 1:length(drone_keys)
                drone_data = obj.drones(drone_keys{i});
                if ~isempty(drone_data.trajectory)
                    last_time = drone_data.trajectory(end).time;
                    max_time = max(max_time, last_time);
                end
            end
            
            obj.max_time = max_time + 15; % 15秒緩衝
        end
        
        function update_safety_distance(obj, slider_handle)
            % 更新安全距離
            new_distance = get(slider_handle, 'Value');
            obj.safety_distance = new_distance;
            obj.warning_distance = new_distance + 3;
            
            % 更新顯示
            text_handle = findobj(obj.control_panel, 'Tag', 'safety_distance_text');
            if ~isempty(text_handle)
                set(text_handle, 'String', sprintf('安全距離: %.1f 公尺', new_distance));
            end
            
            % 重新分析碰撞
            if obj.drones.Count > 1
                obj.collision_system.analyze_trajectory_conflicts();
            end
            
            obj.visualization.update_3d_plot();
        end
        
        function update_playback_speed(obj, slider_handle)
            % 更新播放速度
            new_speed = get(slider_handle, 'Value');
            obj.playback_speed = new_speed;
            
            % 更新顯示
            text_handle = findobj(obj.control_panel, 'Tag', 'playback_speed_text');
            if ~isempty(text_handle)
                set(text_handle, 'String', sprintf('播放速度: %.1fx', new_speed));
            end
            
            % 更新定時器頻率
            if ~isempty(obj.simulation_timer) && isvalid(obj.simulation_timer)
                new_period = obj.time_step / new_speed;
                new_period = max(new_period, 0.01); % 最小10ms
                set(obj.simulation_timer, 'Period', new_period);
            end
        end
        
        function toggle_gpu_mode(obj, checkbox_handle)
            % 切換GPU模式
            if ~obj.gpu_available
                set(checkbox_handle, 'Value', 0);
                msgbox('GPU不可用，無法啟用GPU模式', 'GPU模式', 'warn');
                return;
            end
            
            obj.use_gpu = logical(get(checkbox_handle, 'Value'));
            
            % 重新初始化碰撞檢測系統
            obj.collision_system = CollisionDetectionSystem(obj);
            
            fprintf('計算模式已切換為: %s\n', obj.get_gpu_status_string());
        end
        
        function gpu_status = get_gpu_status_string(obj)
            % 獲取GPU狀態字串
            if obj.gpu_available && obj.use_gpu
                gpu_status = 'GPU加速';
            else
                gpu_status = 'CPU模式';
            end
        end
        
        function enable_status = get_gpu_enable_status(obj)
            % 獲取GPU控制項啟用狀態
            if obj.gpu_available
                enable_status = 'on';
            else
                enable_status = 'off';
            end
        end
        
        function update_ui_state(obj)
            % 更新UI狀態
            start_button = findobj(obj.control_panel, 'Tag', 'start_button');
            pause_button = findobj(obj.control_panel, 'Tag', 'pause_button');
            
            if obj.is_playing
                set(start_button, 'Enable', 'off');
                set(pause_button, 'Enable', 'on');
            else
                set(start_button, 'Enable', 'on');
                set(pause_button, 'Enable', 'off');
            end
        end
        
        function update_status_display(obj)
            % 更新狀態顯示
            % 清除現有狀態文字
            try
                status_children = get(obj.status_panel, 'Children');
                if ~isempty(status_children)
                    text_controls = status_children(strcmp(get(status_children, 'Type'), 'uicontrol'));
                    delete(text_controls);
                end
            catch
                % 忽略清理錯誤
            end
            
            % 創建狀態信息
            status_text = obj.generate_status_text();
            
            % 創建文字框（移除不支援的VerticalAlignment屬性）
            try
                uicontrol('Parent', obj.status_panel, ...
                         'Style', 'text', ...
                         'String', status_text, ...
                         'Position', [10, 10, 380, 520], ...
                         'FontSize', 9, ...
                         'FontName', 'FixedWidth', ...
                         'BackgroundColor', [0.1, 0.1, 0.1], ...
                         'ForegroundColor', 'white', ...
                         'HorizontalAlignment', 'left');
            catch ME
                % 如果仍有錯誤，使用更簡單的方式
                fprintf('狀態顯示更新: %s\n', status_text);
            end
        end
        
        function status_text = generate_status_text(obj)
            % 生成狀態文字
            status_lines = {};
            
            % 系統狀態
            status_lines{end+1} = '=== 系統狀態 ===';
            status_lines{end+1} = sprintf('模擬時間: %.1f / %.1f 秒', obj.current_time, obj.max_time);
            status_lines{end+1} = sprintf('運行狀態: %s', obj.get_simulation_state_text());
            status_lines{end+1} = sprintf('計算模式: %s', obj.get_gpu_status_string());
            status_lines{end+1} = sprintf('安全距離: %.1f 公尺', obj.safety_distance);
            status_lines{end+1} = '';
            
            % 無人機狀態
            status_lines{end+1} = '=== 無人機狀態 ===';
            drone_keys = obj.drones.keys;
            
            if isempty(drone_keys)
                status_lines{end+1} = '無載入的無人機任務';
            else
                for i = 1:length(drone_keys)
                    drone_id = drone_keys{i};
                    drone_data = obj.drones(drone_id);
                    
                    status_lines{end+1} = sprintf('%s:', drone_id);
                    status_lines{end+1} = sprintf('  航點數: %d', length(drone_data.waypoints));
                    
                    if ~isempty(drone_data.trajectory)
                        total_time = drone_data.trajectory(end).time;
                        status_lines{end+1} = sprintf('  任務時間: %.1f 秒', total_time);
                    end
                    
                    status_lines{end+1} = '';
                end
            end
            
            % 安全狀態
            status_lines{end+1} = '=== 安全狀態 ===';
            warnings = obj.collision_system.collision_warnings;
            conflicts = obj.collision_system.trajectory_conflicts;
            
            if isempty(conflicts)
                status_lines{end+1} = '✅ 無軌跡衝突';
            else
                status_lines{end+1} = sprintf('⚠️ %d 個軌跡衝突', length(conflicts));
            end
            
            if isempty(warnings)
                status_lines{end+1} = '✅ 無即時碰撞風險';
            else
                status_lines{end+1} = sprintf('🚨 %d 個即時警告', length(warnings));
            end
            
            % 合併所有行
            status_text = strjoin(status_lines, newline);
        end
        
        function state_text = get_simulation_state_text(obj)
            % 獲取模擬狀態文字
            if obj.is_playing
                state_text = '▶️ 運行中';
            else
                if obj.current_time > 0
                    state_text = '⏸️ 已暫停';
                else
                    state_text = '⏹️ 已停止';
                end
            end
        end
        
        function cleanup_and_close(obj)
            % 清理並關閉
            fprintf('正在清理資源...\n');
            
            obj.stop_simulation();
            
            % 清理定時器
            if ~isempty(obj.simulation_timer) && isvalid(obj.simulation_timer)
                stop(obj.simulation_timer);
                delete(obj.simulation_timer);
            end
            
            % 清理GPU記憶體
            if obj.gpu_available && obj.use_gpu
                try
                    reset(gpuDevice());
                catch
                    % 忽略清理錯誤
                end
            end
            
            delete(obj.main_figure);
            fprintf('=== 模擬器已安全關閉 ===\n');
        end
    end
end