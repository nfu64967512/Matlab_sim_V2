% SystemMonitor.m
% 無人機群飛模擬器系統監控與診斷工具
% 提供即時性能監控、資源使用追蹤和自動診斷功能

classdef SystemMonitor < handle
    
    properties (Constant)
        VERSION = '1.0';
        UPDATE_INTERVAL = 1.0;  % 監控更新間隔(秒)
        LOG_RETENTION_DAYS = 30; % 日誌保留天數
        ALERT_THRESHOLD_CPU = 85; % CPU使用率警告閾值(%)
        ALERT_THRESHOLD_MEMORY = 90; % 記憶體使用率警告閾值(%)
        ALERT_THRESHOLD_GPU = 95; % GPU記憶體使用率警告閾值(%)
    end
    
    properties
        % 監控狀態
        is_monitoring        % 是否正在監控
        monitor_timer       % 監控定時器
        start_time          % 監控開始時間
        
        % 系統信息
        system_info         % 系統基本信息
        hardware_info       % 硬體信息
        
        % 性能數據
        performance_history % 性能歷史數據
        current_metrics     % 當前性能指標
        alert_history       % 警告歷史
        
        % GUI組件
        monitor_figure      % 監控視窗
        metric_plots        % 性能圖表
        status_panel        % 狀態面板
        
        % 回調函數
        alert_callbacks     % 警告回調函數
        
        % 日誌系統
        log_file_handle     % 日誌文件句柄
        log_buffer          % 日誌緩衝區
    end
    
    methods
        function obj = SystemMonitor()
            % 建構函數
            fprintf('📊 初始化系統監控器...\n');
            
            obj.initialize_properties();
            obj.collect_system_info();
            obj.setup_logging();
            obj.initialize_performance_tracking();
            
            fprintf('✅ 系統監控器初始化完成\n');
        end
        
        function initialize_properties(obj)
            % 初始化屬性
            obj.is_monitoring = false;
            obj.monitor_timer = [];
            obj.start_time = [];
            
            obj.performance_history = containers.Map();
            obj.current_metrics = struct();
            obj.alert_history = {};
            obj.alert_callbacks = containers.Map();
            
            obj.monitor_figure = [];
            obj.metric_plots = containers.Map();
            obj.status_panel = [];
            
            obj.log_buffer = {};
        end
        
        function collect_system_info(obj)
            % 收集系統信息
            
            fprintf('   🔍 收集系統信息...\n');
            
            % 基本系統信息
            obj.system_info = struct();
            obj.system_info.matlab_version = version('-release');
            obj.system_info.computer_type = computer;
            obj.system_info.os_version = obj.get_os_version();
            obj.system_info.cpu_count = feature('NumCores');
            obj.system_info.startup_time = now;
            
            % 硬體信息
            obj.hardware_info = struct();
            obj.collect_memory_info();
            obj.collect_gpu_info();
            obj.collect_storage_info();
        end
        
        function collect_memory_info(obj)
            % 收集記憶體信息
            
            try
                if ispc
                    [~, sys_view] = memory;
                    obj.hardware_info.memory = struct();
                    obj.hardware_info.memory.total_gb = sys_view.PhysicalMemory.Total / 1e9;
                    obj.hardware_info.memory.available_gb = sys_view.PhysicalMemory.Available / 1e9;
                    obj.hardware_info.memory.matlab_usage_mb = sys_view.MemUsedMATLAB / 1e6;
                else
                    % Unix系統的簡化記憶體檢測
                    obj.hardware_info.memory = struct();
                    obj.hardware_info.memory.total_gb = 16.0; % 估計值
                    obj.hardware_info.memory.available_gb = 8.0;
                    obj.hardware_info.memory.matlab_usage_mb = 1000;
                end
            catch
                obj.hardware_info.memory = struct();
                obj.hardware_info.memory.total_gb = 0;
                obj.hardware_info.memory.available_gb = 0;
                obj.hardware_info.memory.matlab_usage_mb = 0;
            end
        end
        
        function collect_gpu_info(obj)
            % 收集GPU信息
            
            obj.hardware_info.gpu = struct();
            obj.hardware_info.gpu.available = false;
            obj.hardware_info.gpu.devices = {};
            
            try
                if license('test', 'Parallel_Computing_Toolbox')
                    gpu_count = gpuDeviceCount();
                    if gpu_count > 0
                        obj.hardware_info.gpu.available = true;
                        
                        for i = 1:gpu_count
                            try
                                gpu = gpuDevice(i);
                                device_info = struct();
                                device_info.name = gpu.Name;
                                device_info.total_memory_gb = gpu.TotalMemory / 1e9;
                                device_info.compute_capability = gpu.ComputeCapability;
                                device_info.supported = gpu.DeviceSupported;
                                
                                obj.hardware_info.gpu.devices{end+1} = device_info;
                            catch
                                continue;
                            end
                        end
                    end
                end
            catch
                % GPU信息收集失敗
            end
        end
        
        function collect_storage_info(obj)
            % 收集存儲信息
            
            obj.hardware_info.storage = struct();
            
            try
                current_dir = pwd;
                
                if ispc
                    % Windows磁碟空間檢查
                    [status, result] = system(sprintf('dir /-c "%s"', current_dir));
                    if status == 0
                        % 解析磁碟空間信息
                        obj.hardware_info.storage.current_drive = current_dir(1:2);
                        obj.hardware_info.storage.available_gb = obj.parse_disk_space(result);
                    end
                else
                    % Unix df命令
                    [status, result] = system(sprintf('df -h "%s"', current_dir));
                    if status == 0
                        obj.hardware_info.storage.available_gb = obj.parse_unix_disk_space(result);
                    end
                end
            catch
                obj.hardware_info.storage.available_gb = 0;
            end
        end
        
        function os_version = get_os_version(obj)
            % 獲取操作系統版本
            
            try
                if ispc
                    [~, result] = system('ver');
                    os_version = strtrim(result);
                elseif ismac
                    [~, result] = system('sw_vers -productVersion');
                    os_version = ['macOS ' strtrim(result)];
                else
                    [~, result] = system('uname -r');
                    os_version = ['Linux ' strtrim(result)];
                end
            catch
                os_version = 'Unknown';
            end
        end
        
        function setup_logging(obj)
            % 設置日誌系統
            
            % 創建日誌目錄
            log_dir = 'logs';
            if ~exist(log_dir, 'dir')
                mkdir(log_dir);
            end
            
            % 創建日誌文件
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            log_filename = fullfile(log_dir, sprintf('system_monitor_%s.log', timestamp));
            
            obj.log_file_handle = fopen(log_filename, 'w');
            if obj.log_file_handle ~= -1
                obj.log_message('INFO', '系統監控日誌已啟動');
            end
            
            % 清理舊日誌文件
            obj.cleanup_old_logs();
        end
        
        function initialize_performance_tracking(obj)
            % 初始化性能追蹤
            
            % 初始化性能歷史數據結構
            metrics = {'cpu_usage', 'memory_usage', 'gpu_memory_usage', ...
                      'matlab_memory', 'fps', 'collision_detection_time'};
            
            for i = 1:length(metrics)
                metric = metrics{i};
                obj.performance_history(metric) = struct();
                obj.performance_history(metric).timestamps = [];
                obj.performance_history(metric).values = [];
                obj.performance_history(metric).max_history = 3600; % 1小時的數據
            end
            
            % 初始化當前指標
            obj.current_metrics = struct();
            for i = 1:length(metrics)
                obj.current_metrics.(metrics{i}) = 0;
            end
        end
        
        function start_monitoring(obj, show_gui)
            % 開始監控
            
            if nargin < 2
                show_gui = true;
            end
            
            if obj.is_monitoring
                fprintf('⚠️ 監控已在運行中\n');
                return;
            end
            
            fprintf('🚀 啟動系統監控...\n');
            
            obj.is_monitoring = true;
            obj.start_time = now;
            
            % 創建監控定時器
            obj.monitor_timer = timer('ExecutionMode', 'fixedRate', ...
                                    'Period', obj.UPDATE_INTERVAL, ...
                                    'TimerFcn', @(~,~)obj.update_monitoring_data());
            
            % 啟動GUI (如果需要)
            if show_gui
                obj.create_monitoring_gui();
            end
            
            % 啟動定時器
            start(obj.monitor_timer);
            
            obj.log_message('INFO', '系統監控已啟動');
            fprintf('✅ 系統監控已啟動\n');
        end
        
        function stop_monitoring(obj)
            % 停止監控
            
            if ~obj.is_monitoring
                fprintf('⚠️ 監控未在運行中\n');
                return;
            end
            
            fprintf('🛑 停止系統監控...\n');
            
            % 停止定時器
            if ~isempty(obj.monitor_timer) && isvalid(obj.monitor_timer)
                stop(obj.monitor_timer);
                delete(obj.monitor_timer);
                obj.monitor_timer = [];
            end
            
            % 關閉GUI
            obj.close_monitoring_gui();
            
            obj.is_monitoring = false;
            
            % 保存監控摘要
            obj.save_monitoring_summary();
            
            obj.log_message('INFO', '系統監控已停止');
            fprintf('✅ 系統監控已停止\n');
        end
        
        function update_monitoring_data(obj)
            % 更新監控數據
            
            try
                current_time = now;
                
                % 收集當前性能數據
                obj.collect_current_performance();
                
                % 更新歷史數據
                obj.update_performance_history(current_time);
                
                % 檢查警告條件
                obj.check_alert_conditions();
                
                % 更新GUI
                obj.update_monitoring_gui();
                
                % 寫入日誌緩衝區
                obj.buffer_log_data();
                
            catch ME
                obj.log_message('ERROR', sprintf('監控數據更新失敗: %s', ME.message));
            end
        end
        
        function collect_current_performance(obj)
            % 收集當前性能數據
            
            % CPU使用率 (簡化估算)
            obj.current_metrics.cpu_usage = obj.estimate_cpu_usage();
            
            % 記憶體使用率
            obj.collect_memory_metrics();
            
            % GPU記憶體使用率
            if obj.hardware_info.gpu.available
                obj.collect_gpu_metrics();
            end
            
            % MATLAB特定指標
            obj.collect_matlab_metrics();
        end
        
        function cpu_usage = estimate_cpu_usage(obj)
            % 估算CPU使用率
            
            persistent last_check_time;
            persistent cpu_busy_time;
            
            if isempty(last_check_time)
                last_check_time = now;
                cpu_busy_time = 0;
                cpu_usage = 0;
                return;
            end
            
            % 簡化的CPU使用率估算
            % 基於MATLAB計算活動程度
            current_time = now;
            time_elapsed = (current_time - last_check_time) * 24 * 3600;
            
            if time_elapsed > 0.5
                % 執行簡單的性能測試來估算CPU負載
                test_start = tic;
                test_matrix = rand(100);
                test_result = trace(test_matrix * test_matrix'); %#ok<NASGU>
                test_time = toc(test_start);
                
                % 基於測試時間估算CPU使用率
                expected_time = 0.001; % 預期時間
                cpu_usage = min(100, max(0, (test_time / expected_time - 1) * 100 + 20));
                
                last_check_time = current_time;
            else
                cpu_usage = obj.current_metrics.cpu_usage; % 保持前一個值
            end
        end
        
        function collect_memory_metrics(obj)
            % 收集記憶體指標
            
            try
                if ispc
                    [~, sys_view] = memory;
                    total_mem = sys_view.PhysicalMemory.Total;
                    available_mem = sys_view.PhysicalMemory.Available;
                    used_mem = total_mem - available_mem;
                    
                    obj.current_metrics.memory_usage = (used_mem / total_mem) * 100;
                    obj.current_metrics.matlab_memory = sys_view.MemUsedMATLAB / 1e6; % MB
                else
                    % Unix系統簡化處理
                    obj.current_metrics.memory_usage = 50; % 估計值
                    obj.current_metrics.matlab_memory = 1000; % MB
                end
            catch
                obj.current_metrics.memory_usage = 0;
                obj.current_metrics.matlab_memory = 0;
            end
        end
        
        function collect_gpu_metrics(obj)
            % 收集GPU指標
            
            try
                gpu = gpuDevice();
                total_mem = gpu.TotalMemory;
                available_mem = gpu.AvailableMemory;
                used_mem = total_mem - available_mem;
                
                obj.current_metrics.gpu_memory_usage = (used_mem / total_mem) * 100;
                
            catch
                obj.current_metrics.gpu_memory_usage = 0;
            end
        end
        
        function collect_matlab_metrics(obj)
            % 收集MATLAB特定指標
            
            % FPS (如果有活動的圖形)
            obj.current_metrics.fps = obj.estimate_graphics_fps();
            
            % 碰撞檢測時間 (如果有模擬器運行)
            obj.current_metrics.collision_detection_time = obj.get_collision_detection_time();
        end
        
        function fps = estimate_graphics_fps(obj)
            % 估算圖形FPS
            
            persistent frame_times;
            persistent last_frame_time;
            
            if isempty(frame_times)
                frame_times = [];
                last_frame_time = now;
                fps = 0;
                return;
            end
            
            current_time = now;
            frame_time = (current_time - last_frame_time) * 24 * 3600;
            
            if frame_time > 0
                frame_times = [frame_times, 1/frame_time];
                
                % 保持最近100幀的數據
                if length(frame_times) > 100
                    frame_times = frame_times(end-99:end);
                end
                
                fps = mean(frame_times);
                last_frame_time = current_time;
            else
                fps = obj.current_metrics.fps; % 保持前一個值
            end
        end
        
        function collision_time = get_collision_detection_time(obj)
            % 獲取碰撞檢測時間
            
            % 嘗試從全局變量或模擬器實例獲取
            collision_time = 0;
            
            try
                % 這裡應該連接到實際的模擬器實例
                % collision_time = simulator.last_collision_check_time;
                collision_time = rand() * 0.01; % 模擬數據
            catch
                collision_time = 0;
            end
        end
        
        function update_performance_history(obj, timestamp)
            % 更新性能歷史
            
            metrics = obj.performance_history.keys;
            
            for i = 1:length(metrics)
                metric = metrics{i};
                history = obj.performance_history(metric);
                
                % 添加新數據點
                history.timestamps = [history.timestamps, timestamp];
                
                if isfield(obj.current_metrics, metric)
                    history.values = [history.values, obj.current_metrics.(metric)];
                else
                    history.values = [history.values, 0];
                end
                
                % 限制歷史數據長度
                if length(history.values) > history.max_history
                    history.timestamps = history.timestamps(end-history.max_history+1:end);
                    history.values = history.values(end-history.max_history+1:end);
                end
                
                obj.performance_history(metric) = history;
            end
        end
        
        function check_alert_conditions(obj)
            % 檢查警告條件
            
            alerts = {};
            
            % CPU使用率警告
            if obj.current_metrics.cpu_usage > obj.ALERT_THRESHOLD_CPU
                alerts{end+1} = struct('type', 'CPU_HIGH', ...
                                     'message', sprintf('CPU使用率過高: %.1f%%', obj.current_metrics.cpu_usage), ...
                                     'severity', 'WARNING');
            end
            
            % 記憶體使用率警告
            if obj.current_metrics.memory_usage > obj.ALERT_THRESHOLD_MEMORY
                alerts{end+1} = struct('type', 'MEMORY_HIGH', ...
                                     'message', sprintf('記憶體使用率過高: %.1f%%', obj.current_metrics.memory_usage), ...
                                     'severity', 'CRITICAL');
            end
            
            % GPU記憶體使用率警告
            if obj.hardware_info.gpu.available && obj.current_metrics.gpu_memory_usage > obj.ALERT_THRESHOLD_GPU
                alerts{end+1} = struct('type', 'GPU_MEMORY_HIGH', ...
                                     'message', sprintf('GPU記憶體使用率過高: %.1f%%', obj.current_metrics.gpu_memory_usage), ...
                                     'severity', 'WARNING');
            end
            
            % FPS過低警告
            if obj.current_metrics.fps < 10 && obj.current_metrics.fps > 0
                alerts{end+1} = struct('type', 'FPS_LOW', ...
                                     'message', sprintf('圖形FPS過低: %.1f', obj.current_metrics.fps), ...
                                     'severity', 'WARNING');
            end
            
            % 處理警告
            for i = 1:length(alerts)
                obj.handle_alert(alerts{i});
            end
        end
        
        function handle_alert(obj, alert)
            % 處理警告
            
            alert.timestamp = now;
            alert.formatted_time = datestr(alert.timestamp, 'yyyy-mm-dd HH:MM:SS');
            
            % 添加到警告歷史
            obj.alert_history{end+1} = alert;
            
            % 記錄到日誌
            obj.log_message('ALERT', sprintf('%s: %s', alert.type, alert.message));
            
            % 調用註冊的回調函數
            if obj.alert_callbacks.isKey(alert.type)
                callback_list = obj.alert_callbacks(alert.type);
                for i = 1:length(callback_list)
                    try
                        callback_list{i}(alert);
                    catch ME
                        obj.log_message('ERROR', sprintf('警告回調函數錯誤: %s', ME.message));
                    end
                end
            end
            
            % 在控制台顯示警告
            severity_symbol = '⚠️';
            if strcmp(alert.severity, 'CRITICAL')
                severity_symbol = '🚨';
            end
            
            fprintf('%s [%s] %s: %s\n', severity_symbol, alert.formatted_time, alert.type, alert.message);
        end
        
        function create_monitoring_gui(obj)
            % 創建監控GUI
            
            if ~isempty(obj.monitor_figure) && isvalid(obj.monitor_figure)
                figure(obj.monitor_figure);
                return;
            end
            
            obj.monitor_figure = figure('Name', '系統性能監控器', ...
                                      'NumberTitle', 'off', ...
                                      'Position', [100, 100, 1200, 800], ...
                                      'Color', [0.1, 0.1, 0.1], ...
                                      'MenuBar', 'none', ...
                                      'ToolBar', 'none', ...
                                      'CloseRequestFcn', @(~,~)obj.close_monitoring_gui());
            
            % 創建子圖
            obj.create_performance_plots();
            
            % 創建狀態面板
            obj.create_status_panel();
            
            % 設置更新定時器
            obj.setup_gui_update_timer();
        end
        
        function create_performance_plots(obj)
            % 創建性能圖表
            
            % CPU使用率圖
            obj.metric_plots('cpu') = subplot(2, 3, 1);
            title('CPU 使用率 (%)', 'Color', 'white');
            xlabel('時間', 'Color', 'white');
            ylabel('使用率 (%)', 'Color', 'white');
            set(gca, 'Color', 'black', 'XColor', 'white', 'YColor', 'white');
            ylim([0, 100]);
            grid on;
            
            % 記憶體使用率圖
            obj.metric_plots('memory') = subplot(2, 3, 2);
            title('記憶體使用率 (%)', 'Color', 'white');
            xlabel('時間', 'Color', 'white');
            ylabel('使用率 (%)', 'Color', 'white');
            set(gca, 'Color', 'black', 'XColor', 'white', 'YColor', 'white');
            ylim([0, 100]);
            grid on;
            
            % GPU記憶體使用率圖
            obj.metric_plots('gpu_memory') = subplot(2, 3, 3);
            title('GPU 記憶體使用率 (%)', 'Color', 'white');
            xlabel('時間', 'Color', 'white');
            ylabel('使用率 (%)', 'Color', 'white');
            set(gca, 'Color', 'black', 'XColor', 'white', 'YColor', 'white');
            ylim([0, 100]);
            grid on;
            
            % MATLAB記憶體使用圖
            obj.metric_plots('matlab_memory') = subplot(2, 3, 4);
            title('MATLAB 記憶體使用 (MB)', 'Color', 'white');
            xlabel('時間', 'Color', 'white');
            ylabel('記憶體 (MB)', 'Color', 'white');
            set(gca, 'Color', 'black', 'XColor', 'white', 'YColor', 'white');
            grid on;
            
            % FPS圖
            obj.metric_plots('fps') = subplot(2, 3, 5);
            title('圖形 FPS', 'Color', 'white');
            xlabel('時間', 'Color', 'white');
            ylabel('FPS', 'Color', 'white');
            set(gca, 'Color', 'black', 'XColor', 'white', 'YColor', 'white');
            grid on;
            
            % 碰撞檢測時間圖
            obj.metric_plots('collision_time') = subplot(2, 3, 6);
            title('碰撞檢測時間 (ms)', 'Color', 'white');
            xlabel('時間', 'Color', 'white');
            ylabel('時間 (ms)', 'Color', 'white');
            set(gca, 'Color', 'black', 'XColor', 'white', 'YColor', 'white');
            grid on;
        end
        
        function create_status_panel(obj)
            % 創建狀態面板
            
            % 這裡可以添加狀態面板的創建代碼
            % 由於MATLAB GUI創建較複雜，這裡提供基本框架
            
            obj.status_panel = struct();
            obj.status_panel.system_info = obj.system_info;
            obj.status_panel.hardware_info = obj.hardware_info;
        end
        
        function setup_gui_update_timer(obj)
            % 設置GUI更新定時器
            
            % GUI更新通過主監控定時器觸發
            % 這裡不需要額外的定時器
        end
        
        function update_monitoring_gui(obj)
            % 更新監控GUI
            
            if isempty(obj.monitor_figure) || ~isvalid(obj.monitor_figure)
                return;
            end
            
            % 更新性能圖表
            obj.update_performance_plots();
            
            % 更新狀態面板
            obj.update_status_display();
        end
        
        function update_performance_plots(obj)
            % 更新性能圖表
            
            plot_configs = {
                'cpu', 'cpu_usage', 'CPU 使用率 (%)', [0, 100];
                'memory', 'memory_usage', '記憶體使用率 (%)', [0, 100];
                'gpu_memory', 'gpu_memory_usage', 'GPU 記憶體使用率 (%)', [0, 100];
                'matlab_memory', 'matlab_memory', 'MATLAB 記憶體使用 (MB)', [];
                'fps', 'fps', '圖形 FPS', [0, 60];
                'collision_time', 'collision_detection_time', '碰撞檢測時間 (ms)', []
            };
            
            for i = 1:size(plot_configs, 1)
                plot_key = plot_configs{i, 1};
                metric_key = plot_configs{i, 2};
                plot_title = plot_configs{i, 3};
                y_limits = plot_configs{i, 4};
                
                if obj.metric_plots.isKey(plot_key) && obj.performance_history.isKey(metric_key)
                    axes(obj.metric_plots(plot_key));
                    
                    history = obj.performance_history(metric_key);
                    
                    if ~isempty(history.timestamps)
                        % 轉換時間戳為相對時間（分鐘）
                        time_minutes = (history.timestamps - obj.start_time) * 24 * 60;
                        
                        plot(time_minutes, history.values, 'cyan', 'LineWidth', 1.5);
                        title(plot_title, 'Color', 'white');
                        xlabel('時間 (分鐘)', 'Color', 'white');
                        
                        if ~isempty(y_limits)
                            ylim(y_limits);
                        end
                        
                        set(gca, 'Color', 'black', 'XColor', 'white', 'YColor', 'white');
                        grid on;
                    end
                end
            end
            
            drawnow;
        end
        
        function update_status_display(obj)
            % 更新狀態顯示
            
            % 這裡可以更新狀態面板的內容
            % 由於MATLAB GUI更新較複雜，提供基本框架
        end
        
        function close_monitoring_gui(obj)
            % 關閉監控GUI
            
            if ~isempty(obj.monitor_figure) && isvalid(obj.monitor_figure)
                delete(obj.monitor_figure);
                obj.monitor_figure = [];
                obj.metric_plots = containers.Map();
            end
        end
        
        function register_alert_callback(obj, alert_type, callback_function)
            % 註冊警告回調函數
            
            if ~obj.alert_callbacks.isKey(alert_type)
                obj.alert_callbacks(alert_type) = {};
            end
            
            callback_list = obj.alert_callbacks(alert_type);
            callback_list{end+1} = callback_function;
            obj.alert_callbacks(alert_type) = callback_list;
            
            obj.log_message('INFO', sprintf('警告回調函數已註冊: %s', alert_type));
        end
        
        function save_monitoring_summary(obj)
            % 保存監控摘要
            
            if isempty(obj.start_time)
                return;
            end
            
            summary = struct();
            summary.session_start = datestr(obj.start_time, 'yyyy-mm-dd HH:MM:SS');
            summary.session_end = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            summary.duration_hours = (now - obj.start_time) * 24;
            
            % 計算統計數據
            metrics = obj.performance_history.keys;
            summary.statistics = struct();
            
            for i = 1:length(metrics)
                metric = metrics{i};
                history = obj.performance_history(metric);
                
                if ~isempty(history.values)
                    stats = struct();
                    stats.mean = mean(history.values);
                    stats.max = max(history.values);
                    stats.min = min(history.values);
                    stats.std = std(history.values);
                    
                    summary.statistics.(metric) = stats;
                end
            end
            
            % 警告摘要
            summary.alert_count = length(obj.alert_history);
            summary.alerts_by_type = obj.summarize_alerts_by_type();
            
            % 保存摘要到文件
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            summary_file = fullfile('logs', sprintf('monitoring_summary_%s.json', timestamp));
            
            try
                json_str = jsonencode(summary);
                fid = fopen(summary_file, 'w');
                if fid ~= -1
                    fprintf(fid, '%s', json_str);
                    fclose(fid);
                    obj.log_message('INFO', sprintf('監控摘要已保存: %s', summary_file));
                end
            catch ME
                obj.log_message('ERROR', sprintf('監控摘要保存失敗: %s', ME.message));
            end
        end
        
        function alerts_summary = summarize_alerts_by_type(obj)
            % 按類型統計警告
            
            alerts_summary = containers.Map();
            
            for i = 1:length(obj.alert_history)
                alert = obj.alert_history{i};
                alert_type = alert.type;
                
                if alerts_summary.isKey(alert_type)
                    alerts_summary(alert_type) = alerts_summary(alert_type) + 1;
                else
                    alerts_summary(alert_type) = 1;
                end
            end
        end
        
        function buffer_log_data(obj)
            % 緩衝日誌數據
            
            % 每10秒寫入一次日誌
            persistent last_log_write;
            
            if isempty(last_log_write)
                last_log_write = now;
            end
            
            if (now - last_log_write) * 24 * 3600 > 10
                obj.flush_log_buffer();
                last_log_write = now;
            end
        end
        
        function flush_log_buffer(obj)
            % 刷新日誌緩衝區
            
            if ~isempty(obj.log_buffer) && obj.log_file_handle ~= -1
                for i = 1:length(obj.log_buffer)
                    fprintf(obj.log_file_handle, '%s', obj.log_buffer{i});
                end
                fflush(obj.log_file_handle);
                obj.log_buffer = {};
            end
        end
        
        function cleanup_old_logs(obj)
            % 清理舊日誌文件
            
            log_dir = 'logs';
            if ~exist(log_dir, 'dir')
                return;
            end
            
            try
                log_files = dir(fullfile(log_dir, 'system_monitor_*.log'));
                current_time = now;
                
                for i = 1:length(log_files)
                    file_date = log_files(i).datenum;
                    age_days = current_time - file_date;
                    
                    if age_days > obj.LOG_RETENTION_DAYS
                        file_path = fullfile(log_dir, log_files(i).name);
                        delete(file_path);
                        obj.log_message('INFO', sprintf('清理舊日誌: %s', log_files(i).name));
                    end
                end
            catch ME
                obj.log_message('ERROR', sprintf('清理舊日誌失敗: %s', ME.message));
            end
        end
        
        function log_message(obj, level, message)
            % 記錄日誌消息
            
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            log_entry = sprintf('[%s] %s: %s\n', timestamp, level, message);
            
            % 添加到緩衝區
            obj.log_buffer{end+1} = log_entry;
            
            % 如果是重要消息，立即寫入
            if strcmp(level, 'ERROR') || strcmp(level, 'CRITICAL')
                if obj.log_file_handle ~= -1
                    fprintf(obj.log_file_handle, '%s', log_entry);
                    fflush(obj.log_file_handle);
                end
            end
        end
        
        function print_current_status(obj)
            % 打印當前狀態
            
            fprintf('\n📊 === 系統監控狀態 ===\n');
            fprintf('監控狀態: %s\n', obj.bool_to_str(obj.is_monitoring, '運行中', '已停止'));
            
            if obj.is_monitoring && ~isempty(obj.start_time)
                runtime = (now - obj.start_time) * 24 * 3600;
                fprintf('運行時間: %.0f 秒\n', runtime);
            end
            
            fprintf('\n💻 當前性能指標:\n');
            fprintf('   CPU使用率: %.1f%%\n', obj.current_metrics.cpu_usage);
            fprintf('   記憶體使用率: %.1f%%\n', obj.current_metrics.memory_usage);
            
            if obj.hardware_info.gpu.available
                fprintf('   GPU記憶體使用率: %.1f%%\n', obj.current_metrics.gpu_memory_usage);
            end
            
            fprintf('   MATLAB記憶體: %.1f MB\n', obj.current_metrics.matlab_memory);
            fprintf('   圖形FPS: %.1f\n', obj.current_metrics.fps);
            
            fprintf('\n🚨 警告統計:\n');
            fprintf('   總警告數: %d\n', length(obj.alert_history));
            
            if ~isempty(obj.alert_history)
                alerts_by_type = obj.summarize_alerts_by_type();
                alert_types = alerts_by_type.keys;
                for i = 1:length(alert_types)
                    alert_type = alert_types{i};
                    count = alerts_by_type(alert_type);
                    fprintf('   %s: %d\n', alert_type, count);
                end
            end
            
            fprintf('========================\n\n');
        end
        
        function generate_diagnostic_report(obj)
            % 生成診斷報告
            
            fprintf('🔧 生成系統診斷報告...\n');
            
            report = struct();
            report.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            report.system_info = obj.system_info;
            report.hardware_info = obj.hardware_info;
            report.current_metrics = obj.current_metrics;
            
            % 性能分析
            report.performance_analysis = obj.analyze_performance_trends();
            
            % 系統健康評估
            report.health_assessment = obj.assess_system_health();
            
            % 建議
            report.recommendations = obj.generate_recommendations();
            
            % 保存報告
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            report_file = fullfile('logs', sprintf('diagnostic_report_%s.json', timestamp));
            
            try
                json_str = jsonencode(report);
                fid = fopen(report_file, 'w');
                if fid ~= -1
                    fprintf(fid, '%s', json_str);
                    fclose(fid);
                    fprintf('✅ 診斷報告已生成: %s\n', report_file);
                end
            catch ME
                fprintf('❌ 診斷報告生成失敗: %s\n', ME.message);
            end
            
            % 打印簡要報告
            obj.print_diagnostic_summary(report);
        end
        
        function analysis = analyze_performance_trends(obj)
            % 分析性能趨勢
            
            analysis = struct();
            
            metrics = {'cpu_usage', 'memory_usage', 'gpu_memory_usage'};
            
            for i = 1:length(metrics)
                metric = metrics{i};
                
                if obj.performance_history.isKey(metric)
                    history = obj.performance_history(metric);
                    
                    if length(history.values) > 10
                        % 計算趨勢
                        recent_values = history.values(end-9:end);
                        trend_slope = obj.calculate_trend_slope(recent_values);
                        
                        analysis.(metric) = struct();
                        analysis.(metric).trend = trend_slope;
                        analysis.(metric).average = mean(history.values);
                        analysis.(metric).peak = max(history.values);
                        analysis.(metric).stability = std(history.values);
                    end
                end
            end
        end
        
        function slope = calculate_trend_slope(obj, values)
            % 計算趨勢斜率
            
            if length(values) < 2
                slope = 0;
                return;
            end
            
            x = 1:length(values);
            p = polyfit(x, values, 1);
            slope = p(1);
        end
        
        function health_score = assess_system_health(obj)
            % 評估系統健康狀況
            
            health_score = struct();
            health_score.overall = 100;
            health_score.details = struct();
            
            % CPU健康評估
            if obj.current_metrics.cpu_usage > 80
                health_score.overall = health_score.overall - 20;
                health_score.details.cpu = 'POOR';
            elseif obj.current_metrics.cpu_usage > 60
                health_score.overall = health_score.overall - 10;
                health_score.details.cpu = 'FAIR';
            else
                health_score.details.cpu = 'GOOD';
            end
            
            % 記憶體健康評估
            if obj.current_metrics.memory_usage > 90
                health_score.overall = health_score.overall - 25;
                health_score.details.memory = 'POOR';
            elseif obj.current_metrics.memory_usage > 70
                health_score.overall = health_score.overall - 15;
                health_score.details.memory = 'FAIR';
            else
                health_score.details.memory = 'GOOD';
            end
            
            % GPU健康評估
            if obj.hardware_info.gpu.available
                if obj.current_metrics.gpu_memory_usage > 95
                    health_score.overall = health_score.overall - 15;
                    health_score.details.gpu = 'POOR';
                elseif obj.current_metrics.gpu_memory_usage > 80
                    health_score.overall = health_score.overall - 5;
                    health_score.details.gpu = 'FAIR';
                else
                    health_score.details.gpu = 'GOOD';
                end
            end
            
            health_score.overall = max(0, health_score.overall);
        end
        
        function recommendations = generate_recommendations(obj)
            % 生成建議
            
            recommendations = {};
            
            % CPU建議
            if obj.current_metrics.cpu_usage > 80
                recommendations{end+1} = 'CPU使用率過高，建議減少同時運行的任務或升級CPU';
            end
            
            % 記憶體建議
            if obj.current_metrics.memory_usage > 85
                recommendations{end+1} = '記憶體使用率過高，建議關閉不必要的應用程式或增加記憶體';
            end
            
            % GPU建議
            if obj.hardware_info.gpu.available && obj.current_metrics.gpu_memory_usage > 90
                recommendations{end+1} = 'GPU記憶體不足，建議減少GPU計算負載或使用更大記憶體的GPU';
            end
            
            % FPS建議
            if obj.current_metrics.fps < 15 && obj.current_metrics.fps > 0
                recommendations{end+1} = '圖形FPS過低，建議降低視覺化設置或檢查圖形驅動程式';
            end
            
            if isempty(recommendations)
                recommendations{1} = '系統運行狀況良好，無特殊建議';
            end
        end
        
        function print_diagnostic_summary(obj, report)
            % 打印診斷摘要
            
            fprintf('\n🏥 === 系統診斷摘要 ===\n');
            fprintf('診斷時間: %s\n', report.timestamp);
            
            if isfield(report, 'health_assessment')
                health = report.health_assessment;
                fprintf('系統健康評分: %.0f/100\n', health.overall);
                
                if isfield(health, 'details')
                    fprintf('   CPU: %s\n', health.details.cpu);
                    fprintf('   記憶體: %s\n', health.details.memory);
                    if isfield(health.details, 'gpu')
                        fprintf('   GPU: %s\n', health.details.gpu);
                    end
                end
            end
            
            if isfield(report, 'recommendations')
                fprintf('\n💡 建議:\n');
                for i = 1:length(report.recommendations)
                    fprintf('   %d. %s\n', i, report.recommendations{i});
                end
            end
            
            fprintf('========================\n\n');
        end
        
        function str = bool_to_str(obj, bool_val, true_str, false_str)
            % 布林值轉字符串
            if nargin < 3
                true_str = '是';
            end
            if nargin < 4
                false_str = '否';
            end
            
            if bool_val
                str = true_str;
            else
                str = false_str;
            end
        end
        
        function delete(obj)
            % 析構函數
            
            % 停止監控
            if obj.is_monitoring
                obj.stop_monitoring();
            end
            
            % 刷新日誌緩衝區
            obj.flush_log_buffer();
            
            % 關閉日誌文件
            if obj.log_file_handle ~= -1
                fclose(obj.log_file_handle);
            end
            
            % 關閉GUI
            obj.close_monitoring_gui();
        end
    end
end

%% === 工具函數 ===

function monitor_demo()
    % 系統監控演示
    
    fprintf('🎬 系統監控演示...\n');
    
    try
        % 創建系統監控器
        monitor = SystemMonitor();
        
        % 註冊警告回調函數
        monitor.register_alert_callback('CPU_HIGH', @(alert) fprintf('🔥 CPU警告: %s\n', alert.message));
        monitor.register_alert_callback('MEMORY_HIGH', @(alert) fprintf('💾 記憶體警告: %s\n', alert.message));
        
        % 開始監控 (帶GUI)
        monitor.start_monitoring(true);
        
        fprintf('監控已開始，運行30秒...\n');
        fprintf('你可以同時運行一些計算來測試警告功能\n');
        
        % 運行30秒
        pause(30);
        
        % 生成診斷報告
        monitor.generate_diagnostic_report();
        
        % 打印當前狀態
        monitor.print_current_status();
        
        % 停止監控
        monitor.stop_monitoring();
        
        % 清理
        delete(monitor);
        
        fprintf('✅ 系統監控演示完成\n');
        
    catch ME
        fprintf('❌ 演示失敗: %s\n', ME.message);
    end
end

function quick_system_check()
    % 快速系統檢查
    
    fprintf('⚡ 快速系統檢查...\n');
    
    try
        monitor = SystemMonitor();
        
        % 收集一次性能數據
        monitor.collect_current_performance();
        
        % 打印基本信息
        fprintf('\n📊 系統狀況:\n');
        fprintf('   CPU使用率: %.1f%%\n', monitor.current_metrics.cpu_usage);
        fprintf('   記憶體使用率: %.1f%%\n', monitor.current_metrics.memory_usage);
        
        if monitor.hardware_info.gpu.available
            fprintf('   GPU記憶體使用率: %.1f%%\n', monitor.current_metrics.gpu_memory_usage);
        else
            fprintf('   GPU: 不可用\n');
        end
        
        fprintf('   MATLAB記憶體: %.1f MB\n', monitor.current_metrics.matlab_memory);
        
        % 健康評估
        health = monitor.assess_system_health();
        fprintf('\n🏥 系統健康評分: %.0f/100\n', health.overall);
        
        % 建議
        recommendations = monitor.generate_recommendations();
        if length(recommendations) > 0 && ~contains(recommendations{1}, '無特殊建議')
            fprintf('\n💡 建議:\n');
            for i = 1:min(3, length(recommendations))
                fprintf('   • %s\n', recommendations{i});
            end
        else
            fprintf('\n✅ 系統運行狀況良好\n');
        end
        
        delete(monitor);
        
    catch ME
        fprintf('❌ 系統檢查失敗: %s\n', ME.message);
    end
    
    fprintf('\n');
end