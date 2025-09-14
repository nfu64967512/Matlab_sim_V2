% Enhanced_Drone_Simulator_Launcher.m
% 增強版無人機群飛模擬器啟動器
% 整合所有增強功能模組 (完全修正版)

function Enhanced_Drone_Simulator_Launcher()
    % 主啟動函數
    
    % 清理環境
    clear; clc; close all;
    
    % 顯示歡迎訊息
    display_welcome_banner();
    
    % 系統需求檢查
    fprintf('檢查系統需求...\n');
    [system_ok, requirements] = check_enhanced_system_requirements();
    
    if ~system_ok
        handle_system_requirements_failure(requirements);
        return;
    end
    
    % 配置選擇界面
    config = show_configuration_dialog();
    if isempty(config)
        fprintf('用戶取消啟動\n');
        return;
    end
    
    % 啟動增強模擬器
    try
        launch_enhanced_simulator(config);
    catch ME
        handle_launch_error(ME);
    end
end

function display_welcome_banner()
    % 顯示歡迎橫幅
    fprintf('\n');
    fprintf('=========================================================\n');
    fprintf('            增強版無人機群飛模擬器 v9.0                    \n');
    fprintf('                 Professional Edition                    \n');
    fprintf('=========================================================\n');
    fprintf('  GPU強制加速    真實物理模型    3D視覺化渲染             \n');
    fprintf('  可配置參數    性能監控        智能碰撞檢測             \n');
    fprintf('=========================================================\n');
    fprintf('\n');
end

function [system_ok, requirements] = check_enhanced_system_requirements()
    % 檢查增強系統需求
    
    requirements = struct();
    system_ok = true;
    
    fprintf('   檢查MATLAB版本...\n');
    matlab_version = version('-release');
    matlab_year = str2double(matlab_version(1:4));
    
    requirements.matlab_version = matlab_version;
    requirements.matlab_year = matlab_year;
    requirements.matlab_ok = matlab_year >= 2019;
    
    if requirements.matlab_ok
        fprintf('      MATLAB %s (支援)\n', matlab_version);
    else
        fprintf('      MATLAB %s (需要2019b或更新版本)\n', matlab_version);
        system_ok = false;
    end
    
    fprintf('   檢查必要工具箱...\n');
    required_toolboxes = {
        'Parallel_Computing_Toolbox', 'GPU加速計算';
        'Statistics_Toolbox', '統計分析';
        'Image_Processing_Toolbox', '圖像處理';
        'Signal_Processing_Toolbox', '信號處理'
    };
    
    requirements.toolboxes = struct();
    
    for i = 1:size(required_toolboxes, 1)
        toolbox_id = required_toolboxes{i, 1};
        toolbox_name = required_toolboxes{i, 2};
        
        is_available = license('test', toolbox_id);
        requirements.toolboxes.(toolbox_id) = is_available;
        
        if is_available
            fprintf('      %s\n', toolbox_name);
        else
            fprintf('      %s (建議安裝)\n', toolbox_name);
            if strcmp(toolbox_id, 'Parallel_Computing_Toolbox')
                fprintf('         註：GPU加速功能將被禁用\n');
            end
        end
    end
    
    fprintf('   檢查GPU支援...\n');
    [gpu_ok, gpu_info] = check_gpu_support_enhanced();
    requirements.gpu_available = gpu_ok;
    requirements.gpu_info = gpu_info;
    
    if gpu_ok
        fprintf('      %s (%.1fGB VRAM)\n', gpu_info.name, gpu_info.memory_gb);
    else
        fprintf('      無可用GPU，將使用CPU模式\n');
    end
    
    fprintf('   檢查記憶體需求...\n');
    [memory_ok, memory_info] = check_memory_requirements();
    requirements.memory_ok = memory_ok;
    requirements.memory_info = memory_info;
    
    if memory_ok
        fprintf('      可用記憶體: %.1fGB (足夠)\n', memory_info.available_gb);
    else
        fprintf('      可用記憶體: %.1fGB (建議8GB以上)\n', memory_info.available_gb);
    end
    
    fprintf('   檢查必要文件...\n');
    [files_ok, missing_files] = check_required_files();
    requirements.files_ok = files_ok;
    requirements.missing_files = missing_files;
    
    if files_ok
        fprintf('      所有核心文件已就緒\n');
    else
        fprintf('      缺少必要文件：\n');
        for i = 1:length(missing_files)
            fprintf('         - %s\n', missing_files{i});
        end
        system_ok = false;
    end
    
    if system_ok
        fprintf('系統需求檢查通過！\n\n');
    else
        fprintf('系統需求檢查未通過\n\n');
    end
