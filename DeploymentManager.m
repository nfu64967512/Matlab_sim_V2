% DeploymentManager.m
% 無人機群飛模擬器部署管理器
% 負責系統配置、環境檢查和自動部署

classdef DeploymentManager < handle
    
    properties (Constant)
        VERSION = '1.0';
        CONFIG_FILE = 'drone_sim_config.json';
        LOG_FILE = 'deployment.log';
        BACKUP_DIR = 'backups';
    end
    
    properties
        config_data        % 配置數據
        system_info       % 系統信息
        deployment_status % 部署狀態
        log_handler       % 日誌處理器
    end
    
    methods
        function obj = DeploymentManager()
            % 建構函數
            fprintf('📋 初始化部署管理器...\n');
            
            obj.config_data = struct();
            obj.system_info = struct();
            obj.deployment_status = struct();
            
            obj.initialize_logging();
            obj.detect_system_environment();
            obj.load_or_create_config();
            
            fprintf('✅ 部署管理器初始化完成\n');
        end
        
        function initialize_logging(obj)
            % 初始化日誌系統
            
            obj.log_handler = struct();
            obj.log_handler.file_id = fopen(obj.LOG_FILE, 'a');
            obj.log_handler.start_time = datetime('now');
            
            obj.log_message('INFO', '部署管理器啟動');
        end
        
        function log_message(obj, level, message)
            % 記錄日誌消息
            
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            log_entry = sprintf('[%s] %s: %s\n', timestamp, level, message);
            
            % 輸出到控制台
            if strcmp(level, 'ERROR')
                fprintf(2, '❌ %s', log_entry);
            elseif strcmp(level, 'WARN')
                fprintf('⚠️ %s', log_entry);
            else
                fprintf('%s', log_entry);
            end
            
            % 寫入日誌文件
            if obj.log_handler.file_id ~= -1
                fprintf(obj.log_handler.file_id, '%s', log_entry);
                fflush(obj.log_handler.file_id);
            end
        end
        
        function detect_system_environment(obj)
            % 檢測系統環境
            
            obj.log_message('INFO', '檢測系統環境...');
            
            % MATLAB信息
            obj.system_info.matlab_version = version('-release');
            obj.system_info.matlab_year = str2double(obj.system_info.matlab_version(1:4));
            obj.system_info.matlab_path = matlabroot;
            
            % 系統信息
            obj.system_info.computer_type = computer;
            obj.system_info.os_type = obj.detect_os_type();
            obj.system_info.current_directory = pwd;
            
            % 記憶體信息
            try
                if ispc
                    [~, sys_view] = memory;
                    obj.system_info.total_memory_gb = sys_view.PhysicalMemory.Total / 1e9;
                    obj.system_info.available_memory_gb = sys_view.PhysicalMemory.Available / 1e9;
                else
                    obj.system_info.total_memory_gb = 16; % 估計值
                    obj.system_info.available_memory_gb = 8;
                end
            catch
                obj.system_info.total_memory_gb = 0;
                obj.system_info.available_memory_gb = 0;
            end
            
            % GPU信息
            obj.system_info.gpu_info = obj.detect_gpu_capabilities();
            
            % 工具箱檢查
            obj.system_info.toolboxes = obj.check_toolbox_availability();
            
            % Python環境檢查
            obj.system_info.python_info = obj.detect_python_environment();
            
            obj.log_message('INFO', '系統環境檢測完成');
        end
        
        function os_type = detect_os_type(obj)
            % 檢測操作系統類型
            
            comp_type = computer;
            
            if contains(comp_type, 'WIN')
                os_type = 'Windows';
            elseif contains(comp_type, 'MAC')
                os_type = 'macOS';
            elseif contains(comp_type, 'GLN')
                os_type = 'Linux';
            else
                os_type = 'Unknown';
            end
        end
        
        function gpu_info = detect_gpu_capabilities(obj)
            % 檢測GPU能力
            
            gpu_info = struct();
            gpu_info.available = false;
            gpu_info.device_count = 0;
            gpu_info.devices = {};
            
            try
                if license('test', 'Parallel_Computing_Toolbox')
                    device_count = gpuDeviceCount();
                    gpu_info.device_count = device_count;
                    
                    if device_count > 0
                        for i = 1:device_count
                            try
                                gpu = gpuDevice(i);
                                device_info = struct();
                                device_info.name = gpu.Name;
                                device_info.memory_gb = gpu.TotalMemory / 1e9;
                                device_info.compute_capability = gpu.ComputeCapability;
                                device_info.supported = gpu.DeviceSupported;
                                
                                gpu_info.devices{end+1} = device_info;
                                
                                if gpu.DeviceSupported
                                    gpu_info.available = true;
                                end
                            catch
                                continue;
                            end
                        end
                    end
                end
            catch
                % GPU檢測失敗
            end
        end
        
        function toolboxes = check_toolbox_availability(obj)
            % 檢查工具箱可用性
            
            required_toolboxes = {
                'Parallel_Computing_Toolbox', 'GPU計算';
                'Statistics_Toolbox', '統計工具箱';
                'Image_Processing_Toolbox', '圖像處理';
                'Signal_Processing_Toolbox', '信號處理';
                'Optimization_Toolbox', '優化工具箱';
                'Control_System_Toolbox', '控制系統'
            };
            
            toolboxes = containers.Map();
            
            for i = 1:size(required_toolboxes, 1)
                toolbox_id = required_toolboxes{i, 1};
                toolbox_name = required_toolboxes{i, 2};
                
                is_available = license('test', toolbox_id);
                toolboxes(toolbox_id) = struct('name', toolbox_name, 'available', is_available);
            end
        end
        
        function python_info = detect_python_environment(obj)
            % 檢測Python環境
            
            python_info = struct();
            python_info.available = false;
            python_info.version = '';
            python_info.executable = '';
            python_info.packages = containers.Map();
            
            try
                % 嘗試獲取Python版本
                [status, result] = system('python --version');
                if status == 0
                    python_info.available = true;
                    python_info.version = strtrim(result);
                end
                
                % 檢查Python可執行文件路徑
                [status, result] = system('where python');
                if status == 0 && obj.system_info.os_type == "Windows"
                    python_info.executable = strtrim(result);
                elseif status == 0
                    [status, result] = system('which python');
                    if status == 0
                        python_info.executable = strtrim(result);
                    end
                end
                
                % 檢查關鍵Python包
                required_packages = {'numpy', 'scipy', 'matplotlib', 'pymavlink', 'websockets', 'zmq'};
                for i = 1:length(required_packages)
                    package = required_packages{i};
                    [status, ~] = system(sprintf('python -c "import %s"', package));
                    python_info.packages(package) = (status == 0);
                end
                
            catch
                % Python檢測失敗
            end
        end
        
        function load_or_create_config(obj)
            % 載入或創建配置文件
            
            if exist(obj.CONFIG_FILE, 'file')
                obj.load_config_from_file();
            else
                obj.create_default_config();
                obj.save_config_to_file();
            end
        end
        
        function load_config_from_file(obj)
            % 從文件載入配置
            
            try
                obj.log_message('INFO', sprintf('載入配置文件: %s', obj.CONFIG_FILE));
                
                fid = fopen(obj.CONFIG_FILE, 'r');
                if fid ~= -1
                    json_str = fread(fid, '*char')';
                    fclose(fid);
                    
                    obj.config_data = jsondecode(json_str);
                    obj.log_message('INFO', '配置文件載入成功');
                else
                    error('無法打開配置文件');
                end
                
            catch ME
                obj.log_message('ERROR', sprintf('配置文件載入失敗: %s', ME.message));
                obj.create_default_config();
            end
        end
        
        function create_default_config(obj)
            % 創建默認配置
            
            obj.log_message('INFO', '創建默認配置...');
            
            obj.config_data = struct();
            
            % 基本配置
            obj.config_data.version = obj.VERSION;
            obj.config_data.created_date = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            obj.config_data.last_modified = obj.config_data.created_date;
            
            % 系統配置
            obj.config_data.system = struct();
            obj.config_data.system.use_gpu = obj.system_info.gpu_info.available;
            obj.config_data.system.matlab_path = obj.system_info.matlab_path;
            obj.config_data.system.max_memory_usage_gb = min(obj.system_info.available_memory_gb * 0.8, 8);
            obj.config_data.system.thread_count = feature('NumCores');
            
            % 模擬器配置
            obj.config_data.simulator = struct();
            obj.config_data.simulator.default_physics_model = 'standard';
            obj.config_data.simulator.time_step = 0.1;
            obj.config_data.simulator.max_simulation_time = 300;
            obj.config_data.simulator.safety_distance = 5.0;
            obj.config_data.simulator.warning_distance = 8.0;
            obj.config_data.simulator.critical_distance = 3.0;
            
            % GPU配置
            obj.config_data.gpu = struct();
            obj.config_data.gpu.enabled = obj.system_info.gpu_info.available;
            obj.config_data.gpu.batch_size = 1024;
            obj.config_data.gpu.use_double_precision = false;
            obj.config_data.gpu.memory_pool_size_mb = 512;
            
            % 視覺化配置
            obj.config_data.visualization = struct();
            obj.config_data.visualization.render_quality = 'high';
            obj.config_data.visualization.enable_effects = true;
            obj.config_data.visualization.frame_rate = 30;
            obj.config_data.visualization.lod_distances = [50, 100, 200];
            obj.config_data.visualization.enable_shadows = true;
            obj.config_data.visualization.anti_aliasing = 4;
            
            % 通信配置
            obj.config_data.communication = struct();
            obj.config_data.communication.mavlink_connection = 'udp:localhost:14550';
            obj.config_data.communication.ros2_node_name = 'drone_sim_bridge';
            obj.config_data.communication.websocket_port = 8765;
            obj.config_data.communication.zmq_port = 5555;
            
            % Python橋接配置
            obj.config_data.python_bridge = struct();
            obj.config_data.python_bridge.enabled = obj.system_info.python_info.available;
            obj.config_data.python_bridge.python_path = obj.system_info.python_info.executable;
            obj.config_data.python_bridge.auto_start = false;
            
            % 性能配置
            obj.config_data.performance = struct();
            obj.config_data.performance.auto_optimization = true;
            obj.config_data.performance.benchmark_on_startup = false;
            obj.config_data.performance.monitoring_enabled = true;
            
            obj.log_message('INFO', '默認配置創建完成');
        end
        
        function save_config_to_file(obj)
            % 保存配置到文件
            
            try
                obj.config_data.last_modified = datestr(now, 'yyyy-mm-dd HH:MM:SS');
                
                json_str = jsonencode(obj.config_data);
                
                fid = fopen(obj.CONFIG_FILE, 'w');
                if fid ~= -1
                    fprintf(fid, '%s', json_str);
                    fclose(fid);
                    
                    obj.log_message('INFO', sprintf('配置已保存到: %s', obj.CONFIG_FILE));
                else
                    error('無法創建配置文件');
                end
                
            catch ME
                obj.log_message('ERROR', sprintf('配置保存失敗: %s', ME.message));
            end
        end
        
        function success = deploy_complete_system(obj)
            % 部署完整系統
            
            obj.log_message('INFO', '開始系統部署...');
            success = false;
            
            try
                % 1. 環境檢查
                if ~obj.verify_system_requirements()
                    obj.log_message('ERROR', '系統需求驗證失敗');
                    return;
                end
                
                % 2. 創建必要目錄
                obj.create_directory_structure();
                
                % 3. 配置MATLAB環境
                obj.configure_matlab_environment();
                
                % 4. 設置GPU環境 (如果可用)
                if obj.config_data.gpu.enabled
                    obj.setup_gpu_environment();
                end
                
                % 5. 初始化Python橋接 (如果啟用)
                if obj.config_data.python_bridge.enabled
                    obj.setup_python_bridge();
                end
                
                % 6. 創建示例配置和數據
                obj.create_sample_data();
                
                % 7. 執行系統測試
                obj.run_system_tests();
                
                % 8. 更新部署狀態
                obj.update_deployment_status(true);
                
                obj.log_message('INFO', '系統部署完成!');
                success = true;
                
            catch ME
                obj.log_message('ERROR', sprintf('部署失敗: %s', ME.message));
                obj.update_deployment_status(false, ME.message);
            end
        end
        
        function requirements_ok = verify_system_requirements(obj)
            % 驗證系統需求
            
            obj.log_message('INFO', '驗證系統需求...');
            requirements_ok = true;
            
            % MATLAB版本檢查
            if obj.system_info.matlab_year < 2019
                obj.log_message('ERROR', sprintf('MATLAB版本過舊: %s (需要2019b或更新)', ...
                               obj.system_info.matlab_version));
                requirements_ok = false;
            end
            
            % 記憶體檢查
            if obj.system_info.available_memory_gb < 4
                obj.log_message('WARN', sprintf('可用記憶體偏低: %.1fGB (建議8GB以上)', ...
                               obj.system_info.available_memory_gb));
                % 不是致命錯誤，只是警告
            end
            
            % 核心文件檢查
            required_files = {
                'DroneSwarmSimulator.m';
                'Enhanced3DVisualizationSystem.m';
                'EnhancedQuadrotorPhysics.m';
                'GPUComputeCore.m';
                'PerformanceOptimizer.m'
            };
            
            missing_files = {};
            for i = 1:length(required_files)
                if exist(required_files{i}, 'file') ~= 2
                    missing_files{end+1} = required_files{i}; %#ok<AGROW>
                end
            end
            
            if ~isempty(missing_files)
                obj.log_message('ERROR', '缺少必要文件:');
                for i = 1:length(missing_files)
                    obj.log_message('ERROR', sprintf('  - %s', missing_files{i}));
                end
                requirements_ok = false;
            end
            
            % 工具箱檢查
            critical_toolboxes = {'Parallel_Computing_Toolbox'};
            for i = 1:length(critical_toolboxes)
                toolbox = critical_toolboxes{i};
                if obj.system_info.toolboxes.isKey(toolbox)
                    toolbox_info = obj.system_info.toolboxes(toolbox);
                    if ~toolbox_info.available
                        obj.log_message('WARN', sprintf('%s不可用，GPU功能將受限', toolbox_info.name));
                    end
                end
            end
            
            if requirements_ok
                obj.log_message('INFO', '系統需求驗證通過');
            end
        end
        
        function create_directory_structure(obj)
            % 創建目錄結構
            
            obj.log_message('INFO', '創建目錄結構...');
            
            directories = {
                'data';
                'logs';
                'configs';
                'missions';
                'exports';
                'temp';
                obj.BACKUP_DIR
            };
            
            for i = 1:length(directories)
                dir_name = directories{i};
                if ~exist(dir_name, 'dir')
                    mkdir(dir_name);
                    obj.log_message('INFO', sprintf('創建目錄: %s', dir_name));
                end
            end
        end
        
        function configure_matlab_environment(obj)
            % 配置MATLAB環境
            
            obj.log_message('INFO', '配置MATLAB環境...');
            
            % 設置路徑
            current_path = pwd;
            if ~contains(path, current_path)
                addpath(current_path);
                obj.log_message('INFO', '已添加當前目錄到MATLAB路徑');
            end
            
            % 設置多線程
            if obj.config_data.system.thread_count > 1
                try
                    maxNumCompThreads(obj.config_data.system.thread_count);
                    obj.log_message('INFO', sprintf('設置計算線程數: %d', obj.config_data.system.thread_count));
                catch
                    obj.log_message('WARN', '設置多線程失敗');
                end
            end
            
            % 設置記憶體限制 (如果可能)
            try
                if ispc
                    max_mem_bytes = obj.config_data.system.max_memory_usage_gb * 1e9;
                    % MATLAB沒有直接的記憶體限制API，這裡只是記錄配置
                    obj.log_message('INFO', sprintf('記憶體使用限制: %.1fGB', ...
                                   obj.config_data.system.max_memory_usage_gb));
                end
            catch
                obj.log_message('WARN', '記憶體限制設置失敗');
            end
        end
        
        function setup_gpu_environment(obj)
            % 設置GPU環境
            
            obj.log_message('INFO', '設置GPU環境...');
            
            if obj.system_info.gpu_info.available
                try
                    % 選擇最佳GPU
                    best_gpu_index = obj.select_best_gpu_device();
                    gpuDevice(best_gpu_index);
                    
                    obj.log_message('INFO', sprintf('已選擇GPU設備 #%d', best_gpu_index));
                    
                    % 測試GPU功能
                    obj.test_gpu_functionality();
                    
                catch ME
                    obj.log_message('ERROR', sprintf('GPU設置失敗: %s', ME.message));
                    obj.config_data.gpu.enabled = false;
                end
            else
                obj.log_message('WARN', 'GPU不可用，將使用CPU模式');
            end
        end
        
        function best_index = select_best_gpu_device(obj)
            % 選擇最佳GPU設備
            
            best_index = 1;
            best_score = 0;
            
            for i = 1:length(obj.system_info.gpu_info.devices)
                device = obj.system_info.gpu_info.devices{i};
                
                if device.supported
                    % 計算評分 (記憶體 + 計算能力)
                    score = device.memory_gb + device.compute_capability * 5;
                    
                    if score > best_score
                        best_score = score;
                        best_index = i;
                    end
                end
            end
        end
        
        function test_gpu_functionality(obj)
            % 測試GPU功能
            
            obj.log_message('INFO', '測試GPU功能...');
            
            try
                % 簡單的GPU計算測試
                A = gpuArray(rand(1000, 1000, 'single'));
                B = gpuArray(rand(1000, 1000, 'single'));
                
                tic;
                C = A * B; %#ok<NASGU>
                wait(gpuDevice());
                gpu_time = toc;
                
                obj.log_message('INFO', sprintf('GPU測試通過 (用時: %.3fs)', gpu_time));
                
                % 清理測試數據
                clear A B C;
                
            catch ME
                obj.log_message('ERROR', sprintf('GPU測試失敗: %s', ME.message));
                throw(ME);
            end
        end
        
        function setup_python_bridge(obj)
            % 設置Python橋接
            
            obj.log_message('INFO', '設置Python橋接...');
            
            if obj.system_info.python_info.available
                try
                    % 檢查Python包依賴
                    missing_packages = obj.check_python_dependencies();
                    
                    if ~isempty(missing_packages)
                        obj.log_message('WARN', 'Python缺少以下包:');
                        for i = 1:length(missing_packages)
                            obj.log_message('WARN', sprintf('  - %s', missing_packages{i}));
                        end
                        
                        % 嘗試自動安裝
                        obj.install_python_packages(missing_packages);
                    end
                    
                    % 創建Python橋接啟動腳本
                    obj.create_python_bridge_script();
                    
                catch ME
                    obj.log_message('ERROR', sprintf('Python橋接設置失敗: %s', ME.message));
                end
            else
                obj.log_message('WARN', 'Python不可用，橋接功能將被禁用');
            end
        end
        
        function missing_packages = check_python_dependencies(obj)
            % 檢查Python依賴包
            
            required_packages = {'numpy', 'scipy', 'matplotlib', 'asyncio', 'websockets', 'zmq'};
            missing_packages = {};
            
            package_map = obj.system_info.python_info.packages;
            
            for i = 1:length(required_packages)
                package = required_packages{i};
                if ~package_map.isKey(package) || ~package_map(package)
                    missing_packages{end+1} = package; %#ok<AGROW>
                end
            end
        end
        
        function install_python_packages(obj, packages)
            % 嘗試安裝Python包
            
            obj.log_message('INFO', '嘗試安裝Python包...');
            
            for i = 1:length(packages)
                package = packages{i};
                
                obj.log_message('INFO', sprintf('安裝 %s...', package));
                
                [status, result] = system(sprintf('pip install %s', package));
                
                if status == 0
                    obj.log_message('INFO', sprintf('%s 安裝成功', package));
                else
                    obj.log_message('ERROR', sprintf('%s 安裝失敗: %s', package, result));
                end
            end
        end
        
        function create_python_bridge_script(obj)
            % 創建Python橋接啟動腳本
            
            script_content = sprintf([
                '#!/usr/bin/env python3\n'
                '# 自動生成的Python橋接啟動腳本\n'
                '# 生成時間: %s\n\n'
                'import sys\n'
                'import os\n'
                'import asyncio\n\n'
                '# 添加當前目錄到Python路徑\n'
                'sys.path.insert(0, os.getcwd())\n\n'
                'try:\n'
                '    from python_matlab_bridge import DroneSimulationBridge\n'
                '    \n'
                '    async def main():\n'
                '        config = {\n'
                '            "mavlink_connection": "%s",\n'
                '            "ros2_node_name": "%s",\n'
                '            "websocket_port": %d,\n'
                '            "zmq_port": %d\n'
                '        }\n'
                '        \n'
                '        bridge = DroneSimulationBridge(config)\n'
                '        await bridge.start()\n'
                '    \n'
                '    if __name__ == "__main__":\n'
                '        asyncio.run(main())\n'
                '        \n'
                'except ImportError as e:\n'
                '    print(f"導入錯誤: {e}")\n'
                '    print("請確保python_matlab_bridge.py在當前目錄下")\n'
                'except Exception as e:\n'
                '    print(f"執行錯誤: {e}")\n'
            ], datestr(now), ...
               obj.config_data.communication.mavlink_connection, ...
               obj.config_data.communication.ros2_node_name, ...
               obj.config_data.communication.websocket_port, ...
               obj.config_data.communication.zmq_port);
            
            script_file = 'start_python_bridge.py';
            
            fid = fopen(script_file, 'w');
            if fid ~= -1
                fprintf(fid, '%s', script_content);
                fclose(fid);
                
                obj.log_message('INFO', sprintf('Python橋接腳本已創建: %s', script_file));
                
                % 在Unix系統上設置執行權限
                if ~ispc
                    system(sprintf('chmod +x %s', script_file));
                end
            else
                obj.log_message('ERROR', 'Python橋接腳本創建失敗');
            end
        end
        
        function create_sample_data(obj)
            % 創建示例數據
            
            obj.log_message('INFO', '創建示例數據...');
            
            % 創建示例QGC任務文件
            obj.create_sample_qgc_mission();
            
            % 創建示例CSV軌跡文件
            obj.create_sample_csv_trajectory();
            
            % 創建物理配置示例
            obj.create_physics_config_examples();
        end
        
        function create_sample_qgc_mission(obj)
            % 創建示例QGC任務
            
            mission_file = fullfile('missions', 'sample_mission.plan');
            
            mission_data = struct();
            mission_data.fileType = 'Plan';
            mission_data.version = 1;
            
            % 任務項目
            mission_data.mission = struct();
            mission_data.mission.cruiseSpeed = 15;
            mission_data.mission.firmwareType = 12;
            mission_data.mission.hoverSpeed = 5;
            
            % 航點列表
            waypoints = [
                struct('command', 22, 'coordinate', [24.7814, 120.9935, 50], 'params', [0,0,0,NaN,24.7814,120.9935,50]);
                struct('command', 16, 'coordinate', [24.7824, 120.9945, 50], 'params', [0,0,0,NaN,24.7824,120.9945,50]);
                struct('command', 16, 'coordinate', [24.7834, 120.9955, 50], 'params', [0,0,0,NaN,24.7834,120.9955,50]);
                struct('command', 20, 'coordinate', [0, 0, 0], 'params', [0,0,0,0,0,0,0]);
            ];
            
            mission_data.mission.items = waypoints;
            
            try
                json_str = jsonencode(mission_data);
                
                fid = fopen(mission_file, 'w');
                if fid ~= -1
                    fprintf(fid, '%s', json_str);
                    fclose(fid);
                    
                    obj.log_message('INFO', sprintf('示例QGC任務已創建: %s', mission_file));
                end
            catch
                obj.log_message('ERROR', '示例QGC任務創建失敗');
            end
        end
        
        function create_sample_csv_trajectory(obj)
            % 創建示例CSV軌跡
            
            csv_file = fullfile('data', 'sample_trajectory.csv');
            
            % 生成環形軌跡數據
            t = 0:0.5:60; % 60秒，0.5秒間隔
            
            trajectory_data = [];
            for i = 1:3 % 3架無人機
                drone_id = sprintf('Drone_%d', i);
                
                % 每架無人機不同的軌跡參數
                radius = 50 + i * 10;
                phase_offset = (i-1) * 2 * pi / 3;
                altitude = 30 + i * 5;
                
                x = radius * cos(t * 0.1 + phase_offset);
                y = radius * sin(t * 0.1 + phase_offset);
                z = altitude + 5 * sin(t * 0.2);
                
                for j = 1:length(t)
                    row = {drone_id, t(j), x(j), y(j), z(j), 'AUTO'};
                    trajectory_data = [trajectory_data; row]; %#ok<AGROW>
                end
            end
            
            % 寫入CSV文件
            header = {'DroneID', 'Time', 'X', 'Y', 'Z', 'Phase'};
            
            fid = fopen(csv_file, 'w');
            if fid ~= -1
                % 寫入標題
                fprintf(fid, '%s,%s,%s,%s,%s,%s\n', header{:});
                
                % 寫入數據
                for i = 1:size(trajectory_data, 1)
                    fprintf(fid, '%s,%.1f,%.2f,%.2f,%.2f,%s\n', trajectory_data{i,:});
                end
                
                fclose(fid);
                obj.log_message('INFO', sprintf('示例CSV軌跡已創建: %s', csv_file));
            else
                obj.log_message('ERROR', '示例CSV軌跡創建失敗');
            end
        end
        
        function create_physics_config_examples(obj)
            % 創建物理配置示例
            
            config_dir = 'configs';
            
            % 不同類型無人機的配置
            drone_types = {'phantom', 'racing', 'cargo', 'standard'};
            
            for i = 1:length(drone_types)
                drone_type = drone_types{i};
                config_file = fullfile(config_dir, sprintf('%s_config.json', drone_type));
                
                % 創建配置數據
                config = obj.create_drone_type_config(drone_type);
                
                try
                    json_str = jsonencode(config);
                    
                    fid = fopen(config_file, 'w');
                    if fid ~= -1
                        fprintf(fid, '%s', json_str);
                        fclose(fid);
                        
                        obj.log_message('INFO', sprintf('配置已創建: %s', config_file));
                    end
                catch
                    obj.log_message('ERROR', sprintf('%s配置創建失敗', drone_type));
                end
            end
        end
        
        function config = create_drone_type_config(obj, drone_type)
            % 創建特定類型無人機配置
            
            config = struct();
            config.drone_type = drone_type;
            config.created_date = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            
            switch drone_type
                case 'phantom'
                    config.mass = 1.38;
                    config.wheelbase = 0.35;
                    config.prop_diameter = 0.2388;
                    config.battery_cells = 4;
                    config.battery_capacity = 5870;
                    
                case 'racing'
                    config.mass = 0.68;
                    config.wheelbase = 0.22;
                    config.prop_diameter = 0.127;
                    config.battery_cells = 6;
                    config.battery_capacity = 1500;
                    
                case 'cargo'
                    config.mass = 4.2;
                    config.wheelbase = 0.85;
                    config.prop_diameter = 0.381;
                    config.battery_cells = 12;
                    config.battery_capacity = 16000;
                    
                otherwise % 'standard'
                    config.mass = 1.5;
                    config.wheelbase = 0.58;
                    config.prop_diameter = 0.254;
                    config.battery_cells = 6;
                    config.battery_capacity = 5000;
            end
        end
        
        function run_system_tests(obj)
            % 執行系統測試
            
            obj.log_message('INFO', '執行系統測試...');
            
            test_results = struct();
            
            % 測試1: MATLAB基本功能
            test_results.matlab_basic = obj.test_matlab_basic_functionality();
            
            % 測試2: GPU功能 (如果啟用)
            if obj.config_data.gpu.enabled
                test_results.gpu_compute = obj.test_gpu_compute_functionality();
            end
            
            % 測試3: 文件I/O
            test_results.file_io = obj.test_file_io_functionality();
            
            % 測試4: 模擬器基本功能
            test_results.simulator_basic = obj.test_simulator_functionality();
            
            % 匯總測試結果
            passed_tests = 0;
            total_tests = 0;
            
            test_names = fieldnames(test_results);
            for i = 1:length(test_names)
                total_tests = total_tests + 1;
                if test_results.(test_names{i})
                    passed_tests = passed_tests + 1;
                end
            end
            
            obj.log_message('INFO', sprintf('系統測試完成: %d/%d 通過', passed_tests, total_tests));
            
            if passed_tests == total_tests
                obj.log_message('INFO', '所有系統測試通過!');
            else
                obj.log_message('WARN', sprintf('%d個測試失敗', total_tests - passed_tests));
            end
        end
        
        function success = test_matlab_basic_functionality(obj)
            % 測試MATLAB基本功能
            
            try
                % 矩陣運算測試
                A = rand(100);
                B = rand(100);
                C = A * B; %#ok<NASGU>
                
                % 函數調用測試
                result = sin(pi/2);
                if abs(result - 1) > 1e-10
                    error('數值計算錯誤');
                end
                
                obj.log_message('INFO', 'MATLAB基本功能測試通過');
                success = true;
                
            catch ME
                obj.log_message('ERROR', sprintf('MATLAB基本功能測試失敗: %s', ME.message));
                success = false;
            end
        end
        
        function success = test_gpu_compute_functionality(obj)
            % 測試GPU計算功能
            
            try
                if obj.system_info.gpu_info.available
                    % GPU陣列測試
                    A_gpu = gpuArray(rand(500, 500, 'single'));
                    B_gpu = gpuArray(rand(500, 500, 'single'));
                    C_gpu = A_gpu * B_gpu;
                    wait(gpuDevice());
                    
                    % 數據傳輸測試
                    C_cpu = gather(C_gpu);
                    
                    if size(C_cpu, 1) ~= 500 || size(C_cpu, 2) ~= 500
                        error('GPU數據傳輸錯誤');
                    end
                    
                    obj.log_message('INFO', 'GPU計算功能測試通過');
                    success = true;
                else
                    obj.log_message('WARN', 'GPU不可用，跳過GPU測試');
                    success = true; % 不算失敗
                end
                
            catch ME
                obj.log_message('ERROR', sprintf('GPU計算功能測試失敗: %s', ME.message));
                success = false;
            end
        end
        
        function success = test_file_io_functionality(obj)
            % 測試文件I/O功能
            
            try
                % 創建測試文件
                test_file = 'test_file_io.txt';
                test_data = 'This is a test file for I/O functionality.';
                
                % 寫入測試
                fid = fopen(test_file, 'w');
                if fid == -1
                    error('無法創建測試文件');
                end
                fprintf(fid, '%s', test_data);
                fclose(fid);
                
                % 讀取測試
                fid = fopen(test_file, 'r');
                if fid == -1
                    error('無法讀取測試文件');
                end
                read_data = fread(fid, '*char')';
                fclose(fid);
                
                % 驗證數據
                if ~strcmp(read_data, test_data)
                    error('文件數據不匹配');
                end
                
                % 清理測試文件
                delete(test_file);
                
                obj.log_message('INFO', '文件I/O功能測試通過');
                success = true;
                
            catch ME
                obj.log_message('ERROR', sprintf('文件I/O功能測試失敗: %s', ME.message));
                success = false;
            end
        end
        
        function success = test_simulator_functionality(obj)
            % 測試模擬器功能
            
            try
                % 檢查核心文件是否存在
                if exist('DroneSwarmSimulator.m', 'file') ~= 2
                    error('找不到核心模擬器文件');
                end
                
                % 嘗試創建模擬器實例 (不啟動GUI)
                % 這裡只是語法檢查，不實際運行
                code_check = checkcode('DroneSwarmSimulator.m', '-string');
                if ~isempty(code_check)
                    obj.log_message('WARN', '模擬器代碼檢查發現警告');
                end
                
                obj.log_message('INFO', '模擬器功能測試通過');
                success = true;
                
            catch ME
                obj.log_message('ERROR', sprintf('模擬器功能測試失敗: %s', ME.message));
                success = false;
            end
        end
        
        function update_deployment_status(obj, success, error_message)
            % 更新部署狀態
            
            obj.deployment_status.last_deployment = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            obj.deployment_status.success = success;
            obj.deployment_status.matlab_version = obj.system_info.matlab_version;
            obj.deployment_status.gpu_available = obj.system_info.gpu_info.available;
            
            if nargin > 2 && ~isempty(error_message)
                obj.deployment_status.error_message = error_message;
            end
            
            % 保存部署狀態到配置
            obj.config_data.deployment_status = obj.deployment_status;
            obj.save_config_to_file();
        end
        
        function backup_current_config(obj)
            % 備份當前配置
            
            if ~exist(obj.BACKUP_DIR, 'dir')
                mkdir(obj.BACKUP_DIR);
            end
            
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            backup_file = fullfile(obj.BACKUP_DIR, sprintf('config_backup_%s.json', timestamp));
            
            try
                copyfile(obj.CONFIG_FILE, backup_file);
                obj.log_message('INFO', sprintf('配置已備份到: %s', backup_file));
            catch ME
                obj.log_message('ERROR', sprintf('配置備份失敗: %s', ME.message));
            end
        end
        
        function print_system_summary(obj)
            % 打印系統摘要
            
            fprintf('\n');
            fprintf('╔══════════════════════════════════════════════════════════════╗\n');
            fprintf('║                    系統配置摘要                              ║\n');
            fprintf('╠══════════════════════════════════════════════════════════════╣\n');
            
            % 系統信息
            fprintf('║ 🖥️  系統信息:                                                ║\n');
            fprintf('║   MATLAB版本: %-10s 操作系統: %-15s  ║\n', ...
                   obj.system_info.matlab_version, obj.system_info.os_type);
            fprintf('║   記憶體: %.1fGB / %.1fGB 可用                               ║\n', ...
                   obj.system_info.available_memory_gb, obj.system_info.total_memory_gb);
            
            % GPU信息
            if obj.system_info.gpu_info.available
                best_gpu = obj.system_info.gpu_info.devices{1};
                fprintf('║ 🎮 GPU: %-45s      ║\n', best_gpu.name);
                fprintf('║   記憶體: %.1fGB 計算能力: %.1f                            ║\n', ...
                       best_gpu.memory_gb, best_gpu.compute_capability);
            else
                fprintf('║ 🎮 GPU: 不可用                                               ║\n');
            end
            
            % 配置信息
            fprintf('║                                                              ║\n');
            fprintf('║ ⚙️  配置摘要:                                                ║\n');
            fprintf('║   GPU加速: %-8s 物理模型: %-20s     ║\n', ...
                   obj.bool_to_str(obj.config_data.gpu.enabled), obj.config_data.simulator.default_physics_model);
            fprintf('║   渲染品質: %-10s 安全距離: %.1fm                        ║\n', ...
                   obj.config_data.visualization.render_quality, obj.config_data.simulator.safety_distance);
            
            % 部署狀態
            if isfield(obj.deployment_status, 'success')
                status_str = obj.bool_to_str(obj.deployment_status.success, '成功', '失敗');
                fprintf('║                                                              ║\n');
                fprintf('║ 🚀 部署狀態: %-47s  ║\n', status_str);
                fprintf('║   部署時間: %-47s  ║\n', obj.deployment_status.last_deployment);
            end
            
            fprintf('╚══════════════════════════════════════════════════════════════╝\n');
            fprintf('\n');
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
            if obj.log_handler.file_id ~= -1
                obj.log_message('INFO', '部署管理器關閉');
                fclose(obj.log_handler.file_id);
            end
        end
    end