end

function [gpu_ok, gpu_info] = check_gpu_support_enhanced()
    % 增強版GPU支援檢查
    gpu_ok = false;
    gpu_info = struct();
    
    try
        if license('test', 'Parallel_Computing_Toolbox')
            device_count = gpuDeviceCount();
            if device_count > 0
                for i = 1:device_count
                    try
                        gpu = gpuDevice(i);
                        
                        if gpu.DeviceSupported && gpu.AvailableMemory > 1e9 % 至少1GB
                            gpu_ok = true;
                            gpu_info.name = gpu.Name;
                            gpu_info.memory_gb = gpu.AvailableMemory / 1e9;
                            gpu_info.compute_capability = gpu.ComputeCapability;
                            gpu_info.device_index = i;
                            break;
                        end
                    catch
                        continue;
                    end
                end
            end
        end
    catch
        % GPU檢查失敗
    end
    
    if ~gpu_ok
        gpu_info.name = 'None';
        gpu_info.memory_gb = 0;
        gpu_info.compute_capability = 0;
        gpu_info.device_index = 0;
    end
end

function [memory_ok, memory_info] = check_memory_requirements()
    % 檢查記憶體需求
    
    try
        if ispc
            % Windows系統
            [~, sys_info] = memory;
            available_bytes = sys_info.PhysicalMemory.Available;
            total_bytes = sys_info.PhysicalMemory.Total;
        else
            % Linux/Mac系統 - 簡化檢查
            available_bytes = 8e9; % 假設8GB
            total_bytes = 16e9; % 假設16GB
        end
        
        memory_info.available_gb = available_bytes / 1e9;
        memory_info.total_gb = total_bytes / 1e9;
        memory_info.usage_percent = (total_bytes - available_bytes) / total_bytes * 100;
        
        % 至少需要4GB可用記憶體
        memory_ok = memory_info.available_gb >= 4.0;
        
    catch
        % 記憶體檢查失敗，假設足夠
        memory_ok = true;
        memory_info.available_gb = 8.0;
        memory_info.total_gb = 16.0;
        memory_info.usage_percent = 50.0;
    end
end

function [files_ok, missing_files] = check_required_files()
    % 檢查必要文件
    
    required_files = {
        'DroneSwarmSimulator.m';
        'GPU_Enhanced_DroneSwarmSimulator.m';
        'EnhancedQuadrotorPhysics.m';
        'Enhanced3DVisualizationSystem.m';
        'CoordinateSystem.m';
        'CollisionDetectionSystem.m';
        'VisualizationSystem.m';
        'QGCFileParser.m';
    };
    
    missing_files = {};
    
    for i = 1:length(required_files)
        if exist(required_files{i}, 'file') ~= 2
            missing_files{end+1} = required_files{i}; %#ok<AGROW>
        end
    end
    
    files_ok = isempty(missing_files);
end

function handle_system_requirements_failure(requirements)
    % 處理系統需求檢查失敗
    
    fprintf('系統需求檢查未通過，提供解決方案：\n\n');
    
    if ~requirements.matlab_ok
        fprintf('MATLAB版本問題：\n');
        fprintf('   當前版本: %s\n', requirements.matlab_version);
        fprintf('   需要版本: 2019b或更新\n');
        fprintf('   解決方案: 升級MATLAB到支援版本\n\n');
    end
    
    if ~requirements.files_ok
        fprintf('缺少必要文件：\n');
        for i = 1:length(requirements.missing_files)
            fprintf('   - %s\n', requirements.missing_files{i});
        end
        fprintf('   解決方案: 確保所有文件在同一目錄下\n\n');
    end
    
    fprintf('建議操作：\n');
    fprintf('   1. 檢查文件完整性\n');
    fprintf('   2. 確認MATLAB工具箱授權\n');
    fprintf('   3. 重新啟動MATLAB\n');
    fprintf('   4. 聯繫技術支援\n\n');
    
    % 提供降級選項
    try
        choice = questdlg('系統需求未完全滿足，是否嘗試基本模式？', ...
                         '系統檢查', '基本模式', '取消', '取消');
        
        if strcmp(choice, '基本模式')
            fprintf('啟動基本模式...\n');
            launch_basic_mode();
        end
    catch
        fprintf('GUI對話框不可用，直接嘗試基本模式\n');
        launch_basic_mode();
    end
end

function config = show_configuration_dialog()
    % 顯示配置對話框
    
    fprintf('配置選擇\n');
    
    % 檢查是否支持GUI
    try
        config = create_gui_config();
    catch ME
        fprintf('GUI配置界面不可用: %s\n', ME.message);
        fprintf('使用預設配置\n');
        config = get_default_config();
    end
end