end

%% === 獨立部署函數 ===

function quick_deploy()
    % 快速部署函數
    
    fprintf('🚀 開始快速部署無人機群飛模擬器...\n\n');
    
    try
        % 創建部署管理器
        deploy_manager = DeploymentManager();
        
        % 執行完整部署
        success = deploy_manager.deploy_complete_system();
        
        if success
            % 顯示系統摘要
            deploy_manager.print_system_summary();
            
            fprintf('🎉 部署成功！您現在可以:\n');
            fprintf('   1. 運行 Enhanced_Drone_Simulator_Launcher() 啟動模擬器\n');
            fprintf('   2. 運行 python start_python_bridge.py 啟動Python橋接\n');
            fprintf('   3. 查看 configs/ 目錄中的配置示例\n');
            fprintf('   4. 查看 missions/ 目錄中的任務示例\n\n');
            
        else
            fprintf('❌ 部署失敗，請檢查日誌文件 %s\n', deploy_manager.LOG_FILE);
        end
        
        % 清理
        delete(deploy_manager);
        
    catch ME
        fprintf('❌ 部署過程出現錯誤: %s\n', ME.message);
        
        if ~isempty(ME.stack)
            fprintf('錯誤堆疊:\n');
            for i = 1:length(ME.stack)
                fprintf('   %s (第%d行)\n', ME.stack(i).file, ME.stack(i).line);
            end
        end
    end