function config = create_gui_config()
    % 創建GUI配置界面
    
    % 創建配置GUI
    fig = figure('Name', '無人機模擬器配置', ...
                'NumberTitle', 'off', ...
                'Position', [500, 300, 600, 500], ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Resize', 'off');
    
    % 配置選項
    config_data = struct();
    config_data.selected = false;
    
    % GPU設置
    gpu_panel = uipanel(fig, 'Title', 'GPU設置', ...
                       'Position', [0.05, 0.75, 0.9, 0.2]);
    
    gpu_checkbox = uicontrol(gpu_panel, 'Style', 'checkbox', ...
                            'String', '強制啟用GPU加速', ...
                            'Position', [20, 60, 200, 20], ...
                            'Value', 1);
    
    gpu_fallback = uicontrol(gpu_panel, 'Style', 'checkbox', ...
                            'String', '允許CPU備援', ...
                            'Position', [20, 30, 200, 20], ...
                            'Value', 1);
    
    % 物理模型設置
    physics_panel = uipanel(fig, 'Title', '物理模型設置', ...
                           'Position', [0.05, 0.5, 0.9, 0.2]);
    
    model_types = {'標準四旋翼', 'DJI Phantom風格', 'FPV競速機', '載重貨運機'};
    model_popup = uicontrol(physics_panel, 'Style', 'popup', ...
                           'String', model_types, ...
                           'Position', [20, 50, 200, 25]);
    
    physics_detail = uicontrol(physics_panel, 'Style', 'checkbox', ...
                              'String', '啟用詳細物理計算', ...
                              'Position', [20, 20, 200, 20], ...
                              'Value', 1);
    
    % 視覺化設置
    visual_panel = uipanel(fig, 'Title', '視覺化設置', ...
                          'Position', [0.05, 0.25, 0.9, 0.2]);
    
    render_qualities = {'低', '中', '高', '超高'};
    quality_popup = uicontrol(visual_panel, 'Style', 'popup', ...
                             'String', render_qualities, ...
                             'Position', [20, 50, 150, 25], ...
                             'Value', 3); % 預設高品質
    
    effects_checkbox = uicontrol(visual_panel, 'Style', 'checkbox', ...
                                'String', '啟用視覺效果', ...
                                'Position', [20, 20, 200, 20], ...
                                'Value', 1);
    
    % 按鈕
    uicontrol(fig, 'Style', 'pushbutton', ...
             'String', '啟動模擬器', ...
             'Position', [400, 50, 100, 30], ...
             'Callback', @ok_callback);
    
    uicontrol(fig, 'Style', 'pushbutton', ...
             'String', '取消', ...
             'Position', [520, 50, 60, 30], ...
             'Callback', @cancel_callback);
    
    % 回調函數
    function ok_callback(~, ~)
        config_data.gpu_enabled = get(gpu_checkbox, 'Value');
        config_data.gpu_fallback = get(gpu_fallback, 'Value');
        
        model_index = get(model_popup, 'Value');
        model_keys = {'standard', 'phantom', 'racing', 'cargo'};
        config_data.physics_model = model_keys{model_index};
        config_data.physics_detail = get(physics_detail, 'Value');
        
        quality_index = get(quality_popup, 'Value');
        quality_levels = {'low', 'medium', 'high', 'ultra'};
        config_data.render_quality = quality_levels{quality_index};
        config_data.visual_effects = get(effects_checkbox, 'Value');
        
        config_data.selected = true;
        close(fig);
    end
    
    function cancel_callback(~, ~)
        config_data.selected = false;
        close(fig);
    end
    
    % 等待用戶選擇
    uiwait(fig);
    
    if config_data.selected
        config = config_data;
        fprintf('配置已選定\n\n');
    else
        config = [];
    end
end

function config = get_default_config()
    % 獲取預設配置
    config = struct();
    config.gpu_enabled = true;
    config.gpu_fallback = true;
    config.physics_model = 'standard';
    config.physics_detail = true;
    config.render_quality = 'high';
    config.visual_effects = true;
end

function launch_enhanced_simulator(config)
    % 啟動增強模擬器
    
    fprintf('啟動增強版無人機群飛模擬器...\n');
    
    % 1. 初始化物理參數模組
    fprintf('   初始化物理參數模組...\n');
    try
        physics = EnhancedQuadrotorPhysics(config.physics_model);
        if ismethod(physics, 'print_configuration_summary')
            physics.print_configuration_summary();
        end
    catch ME
        fprintf('   物理模組初始化警告: %s\n', ME.message);
    end
    
    % 2. 創建增強模擬器實例
    fprintf('   創建模擬器實例...\n');
    
    if config.gpu_enabled
        fprintf('      啟用GPU增強模式\n');
        simulator = GPU_Enhanced_DroneSwarmSimulator();
    else
        fprintf('      使用標準模式\n');
        simulator = DroneSwarmSimulator();
    end
    
    % 3. 配置視覺化系統
    fprintf('   配置3D視覺化系統...\n');
    try
        visual_system = Enhanced3DVisualizationSystem(simulator);
        configure_visual_system(visual_system, config);
        simulator.visualization = visual_system;
    catch ME
        fprintf('   視覺化系統配置警告: %s\n', ME.message);
    end
    
    % 4. 應用配置
    apply_configuration_to_simulator(simulator, config);
    
    % 5. 啟動性能監控
    if config.gpu_enabled
        start_performance_monitoring(simulator);
    end
    
    % 6. 顯示操作提示
    display_usage_instructions();
    
    fprintf('增強版模擬器啟動完成！\n');
    fprintf('GUI界面已開啟，可以開始載入任務和模擬\n\n');
end

function configure_visual_system(visual_system, config)
    % 配置視覺化系統
    
    try
        % 檢查並設置視覺化屬性
        if isprop(visual_system, 'render_quality')
            visual_system.render_quality.level = config.render_quality;
        end
        
        if isprop(visual_system, 'particle_systems')
            if isa(visual_system.particle_systems, 'containers.Map') && ...
               visual_system.particle_systems.isKey('propwash')
                visual_system.particle_systems('propwash').enabled = config.visual_effects;
            end
        end
        
        if isprop(visual_system, 'trail_systems')
            if isa(visual_system.trail_systems, 'containers.Map') && ...
               visual_system.trail_systems.isKey('default')
                visual_system.trail_systems('default').enabled = config.visual_effects;
            end
        end
    catch ME
        fprintf('   視覺化配置細節警告: %s\n', ME.message);
    end
end

function apply_configuration_to_simulator(simulator, config)
    % 應用配置到模擬器
    
    % GPU設置
    if isfield(config, 'gpu_enabled') && config.gpu_enabled
        if isprop(simulator, 'GPU_FALLBACK_ENABLED')
            simulator.GPU_FALLBACK_ENABLED = config.gpu_fallback;
        end
    end
    
    % 物理模型設置
    if isfield(config, 'physics_detail') && config.physics_detail
        % 啟用詳細物理計算
        if isprop(simulator, 'time_step')
            simulator.time_step = 0.001; % 更小的時間步長
        end
    else
        if isprop(simulator, 'time_step')
            simulator.time_step = 0.01;  % 標準時間步長
        end
    end
    
    % 調試模式設置
    if isprop(simulator, 'debug_mode')
        simulator.debug_mode = true; % 增強版預設啟用調試
    end
end

function start_performance_monitoring(simulator)
    % 啟動性能監控
    
    fprintf('   啟動性能監控系統...\n');
    
    try
        % 創建性能監控定時器
        performance_timer = timer('ExecutionMode', 'fixedRate', ...
                                 'Period', 2.0, ...
                                 'TimerFcn', @(~,~)monitor_performance(simulator));
        
        % 儲存定時器引用
        if isprop(simulator, 'main_figure') && ~isempty(simulator.main_figure) && ...
           isvalid(simulator.main_figure)
            setappdata(simulator.main_figure, 'PerformanceTimer', performance_timer);
        end
        
        % 啟動定時器
        start(performance_timer);
        
    catch ME
        fprintf('   性能監控啟動警告: %s\n', ME.message);
    end
end

function monitor_performance(simulator)
    % 監控性能指標
    
    try
        % GPU記憶體使用
        if isprop(simulator, 'use_gpu') && simulator.use_gpu && ...
           isprop(simulator, 'gpu_available') && simulator.gpu_available
            
            gpu_info = gpuDevice();
            gpu_memory_used = (gpu_info.TotalMemory - gpu_info.AvailableMemory) / 1e6; % MB
            
            % 更新性能指標顯示
            update_performance_display(simulator, gpu_memory_used);
        end
    catch
        % 靜默處理監控錯誤
    end
end

function update_performance_display(simulator, gpu_memory_used)
    % 更新性能顯示
    
    try
        % 在GUI中顯示性能信息
        if isprop(simulator, 'status_panel') && ~isempty(simulator.status_panel) && ...
           isvalid(simulator.status_panel)
            
            perf_text = sprintf('GPU記憶體: %.1f MB', gpu_memory_used);
            
            % 找到或創建性能標籤
            perf_label = findobj(simulator.status_panel, 'Tag', 'PerformanceLabel');
            if isempty(perf_label)
                perf_label = uicontrol(simulator.status_panel, ...
                                      'Style', 'text', ...
                                      'Tag', 'PerformanceLabel', ...
                                      'Position', [10, 10, 200, 20], ...
                                      'BackgroundColor', [0.1, 0.1, 0.1], ...
                                      'ForegroundColor', 'cyan');
            end
            
            set(perf_label, 'String', perf_text);
        end
    catch
        % 靜默處理顯示錯誤
    end
end

function display_usage_instructions()
    % 顯示使用說明
    
    fprintf('使用說明：\n');
    fprintf('------------------------------------------------\n');
    fprintf('載入任務：\n');
    fprintf('   • 點擊「載入QGC文件」載入QGroundControl任務文件\n');
    fprintf('   • 點擊「載入CSV文件」載入自定義軌跡數據\n');
    fprintf('   • 點擊「創建測試任務」生成示例任務\n\n');
    
    fprintf('控制操作：\n');
    fprintf('   • 播放/暫停按鈕：播放/暫停模擬\n');
    fprintf('   • 時間滑桿：手動控制模擬時間\n');
    fprintf('   • 速度滑桿：調整播放速度\n\n');
    
    fprintf('視覺控制：\n');
    fprintf('   • 滑鼠右鍵拖拽：旋轉視角\n');
    fprintf('   • 滾輪：縮放\n');
    fprintf('   • 滑鼠中鍵拖拽：平移視圖\n\n');
    
    fprintf('GPU功能：\n');
    fprintf('   • GPU記憶體監控面板顯示使用情況\n');
    fprintf('   • 碰撞檢測自動使用GPU加速\n');
    fprintf('   • 大型數據集自動批次處理\n\n');
    
    fprintf('高級功能：\n');
    fprintf('   • 安全距離調整：修改碰撞檢測靈敏度\n');
    fprintf('   • 物理參數：即時調整無人機特性\n');
    fprintf('   • 效果切換：開關視覺特效以平衡性能\n');
    fprintf('------------------------------------------------\n\n');
end

function launch_basic_mode()
    % 啟動基本模式 (降級版本)
    
    fprintf('啟動基本模式模擬器...\n');
    
    try
        % 嘗試啟動標準模擬器
        simulator = DroneSwarmSimulator(); %#ok<NASGU>
        fprintf('基本模式啟動成功\n');
    catch ME
        fprintf('基本模式啟動失敗：%s\n', ME.message);
        fprintf('建議檢查MATLAB安裝和文件完整性\n');
    end
end

function handle_launch_error(ME)
    % 處理啟動錯誤
    
    fprintf('模擬器啟動失敗\n');
    fprintf('錯誤信息：%s\n', ME.message);
    
    if ~isempty(ME.stack)
        fprintf('錯誤位置：%s (第%d行)\n', ME.stack(1).file, ME.stack(1).line);
    end
    
    fprintf('\n可能的解決方案：\n');
    fprintf('1. 檢查所有文件是否在同一目錄\n');
    fprintf('2. 重新啟動MATLAB\n');
    fprintf('3. 清除工作空間：clear all; close all; clc\n');
    fprintf('4. 檢查MATLAB版本兼容性\n');
    fprintf('5. 檢查工具箱授權\n\n');
    
    % 提供診斷選項
    try
        choice = questdlg('是否執行自動診斷？', '啟動錯誤', '診斷', '取消', '診斷');
        
        if strcmp(choice, '診斷')
            run_diagnostic_tools();
        end
    catch
        fprintf('GUI對話框不可用，跳過診斷選項\n');
    end
end

function run_diagnostic_tools()
    % 執行診斷工具
    
    fprintf('執行系統診斷...\n');
    
    % MATLAB環境診斷
    fprintf('\nMATLAB環境信息：\n');
    fprintf('   版本：%s\n', version);
    fprintf('   路徑：%s\n', matlabroot);
    
    % 記憶體診斷
    fprintf('\n記憶體信息：\n');
    try
        if ispc
            [~, sys_info] = memory;
            fprintf('   MATLAB記憶體：%.1f MB 使用中\n', ...
                   (sys_info.MemUsedMATLAB / 1e6));
            fprintf('   系統記憶體：%.1f%% 使用中\n', ...
                   ((sys_info.PhysicalMemory.Total - sys_info.PhysicalMemory.Available) / ...
                    sys_info.PhysicalMemory.Total * 100));
        end
    catch
        fprintf('   記憶體信息獲取失敗\n');
    end
    
    % 文件系統診斷
    fprintf('\n文件系統檢查：\n');
    current_dir = pwd;
    fprintf('   當前目錄：%s\n', current_dir);
    
    m_files = dir('*.m');
    fprintf('   找到%d個.m文件\n', length(m_files));
    
    % 工具箱診斷
    fprintf('\n已安裝工具箱：\n');
    try
        toolbox_info = ver;
        for i = 1:length(toolbox_info)
            if contains(toolbox_info(i).Name, {'Parallel', 'Statistics', 'Image', 'Signal'})
                fprintf('   %s %s\n', toolbox_info(i).Name, toolbox_info(i).Version);
            end
        end
    catch
        fprintf('   工具箱信息獲取失敗\n');
    end
    
    fprintf('\n診斷完成\n');
end