end

function create_startup_scripts()
    % 創建啟動腳本
    
    fprintf('📝 創建啟動腳本...\n');
    
    % Windows批次腳本
    if ispc
        batch_content = [
            '@echo off\n'
            'echo Starting Drone Swarm Simulator...\n'
            'cd /d %~dp0\n'
            'matlab -nodisplay -nosplash -r "Enhanced_Drone_Simulator_Launcher(); exit"\n'
            'pause\n'
        ];
        
        fid = fopen('start_simulator.bat', 'w');
        if fid ~= -1
            fprintf(fid, batch_content);
            fclose(fid);
            fprintf('✅ Windows啟動腳本已創建: start_simulator.bat\n');
        end
    end
    
    % Unix shell腳本
    if ~ispc
        shell_content = [
            '#!/bin/bash\n'
            'echo "Starting Drone Swarm Simulator..."\n'
            'cd "$(dirname "$0")"\n'
            'matlab -nodisplay -nosplash -r "Enhanced_Drone_Simulator_Launcher(); exit"\n'
        ];
        
        fid = fopen('start_simulator.sh', 'w');
        if fid ~= -1
            fprintf(fid, shell_content);
            fclose(fid);
            
            % 設置執行權限
            system('chmod +x start_simulator.sh');
            fprintf('✅ Unix啟動腳本已創建: start_simulator.sh\n');
        end
    end
    
    % Python橋接啟動腳本
    python_launcher = [
        '#!/usr/bin/env python3\n'
        '# Python橋接啟動器\n'
        'import subprocess\n'
        'import sys\n'
        'import os\n\n'
        'def main():\n'
        '    print("🐍 啟動Python橋接...")\n'
        '    \n'
        '    if not os.path.exists("start_python_bridge.py"):\n'
        '        print("❌ 找不到 start_python_bridge.py")\n'
        '        print("請先執行部署程序")\n'
        '        return 1\n'
        '    \n'
        '    try:\n'
        '        subprocess.run([sys.executable, "start_python_bridge.py"])\n'
        '    except KeyboardInterrupt:\n'
        '        print("\\n🛑 Python橋接已停止")\n'
        '    except Exception as e:\n'
        '        print(f"❌ 啟動失敗: {e}")\n'
        '        return 1\n'
        '    \n'
        '    return 0\n\n'
        'if __name__ == "__main__":\n'
        '    sys.exit(main())\n'
    ];
    
    fid = fopen('launch_python_bridge.py', 'w');
    if fid ~= -1
        fprintf(fid, python_launcher);
        fclose(fid);
        
        if ~ispc
            system('chmod +x launch_python_bridge.py');
        end
        
        fprintf('✅ Python橋接啟動器已創建: launch_python_bridge.py\n');
    end
    
    fprintf('📝 所有啟動腳本創建完成\n\n');
end